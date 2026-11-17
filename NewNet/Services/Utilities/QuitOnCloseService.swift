import AppKit
import ApplicationServices
import Combine
import Foundation
import os.log

@MainActor
final class QuitOnCloseService: ObservableObject {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "NewNet", category: "QuitOnClose")

    @Published var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                startMonitoring()
            } else {
                stopMonitoring()
            }
        }
    }
    @Published var exceptions: [String] = [] {
        didSet {
            exceptionSet = Set(exceptions)
            UserDefaults.standard.set(exceptions, forKey: "settings.autoQuitExceptions")
        }
    }
    @Published private(set) var hasPermissionError: Bool = false

    private var exceptionSet: Set<String> = []
    private var hadWindows: Set<pid_t> = []
    private var pendingChecks: [pid_t: DispatchWorkItem] = [:]
    private var isMonitoring: Bool = false
    private var cancellables: Set<AnyCancellable> = []

    // Default system apps that should never be auto-quit
    private static let defaultExcludedBundleIDs: Set<String> = [
        "com.apple.finder",
        "com.apple.Safari",
        "com.apple.Preview",
        Bundle.main.bundleIdentifier ?? "NihanviBuilds.NewNet"
    ]

    init() {
        let stored = UserDefaults.standard.stringArray(forKey: "settings.autoQuitExceptions") ?? []
        self.exceptions = stored
        self.exceptionSet = Set(stored)

        PermissionsManager.shared.$isAccessibilityGranted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] granted in
                guard let self = self else { return }
                if granted {
                    if self.hasPermissionError {
                        self.hasPermissionError = false
                    }
                    if self.isEnabled && !self.isMonitoring {
                        self.startMonitoring()
                    }
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        MainActor.assumeIsolated {
            stopMonitoring()
        }
    }

    func addException(bundleIdentifier: String) {
        let trimmed = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !exceptions.contains(trimmed) else { return }
        exceptions.append(trimmed)
    }

    func removeException(bundleIdentifier: String) {
        exceptions.removeAll { $0 == bundleIdentifier }
    }

    func toggle() {
        isEnabled.toggle()
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard !isMonitoring else { return }
        guard SystemPermissionsHelper.isAccessibilityGranted else {
            hasPermissionError = true
            Self.logger.warning("Accessibility permission required for Quit on Close")
            return
        }
        hasPermissionError = false

        isMonitoring = true

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppDeactivated(_:)),
            name: NSWorkspace.didDeactivateApplicationNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleAppTerminated(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )

        // Seed initial apps that have windows
        updateInitialWindowedApps()
        Self.logger.info("Quit on Close monitoring started")
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.didDeactivateApplicationNotification, object: nil)
        NSWorkspace.shared.notificationCenter.removeObserver(self, name: NSWorkspace.didTerminateApplicationNotification, object: nil)

        pendingChecks.values.forEach { $0.cancel() }
        pendingChecks.removeAll()
        hadWindows.removeAll()

        Self.logger.info("Quit on Close monitoring stopped")
    }

    private func updateInitialWindowedApps() {
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            if countWindows(for: app) > 0 {
                hadWindows.insert(app.processIdentifier)
            }
        }
    }

    @objc private func handleAppDeactivated(_ notification: Notification) {
        guard isEnabled else { return }
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        let pid = app.processIdentifier
        let bundleID = app.bundleIdentifier ?? ""

        // Exclude background agents, system apps, and user exceptions
        guard app.activationPolicy == .regular else { return }
        guard !Self.defaultExcludedBundleIDs.contains(bundleID) else { return }
        guard !exceptionSet.contains(bundleID) else { return }

        // If the app currently has windows, register it
        let currentWindowCount = countWindows(for: app)
        if currentWindowCount > 0 {
            hadWindows.insert(pid)
            return
        }

        // Only auto-quit apps that have previously presented a window in this session
        guard hadWindows.contains(pid) else { return }

        // Schedule check with a brief debounce so dialogs or new windows have time to render
        pendingChecks[pid]?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.performQuitCheck(for: app)
            }
        }
        pendingChecks[pid] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    @objc private func handleAppTerminated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        let pid = app.processIdentifier
        hadWindows.remove(pid)
        pendingChecks[pid]?.cancel()
        pendingChecks.removeValue(forKey: pid)
    }

    private func performQuitCheck(for app: NSRunningApplication) {
        let pid = app.processIdentifier
        pendingChecks.removeValue(forKey: pid)

        guard !app.isTerminated else {
            hadWindows.remove(pid)
            return
        }

        let windowCount = countWindows(for: app)
        if windowCount == 0 && hadWindows.contains(pid) {
            Self.logger.info("Auto-quitting application: \(app.localizedName ?? "\(pid)")")
            hadWindows.remove(pid)
            app.terminate()
        }
    }

    private func countWindows(for app: NSRunningApplication) -> Int {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            return 0
        }

        // Filter out minimized or hidden sheets if needed
        var standardWindows = 0
        for window in windows {
            var roleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleRef) == .success,
               let role = roleRef as? String,
               role == kAXWindowRole as String {
                standardWindows += 1
            }
        }

        return standardWindows
    }
}
