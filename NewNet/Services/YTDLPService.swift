import Foundation

enum YTDLPEvent {
    case title(String)
    case progress(downloadedBytes: Int64, totalBytes: Int64?)
    case finalFile(URL)
    case terminated(exitCode: Int32, message: String?)
}

enum YTDLPServiceError: LocalizedError {
    case binaryNotFound
    case installFailed(String)
    case inspectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "The media engine is unavailable."
        case .installFailed(let message):
            return message
        case .inspectionFailed(let message):
            return message
        }
    }
}

actor YTDLPInstaller {
    private let fileManager = FileManager.default
    private var installTask: Task<URL, Error>?

    func ensureInstalled(targetURL: URL, downloadURL: URL) async throws -> URL {
        if fileManager.isExecutableFile(atPath: targetURL.path(percentEncoded: false)) {
            return targetURL
        }

        if let installTask {
            return try await installTask.value
        }

        let task = Task<URL, Error> {
            let parentDirectory = targetURL.deletingLastPathComponent()
            try self.fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true)

            let (temporaryURL, _) = try await URLSession.shared.download(from: downloadURL)

            if self.fileManager.fileExists(atPath: targetURL.path(percentEncoded: false)) {
                try self.fileManager.removeItem(at: targetURL)
            }

            try self.fileManager.moveItem(at: temporaryURL, to: targetURL)
            try self.fileManager.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o755))],
                ofItemAtPath: targetURL.path(percentEncoded: false)
            )

            return targetURL
        }

        installTask = task

        do {
            let result = try await task.value
            installTask = nil
            return result
        } catch {
            installTask = nil
            throw error
        }
    }
}

actor FFmpegInstaller {
    private let fileManager = FileManager.default
    private var installTask: Task<URL, Error>?

    func ensureInstalled(targetURL: URL, downloadURL: URL) async throws -> URL {
        if fileManager.isExecutableFile(atPath: targetURL.path(percentEncoded: false)) {
            return targetURL
        }

        if let installTask {
            return try await installTask.value
        }

        let task = Task<URL, Error> {
            let parentDirectory = targetURL.deletingLastPathComponent()
            try self.fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true)

            let (temporaryURL, _) = try await URLSession.shared.download(from: downloadURL)

            if self.fileManager.fileExists(atPath: targetURL.path(percentEncoded: false)) {
                try self.fileManager.removeItem(at: targetURL)
            }

            try self.fileManager.moveItem(at: temporaryURL, to: targetURL)
            try self.fileManager.setAttributes(
                [.posixPermissions: NSNumber(value: Int16(0o755))],
                ofItemAtPath: targetURL.path(percentEncoded: false)
            )

            return targetURL
        }

        installTask = task

        do {
            let result = try await task.value
            installTask = nil
            return result
        } catch {
            installTask = nil
            throw error
        }
    }
}

final class YTDLPRunningTask {
    let process: Process

    private let stdoutPipe: Pipe
    private let stderrPipe: Pipe
    private let stdoutAccumulator: LineAccumulator
    private let stderrAccumulator: LineAccumulator

    fileprivate init(
        process: Process,
        stdoutPipe: Pipe,
        stderrPipe: Pipe,
        stdoutAccumulator: LineAccumulator,
        stderrAccumulator: LineAccumulator
    ) {
        self.process = process
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        self.stdoutAccumulator = stdoutAccumulator
        self.stderrAccumulator = stderrAccumulator
    }

    fileprivate func finishIO() {
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil
        stdoutAccumulator.finish()
        stderrAccumulator.finish()
    }
}

final class YTDLPService {
    private static let releaseBinaryURL = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!
    private static let ffmpegReleaseTag = "b6.1.1"
    private static let ffmpegDownloadBaseURL = URL(
        string: "https://github.com/eugeneware/ffmpeg-static/releases/download/\(ffmpegReleaseTag)/"
    )!
    private static let supportedHosts = [
        "youtube.com",
        "youtu.be",
        "m.youtube.com",
        "x.com",
        "twitter.com",
        "instagram.com"
    ]

    private static var commonBinaryPaths: [String] {
        [
            managedBinaryURL.path(percentEncoded: false),
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "/usr/bin/yt-dlp"
        ]
    }

    private static var commonFFmpegPaths: [String] {
        bundledFFmpegCandidates + [
            managedFFmpegURL.path(percentEncoded: false),
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]
    }

    private static let installer = YTDLPInstaller()
    private static let ffmpegInstaller = FFmpegInstaller()

    private static var managedBinaryURL: URL {
        let supportURL = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())

        return supportURL
            .appendingPathComponent("NewNet/Tools", isDirectory: true)
            .appendingPathComponent("yt-dlp")
    }

    private static var managedFFmpegURL: URL {
        let supportURL = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())

        return supportURL
            .appendingPathComponent("NewNet/Tools", isDirectory: true)
            .appendingPathComponent("ffmpeg")
    }

    private static var bundledFFmpegCandidates: [String] {
        var candidates: [String] = []

        if let auxPath = Bundle.main.path(forAuxiliaryExecutable: "ffmpeg"), !auxPath.isEmpty {
            candidates.append(auxPath)
        }

        if let resourceURL = Bundle.main.resourceURL {
            let preferredName = prefersIntelFFmpeg ? "ffmpeg-x64" : "ffmpeg-arm64"
            let fallbackName = prefersIntelFFmpeg ? "ffmpeg-arm64" : "ffmpeg-x64"
            candidates.append(resourceURL.appendingPathComponent(preferredName).path(percentEncoded: false))
            candidates.append(resourceURL.appendingPathComponent(fallbackName).path(percentEncoded: false))
            candidates.append(resourceURL.appendingPathComponent("ffmpeg").path(percentEncoded: false))
        }

        return candidates
    }
    private static var prefersIntelFFmpeg: Bool {
        if ProcessInfo.processInfo.isTranslated {
            return true
        }
#if arch(arm64)
        return false
#else
        return true
#endif
    }

    private static var ffmpegDownloadURL: URL {
        let assetName = prefersIntelFFmpeg ? "ffmpeg-darwin-x64" : "ffmpeg-darwin-arm64"
        return ffmpegDownloadBaseURL.appendingPathComponent(assetName)
    }

    func canHandle(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return Self.supportedHosts.contains { host == $0 || host.hasSuffix(".\($0)") }
    }

    func resolvedBinaryURL(settings: AppSettings) -> URL? {
        let candidatePaths = [
            settings.ytDLPPath.trimmingCharacters(in: .whitespacesAndNewlines),
            Bundle.main.path(forAuxiliaryExecutable: "yt-dlp") ?? "",
            Bundle.main.resourceURL?
                .appendingPathComponent("yt-dlp")
                .path(percentEncoded: false) ?? ""
        ] + Self.commonBinaryPaths

        for path in candidatePaths where !path.isEmpty {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        return nil
    }

    func ensureInstalled(settings: AppSettings) async throws -> URL {
        if let binaryURL = resolvedBinaryURL(settings: settings) {
            return binaryURL
        }

        do {
            return try await Self.installer.ensureInstalled(
                targetURL: Self.managedBinaryURL,
                downloadURL: Self.releaseBinaryURL
            )
        } catch {
            throw YTDLPServiceError.installFailed(
                "NewNet could not automatically install the media engine. Check your connection and try again."
            )
        }
    }

    func ensureFFmpegInstalled() async throws -> URL {
        if let binaryURL = resolvedFFmpegURL() {
            return binaryURL
        }

        do {
            return try await Self.ffmpegInstaller.ensureInstalled(
                targetURL: Self.managedFFmpegURL,
                downloadURL: Self.ffmpegDownloadURL
            )
        } catch {
            throw YTDLPServiceError.installFailed(
                "NewNet could not automatically install ffmpeg. Check your connection and try again."
            )
        }
    }

    func resolvedFFmpegURL() -> URL? {
        for path in Self.commonFFmpegPaths where !path.isEmpty {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        return nil
    }

    func discoveredBinaryDescription(settings: AppSettings) -> String {
        if let binaryURL = resolvedBinaryURL(settings: settings) {
            return binaryURL.path(percentEncoded: false)
        }

        return "Auto-installs on first social-media download"
    }

    func requiresFFmpeg(for item: DownloadItem) -> Bool {
        guard let configuration = item.ytDLPConfiguration else { return false }
        if configuration.formatExpression.contains("+") {
            return true
        }
        if configuration.extractAudio {
            return true
        }
        if let mergeOutputFormat = configuration.mergeOutputFormat, !mergeOutputFormat.isEmpty {
            return true
        }
        return false
    }

    func inspectMedia(
        url: URL,
        settings: AppSettings,
        preferredContent: DownloadContentPreference
    ) async throws -> YTDLPMediaInfo {
        _ = preferredContent
        let binaryURL = try await ensureInstalled(settings: settings)
        let output = try await runInspection(binaryURL: binaryURL, url: url)
        let jsonData = extractJSONObject(from: output)

        let decoder = JSONDecoder()

        let response: YTDLPInspectionResponse
        do {
            response = try decoder.decode(YTDLPInspectionResponse.self, from: jsonData)
        } catch {
            print("yt-dlp inspection decode failure:", error)
            throw YTDLPServiceError.inspectionFailed(
                "NewNet could not read the available formats for this link."
            )
        }

        let videoOptions = buildVideoOptions(from: response.formats)
        let audioOptions = buildAudioOptions(from: response.formats)

        guard !videoOptions.isEmpty || !audioOptions.isEmpty else {
            throw YTDLPServiceError.inspectionFailed("No downloadable formats were found for this link.")
        }

        let thumbnailURL = response.thumbnails?
            .compactMap(\.url)
            .compactMap(URL.init(string:))
            .last ?? response.thumbnail.flatMap(URL.init(string:))

        let effectiveTitle = response.title?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .ifEmpty(url.host?.replacingOccurrences(of: "www.", with: "") ?? "Media Download")
            ?? (url.host?.replacingOccurrences(of: "www.", with: "") ?? "Media Download")

        return YTDLPMediaInfo(
            sourceURL: url,
            title: effectiveTitle,
            uploader: response.uploader,
            extractor: response.extractorKey ?? response.extractor,
            duration: response.duration,
            thumbnailURL: thumbnailURL,
            videoOptions: videoOptions,
            audioOptions: audioOptions
        )
    }

    func startDownload(
        item: DownloadItem,
        settings: AppSettings,
        onEvent: @escaping @Sendable (YTDLPEvent) -> Void
    ) throws -> YTDLPRunningTask {
        guard let binaryURL = resolvedBinaryURL(settings: settings) else {
            throw YTDLPServiceError.binaryNotFound
        }

        if let configuration = item.ytDLPConfiguration,
           configuration.formatExpression.contains("+"),
           resolvedFFmpegURL() == nil
        {
            throw YTDLPServiceError.installFailed(
                "NewNet could not prepare ffmpeg. Check your connection and try again."
            )
        }

        let process = Process()
        process.executableURL = binaryURL
        process.arguments = arguments(for: item, settings: settings)
        process.environment = {
            var environment = ProcessInfo.processInfo.environment
            environment["PYTHONIOENCODING"] = "utf-8"

            let ffmpegDirectories = Self.commonFFmpegPaths
                .filter { !$0.isEmpty }
                .map { URL(fileURLWithPath: $0).deletingLastPathComponent().path(percentEncoded: false) }

            let existingPath = environment["PATH"] ?? ""
            var mergedPathEntries: [String] = []
            for entry in ffmpegDirectories + existingPath.split(separator: ":").map(String.init) {
                if !mergedPathEntries.contains(entry) {
                    mergedPathEntries.append(entry)
                }
            }
            environment["PATH"] = mergedPathEntries.joined(separator: ":")
            return environment
        }()

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutAccumulator = LineAccumulator { line in
            Self.handleStandardOutput(line, onEvent: onEvent)
        }

        let progressAccumulator = LineAccumulator(trackSignificantLine: false) { line in
            Self.handleStandardOutput(line, onEvent: onEvent)
        }

        let stderrAccumulator = LineAccumulator()

        let runningTask = YTDLPRunningTask(
            process: process,
            stdoutPipe: stdoutPipe,
            stderrPipe: stderrPipe,
            stdoutAccumulator: stdoutAccumulator,
            stderrAccumulator: stderrAccumulator
        )

        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                stdoutAccumulator.finish()
                return
            }

            stdoutAccumulator.append(data)
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                stderrAccumulator.finish()
                progressAccumulator.finish()
                return
            }

            stderrAccumulator.append(data)
            progressAccumulator.append(data)
        }

        process.terminationHandler = { process in
            runningTask.finishIO()
            progressAccumulator.finish()
            let message = stderrAccumulator.lastSignificantLine
            onEvent(.terminated(exitCode: process.terminationStatus, message: message))
        }

        try process.run()
        return runningTask
    }

    private func arguments(for item: DownloadItem, settings: AppSettings) -> [String] {
        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        var arguments = [
            "--newline",
            "--continue",
            "--no-playlist",
            "--paths",
            downloadsDirectory.path(percentEncoded: false),
            "--output",
            "%(title).170B [%(extractor_key)s-%(id)s].%(ext)s",
            "--print",
            "before_dl:TITLE:%(title)s",
            "--print",
            "after_move:FILE:%(filepath)s",
            "--progress-template",
            "download:PROGRESS:%(progress.downloaded_bytes)s|%(progress.downloaded_bytes_estimate)s|%(progress.total_bytes)s|%(progress.total_bytes_estimate)s",
            "--concurrent-fragments",
            "\(max(settings.maxSegments, 1))"
        ]

        if let ffmpegURL = resolvedFFmpegURL() {
            arguments += ["--ffmpeg-location", ffmpegURL.path(percentEncoded: false)]
        }

        if settings.speedLimitKBps > 0 {
            arguments += ["--limit-rate", "\(settings.speedLimitKBps)K"]
        }

        if let configuration = item.ytDLPConfiguration {
            arguments += ["-f", configuration.formatExpression]

            if configuration.extractAudio {
                arguments.append("--extract-audio")
                if let audioFormat = configuration.audioFormat, !audioFormat.isEmpty {
                    arguments += ["--audio-format", audioFormat]
                }
            }

            if let mergeOutputFormat = configuration.mergeOutputFormat, !mergeOutputFormat.isEmpty {
                arguments += ["--merge-output-format", mergeOutputFormat]
            }
        } else {
            switch item.contentPreference {
            case .auto:
                arguments += ["-f", "bestvideo*+bestaudio/best"]
            case .video:
                arguments += ["-f", "bestvideo*+bestaudio/best"]
            case .audio:
                arguments += ["-f", "bestaudio/best"]
            }
        }

        arguments.append(item.sourceURL.absoluteString)
        return arguments
    }

    private func runInspection(binaryURL: URL, url: URL) async throws -> Data {
        let task = Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = binaryURL
            process.arguments = [
                "--dump-single-json",
                "--no-playlist",
                "--no-warnings",
                "--skip-download",
                url.absoluteString
            ]
            process.environment = {
                var environment = ProcessInfo.processInfo.environment
                environment["PYTHONIOENCODING"] = "utf-8"
                return environment
            }()

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let stdoutTask = Task.detached(priority: .utility) {
                stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            }
            let stderrTask = Task.detached(priority: .utility) {
                stderrPipe.fileHandleForReading.readDataToEndOfFile()
            }

            try process.run()
            process.waitUntilExit()

            let stdoutData = await stdoutTask.value
            let stderrData = await stderrTask.value

            guard process.terminationStatus == 0 else {
                let message = String(data: stderrData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .ifEmpty("NewNet could not inspect this link.")
                    ?? "NewNet could not inspect this link."
                throw YTDLPServiceError.inspectionFailed(message)
            }

            return stdoutData
        }

        return try await task.value
    }

    private func extractJSONObject(from data: Data) -> Data {
        guard
            let firstBrace = data.firstIndex(of: UInt8(ascii: "{")),
            let lastBrace = data.lastIndex(of: UInt8(ascii: "}")),
            firstBrace <= lastBrace
        else {
            return data
        }

        return data[firstBrace...lastBrace]
    }

    private func buildVideoOptions(from formats: [YTDLPInspectionFormat]) -> [YTDLPDownloadOption] {
        let combinedFormats = formats
            .filter(\.hasVideo)
            .filter(\.hasAudio)
            .sorted(by: Self.isPreferredVideoFormat)

        let videoOnlyFormats = formats
            .filter(\.hasVideo)
            .filter { !$0.hasAudio }
            .sorted(by: Self.isPreferredVideoFormat)

        let audioOnlyFormats = formats
            .filter(\.hasAudio)
            .filter { !$0.hasVideo }
            .sorted(by: Self.isPreferredAudioFormat)

        var options: [YTDLPDownloadOption] = []
        var seenIDs: Set<String> = []

        for format in combinedFormats {
            let option = makeCombinedVideoOption(from: format)
            if seenIDs.insert(option.id).inserted {
                options.append(option)
            }
        }

        for format in videoOnlyFormats {
            guard let audio = bestCompatibleAudio(for: format, from: audioOnlyFormats) else { continue }
            let option = makeMuxedVideoOption(video: format, audio: audio)
            if seenIDs.insert(option.id).inserted {
                options.append(option)
            }
        }

        return options
    }

    private func buildAudioOptions(from formats: [YTDLPInspectionFormat]) -> [YTDLPDownloadOption] {
        formats
            .filter(\.hasAudio)
            .filter { !$0.hasVideo }
            .sorted(by: Self.isPreferredAudioFormat)
            .reduce(into: [YTDLPDownloadOption]()) { result, format in
                let option = makeAudioOption(from: format)
                if !result.contains(where: { $0.id == option.id }) {
                    result.append(option)
                }
            }
    }

    private func makeCombinedVideoOption(from format: YTDLPInspectionFormat) -> YTDLPDownloadOption {
        let size = format.fileSize
        let label = [Self.videoQualityLabel(for: format), format.ext?.uppercased()]
            .compactMap { $0 }
            .joined(separator: " • ")
        let detail = [
            format.formatNote?.nilIfNone,
            Self.codecSummary(for: format),
            size.map(ByteCountFormatter.compactFileSize)
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: "  ")

        return YTDLPDownloadOption(
            id: format.formatId,
            label: label.ifEmpty("Video"),
            detail: detail.ifEmpty("Combined video and audio"),
            estimatedBytes: size,
            configuration: YTDLPDownloadConfiguration(
                formatExpression: format.formatId,
                displayName: label.ifEmpty("Video"),
                detailText: detail.ifEmpty("Combined video and audio"),
                contentPreference: .video,
                extractAudio: false,
                audioFormat: nil,
                mergeOutputFormat: nil
            )
        )
    }

    private func makeMuxedVideoOption(video: YTDLPInspectionFormat, audio: YTDLPInspectionFormat) -> YTDLPDownloadOption {
        let combinedSize = video.fileSize.flatMap { videoSize in
            audio.fileSize.map { audioSize in videoSize + audioSize }
        } ?? video.fileSize ?? audio.fileSize

        let label = [
            Self.videoQualityLabel(for: video),
            "\(video.ext?.uppercased() ?? "video") + \(audio.ext?.uppercased() ?? "audio")"
        ]
        .joined(separator: " • ")

        let detail = [
            "Muxed on download",
            Self.codecSummary(for: video),
            audio.formatNote?.nilIfNone ?? Self.audioQualityLabel(for: audio),
            combinedSize.map(ByteCountFormatter.compactFileSize)
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: "  ")

        return YTDLPDownloadOption(
            id: "\(video.formatId)+\(audio.formatId)",
            label: label,
            detail: detail.ifEmpty("Video and audio merged during download"),
            estimatedBytes: combinedSize,
            configuration: YTDLPDownloadConfiguration(
                formatExpression: "\(video.formatId)+\(audio.formatId)",
                displayName: label,
                detailText: detail.ifEmpty("Video and audio merged during download"),
                contentPreference: .video,
                extractAudio: false,
                audioFormat: nil,
                mergeOutputFormat: Self.mergeOutputFormat(for: video, audio: audio)
            )
        )
    }

    private func makeAudioOption(from format: YTDLPInspectionFormat) -> YTDLPDownloadOption {
        let size = format.fileSize
        let label = [
            Self.audioQualityLabel(for: format),
            format.ext?.uppercased()
        ]
        .compactMap { $0 }
        .joined(separator: " • ")

        let detail = [
            format.formatNote?.nilIfNone,
            Self.audioCodecSummary(for: format),
            size.map(ByteCountFormatter.compactFileSize)
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: "  ")

        return YTDLPDownloadOption(
            id: format.formatId,
            label: label.ifEmpty("Audio"),
            detail: detail.ifEmpty("Audio only"),
            estimatedBytes: size,
            configuration: YTDLPDownloadConfiguration(
                formatExpression: format.formatId,
                displayName: label.ifEmpty("Audio"),
                detailText: detail.ifEmpty("Audio only"),
                contentPreference: .audio,
                extractAudio: false,
                audioFormat: nil,
                mergeOutputFormat: nil
            )
        )
    }

    private func bestCompatibleAudio(
        for video: YTDLPInspectionFormat,
        from audioFormats: [YTDLPInspectionFormat]
    ) -> YTDLPInspectionFormat? {
        let preferredExtensions = Self.preferredAudioExtensions(for: video.ext)

        return audioFormats.first(where: { preferredExtensions.contains($0.ext?.lowercased() ?? "") }) ?? audioFormats.first
    }

    nonisolated private static func preferredAudioExtensions(for videoExtension: String?) -> [String] {
        switch videoExtension?.lowercased() {
        case "mp4", "m4v", "mov":
            return ["m4a", "mp4", "aac"]
        case "webm":
            return ["webm", "weba", "opus", "ogg"]
        default:
            return []
        }
    }

    nonisolated private static func mergeOutputFormat(for video: YTDLPInspectionFormat, audio: YTDLPInspectionFormat) -> String? {
        let videoExt = video.ext?.lowercased()
        let audioExt = audio.ext?.lowercased()

        if ["mp4", "m4v", "mov"].contains(videoExt), ["m4a", "mp4", "aac"].contains(audioExt) {
            return "mp4"
        }

        if videoExt == "webm", ["webm", "weba", "opus", "ogg"].contains(audioExt) {
            return "webm"
        }

        return nil
    }

    nonisolated private static func isPreferredVideoFormat(_ lhs: YTDLPInspectionFormat, _ rhs: YTDLPInspectionFormat) -> Bool {
        if lhs.height != rhs.height { return (lhs.height ?? 0) > (rhs.height ?? 0) }
        if lhs.fps != rhs.fps { return (lhs.fps ?? 0) > (rhs.fps ?? 0) }
        if lhs.dynamicRangePriority != rhs.dynamicRangePriority {
            return lhs.dynamicRangePriority > rhs.dynamicRangePriority
        }
        return (lhs.tbr ?? 0) > (rhs.tbr ?? 0)
    }

    nonisolated private static func isPreferredAudioFormat(_ lhs: YTDLPInspectionFormat, _ rhs: YTDLPInspectionFormat) -> Bool {
        if lhs.audioBitrate != rhs.audioBitrate { return lhs.audioBitrate > rhs.audioBitrate }
        return (lhs.fileSize ?? 0) > (rhs.fileSize ?? 0)
    }

    nonisolated private static func videoQualityLabel(for format: YTDLPInspectionFormat) -> String {
        if let height = format.height {
            if let fps = format.fps, fps >= 50 {
                return "\(height)p\(Int(fps.rounded()))"
            }

            return "\(height)p"
        }

        return format.resolution?.nilIfNone ?? format.formatNote?.nilIfNone ?? "Video"
    }

    nonisolated private static func audioQualityLabel(for format: YTDLPInspectionFormat) -> String {
        if format.audioBitrate > 0 {
            return "\(Int(format.audioBitrate.rounded())) kbps"
        }

        return format.formatNote?.nilIfNone ?? "Audio"
    }

    nonisolated private static func codecSummary(for format: YTDLPInspectionFormat) -> String? {
        let parts = [
            format.vcodec?.nilIfNone,
            format.acodec?.nilIfNone
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " + ")
    }

    nonisolated private static func audioCodecSummary(for format: YTDLPInspectionFormat) -> String? {
        format.acodec?.nilIfNone
    }

    private static func handleStandardOutput(_ line: String, onEvent: @escaping @Sendable (YTDLPEvent) -> Void) {
        if line.hasPrefix("TITLE:") {
            let title = String(line.dropFirst("TITLE:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return }
            onEvent(.title(title))
            return
        }

        if line.hasPrefix("FILE:") {
            let path = String(line.dropFirst("FILE:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { return }
            onEvent(.finalFile(URL(fileURLWithPath: path)))
            return
        }

        if let progressRange = line.range(of: "PROGRESS:") {
            let payload = String(line[progressRange.upperBound...])
            let components = payload.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            let downloadedBytes = parseByteValue(components[safe: 0]) ?? parseByteValue(components[safe: 1])
            let explicitTotal = parseByteValue(components[safe: 2])
            let estimatedTotal = parseByteValue(components[safe: 3])

            guard let downloaded = downloadedBytes else { return }
            onEvent(.progress(downloadedBytes: downloaded, totalBytes: explicitTotal ?? estimatedTotal))
            return
        }

        if let fallback = parseLegacyProgressLine(line) {
            onEvent(.progress(downloadedBytes: fallback.downloadedBytes, totalBytes: fallback.totalBytes))
        }
    }
}

private func parseLegacyProgressLine(_ line: String) -> (downloadedBytes: Int64, totalBytes: Int64?)? {
    guard line.contains("[download]") else { return nil }

    let percentPattern = #"([0-9]+(?:\.[0-9]+)?)%\s+of\s+~?([0-9]+(?:\.[0-9]+)?)\s*([KMGTP]?i?B)"#
    if let match = firstRegexMatch(pattern: percentPattern, in: line) {
        let percent = match.group(1)
        let totalValue = match.group(2)
        let totalUnit = match.group(3)
        if let percentDouble = Double(percent),
           let totalBytes = sizeToBytes(value: totalValue, unit: totalUnit)
        {
            let downloaded = Int64((Double(totalBytes) * percentDouble / 100.0).rounded())
            return (downloadedBytes: max(0, downloaded), totalBytes: totalBytes)
        }
    }

    let ofPattern = #"([0-9]+(?:\.[0-9]+)?)\s*([KMGTP]?i?B)\s+of\s+~?([0-9]+(?:\.[0-9]+)?)\s*([KMGTP]?i?B)"#
    if let match = firstRegexMatch(pattern: ofPattern, in: line) {
        let downloadedValue = match.group(1)
        let downloadedUnit = match.group(2)
        let totalValue = match.group(3)
        let totalUnit = match.group(4)
        if let downloadedBytes = sizeToBytes(value: downloadedValue, unit: downloadedUnit),
           let totalBytes = sizeToBytes(value: totalValue, unit: totalUnit)
        {
            return (downloadedBytes: downloadedBytes, totalBytes: totalBytes)
        }
    }

    let singlePattern = #"([0-9]+(?:\.[0-9]+)?)\s*([KMGTP]?i?B)"#
    if let match = firstRegexMatch(pattern: singlePattern, in: line) {
        let downloadedValue = match.group(1)
        let downloadedUnit = match.group(2)
        if let downloadedBytes = sizeToBytes(value: downloadedValue, unit: downloadedUnit) {
            return (downloadedBytes: downloadedBytes, totalBytes: nil)
        }
    }

    return nil
}

private func firstRegexMatch(pattern: String, in text: String) -> RegexMatch? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }
    return RegexMatch(match: match, text: text)
}

private struct RegexMatch {
    let match: NSTextCheckingResult
    let text: String

    func group(_ index: Int) -> String {
        guard index < match.numberOfRanges, let range = Range(match.range(at: index), in: text) else { return "" }
        return String(text[range])
    }
}

private func sizeToBytes(value: String, unit: String) -> Int64? {
    guard let numeric = Double(value) else { return nil }
    let normalized = unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let multiplier: Double
    switch normalized {
    case "b":
        multiplier = 1
    case "kb":
        multiplier = 1_000
    case "mb":
        multiplier = 1_000_000
    case "gb":
        multiplier = 1_000_000_000
    case "tb":
        multiplier = 1_000_000_000_000
    case "kib":
        multiplier = 1_024
    case "mib":
        multiplier = 1_048_576
    case "gib":
        multiplier = 1_073_741_824
    case "tib":
        multiplier = 1_099_511_627_776
    default:
        return nil
    }
    return Int64((numeric * multiplier).rounded())
}

private func parseByteValue(_ raw: String?) -> Int64? {
    guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
    let lowered = raw.lowercased()
    if lowered == "na" || lowered == "nan" || lowered == "inf" {
        return nil
    }
    if let value = Double(raw), value.isFinite {
        return Int64(value)
    }
    return nil
}

private struct YTDLPInspectionResponse: Decodable {
    let title: String?
    let uploader: String?
    let duration: TimeInterval?
    let thumbnail: String?
    let thumbnails: [YTDLPInspectionThumbnail]?
    let extractorKey: String?
    let extractor: String?
    let formats: [YTDLPInspectionFormat]

    private enum CodingKeys: String, CodingKey {
        case title
        case uploader
        case duration
        case thumbnail
        case thumbnails
        case extractorKey = "extractor_key"
        case extractor
        case formats
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        uploader = try container.decodeIfPresent(String.self, forKey: .uploader)
        duration = container.decodeLossyDouble(forKey: .duration)
        thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
        thumbnails = try container.decodeIfPresent([YTDLPInspectionThumbnail].self, forKey: .thumbnails)
        extractorKey = try container.decodeIfPresent(String.self, forKey: .extractorKey)
        extractor = try container.decodeIfPresent(String.self, forKey: .extractor)
        formats = try container.decodeIfPresent([YTDLPInspectionFormat].self, forKey: .formats) ?? []
    }
}

private struct YTDLPInspectionThumbnail: Decodable {
    let url: String?
}

private struct YTDLPInspectionFormat: Decodable {
    let formatId: String
    let formatNote: String?
    let ext: String?
    let width: Int?
    let height: Int?
    let fps: Double?
    let tbr: Double?
    let abr: Double?
    let audioChannels: Int?
    let resolution: String?
    let format: String?
    let fileSizeExact: Int64?
    let fileSizeApprox: Int64?
    let vcodec: String?
    let acodec: String?
    let dynamicRange: String?

    nonisolated var hasVideo: Bool {
        vcodec?.lowercased() != "none"
    }

    nonisolated var hasAudio: Bool {
        acodec?.lowercased() != "none"
    }

    nonisolated var fileSize: Int64? {
        fileSizeExact ?? fileSizeApprox
    }

    nonisolated var audioBitrate: Double {
        abr ?? tbr ?? 0
    }

    nonisolated var dynamicRangePriority: Int {
        switch dynamicRange?.lowercased() {
        case "hdr", "hdr10", "hdr10+":
            return 2
        case "sdr":
            return 1
        default:
            return 0
        }
    }

    private enum CodingKeys: String, CodingKey {
        case formatId = "format_id"
        case formatNote = "format_note"
        case ext
        case width
        case height
        case fps
        case tbr
        case abr
        case audioChannels = "audio_channels"
        case resolution
        case format
        case fileSizeExact = "filesize"
        case fileSizeApprox = "filesize_approx"
        case vcodec
        case acodec
        case dynamicRange = "dynamic_range"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatId = try container.decode(String.self, forKey: .formatId)
        formatNote = try container.decodeIfPresent(String.self, forKey: .formatNote)
        ext = try container.decodeIfPresent(String.self, forKey: .ext)
        width = container.decodeLossyInt(forKey: .width)
        height = container.decodeLossyInt(forKey: .height)
        fps = container.decodeLossyDouble(forKey: .fps)
        tbr = container.decodeLossyDouble(forKey: .tbr)
        abr = container.decodeLossyDouble(forKey: .abr)
        audioChannels = container.decodeLossyInt(forKey: .audioChannels)
        resolution = try container.decodeIfPresent(String.self, forKey: .resolution)
        format = try container.decodeIfPresent(String.self, forKey: .format)
        fileSizeExact = container.decodeLossyInt64(forKey: .fileSizeExact)
        fileSizeApprox = container.decodeLossyInt64(forKey: .fileSizeApprox)
        vcodec = try container.decodeIfPresent(String.self, forKey: .vcodec)
        acodec = try container.decodeIfPresent(String.self, forKey: .acodec)
        dynamicRange = try container.decodeIfPresent(String.self, forKey: .dynamicRange)
    }
}

private final class LineAccumulator {
    private var buffer = Data()
    private let onLine: (String) -> Void
    private let trackSignificantLine: Bool

    var lastSignificantLine: String?

    init(trackSignificantLine: Bool = true, onLine: @escaping (String) -> Void = { _ in }) {
        self.onLine = onLine
        self.trackSignificantLine = trackSignificantLine
    }

    func append(_ data: Data) {
        buffer.append(data)
        flushLines()
    }

    func finish() {
        guard !buffer.isEmpty else { return }
        emit(buffer)
        buffer.removeAll(keepingCapacity: false)
    }

    private func flushLines() {
        while let lineBreakIndex = buffer.firstIndex(where: { $0 == 0x0A || $0 == 0x0D }) {
            let line = buffer.prefix(upTo: lineBreakIndex)
            emit(line)
            buffer.removeSubrange(...lineBreakIndex)
        }
    }

    private func emit<T: DataProtocol>(_ data: T) {
        guard let line = String(data: Data(data), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !line.isEmpty
        else {
            return
        }

        if trackSignificantLine && !line.hasPrefix("[debug]") {
            lastSignificantLine = line
        }

        onLine(line)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension String {
    nonisolated func ifEmpty(_ fallback: @autoclosure () -> String) -> String {
        isEmpty ? fallback() : self
    }

    nonisolated var nilIfNone: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        return trimmed.lowercased() == "none" ? nil : trimmed
    }
}

private extension Optional where Wrapped == String {
    nonisolated var nilIfNone: String? {
        switch self {
        case .some(let value):
            return value.nilIfNone
        case .none:
            return nil
        }
    }
}

private extension ProcessInfo {
    var isTranslated: Bool {
        var flag: Int32 = 0
        var size = size_t(MemoryLayout<Int32>.size)
        let result = sysctlbyname("sysctl.proc_translated", &flag, &size, nil, 0)
        return result == 0 && flag == 1
    }
}

private extension KeyedDecodingContainer {
    func decodeLossyDouble(forKey key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }

        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }

        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Double(value)
        }

        return nil
    }

    func decodeLossyInt(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }

        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }

        if let value = try? decodeIfPresent(String.self, forKey: key) {
            if let numeric = Double(value) {
                return Int(numeric)
            }
        }

        return nil
    }

    func decodeLossyInt64(forKey key: Key) -> Int64? {
        if let value = try? decodeIfPresent(Int64.self, forKey: key) {
            return value
        }

        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Int64(value)
        }

        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int64(value)
        }

        if let value = try? decodeIfPresent(String.self, forKey: key) {
            if let numeric = Double(value) {
                return Int64(numeric)
            }
        }

        return nil
    }
}
