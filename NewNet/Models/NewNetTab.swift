import Foundation

enum NewNetTab: String, CaseIterable, Codable, Identifiable {
    case network
    case ytdlp
    case music
    case clipboard
    case utilities

    static let defaultOrder: [NewNetTab] = [.network, .ytdlp, .music, .clipboard, .utilities]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .network: return "Network"
        case .ytdlp: return "yt-dlp"
        case .music: return "Music"
        case .clipboard: return "Clipboard"
        case .utilities: return "Utilities"
        }
    }

    var systemImage: String {
        switch self {
        case .network: return "globe"
        case .ytdlp: return "arrow.down.circle"
        case .music: return "music.note"
        case .clipboard: return "doc.on.clipboard"
        case .utilities: return "wrench.and.screwdriver"
        }
    }
}
