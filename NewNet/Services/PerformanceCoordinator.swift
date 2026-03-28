import Combine
import Foundation

@MainActor
final class PerformanceCoordinator {
    private let settings: AppSettings
    private let networkMonitor: NetworkSpeedMonitor
    private let clipboardMonitor: ClipboardMonitor
    private let downloadManager: DownloadManager
    private var cancellables: Set<AnyCancellable> = []

    init(
        settings: AppSettings,
        networkMonitor: NetworkSpeedMonitor,
        clipboardMonitor: ClipboardMonitor,
        downloadManager: DownloadManager
    ) {
        self.settings = settings
        self.networkMonitor = networkMonitor
        self.clipboardMonitor = clipboardMonitor
        self.downloadManager = downloadManager

        observeSignals()
        applyPolicy()
    }

    private func observeSignals() {
        settings.$powerSavingEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyPolicy() }
            .store(in: &cancellables)

        downloadManager.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyPolicy() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyPolicy() }
            .store(in: &cancellables)
    }

    private func applyPolicy() {
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let hasActiveDownloads = downloadManager.items.contains(where: { $0.isActive })
        let powerSaving = settings.powerSavingEnabled || lowPower

        let networkInterval: TimeInterval
        if !powerSaving {
            networkInterval = 1
        } else if hasActiveDownloads {
            networkInterval = lowPower ? 2 : 1
        } else {
            networkInterval = lowPower ? 5 : 3
        }

        let clipboardInterval: TimeInterval
        if powerSaving {
            clipboardInterval = lowPower ? 8 : 5
        } else {
            clipboardInterval = 2
        }

        networkMonitor.setRefreshInterval(networkInterval)
        clipboardMonitor.setPollInterval(clipboardInterval)
    }
}
