import Combine
import Foundation
import UniformTypeIdentifiers

struct PendingMediaSelection: Identifiable, Hashable {
    let id = UUID()
    let mediaInfo: YTDLPMediaInfo
    var selectedPreference: DownloadContentPreference
    var selectedOptionID: String

    var availableOptions: [YTDLPDownloadOption] {
        switch selectedPreference {
        case .audio:
            return mediaInfo.audioOptions
        case .auto, .video:
            return mediaInfo.videoOptions
        }
    }

    var selectedOption: YTDLPDownloadOption? {
        availableOptions.first(where: { $0.id == selectedOptionID })
    }
}

@MainActor
final class DownloadManagerViewModel: ObservableObject {
    @Published private(set) var items: [DownloadItem] = []
    @Published var urlField = ""
    @Published var validationMessage: String?
    @Published var contentPreference: DownloadContentPreference
    @Published var isInspectingURL = false
    @Published var pendingMediaSelection: PendingMediaSelection?

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
        guard !isInspectingURL else { return }

        let submittedValue = urlField
        isInspectingURL = true
        validationMessage = nil

        Task { @MainActor [weak self] in
            guard let self else { return }

            let result = await downloadManager.prepareDownload(from: submittedValue, contentPreference: contentPreference)
            isInspectingURL = false

            switch result {
            case .queued:
                validationMessage = nil
                pendingMediaSelection = nil
                urlField = ""
            case .requiresFormatSelection(let mediaInfo):
                pendingMediaSelection = makePendingSelection(for: mediaInfo)
            case .rejected(let message):
                validationMessage = message
            }
        }
    }

    func cancelPendingSelection() {
        pendingMediaSelection = nil
    }

    func setPendingPreference(_ preference: DownloadContentPreference) {
        guard var pendingMediaSelection else { return }

        let normalizedPreference: DownloadContentPreference = preference == .audio ? .audio : .video
        pendingMediaSelection.selectedPreference = normalizedPreference

        let availableOptions = pendingMediaSelection.availableOptions
        if !availableOptions.contains(where: { $0.id == pendingMediaSelection.selectedOptionID }) {
            pendingMediaSelection.selectedOptionID = availableOptions.first?.id ?? ""
        }

        self.pendingMediaSelection = pendingMediaSelection
    }

    func setPendingOption(id: String) {
        guard var pendingMediaSelection else { return }
        pendingMediaSelection.selectedOptionID = id
        self.pendingMediaSelection = pendingMediaSelection
    }

    func confirmPendingSelection() {
        guard let pendingMediaSelection, let option = pendingMediaSelection.selectedOption else {
            validationMessage = "Choose a format before downloading."
            return
        }

        switch downloadManager.confirmMediaDownload(mediaInfo: pendingMediaSelection.mediaInfo, option: option) {
        case .accepted:
            validationMessage = nil
            urlField = ""
            self.pendingMediaSelection = nil
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

    private func makePendingSelection(for mediaInfo: YTDLPMediaInfo) -> PendingMediaSelection {
        let preferredSelection: DownloadContentPreference
        switch contentPreference {
        case .audio:
            preferredSelection = mediaInfo.audioOptions.isEmpty ? .video : .audio
        case .auto, .video:
            preferredSelection = mediaInfo.videoOptions.isEmpty ? .audio : .video
        }

        let selectedOptionID = {
            switch preferredSelection {
            case .audio:
                return mediaInfo.audioOptions.first?.id
            case .auto, .video:
                return mediaInfo.videoOptions.first?.id
            }
        }() ?? ""

        return PendingMediaSelection(
            mediaInfo: mediaInfo,
            selectedPreference: preferredSelection,
            selectedOptionID: selectedOptionID
        )
    }
}
