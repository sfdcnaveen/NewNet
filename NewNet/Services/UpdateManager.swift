import Foundation
import Combine
import OSLog
import Sparkle
import UserNotifications
import AppKit

@MainActor
final class UpdateManager: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let shared = UpdateManager()

    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var availableUpdate: SUAppcastItem?
    @Published private(set) var isDownloadingUpdate = false
    @Published private(set) var updateDownloadProgress: Double = 0.0
    @Published private(set) var isCheckingForUpdates = false
    @Published private(set) var lastCheckDate: Date?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var isUpdateNotificationSuppressed = false

    private static let feedPlaceholder = "https://raw.githubusercontent.com/OWNER/REPO/main/appcast.xml"
    private static let publicKeyPlaceholder = "CHANGE_ME_WITH_SPARKLE_PUBLIC_KEY"

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "NewNet", category: "updates")
    private var updater: SPUUpdater?
    private var silentDriver: SilentUserDriver?
    private var canCheckObservation: NSKeyValueObservation?
    private var didPerformLaunchCheck = false
    private var updateReplyHandler: ((SPUUserUpdateChoice) -> Void)?
    private var periodicCheckTask: Task<Void, Never>?
    private var foregroundObserver: Any?
    private let defaults = UserDefaults.standard
    private let suppressedVersionKey = "updates.suppressedVersion"
    private let notifiedVersionKey = "updates.notifiedVersion"

    private override init() {
        super.init()

        if Self.isSparkleConfigured {
            let driver = SilentUserDriver()
            self.silentDriver = driver
            
            driver.onUpdateFound = { [weak self] item, reply in
                Task { @MainActor [weak self] in
                    self?.receiveUpdate(item, reply: reply)
                }
            }
            driver.onDownloadProgress = { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.isDownloadingUpdate = true
                    self?.updateDownloadProgress = progress
                    self?.lastErrorMessage = nil
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
                foregroundObserver = NotificationCenter.default.addObserver(
                    forName: NSApplication.didBecomeActiveNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.checkForUpdates(reason: "foreground")
                    }
                }
                periodicCheckTask = Task { @MainActor [weak self] in
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 6 * 60 * 60 * 1_000_000_000)
                        guard !Task.isCancelled else { return }
                        self?.checkForUpdates(reason: "periodic")
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
        checkForUpdates(reason: "launch")
    }

    func checkForUpdatesManually() {
        guard updater != nil else {
            logger.notice("Manual update check ignored: Sparkle not configured")
            return
        }
        checkForUpdates(reason: "manual", userInitiated: true)
    }

    func dismissAvailableUpdate() {
        guard let availableUpdate else { return }
        defaults.set(availableUpdate.versionString, forKey: suppressedVersionKey)
        isUpdateNotificationSuppressed = true
        updateReplyHandler?(.dismiss)
        updateReplyHandler = nil
    }

    func showDismissedUpdateAgain() {
        defaults.removeObject(forKey: suppressedVersionKey)
        isUpdateNotificationSuppressed = false
        checkForUpdates(reason: "manual", userInitiated: true)
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

    private func checkForUpdates(reason: String, userInitiated: Bool = false) {
        guard let updater else { return }
        if userInitiated, !updater.canCheckForUpdates { return }

        isCheckingForUpdates = true
        lastErrorMessage = nil
        logger.info("Performing \(reason, privacy: .public) update check")
        if userInitiated {
            updater.checkForUpdates()
        } else {
            updater.checkForUpdatesInBackground()
        }
    }

    private func receiveUpdate(_ item: SUAppcastItem, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        availableUpdate = item
        updateReplyHandler = reply
        isCheckingForUpdates = false
        lastCheckDate = .now
        let suppressedVersion = defaults.string(forKey: suppressedVersionKey)
        isUpdateNotificationSuppressed = suppressedVersion == item.versionString

        guard !isUpdateNotificationSuppressed else {
            reply(.dismiss)
            updateReplyHandler = nil
            return
        }
        if defaults.string(forKey: notifiedVersionKey) != item.versionString {
            defaults.set(item.versionString, forKey: notifiedVersionKey)
            postUpdateNotification(for: item)
        }
    }

    private func postUpdateNotification(for item: SUAppcastItem) {
        let content = UNMutableNotificationContent()
        content.title = "NewNet update available"
        content.body = "Version \(item.displayVersionString) is ready to install."
        content.sound = .default
        content.categoryIdentifier = "NEWNET_UPDATE"
        content.userInfo = ["version": item.versionString]

        let request = UNNotificationRequest(
            identifier: "newnet.update.\(item.versionString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                Task { @MainActor [weak self] in
                    self?.logger.debug("Could not post update notification: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    // MARK: - SPUUpdaterDelegate
    nonisolated func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        Task { @MainActor in
            self.isCheckingForUpdates = false
            self.lastCheckDate = .now
            if let error {
                if (error as NSError).code == SUError.noUpdateError.rawValue {
                    self.availableUpdate = nil
                    self.updateReplyHandler = nil
                } else {
                    self.lastErrorMessage = error.localizedDescription
                }
            } else {
                self.lastErrorMessage = nil
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
