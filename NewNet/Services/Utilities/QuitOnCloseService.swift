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
    private var observers: [pid_t: AXObserver] = [:]
    private var pendingChecks: [pid_t: DispatchWorkItem] = [:]
    private var isMonitoring: Bool = false
    private var cancellables: Set<AnyCancellable> = []

    // Default system apps that should never be auto-quit
    private static let defaultExcludedBundleIDs: Set<String> = [
        "com.apple.finder",
        Bundle.main.bundleIdentifier ?? "NihanviBuilds.NewNet"
    ]

    private static let appNotifications = [
        kAXWindowCreatedNotification,
        kAXMainWindowChangedNotification,
        kAXFocusedWindowChangedNotification,
        kAXApplicationActivatedNotification
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

        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            self,
            selector: #selector(handleAppLaunched(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleAppActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        center.addObserver(
            self,
            selector: #selector(handleAppTerminated(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            attach(app)
        }

        Self.logger.info("Quit on Close monitoring started with AXObserver")
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        let center = NSWorkspace.shared.notificationCenter
        center.removeObserver(self, name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        center.removeObserver(self, name: NSWorkspace.didActivateApplicationNotification, object: nil)
        center.removeObserver(self, name: NSWorkspace.didTerminateApplicationNotification, object: nil)

        for pid in Array(observers.keys) {
            detach(pid: pid)
        }
        observers.removeAll()
        pendingChecks.values.forEach { $0.cancel() }
        pendingChecks.removeAll()
        hadWindows.removeAll()

        Self.logger.info("Quit on Close monitoring stopped")
    }

    // MARK: - AXObserver Attachment

    private func attach(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        let bundleID = app.bundleIdentifier ?? ""

        guard app.activationPolicy == .regular else { return }
        guard !Self.defaultExcludedBundleIDs.contains(bundleID), !exceptionSet.contains(bundleID) else { return }
        guard observers[pid] == nil else { return }

        var observerRef: AXObserver?
        guard AXObserverCreate(
            pid,
            { (observer, element, notification, refcon) in
                guard let refcon = refcon else { return }
                let service = Unmanaged<QuitOnCloseService>.fromOpaque(refcon).takeUnretainedValue()
                Task { @MainActor in
                    service.handleAXNotification(observer: observer, element: element, notification: notification as String)
                }
            },
            &observerRef
        ) == .success,
        let observer = observerRef else { return }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 0.35)

        for notification in Self.appNotifications {
            AXObserverAddNotification(observer, appElement, notification as CFString, refcon)
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        observers[pid] = observer

        refreshWindows(pid: pid, observer: observer)
    }

    private func detach(pid: pid_t) {
        if let observer = observers[pid] {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observers.removeValue(forKey: pid)
        hadWindows.remove(pid)
        pendingChecks[pid]?.cancel()
        pendingChecks.removeValue(forKey: pid)
    }

    private func refreshWindows(pid: pid_t, observer: AXObserver) {
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 0.35)

        let windows = standardWindows(of: appElement)
        if !windows.isEmpty {
            hadWindows.insert(pid)
        }

        for window in windows {
            AXObserverAddNotification(observer, window, kAXUIElementDestroyedNotification as CFString, refcon)
        }
    }

    // MARK: - Event Handling

    func handleAXNotification(observer: AXObserver, element: AXUIElement, notification: String) {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        if pid == 0 {
            pid = observers.first(where: { CFEqual($0.value, observer) })?.key ?? 0
        }
        guard pid != 0 else { return }

        if notification == (kAXWindowCreatedNotification as String) {
            hadWindows.insert(pid)
            pendingChecks[pid]?.cancel()
            pendingChecks.removeValue(forKey: pid)
            refreshWindows(pid: pid, observer: observer)
            return
        }

        if notification == (kAXUIElementDestroyedNotification as String) ||
           notification == (kAXMainWindowChangedNotification as String) {
            guard hadWindows.contains(pid) else { return }
            scheduleQuitCheck(pid: pid)
        }
    }

    private func scheduleQuitCheck(pid: pid_t) {
        pendingChecks[pid]?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self, self.isMonitoring else { return }
                self.performQuitCheck(pid: pid)
            }
        }
        pendingChecks[pid] = workItem
        // Brief debounce to allow new windows/tabs to open or dialogs to appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
    }

    private func performQuitCheck(pid: pid_t) {
        pendingChecks.removeValue(forKey: pid)

        guard let app = NSRunningApplication(processIdentifier: pid),
              !app.isTerminated,
              app.activationPolicy == .regular else {
            detach(pid: pid)
            return
        }

        let bundleID = app.bundleIdentifier ?? ""
        guard !Self.defaultExcludedBundleIDs.contains(bundleID), !exceptionSet.contains(bundleID) else { return }

        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 0.35)
        let windows = standardWindows(of: appElement)

        if windows.isEmpty && hadWindows.contains(pid) {
            Self.logger.info("QuitOnClose: Terminating \(app.localizedName ?? "\(pid)") because its last standard window was closed")
            detach(pid: pid)
            app.terminate()
        }
    }

    // MARK: - App Notifications

    @objc private func handleAppLaunched(_ notification: Notification) {
        guard isEnabled else { return }
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        attach(app)
    }

    @objc private func handleAppActivated(_ notification: Notification) {
        guard isEnabled else { return }
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        attach(app)
    }

    @objc private func handleAppTerminated(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        detach(pid: app.processIdentifier)
    }

    // MARK: - Window Inspection

    private func standardWindows(of appElement: AXUIElement) -> [AXUIElement] {
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            return []
        }

        return windows.filter { isStandardWindow($0) }
    }

    private func isStandardWindow(_ window: AXUIElement) -> Bool {
        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleRef) == .success,
              let role = roleRef as? String,
              role == (kAXWindowRole as String) else {
            return false
        }

        var subroleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &subroleRef) == .success,
           let subrole = subroleRef as? String {
            if subrole == (kAXFloatingWindowSubrole as String) || subrole == (kAXSystemDialogSubrole as String) {
                return false
            }
        }

        return true
    }
}
