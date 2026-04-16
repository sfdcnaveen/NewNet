import Foundation
import Combine
import OSLog
import Sparkle

@MainActor
final class UpdateManager: NSObject, ObservableObject {
    static let shared = UpdateManager()

    @Published private(set) var canCheckForUpdates = false

    private static let feedPlaceholder = "https://raw.githubusercontent.com/OWNER/REPO/main/appcast.xml"
    private static let publicKeyPlaceholder = "CHANGE_ME_WITH_SPARKLE_PUBLIC_KEY"

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "NewNet", category: "updates")
    private let updaterController: SPUStandardUpdaterController?
    private var canCheckObservation: NSKeyValueObservation?
    private var didPerformLaunchCheck = false

    private override init() {
        if Self.isSparkleConfigured {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        } else {
            updaterController = nil
        }

        super.init()

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
        guard updater.automaticallyChecksForUpdates else { return }

        logger.info("Performing launch update check")
        updater.checkForUpdatesInBackground()
    }

    func checkForUpdatesManually() {
        guard let updaterController else {
            logger.notice("Manual update check ignored: Sparkle not configured")
            return
        }

        logger.info("Performing manual update check")
        updaterController.checkForUpdates(nil)
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
