import Foundation

enum ExternalTool: String, CaseIterable, Identifiable {
    case ytDLP = "yt-dlp"
    case youtubeDL = "youtube-dl"
    case galleryDL = "gallery-dl"
    case youGet = "you-get"
    case svtplayDL = "svtplay-dl"
    case aria2c = "aria2c"
    case wget = "wget"
    case getSauce = "get-sauce"
    case lux = "lux"

    var id: String { rawValue }

    var title: String { rawValue }

    var defaultPaths: [String] {
        [
            "/opt/homebrew/bin/\(rawValue)",
            "/usr/local/bin/\(rawValue)",
            "/usr/bin/\(rawValue)"
        ]
    }
}

struct ExternalToolStatus: Identifiable {
    let tool: ExternalTool
    let resolvedPath: String?

    var id: String { tool.id }

    var description: String {
        resolvedPath ?? "Not found"
    }
}

final class ExternalToolsService {
    func resolvePath(for tool: ExternalTool, overridePath: String) -> String? {
        let trimmedOverride = overridePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = [trimmedOverride].filter { !$0.isEmpty } + tool.defaultPaths

        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        return nil
    }

    func status(for tool: ExternalTool, settings: AppSettings) -> ExternalToolStatus {
        ExternalToolStatus(
            tool: tool,
            resolvedPath: resolvePath(for: tool, overridePath: settings.overridePath(for: tool))
        )
    }
}
