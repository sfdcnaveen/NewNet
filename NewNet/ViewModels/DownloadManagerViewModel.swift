import Combine
import Foundation
import UniformTypeIdentifiers

struct PendingMediaSelection: Identifiable, Hashable {
    let id = UUID()
    let mediaInfo: YTDLPMediaInfo
    var selectedPreference: DownloadContentPreference
    var selectedOptionID: String
    var gifStart: TimeInterval = 0
    var gifEnd: TimeInterval = 5

    var availableOptions: [YTDLPDownloadOption] {
        switch selectedPreference {
        case .audio:
            return mediaInfo.audioOptions
        case .gif:
            return mediaInfo.videoOptions.map(makeGIFOption)
        case .auto, .video:
            return mediaInfo.videoOptions
        }
    }

    var selectedOption: YTDLPDownloadOption? {
        availableOptions.first(where: { $0.id == selectedOptionID })
    }

    var gifDuration: TimeInterval {
        max(0.5, gifEnd - gifStart)
    }

    private func makeGIFOption(from option: YTDLPDownloadOption) -> YTDLPDownloadOption {
        var configuration = option.configuration
        configuration.formatExpression = option.configuration.formatExpression.split(separator: "+", maxSplits: 1).first.map(String.init) ?? option.configuration.formatExpression
        configuration.displayName = "GIF • \(qualityLabel(for: option.label))"
        configuration.detailText = "Animated GIF • \(option.label)"
        configuration.contentPreference = .gif
        configuration.extractAudio = false
        configuration.audioFormat = nil
        configuration.mergeOutputFormat = nil

        return YTDLPDownloadOption(
            id: option.id,
            label: configuration.displayName,
            detail: configuration.detailText,
            estimatedBytes: option.estimatedBytes,
            configuration: configuration
        )
    }

    private func qualityLabel(for label: String) -> String {
        label.split(separator: "•", maxSplits: 1).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? label
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
    @Published private(set) var isYTDLPInstalled: Bool
    @Published private(set) var isInstallingYTDLP = false
    @Published var ytdlpInstallError: String?

    private let downloadManager: DownloadManager
    private let settings: AppSettings
    private let ytDLPService = YTDLPService()
    private var cancellables: Set<AnyCancellable> = []

    init(downloadManager: DownloadManager, settings: AppSettings) {
        self.downloadManager = downloadManager
        self.settings = settings
        isYTDLPInstalled = ytDLPService.isInstalled(settings: settings)
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

        let hasVideo = !pendingMediaSelection.mediaInfo.videoOptions.isEmpty
        let hasAudio = !pendingMediaSelection.mediaInfo.audioOptions.isEmpty
        let normalizedPreference: DownloadContentPreference = {
            if preference == .audio, hasAudio { return .audio }
            if preference == .gif, hasVideo { return .gif }
            return hasVideo ? .video : .audio
        }()
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

        var selectedOption = option
        if pendingMediaSelection.selectedPreference == .gif {
            var configuration = option.configuration
            configuration.contentPreference = .gif
            configuration.clipStart = pendingMediaSelection.gifStart
            configuration.clipEnd = pendingMediaSelection.gifEnd
            selectedOption = YTDLPDownloadOption(
                id: "gif-\(option.id)-\(Int(pendingMediaSelection.gifStart))-\(Int(pendingMediaSelection.gifEnd))",
                label: "GIF • \(durationString(pendingMediaSelection.gifDuration))",
                detail: "Animated clip • \(option.label)",
                estimatedBytes: option.estimatedBytes,
                configuration: configuration
            )
        }

        switch downloadManager.confirmMediaDownload(mediaInfo: pendingMediaSelection.mediaInfo, option: selectedOption) {
        case .accepted:
            validationMessage = nil
            urlField = ""
            self.pendingMediaSelection = nil
        case .rejected(let message):
            validationMessage = message
        }
    }

    func setGIFRange(start: TimeInterval, end: TimeInterval) {
        guard var pendingMediaSelection else { return }
        let maxDuration = pendingMediaSelection.mediaInfo.duration ?? 86_400
        let clampedStart = min(max(start, 0), maxDuration)
        let clampedEnd = min(max(end, clampedStart + 0.5), maxDuration)
        pendingMediaSelection.gifStart = clampedStart
        pendingMediaSelection.gifEnd = clampedEnd
        self.pendingMediaSelection = pendingMediaSelection
    }

    func applyGIFPreset(_ duration: TimeInterval) {
        guard let pendingMediaSelection else { return }
        let maxDuration = pendingMediaSelection.mediaInfo.duration ?? duration
        setGIFRange(start: pendingMediaSelection.gifStart, end: min(pendingMediaSelection.gifStart + duration, maxDuration))
    }

    func installYTDLP() {
        guard !isInstallingYTDLP else { return }
        isInstallingYTDLP = true
        ytdlpInstallError = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                _ = try await ytDLPService.install(settings: settings)
                isYTDLPInstalled = true
            } catch {
                ytdlpInstallError = error.localizedDescription
            }
            isInstallingYTDLP = false
        }
    }

    private func submitDefaultMediaDownload(_ mediaInfo: YTDLPMediaInfo) {
        let pendingSelection = makePendingSelection(for: mediaInfo)
        guard let option = pendingSelection.selectedOption else {
            validationMessage = "No downloadable formats were found for this link."
            pendingMediaSelection = nil
            return
        }

        switch downloadManager.confirmMediaDownload(mediaInfo: mediaInfo, option: option) {
        case .accepted:
            validationMessage = nil
            urlField = ""
            pendingMediaSelection = nil
        case .rejected(let message):
            validationMessage = message
            pendingMediaSelection = nil
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

    func showInFinder(_ item: DownloadItem) {
        downloadManager.showInFinder(item)
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
        case .gif:
            preferredSelection = mediaInfo.videoOptions.isEmpty ? .audio : .gif
        case .auto, .video:
            preferredSelection = mediaInfo.videoOptions.isEmpty ? .audio : .video
        }

        let selectedOptionID = {
            switch preferredSelection {
            case .audio:
                return mediaInfo.audioOptions.first?.id
            case .auto, .video, .gif:
                return mediaInfo.videoOptions.first?.id
            }
        }() ?? ""

        return PendingMediaSelection(
            mediaInfo: mediaInfo,
            selectedPreference: preferredSelection,
            selectedOptionID: selectedOptionID,
            gifEnd: min(5, mediaInfo.duration ?? 5)
        )
    }

    private func durationString(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        return "\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))"
    }
}
