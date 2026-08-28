import Foundation
import Combine
import OSLog
import Sparkle

@MainActor
final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = UpdateManager()

    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var availableUpdate: SUAppcastItem?
    @Published private(set) var isDownloadingUpdate = false
    @Published private(set) var updateDownloadProgress: Double = 0.0

    private static let feedPlaceholder = "https://raw.githubusercontent.com/OWNER/REPO/main/appcast.xml"
    private static let publicKeyPlaceholder = "CHANGE_ME_WITH_SPARKLE_PUBLIC_KEY"

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "NewNet", category: "updates")
    private var updater: SPUUpdater?
    private var silentDriver: SilentUserDriver?
    private var canCheckObservation: NSKeyValueObservation?
    private var didPerformLaunchCheck = false
    private var updateReplyHandler: ((SPUUserUpdateChoice) -> Void)?

    private override init() {
        super.init()

        if Self.isSparkleConfigured {
            let driver = SilentUserDriver()
            self.silentDriver = driver
            
            driver.onUpdateFound = { [weak self] item, reply in
                Task { @MainActor [weak self] in
                    self?.availableUpdate = item
                    self?.updateReplyHandler = reply
                }
            }
            driver.onDownloadProgress = { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.isDownloadingUpdate = true
                    self?.updateDownloadProgress = progress
                }
            }
            driver.onReadyToInstall = { reply in
                reply(.install)
            }

            do {
                let newUpdater = SPUUpdater(
                    hostBundle: Bundle.main,
                    applicationBundle: Bundle.main,
                    userDriver: driver,
                    delegate: self
                )
                self.updater = newUpdater
                try newUpdater.start()
                
                newUpdater.automaticallyChecksForUpdates = true
                newUpdater.automaticallyDownloadsUpdates = false // Wait for user to tap "Install" on the banner
                
                canCheckObservation = newUpdater.observe(\SPUUpdater.canCheckForUpdates, options: [.initial, .new]) { [weak self] observedUpdater, _ in
                    Task { @MainActor [weak self] in
                        self?.canCheckForUpdates = observedUpdater.canCheckForUpdates
                    }
                }
                logger.info("Sparkle custom updater initialized")
            } catch {
                logger.error("Failed to start Sparkle updater: \(error.localizedDescription)")
            }
        } else {
            logger.notice("Sparkle disabled: set SUFeedURL and SUPublicEDKey to enable updates")
        }
    }

    func checkForUpdatesOnLaunch() {
        guard !didPerformLaunchCheck else { return }
        didPerformLaunchCheck = true
        guard let updater = updater else { return }
        
        logger.info("Performing silent launch update check")
        updater.checkForUpdatesInBackground()
    }

    func checkForUpdatesManually() {
        guard let updater = updater else {
            logger.notice("Manual update check ignored: Sparkle not configured")
            return
        }
        logger.info("Performing manual update check")
        updater.checkForUpdates()
    }

    func installUpdate() {
        if let reply = updateReplyHandler {
            logger.info("User tapped install, proceeding with download and installation.")
            isDownloadingUpdate = true
            updateDownloadProgress = 0.0
            reply(.install)
            updateReplyHandler = nil
        }
    }

    // MARK: - SPUUpdaterDelegate
    nonisolated func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        if error != nil {
            Task { @MainActor in
                if let code = (error as NSError?)?.code, code == SUError.noUpdateError.rawValue {
                    self.availableUpdate = nil
                    self.isDownloadingUpdate = false
                    self.updateDownloadProgress = 0.0
                }
            }
        }
    }

    private static var isSparkleConfigured: Bool {
        guard let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              !feedURL.isEmpty,
              feedURL != feedPlaceholder,
              URL(string: feedURL) != nil
        else {
            return false
        }

        guard let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              !publicKey.isEmpty,
              publicKey != publicKeyPlaceholder
        else {
            return false
        }

        return true
    }
}
