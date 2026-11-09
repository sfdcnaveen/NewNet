import Foundation

enum NewNetTab: String, CaseIterable, Codable, Identifiable {
    case network
    case ytdlp
    case music

    static let defaultOrder: [NewNetTab] = [.network, .ytdlp, .music]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .network: return "Network"
        case .ytdlp: return "yt-dlp"
        case .music: return "Music"
        }
    }

    var systemImage: String {
        switch self {
        case .network: return "globe"
        case .ytdlp: return "arrow.down.circle"
        case .music: return "music.note"
        }
    }
}
