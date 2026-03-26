import AppKit
import Combine
import Foundation
import UserNotifications

enum DownloadSubmissionResult {
    case accepted
    case rejected(String)
}

enum DownloadPreparationResult {
    case queued
    case requiresFormatSelection(YTDLPMediaInfo)
    case rejected(String)
}

actor TransferLimiter {
    private var windowStart = Date()
    private var bytesTransferredInWindow = 0

    func awaitPermit(for bytes: Int, limitKBps: Int) async {
        guard limitKBps > 0 else { return }

        let byteLimit = max(limitKBps * 1024, 1024)

        while true {
            let now = Date()
            if now.timeIntervalSince(windowStart) >= 1 {
                windowStart = now
                bytesTransferredInWindow = 0
            }

            if bytesTransferredInWindow + bytes <= byteLimit {
                bytesTransferredInWindow += bytes
                return
            }

            let remaining = max(0.05, 1 - now.timeIntervalSince(windowStart))
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
    }
}

actor SegmentFileStore {
    private let baseURL: URL
    private var handles: [String: FileHandle] = [:]

    init(fileManager: FileManager = .default) {
        let supportURL = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        baseURL = (supportURL ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("NewNet/Segments", isDirectory: true)

        try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    func prepareSegment(downloadID: UUID, segmentIndex: Int, preserveExisting: Bool) throws {
        let directory = baseURL.appendingPathComponent(downloadID.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = segmentURL(downloadID: downloadID, segmentIndex: segmentIndex)
        if !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            FileManager.default.createFile(atPath: url.path(percentEncoded: false), contents: nil)
        } else if !preserveExisting {
            try FileManager.default.removeItem(at: url)
            FileManager.default.createFile(atPath: url.path(percentEncoded: false), contents: nil)
        }

        let key = handleKey(downloadID: downloadID, segmentIndex: segmentIndex)
        if handles[key] == nil {
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            handles[key] = handle
        }
    }

    func append(_ data: Data, downloadID: UUID, segmentIndex: Int) throws {
        try prepareSegment(downloadID: downloadID, segmentIndex: segmentIndex, preserveExisting: true)
        let key = handleKey(downloadID: downloadID, segmentIndex: segmentIndex)
        guard let handle = handles[key] else { return }
        try handle.write(contentsOf: data)
    }

    func closeHandles(for downloadID: UUID) {
        let prefix = downloadID.uuidString
        for key in handles.keys where key.hasPrefix(prefix) {
            try? handles[key]?.close()
            handles.removeValue(forKey: key)
        }
    }

    func merge(_ item: DownloadItem) throws {
        closeHandles(for: item.id)

        let destination = item.destinationURL
        let parent = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: destination)
        }

        FileManager.default.createFile(atPath: destination.path(percentEncoded: false), contents: nil)
        let destinationHandle = try FileHandle(forWritingTo: destination)

        defer { try? destinationHandle.close() }

        for segment in item.segments.sorted(by: { $0.index < $1.index }) {
            let segmentURL = segmentURL(downloadID: item.id, segmentIndex: segment.index)
            let data = try Data(contentsOf: segmentURL)
            try destinationHandle.write(contentsOf: data)
        }
    }

    func removeArtifacts(for downloadID: UUID) throws {
        closeHandles(for: downloadID)
        let directory = baseURL.appendingPathComponent(downloadID.uuidString, isDirectory: true)
        if FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    private func segmentURL(downloadID: UUID, segmentIndex: Int) -> URL {
        baseURL
            .appendingPathComponent(downloadID.uuidString, isDirectory: true)
            .appendingPathComponent("segment-\(segmentIndex).part")
    }

    private func handleKey(downloadID: UUID, segmentIndex: Int) -> String {
        "\(downloadID.uuidString)-\(segmentIndex)"
    }
}

@MainActor
final class DownloadManager: ObservableObject {
    @Published private(set) var items: [DownloadItem]

    private struct Metadata {
        var fileName: String
        var totalBytes: Int64
        var acceptsRanges: Bool
    }

    private let settings: AppSettings
    private let store: DownloadStore
    private let session: URLSession
    private let fileStore = SegmentFileStore()
    private let limiter = TransferLimiter()
    private let ytDLPService = YTDLPService()

    private var segmentTasks: [UUID: [Int: Task<Void, Never>]] = [:]
    private var preparationTasks: [UUID: Task<Void, Never>] = [:]
    private var ytDLPTasks: [UUID: YTDLPRunningTask] = [:]
    private var ytDLPPausedIDs: Set<UUID> = []
    private var saveTask: Task<Void, Never>?

    init(settings: AppSettings, store: DownloadStore? = nil) {
        self.settings = settings
        self.store = store ?? DownloadStore()

        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60 * 60 * 24
        configuration.httpMaximumConnectionsPerHost = 8

        session = URLSession(configuration: configuration)

        items = self.store.load().sorted(by: { $0.createdAt > $1.createdAt })
        normalizeRestoredState()

        if settings.autoResumeDownloads {
            for item in items where !item.isTerminal {
                resume(id: item.id)
            }
        }
    }

    func prepareDownload(
        from input: String,
        contentPreference: DownloadContentPreference? = nil
    ) async -> DownloadPreparationResult {
        guard let url = validatedURL(from: input) else {
            return .rejected("Enter a valid http or https URL.")
        }

        let effectivePreference = contentPreference ?? settings.preferredMediaType
        let engine: DownloadEngine = ytDLPService.canHandle(url) ? .ytDLP : .native

        if let existingItem = duplicateItem(for: url, engine: engine) {
            if existingItem.isTerminal {
                return .rejected("This link was already downloaded recently.")
            }

            return .rejected("This link is already in your downloads.")
        }

        switch engine {
        case .native:
            enqueue(
                url: url,
                engine: engine,
                contentPreference: effectivePreference,
                ytDLPConfiguration: nil,
                preferredFileName: nil
            )
            return .queued
        case .ytDLP:
            do {
                let mediaInfo = try await ytDLPService.inspectMedia(
                    url: url,
                    settings: settings,
                    preferredContent: effectivePreference
                )
                return .requiresFormatSelection(mediaInfo)
            } catch {
                return .rejected(error.localizedDescription)
            }
        }
    }

    func confirmMediaDownload(
        mediaInfo: YTDLPMediaInfo,
        option: YTDLPDownloadOption
    ) -> DownloadSubmissionResult {
        if let existingItem = duplicateItem(for: mediaInfo.sourceURL, engine: .ytDLP) {
            if existingItem.isTerminal {
                return .rejected("This link was already downloaded recently.")
            }

            return .rejected("This link is already in your downloads.")
        }

        enqueue(
            url: mediaInfo.sourceURL,
            engine: .ytDLP,
            contentPreference: option.configuration.contentPreference,
            ytDLPConfiguration: option.configuration,
            preferredFileName: mediaInfo.title
        )

        return .accepted
    }

    func pause(_ item: DownloadItem) {
        pause(id: item.id)
    }

    func resume(_ item: DownloadItem) {
        resume(id: item.id)
    }

    func open(_ item: DownloadItem) {
        open(id: item.id)
    }

    func pause(id: UUID) {
        guard let index = indexOfItem(id: id) else { return }

        switch items[index].engine {
        case .native:
            cancelNativeTasks(for: id)
            items[index].state = .paused
            items[index].errorDescription = nil
            scheduleSave()
        case .ytDLP:
            pauseYTDLP(id: id)
        }
    }

    func resume(id: UUID) {
        guard let index = indexOfItem(id: id) else { return }
        guard items[index].state != .completed else { return }

        items[index].errorDescription = nil

        switch items[index].engine {
        case .native:
            if items[index].segments.isEmpty {
                prepareNativeDownload(id: id)
                return
            }

            items[index].state = .downloading
            scheduleSave()
            startSegments(for: id)
        case .ytDLP:
            startYTDLPDownload(id: id)
        }
    }

    func openDownloadsFolder() {
        NSWorkspace.shared.open(downloadsDirectory)
    }

    func clearRecentDownloads() {
        items.removeAll { $0.isTerminal }
        scheduleSave()
    }

    func ytDLPBinaryDescription() -> String {
        ytDLPService.discoveredBinaryDescription(settings: settings)
    }

    private var downloadsDirectory: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    }

    private func enqueue(
        url: URL,
        engine: DownloadEngine,
        contentPreference: DownloadContentPreference,
        ytDLPConfiguration: YTDLPDownloadConfiguration?,
        preferredFileName: String?
    ) {
        let id = UUID()
        let defaultName = defaultFileName(for: url, engine: engine, preferredFileName: preferredFileName)

        let item = DownloadItem(
            id: id,
            sourceURL: url,
            destinationURL: engine == .ytDLP ? downloadsDirectory : resolvedDestinationURL(for: defaultName),
            fileName: defaultName,
            engine: engine,
            contentPreference: contentPreference,
            ytDLPConfiguration: ytDLPConfiguration,
            state: .queued,
            createdAt: .now,
            totalBytesExpected: 0,
            downloadedBytes: 0,
            supportsResuming: engine == .ytDLP,
            segments: [],
            errorDescription: nil
        )

        items.insert(item, at: 0)
        scheduleSave()
        resume(id: id)
    }

    private func defaultFileName(for url: URL, engine: DownloadEngine, preferredFileName: String?) -> String {
        switch engine {
        case .native:
            return url.lastPathComponent.ifEmpty("Download-\(UUID().uuidString.prefix(6))")
        case .ytDLP:
            return preferredFileName?.trimmingCharacters(in: .whitespacesAndNewlines)
                .ifEmpty(url.host?.replacingOccurrences(of: "www.", with: "") ?? "Media Download")
                ?? (url.host?.replacingOccurrences(of: "www.", with: "") ?? "Media Download")
        }
    }

    private func normalizeRestoredState() {
        for index in items.indices {
            switch items[index].state {
            case .preparing, .downloading, .completing, .queued:
                items[index].state = .paused
            default:
                break
            }

            if items[index].state == .completed,
               items[index].downloadedBytes == 0 || items[index].totalBytesExpected == 0
            {
                syncFileMetrics(for: index)
            }
        }
    }

    private func prepareNativeDownload(id: UUID) {
        guard let index = indexOfItem(id: id) else { return }

        items[index].state = .preparing
        items[index].errorDescription = nil
        scheduleSave()

        preparationTasks[id]?.cancel()
        preparationTasks[id] = Task { [weak self] in
            guard let self else { return }

            do {
                let metadata = try await self.fetchMetadata(for: self.items[index].sourceURL)
                guard let refreshedIndex = self.indexOfItem(id: id) else { return }

                self.items[refreshedIndex].fileName = metadata.fileName
                self.items[refreshedIndex].destinationURL = self.resolvedDestinationURL(for: metadata.fileName)
                self.items[refreshedIndex].totalBytesExpected = metadata.totalBytes
                self.items[refreshedIndex].supportsResuming = metadata.acceptsRanges && metadata.totalBytes > 0
                self.items[refreshedIndex].segments = self.makeSegments(
                    totalBytes: metadata.totalBytes,
                    supportsRanges: metadata.acceptsRanges
                )
                self.items[refreshedIndex].state = .downloading
                self.scheduleSave()
                self.startSegments(for: id)
            } catch {
                self.markFailed(id: id, message: error.localizedDescription)
            }

            self.preparationTasks[id] = nil
        }
    }

    private func startYTDLPDownload(id: UUID) {
        guard let index = indexOfItem(id: id) else { return }
        guard ytDLPTasks[id] == nil else { return }

        items[index].state = .preparing
        items[index].supportsResuming = true
        items[index].errorDescription = nil
        ytDLPPausedIDs.remove(id)
        scheduleSave()

        Task { [weak self] in
            guard let self else { return }

            do {
                _ = try await self.ytDLPService.ensureInstalled(settings: self.settings)

                let itemRequiresFFmpeg: Bool = await MainActor.run {
                    guard let currentIndex = self.indexOfItem(id: id) else { return false }
                    return self.ytDLPService.requiresFFmpeg(for: self.items[currentIndex])
                }
                if itemRequiresFFmpeg {
                    _ = try await self.ytDLPService.ensureFFmpegInstalled()
                }

                await MainActor.run {
                    guard let refreshedIndex = self.indexOfItem(id: id) else { return }
                    guard self.items[refreshedIndex].state != .paused else { return }

                    self.items[refreshedIndex].state = .downloading
                    self.scheduleSave()

                    do {
                        let item = self.items[refreshedIndex]
                        let task = try self.ytDLPService.startDownload(item: item, settings: self.settings) { [weak self] event in
                            Task { @MainActor [weak self] in
                                self?.handleYTDLPEvent(event, for: id)
                            }
                        }
                        self.ytDLPTasks[id] = task
                    } catch {
                        self.markFailed(id: id, message: error.localizedDescription)
                    }
                }
            } catch {
                await MainActor.run {
                    self.markFailed(id: id, message: error.localizedDescription)
                }
            }
        }
    }

    private func pauseYTDLP(id: UUID) {
        guard let index = indexOfItem(id: id) else { return }
        items[index].state = .paused
        items[index].errorDescription = nil
        ytDLPPausedIDs.insert(id)
        ytDLPTasks[id]?.process.interrupt()
        scheduleSave()
    }

    private func handleYTDLPEvent(_ event: YTDLPEvent, for id: UUID) {
        guard let index = indexOfItem(id: id) else { return }

        switch event {
        case .title(let title):
            items[index].fileName = title
            scheduleSave()

        case .progress(let downloadedBytes, let totalBytes):
            items[index].downloadedBytes = max(items[index].downloadedBytes, downloadedBytes)
            if let totalBytes, totalBytes > 0 {
                items[index].totalBytesExpected = totalBytes
            } else if items[index].totalBytesExpected < items[index].downloadedBytes {
                items[index].totalBytesExpected = items[index].downloadedBytes
            }
            items[index].state = .downloading
            scheduleSave()

        case .finalFile(let fileURL):
            items[index].destinationURL = fileURL
            items[index].fileName = fileURL.lastPathComponent
            syncFileMetrics(for: index, preferredURL: fileURL)
            items[index].state = .completing
            scheduleSave()

        case .terminated(let exitCode, let message):
            ytDLPTasks[id] = nil
            let wasPaused = ytDLPPausedIDs.remove(id) != nil

            if wasPaused {
                items[index].state = .paused
                items[index].errorDescription = nil
                scheduleSave()
                return
            }

            if exitCode == 0 {
                syncFileMetrics(for: index)

                if items[index].totalBytesExpected < items[index].downloadedBytes {
                    items[index].totalBytesExpected = items[index].downloadedBytes
                }

                if items[index].totalBytesExpected == 0, items[index].downloadedBytes > 0 {
                    items[index].totalBytesExpected = items[index].downloadedBytes
                }

                items[index].state = .completed
                items[index].errorDescription = nil
                scheduleSave()
                sendCompletionNotification(for: items[index])
            } else {
                markFailed(id: id, message: message ?? "yt-dlp exited with status \(exitCode).")
            }
        }
    }

    private func makeSegments(totalBytes: Int64, supportsRanges: Bool) -> [DownloadSegment] {
        guard supportsRanges, totalBytes > 0 else {
            return [
                DownloadSegment(index: 0, lowerBound: 0, upperBound: max(totalBytes - 1, -1), receivedBytes: 0)
            ]
        }

        let segmentCount = min(settings.maxSegments, max(1, Int(totalBytes / (2 * 1024 * 1024))))
        let count = max(segmentCount, 1)
        let baseSize = totalBytes / Int64(count)
        let remainder = totalBytes % Int64(count)

        var segments: [DownloadSegment] = []
        var cursor: Int64 = 0

        for index in 0..<count {
            let extraByte: Int64 = Int64(index) < remainder ? 1 : 0
            let segmentSize = baseSize + extraByte
            let upperBound = cursor + segmentSize - 1
            segments.append(
                DownloadSegment(index: index, lowerBound: cursor, upperBound: upperBound, receivedBytes: 0)
            )
            cursor = upperBound + 1
        }

        return segments
    }

    private func startSegments(for id: UUID) {
        guard let index = indexOfItem(id: id) else { return }

        for segment in items[index].segments where !segment.isComplete {
            if segmentTasks[id]?[segment.index] != nil {
                continue
            }

            let task = Task(priority: .utility) { [weak self] in
                guard let self else { return }

                do {
                    try await self.runSegmentDownload(downloadID: id, segmentIndex: segment.index)
                } catch is CancellationError {
                    return
                } catch {
                    await MainActor.run {
                        self.markFailed(id: id, message: error.localizedDescription)
                    }
                }
            }

            segmentTasks[id, default: [:]][segment.index] = task
        }
    }

    private func runSegmentDownload(downloadID: UUID, segmentIndex: Int) async throws {
        guard let itemIndex = indexOfItem(id: downloadID) else { return }
        let item = items[itemIndex]
        guard let segment = item.segments.first(where: { $0.index == segmentIndex }) else { return }
        guard !segment.isComplete else { return }

        try await fileStore.prepareSegment(
            downloadID: downloadID,
            segmentIndex: segmentIndex,
            preserveExisting: segment.receivedBytes > 0
        )

        var request = URLRequest(url: item.sourceURL)
        request.timeoutInterval = 60

        let rangeStart = segment.resumeOffset
        if item.supportsResuming {
            if segment.upperBound >= rangeStart {
                request.setValue("bytes=\(rangeStart)-\(segment.upperBound)", forHTTPHeaderField: "Range")
            } else {
                request.setValue("bytes=\(rangeStart)-", forHTTPHeaderField: "Range")
            }
        }

        let (bytes, response) = try await session.bytes(for: request)

        if item.supportsResuming,
           let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 200,
           segment.index > 0
        {
            throw URLError(.badServerResponse)
        }

        var buffer = Data()
        buffer.reserveCapacity(64 * 1024)

        for try await byte in bytes {
            try Task.checkCancellation()
            buffer.append(byte)

            if buffer.count >= 64 * 1024 {
                try await flush(buffer, for: downloadID, segmentIndex: segmentIndex)
                buffer.removeAll(keepingCapacity: true)
            }
        }

        if !buffer.isEmpty {
            try await flush(buffer, for: downloadID, segmentIndex: segmentIndex)
        }

        await MainActor.run {
            self.finishSegment(downloadID: downloadID, segmentIndex: segmentIndex)
        }
    }

    private func flush(_ data: Data, for downloadID: UUID, segmentIndex: Int) async throws {
        try Task.checkCancellation()
        await limiter.awaitPermit(for: data.count, limitKBps: settings.speedLimitKBps)
        try await fileStore.append(data, downloadID: downloadID, segmentIndex: segmentIndex)

        await MainActor.run {
            guard let itemIndex = self.indexOfItem(id: downloadID) else { return }
            guard let segmentOffset = self.items[itemIndex].segments.firstIndex(where: { $0.index == segmentIndex }) else {
                return
            }

            self.items[itemIndex].segments[segmentOffset].receivedBytes += Int64(data.count)
            self.items[itemIndex].downloadedBytes += Int64(data.count)

            if self.items[itemIndex].totalBytesExpected == 0 {
                self.items[itemIndex].totalBytesExpected = self.items[itemIndex].downloadedBytes
            }

            self.scheduleSave()
        }
    }

    private func finishSegment(downloadID: UUID, segmentIndex: Int) {
        guard let itemIndex = indexOfItem(id: downloadID) else { return }
        guard let segmentOffset = items[itemIndex].segments.firstIndex(where: { $0.index == segmentIndex }) else { return }

        if items[itemIndex].segments[segmentOffset].upperBound < items[itemIndex].segments[segmentOffset].lowerBound {
            items[itemIndex].segments[segmentOffset].upperBound =
                items[itemIndex].segments[segmentOffset].lowerBound +
                items[itemIndex].segments[segmentOffset].receivedBytes - 1
            items[itemIndex].totalBytesExpected = items[itemIndex].downloadedBytes
        }

        segmentTasks[downloadID]?[segmentIndex] = nil

        let expectedBytes = items[itemIndex].segments[segmentOffset].expectedBytes
        if expectedBytes > 0 {
            items[itemIndex].segments[segmentOffset].receivedBytes = expectedBytes
        }

        if items[itemIndex].segments.allSatisfy(\.isComplete) {
            items[itemIndex].state = .completing
            scheduleSave()
            completeNativeDownload(id: downloadID)
        } else {
            items[itemIndex].state = .downloading
            scheduleSave()
        }
    }

    private func completeNativeDownload(id: UUID) {
        Task { [weak self] in
            guard let self else { return }
            guard let itemIndex = self.indexOfItem(id: id) else { return }
            let item = self.items[itemIndex]

            do {
                try await self.fileStore.merge(item)
                try await self.fileStore.removeArtifacts(for: id)

                guard let refreshedIndex = self.indexOfItem(id: id) else { return }
                self.items[refreshedIndex].state = .completed
                self.items[refreshedIndex].errorDescription = nil
                self.scheduleSave()
                self.sendCompletionNotification(for: self.items[refreshedIndex])
            } catch {
                self.markFailed(id: id, message: error.localizedDescription)
            }
        }
    }

    private func markFailed(id: UUID, message: String) {
        cancelDownloadWork(for: id)
        guard let index = indexOfItem(id: id) else { return }
        items[index].state = .failed
        items[index].errorDescription = message
        scheduleSave()
    }

    private func cancelDownloadWork(for id: UUID) {
        cancelNativeTasks(for: id)

        ytDLPPausedIDs.remove(id)
        if let task = ytDLPTasks.removeValue(forKey: id) {
            task.process.terminate()
        }
    }

    private func cancelNativeTasks(for id: UUID) {
        preparationTasks[id]?.cancel()
        preparationTasks[id] = nil

        segmentTasks[id]?.values.forEach { $0.cancel() }
        segmentTasks[id] = nil

        Task {
            await fileStore.closeHandles(for: id)
        }
    }

    private func fetchMetadata(for url: URL) async throws -> Metadata {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 30

        do {
            let (_, response) = try await session.data(for: request)
            return metadata(from: response, fallbackURL: url)
        } catch {
            var fallback = URLRequest(url: url)
            fallback.httpMethod = "GET"
            fallback.setValue("bytes=0-0", forHTTPHeaderField: "Range")
            fallback.timeoutInterval = 30

            let (_, response) = try await session.data(for: fallback)
            return metadata(from: response, fallbackURL: url)
        }
    }

    private func metadata(from response: URLResponse, fallbackURL: URL) -> Metadata {
        let fileName = response.suggestedFilename ?? fallbackURL.lastPathComponent.ifEmpty("Download")
        let totalBytes = max(response.expectedContentLength, 0)

        let acceptsRanges: Bool
        if let httpResponse = response as? HTTPURLResponse {
            acceptsRanges = httpResponse.value(forHTTPHeaderField: "Accept-Ranges")?.contains("bytes") == true
        } else {
            acceptsRanges = false
        }

        return Metadata(fileName: fileName, totalBytes: totalBytes, acceptsRanges: acceptsRanges)
    }

    private func resolvedDestinationURL(for fileName: String) -> URL {
        let sanitized = fileName.isEmpty ? "Download" : fileName

        let fileExtension = URL(fileURLWithPath: sanitized).pathExtension
        let baseName = URL(fileURLWithPath: sanitized).deletingPathExtension().lastPathComponent

        var candidate = downloadsDirectory.appendingPathComponent(sanitized)
        var attempt = 1

        while FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
            let suffix = " \(attempt)"
            let name = baseName + suffix + (fileExtension.isEmpty ? "" : ".\(fileExtension)")
            candidate = downloadsDirectory.appendingPathComponent(name)
            attempt += 1
        }

        return candidate
    }

    private func indexOfItem(id: UUID) -> Int? {
        items.firstIndex(where: { $0.id == id })
    }

    private func open(id: UUID) {
        guard let index = indexOfItem(id: id) else { return }

        let destinationURL = items[index].destinationURL
        let destinationPath = destinationURL.path(percentEncoded: false)

        if FileManager.default.fileExists(atPath: destinationPath) {
            NSWorkspace.shared.open(destinationURL)
            return
        }

        NSWorkspace.shared.open(downloadsDirectory)
    }

    private func duplicateItem(for url: URL, engine: DownloadEngine) -> DownloadItem? {
        let normalizedCandidate = normalizedURLString(for: url)
        let now = Date()

        return items.first { item in
            guard item.engine == engine else { return false }
            guard normalizedURLString(for: item.sourceURL) == normalizedCandidate else { return false }

            if !item.isTerminal {
                return true
            }

            if item.state == .completed {
                return now.timeIntervalSince(item.createdAt) < 120
            }

            return false
        }
    }

    private func validatedURL(from input: String) -> URL? {
        guard
            let url = URL(string: input.trimmingCharacters(in: .whitespacesAndNewlines)),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme)
        else {
            return nil
        }

        return url
    }

    private func normalizedURLString(for url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        if let host = components?.host?.lowercased() {
            components?.host = host
        }
        if let scheme = components?.scheme?.lowercased() {
            components?.scheme = scheme
        }

        return components?.string ?? url.absoluteString
    }

    private func syncFileMetrics(for index: Int, preferredURL: URL? = nil) {
        let candidateURLs = [preferredURL, items[index].destinationURL].compactMap { $0 }

        for fileURL in candidateURLs {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = values.fileSize,
                  fileSize > 0 else {
                continue
            }

            let byteCount = Int64(fileSize)
            items[index].downloadedBytes = byteCount
            items[index].totalBytesExpected = byteCount
            return
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 400_000_000)
            try? self.store.save(self.items)
        }
    }

    private func sendCompletionNotification(for item: DownloadItem) {
        let content = UNMutableNotificationContent()
        content.title = "Download finished"
        content.body = item.fileName
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: item.id.uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}

private extension String {
    func ifEmpty(_ fallback: @autoclosure () -> String) -> String {
        isEmpty ? fallback() : self
    }
}
