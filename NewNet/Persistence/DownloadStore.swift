import Foundation

final class DownloadStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let supportURL = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let baseURL = (supportURL ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("NewNet", isDirectory: true)

        try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        fileURL = baseURL.appendingPathComponent("downloads.json")
    }

    func load() -> [DownloadItem] {
        guard
            let data = try? Data(contentsOf: fileURL),
            let items = try? decoder.decode([DownloadItem].self, from: data)
        else {
            return []
        }

        return items
    }

    func save(_ items: [DownloadItem]) throws {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(items)
        try data.write(to: fileURL, options: .atomic)
    }
}
