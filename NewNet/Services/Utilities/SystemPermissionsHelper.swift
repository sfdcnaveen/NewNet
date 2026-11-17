import AppKit
import ApplicationServices
import Combine
import Foundation

@MainActor
final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published private(set) var isAccessibilityGranted: Bool = AXIsProcessTrusted()
    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []

    private init() {
        refresh()

        // Re-check whenever application becomes active
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refresh()
                }
            }
            .store(in: &cancellables)

        // Periodic light polling so toggling in System Settings reflects immediately
        startPolling()
    }

    func refresh() {
        let granted = AXIsProcessTrusted()
        if isAccessibilityGranted != granted {
            isAccessibilityGranted = granted
            objectWillChange.send()
        }
    }

    func startPolling(interval: TimeInterval = 1.0) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        timer?.tolerance = 0.2
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            SystemPermissionsHelper.openAccessibilityPreferences()
        }
        // Poll aggressively for 15 seconds after requesting
        startFastPolling()
    }

    private func startFastPolling() {
        timer?.invalidate()
        var elapsed = 0.0
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] t in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.refresh()
                elapsed += 0.5
                if self.isAccessibilityGranted || elapsed >= 15.0 {
                    t.invalidate()
                    self.startPolling()
                }
            }
        }
    }
}

enum SystemPermissionsHelper {
    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibility() {
        PermissionsManager.shared.requestAccessibility()
    }

    static func openAccessibilityPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

