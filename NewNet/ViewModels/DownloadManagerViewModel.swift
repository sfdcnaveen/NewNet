import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class DownloadManagerViewModel: ObservableObject {
    @Published private(set) var items: [DownloadItem] = []
    @Published var urlField = ""
    @Published var validationMessage: String?
    @Published var contentPreference: DownloadContentPreference

    private let downloadManager: DownloadManager
    private let settings: AppSettings
    private var cancellables: Set<AnyCancellable> = []

    init(downloadManager: DownloadManager, settings: AppSettings) {
        self.downloadManager = downloadManager
        self.settings = settings
        contentPreference = settings.preferredMediaType

        downloadManager.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.items = $0 }
            .store(in: &cancellables)

        $contentPreference
            .dropFirst()
            .sink { [weak self] in
                self?.settings.preferredMediaType = $0
            }
            .store(in: &cancellables)
    }

    var activeDownloads: [DownloadItem] {
        items.filter { !$0.isTerminal }
    }

    var recentDownloads: [DownloadItem] {
        items.prefix(6).map { $0 }
    }

    var canClearRecentDownloads: Bool {
        items.contains { $0.isTerminal }
    }

    func submitURL() {
        switch downloadManager.addDownload(from: urlField, contentPreference: contentPreference) {
        case .accepted:
            validationMessage = nil
            urlField = ""
        case .rejected(let message):
            validationMessage = message
        }
    }

    func pause(_ item: DownloadItem) {
        downloadManager.pause(item)
    }

    func resume(_ item: DownloadItem) {
        downloadManager.resume(item)
    }

    func open(_ item: DownloadItem) {
        downloadManager.open(item)
    }

    func openDownloadsFolder() {
        downloadManager.openDownloadsFolder()
    }

    func clearRecentDownloads() {
        downloadManager.clearRecentDownloads()
    }

    func fillURLField(with url: URL) {
        urlField = url.absoluteString
        validationMessage = nil
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        let supported = providers.contains {
            $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) ||
            $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
        }

        guard supported else { return false }

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, _ in
                    guard let self else { return }
                    if let data = item as? Data,
                       let string = String(data: data, encoding: .utf8),
                       let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines))
                    {
                        Task { @MainActor in
                            self.urlField = url.absoluteString
                            self.submitURL()
                        }
                    } else if let url = item as? URL {
                        Task { @MainActor in
                            self.urlField = url.absoluteString
                            self.submitURL()
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, _ in
                    guard let self else { return }
                    if let data = item as? Data,
                       let string = String(data: data, encoding: .utf8)
                    {
                        Task { @MainActor in
                            self.urlField = string.trimmingCharacters(in: .whitespacesAndNewlines)
                            self.submitURL()
                        }
                    } else if let string = item as? String {
                        Task { @MainActor in
                            self.urlField = string.trimmingCharacters(in: .whitespacesAndNewlines)
                            self.submitURL()
                        }
                    }
                }
            }
        }

        return true
    }
}
