import SwiftUI

@main
struct NewNetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var updateManager: UpdateManager
    @StateObject private var settings: AppSettings
    @StateObject private var networkMonitor: NetworkSpeedMonitor
    @StateObject private var clipboardMonitor: ClipboardMonitor
    @StateObject private var downloadManager: DownloadManager
    @StateObject private var menuBarViewModel: MenuBarViewModel
    @StateObject private var downloadManagerViewModel: DownloadManagerViewModel
    private let statusBarController: StatusBarController
    private let performanceCoordinator: PerformanceCoordinator

    init() {
        let analytics = AnalyticsClient.shared
        let updateManager = UpdateManager.shared
        let settings = AppSettings()
        let usageStore = NetworkUsageStore()
        let networkMonitor = NetworkSpeedMonitor(usageStore: usageStore)
        let clipboardMonitor = ClipboardMonitor(settings: settings)
        let downloadManager = DownloadManager(settings: settings, analytics: analytics)
        let menuBarViewModel = MenuBarViewModel(
            networkMonitor: networkMonitor,
            clipboardMonitor: clipboardMonitor
        )
        let downloadManagerViewModel = DownloadManagerViewModel(
            downloadManager: downloadManager,
            settings: settings
        )
        let statusBarController = StatusBarController(
            menuBarViewModel: menuBarViewModel,
            downloadManagerViewModel: downloadManagerViewModel,
            settings: settings
        )
        let performanceCoordinator = PerformanceCoordinator(
            settings: settings,
            networkMonitor: networkMonitor,
            clipboardMonitor: clipboardMonitor,
            downloadManager: downloadManager
        )

        _updateManager = StateObject(wrappedValue: updateManager)
        _settings = StateObject(wrappedValue: settings)
        _networkMonitor = StateObject(wrappedValue: networkMonitor)
        _clipboardMonitor = StateObject(wrappedValue: clipboardMonitor)
        _downloadManager = StateObject(wrappedValue: downloadManager)
        _menuBarViewModel = StateObject(wrappedValue: menuBarViewModel)
        _downloadManagerViewModel = StateObject(wrappedValue: downloadManagerViewModel)
        self.statusBarController = statusBarController
        self.performanceCoordinator = performanceCoordinator

        Task { @MainActor in
            updateManager.checkForUpdatesOnLaunch()
            await analytics.setEnabled(settings.analyticsEnabled)
            await analytics.trackInstallIfNeeded()
            await analytics.trackAppOpened()
        }
    }

    var body: some Scene {
        Settings {
            SettingsView(settings: settings)
                .frame(width: 420, height: 360)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updateManager.checkForUpdatesManually()
                }
                .disabled(!updateManager.canCheckForUpdates)
            }
        }
    }
}
