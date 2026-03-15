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

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "The media engine is unavailable."
        case .installFailed(let message):
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

    private static let installer = YTDLPInstaller()

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

    func discoveredBinaryDescription(settings: AppSettings) -> String {
        if let binaryURL = resolvedBinaryURL(settings: settings) {
            return binaryURL.path(percentEncoded: false)
        }

        return "Auto-installs on first social-media download"
    }

    func startDownload(
        item: DownloadItem,
        settings: AppSettings,
        onEvent: @escaping @Sendable (YTDLPEvent) -> Void
    ) throws -> YTDLPRunningTask {
        guard let binaryURL = resolvedBinaryURL(settings: settings) else {
            throw YTDLPServiceError.binaryNotFound
        }

        let process = Process()
        process.executableURL = binaryURL
        process.arguments = arguments(for: item, settings: settings)
        process.environment = {
            var environment = ProcessInfo.processInfo.environment
            environment["PYTHONIOENCODING"] = "utf-8"
            return environment
        }()

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdoutAccumulator = LineAccumulator { line in
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
                return
            }

            stderrAccumulator.append(data)
        }

        process.terminationHandler = { process in
            runningTask.finishIO()
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
            "download:PROGRESS:%(progress.downloaded_bytes)s|%(progress.total_bytes)s|%(progress.total_bytes_estimate)s",
            "--concurrent-fragments",
            "\(max(settings.maxSegments, 1))"
        ]

        if settings.speedLimitKBps > 0 {
            arguments += ["--limit-rate", "\(settings.speedLimitKBps)K"]
        }

        switch item.contentPreference {
        case .auto:
            break
        case .video:
            arguments += ["-f", "bestvideo*+bestaudio/best"]
        case .audio:
            arguments += ["-f", "bestaudio/best"]
        }

        arguments.append(item.sourceURL.absoluteString)
        return arguments
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

        if line.hasPrefix("PROGRESS:") {
            let payload = String(line.dropFirst("PROGRESS:".count))
            let components = payload.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard let downloadedBytes = Int64(components[safe: 0] ?? "") else { return }

            let explicitTotal = Int64(components[safe: 1] ?? "")
            let estimatedTotal = Int64(components[safe: 2] ?? "")
            onEvent(.progress(downloadedBytes: downloadedBytes, totalBytes: explicitTotal ?? estimatedTotal))
        }
    }
}

private final class LineAccumulator {
    private var buffer = Data()
    private let onLine: (String) -> Void

    var lastSignificantLine: String?

    init(onLine: @escaping (String) -> Void = { _ in }) {
        self.onLine = onLine
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
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let line = buffer.prefix(upTo: newlineIndex)
            emit(line)
            buffer.removeSubrange(...newlineIndex)
        }
    }

    private func emit<T: DataProtocol>(_ data: T) {
        guard let line = String(data: Data(data), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !line.isEmpty
        else {
            return
        }

        if !line.hasPrefix("[debug]") {
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
