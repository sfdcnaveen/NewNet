import Foundation
import Combine
import OSLog
import Sparkle

@MainActor
final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = UpdateManager()

    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var availableUpdate: SUAppcastItem?

    private static let feedPlaceholder = "https://raw.githubusercontent.com/OWNER/REPO/main/appcast.xml"
    private static let publicKeyPlaceholder = "CHANGE_ME_WITH_SPARKLE_PUBLIC_KEY"

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "NewNet", category: "updates")
    private var updaterController: SPUStandardUpdaterController?
    private var canCheckObservation: NSKeyValueObservation?
    private var didPerformLaunchCheck = false

    private override init() {
        super.init()

        if Self.isSparkleConfigured {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: self,
                userDriverDelegate: nil
            )
            // Ensure automatic checks are enabled to keep the app up to date silently
            updaterController?.updater.automaticallyChecksForUpdates = true
            // Enable automatic downloading so it doesn't prompt to download
            updaterController?.updater.automaticallyDownloadsUpdates = true
        }

        guard let controller = updaterController else {
            logger.notice("Sparkle disabled: set SUFeedURL and SUPublicEDKey to enable updates")
            return
        }

        canCheckObservation = controller.updater.observe(\SPUUpdater.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            Task { @MainActor [weak self] in
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }

        logger.info("Sparkle updater initialized")
    }

    func checkForUpdatesOnLaunch() {
        guard !didPerformLaunchCheck else { return }
        didPerformLaunchCheck = true
        guard let updater = updaterController?.updater else { return }
        
        logger.info("Performing silent launch update check")
        updater.checkForUpdateInformation()
    }

    func checkForUpdatesManually() {
        guard let updaterController else {
            logger.notice("Manual update check ignored: Sparkle not configured")
            return
        }
        logger.info("Performing manual update check")
        updaterController.checkForUpdates(nil)
    }

    func installUpdate() {
        guard let updaterController else { return }
        // This will present the download/install UI from Sparkle seamlessly
        updaterController.updater.checkForUpdatesInBackground()
    }

    // MARK: - SPUUpdaterDelegate
    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        Task { @MainActor in
            self.availableUpdate = item
        }
    }
    
    nonisolated func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        // If an error happens or no update is found during a silent check, clear available update
        if error != nil {
            Task { @MainActor in
                // If it's a "no update found" error, clear the banner
                if let code = (error as NSError?)?.code, code == SUError.noUpdateError.rawValue {
                    self.availableUpdate = nil
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
