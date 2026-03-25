import Foundation

enum DownloadState: String, Codable {
    case queued
    case preparing
    case downloading
    case paused
    case completing
    case completed
    case failed
}

enum DownloadEngine: String, Codable {
    case native
    case ytDLP

    var displayName: String {
        switch self {
        case .native:
            return "Direct"
        case .ytDLP:
            return "yt-dlp"
        }
    }
}

enum DownloadContentPreference: String, Codable, CaseIterable, Identifiable {
    case auto
    case video
    case audio

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:
            return "Auto"
        case .video:
            return "Video"
        case .audio:
            return "Audio"
        }
    }
}

struct YTDLPDownloadConfiguration: Codable, Hashable, Sendable {
    var formatExpression: String
    var displayName: String
    var detailText: String
    var contentPreference: DownloadContentPreference
    var extractAudio: Bool
    var audioFormat: String?
    var mergeOutputFormat: String?
}

struct YTDLPDownloadOption: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let detail: String
    let estimatedBytes: Int64?
    let configuration: YTDLPDownloadConfiguration
}

struct YTDLPMediaInfo: Identifiable, Hashable, Sendable {
    let id = UUID()
    let sourceURL: URL
    let title: String
    let uploader: String?
    let extractor: String?
    let duration: TimeInterval?
    let thumbnailURL: URL?
    let videoOptions: [YTDLPDownloadOption]
    let audioOptions: [YTDLPDownloadOption]
}

struct DownloadSegment: Codable, Identifiable, Hashable {
    let index: Int
    var lowerBound: Int64
    var upperBound: Int64
    var receivedBytes: Int64

    var id: Int { index }

    var expectedBytes: Int64 {
        guard upperBound >= lowerBound else { return 0 }
        return upperBound - lowerBound + 1
    }

    var isComplete: Bool {
        guard expectedBytes > 0 else { return false }
        return receivedBytes >= expectedBytes
    }

    var resumeOffset: Int64 {
        lowerBound + receivedBytes
    }
}

struct DownloadItem: Identifiable, Codable, Hashable {
    let id: UUID
    let sourceURL: URL
    var destinationURL: URL
    var fileName: String
    var engine: DownloadEngine
    var contentPreference: DownloadContentPreference
    var ytDLPConfiguration: YTDLPDownloadConfiguration?
    var state: DownloadState
    var createdAt: Date
    var totalBytesExpected: Int64
    var downloadedBytes: Int64
    var supportsResuming: Bool
    var segments: [DownloadSegment]
    var errorDescription: String?

    init(
        id: UUID,
        sourceURL: URL,
        destinationURL: URL,
        fileName: String,
        engine: DownloadEngine,
        contentPreference: DownloadContentPreference,
        ytDLPConfiguration: YTDLPDownloadConfiguration?,
        state: DownloadState,
        createdAt: Date,
        totalBytesExpected: Int64,
        downloadedBytes: Int64,
        supportsResuming: Bool,
        segments: [DownloadSegment],
        errorDescription: String?
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.fileName = fileName
        self.engine = engine
        self.contentPreference = contentPreference
        self.ytDLPConfiguration = ytDLPConfiguration
        self.state = state
        self.createdAt = createdAt
        self.totalBytesExpected = totalBytesExpected
        self.downloadedBytes = downloadedBytes
        self.supportsResuming = supportsResuming
        self.segments = segments
        self.errorDescription = errorDescription
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case sourceURL
        case destinationURL
        case fileName
        case engine
        case contentPreference
        case ytDLPConfiguration
        case state
        case createdAt
        case totalBytesExpected
        case downloadedBytes
        case supportsResuming
        case segments
        case errorDescription
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sourceURL = try container.decode(URL.self, forKey: .sourceURL)
        destinationURL = try container.decode(URL.self, forKey: .destinationURL)
        fileName = try container.decode(String.self, forKey: .fileName)
        engine = try container.decodeIfPresent(DownloadEngine.self, forKey: .engine) ?? .native
        contentPreference = try container.decodeIfPresent(DownloadContentPreference.self, forKey: .contentPreference) ?? .auto
        ytDLPConfiguration = try container.decodeIfPresent(YTDLPDownloadConfiguration.self, forKey: .ytDLPConfiguration)
        state = try container.decode(DownloadState.self, forKey: .state)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        totalBytesExpected = try container.decode(Int64.self, forKey: .totalBytesExpected)
        downloadedBytes = try container.decode(Int64.self, forKey: .downloadedBytes)
        supportsResuming = try container.decode(Bool.self, forKey: .supportsResuming)
        segments = try container.decode([DownloadSegment].self, forKey: .segments)
        errorDescription = try container.decodeIfPresent(String.self, forKey: .errorDescription)
    }

    var progress: Double {
        guard totalBytesExpected > 0 else { return 0 }
        return min(max(Double(downloadedBytes) / Double(totalBytesExpected), 0), 1)
    }

    var isTerminal: Bool {
        state == .completed || state == .failed
    }

    var isActive: Bool {
        state == .preparing || state == .downloading || state == .completing
    }
}
