import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: "NEWNET_UPDATE",
                actions: [
                    UNNotificationAction(identifier: "INSTALL_UPDATE", title: "Open NewNet", options: [.foreground]),
                    UNNotificationAction(identifier: "DISMISS_UPDATE", title: "Dismiss", options: [])
                ],
                intentIdentifiers: [],
                options: []
            )
        ])
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == "INSTALL_UPDATE" else { return }
        await MainActor.run {
            UpdateManager.shared.installUpdate()
        }
    }
}
