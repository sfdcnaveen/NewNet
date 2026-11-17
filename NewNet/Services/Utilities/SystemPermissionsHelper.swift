import AppKit
import ApplicationServices
import Combine
import Foundation
import os.log

public enum AccessibilityPermissionStatus: String, Sendable, Equatable {
    case granted
    case notGranted
    case unknown
}

@MainActor
public final class PermissionsManager: ObservableObject {
    public static let shared = PermissionsManager()
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "NewNet", category: "PermissionsManager")

    @Published public private(set) var status: AccessibilityPermissionStatus = .unknown
    @Published public private(set) var isAccessibilityGranted: Bool = false

    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        // Initial passive check without prompt
        refresh(prompt: false)
        setupNotificationObservers()
        startPolling()
    }

    private func setupNotificationObservers() {
        // App became active (window focus)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refresh(prompt: false)
                }
            }
            .store(in: &cancellables)

        // Window became key
        NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refresh(prompt: false)
                }
            }
            .store(in: &cancellables)

        // System wake from sleep
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refresh(prompt: false)
                }
            }
            .store(in: &cancellables)
    }

    @discardableResult
    public func refresh(prompt: Bool = false) -> Bool {
        let granted = Self.queryAccessibilityStatus(prompt: prompt)
        let newStatus: AccessibilityPermissionStatus = granted ? .granted : .notGranted

        if status != newStatus || isAccessibilityGranted != granted {
            status = newStatus
            isAccessibilityGranted = granted
            objectWillChange.send()
            Self.logger.info("Accessibility permission status updated: \(newStatus.rawValue)")
        }

        return granted
    }

    public func startPolling(interval: TimeInterval = 1.0) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh(prompt: false)
            }
        }
        timer?.tolerance = 0.2
    }

    public func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    public func requestAccessibility() {
        // Explicit user action: prompt TCC dialog and open System Settings if not already granted
        let trusted = refresh(prompt: true)
        if !trusted {
            SystemPermissionsHelper.openAccessibilityPreferences()
        }
        startFastPolling()
    }

    private var fastPollingRemainingTicks: Int = 0

    private func startFastPolling() {
        timer?.invalidate()
        fastPollingRemainingTicks = 40
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let granted = self.refresh(prompt: false)
                self.fastPollingRemainingTicks -= 1
                if granted || self.fastPollingRemainingTicks <= 0 {
                    self.timer?.invalidate()
                    self.startPolling()
                }
            }
        }
    }

    public static func restartApplication() {
        let bundleURL = Bundle.main.bundleURL
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    // Thread-safe query using AXIsProcessTrustedWithOptions
    nonisolated private static func queryAccessibilityStatus(prompt: Bool) -> Bool {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: prompt ? kCFBooleanTrue : kCFBooleanFalse] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

public enum SystemPermissionsHelper {
    public static var isAccessibilityGranted: Bool {
        PermissionsManager.shared.isAccessibilityGranted
    }

    public static var status: AccessibilityPermissionStatus {
        PermissionsManager.shared.status
    }

    public static func requestAccessibility() {
        PermissionsManager.shared.requestAccessibility()
    }

    public static func openAccessibilityPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public static func restartApplication() {
        PermissionsManager.restartApplication()
    }
}


