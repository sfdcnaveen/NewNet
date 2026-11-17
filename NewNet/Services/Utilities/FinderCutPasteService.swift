import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import Foundation
import os
fileprivate let finderLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "NewNet", category: "FinderCutPaste")

@MainActor
final class FinderCutPasteService: ObservableObject {
    private static let finderBundleID = "com.apple.finder"

    @Published var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                start()
            } else {
                stop()
            }
        }
    }
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var markedURLs: [URL] = []
    @Published private(set) var hasPermissionError: Bool = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var markedPasteboardChangeCount: Int = 0

    // Virtual key codes for ANSI
    private enum KeyCode {
        static let x: Int64 = 7
        static let v: Int64 = 9
        static let escape: Int64 = 53
    }

    init() {
        let stored = UserDefaults.standard.bool(forKey: "settings.finderCutPasteEnabled")
        if stored {
            self.isEnabled = true
        }
    }

    deinit {
        MainActor.assumeIsolated {
            stop()
        }
    }

    func toggle() {
        isEnabled.toggle()
        UserDefaults.standard.set(isEnabled, forKey: "settings.finderCutPasteEnabled")
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }

        guard SystemPermissionsHelper.isAccessibilityGranted else {
            hasPermissionError = true
            finderLogger.warning("Accessibility permission missing for Finder Cut & Paste")
            return
        }
        hasPermissionError = false

        let eventMask = (1 << CGEventType.keyDown.rawValue)
        let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let service = Unmanaged<FinderCutPasteService>.fromOpaque(refcon).takeUnretainedValue()
                return service.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: observer
        ) else {
            hasPermissionError = true
            finderLogger.error("Failed to create CGEvent tap for Finder Cut & Paste")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)

        self.eventTap = tap
        self.runLoopSource = source
        self.isRunning = true
        CGEvent.tapEnable(tap: tap, enable: true)

        finderLogger.info("Finder Cut & Paste event tap installed")
    }

    func stop() {
        guard isRunning else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            self.runLoopSource = nil
        }
        self.eventTap = nil
        self.isRunning = false
        self.markedURLs.removeAll()

        finderLogger.info("Finder Cut & Paste event tap removed")
    }

    // MARK: - Event Tap Callback

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        // Only intercept when Finder is the frontmost application
        guard isFinderFrontmost() else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Check for Escape to cancel cut
        if keyCode == KeyCode.escape && !markedURLs.isEmpty {
            Task { @MainActor [weak self] in
                self?.markedURLs.removeAll()
            }
            return Unmanaged.passUnretained(event)
        }

        // Check for Cmd key without Shift, Control, or Option
        let cmdPressed = flags.contains(.maskCommand)
        let otherModifiers = flags.contains(.maskAlternate) || flags.contains(.maskControl) || flags.contains(.maskShift)
        guard cmdPressed && !otherModifiers else {
            return Unmanaged.passUnretained(event)
        }

        // If user is editing text (renaming or search box), do NOT intercept
        if isFinderEditingText() {
            return Unmanaged.passUnretained(event)
        }

        if keyCode == KeyCode.x {
            // ⌘X: Cut selected items
            return handleCut(event: event)
        } else if keyCode == KeyCode.v {
            // ⌘V: Paste / Move cut items
            return handlePaste(event: event)
        }

        return Unmanaged.passUnretained(event)
    }

    private func isFinderFrontmost() -> Bool {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Self.finderBundleID
    }

    private func isFinderEditingText() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.bundleIdentifier == Self.finderBundleID else { return false }

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        var focusedElementRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElementRef) == .success,
              let focusedElement = focusedElementRef else {
            return false
        }

        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String {
            if role == kAXTextFieldRole as String || role == kAXTextAreaRole as String {
                return true
            }
        }
        return false
    }

    // MARK: - Cut Operation

    private func handleCut(event: CGEvent) -> Unmanaged<CGEvent>? {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let urls = self.fetchFinderSelection()
            guard !urls.isEmpty else { return }

            DispatchQueue.main.async {
                self.markedURLs = urls
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.writeObjects(urls.map { $0 as NSURL })
                self.markedPasteboardChangeCount = pb.changeCount
                NSSound(named: "Pop")?.play()
                finderLogger.info("Marked \(urls.count) files for cut")
            }
        }

        // Swallow the key event so Finder does not beep
        return nil
    }

    // MARK: - Paste / Move Operation

    private func handlePaste(event: CGEvent) -> Unmanaged<CGEvent>? {
        let pb = NSPasteboard.general
        // Verify clipboard changeCount matches: if user copied something else, leave ⌘V as normal paste
        guard !markedURLs.isEmpty, pb.changeCount == markedPasteboardChangeCount else {
            if !markedURLs.isEmpty {
                markedURLs.removeAll()
            }
            return Unmanaged.passUnretained(event)
        }

        let urlsToMove = markedURLs
        markedURLs.removeAll()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard let targetFolder = self.fetchFinderInsertionLocation() else {
                finderLogger.warning("Could not determine Finder insertion location for paste")
                return
            }

            self.moveFiles(urlsToMove, to: targetFolder)
            DispatchQueue.main.async {
                NSSound(named: "Blow")?.play()
            }
        }

        // Swallow the event so Finder does not execute standard paste
        return nil
    }

    // MARK: - AppleScript Finder Integration

    nonisolated private func fetchFinderSelection() -> [URL] {
        let script = """
        tell application "Finder"
            set out to ""
            repeat with f in (get selection)
                set out to out & (POSIX path of (f as alias)) & linefeed
            end repeat
            return out
        end tell
        """
        guard let result = runAppleScript(script) else { return [] }
        return result.split(whereSeparator: \.isNewline)
            .map { URL(fileURLWithPath: String($0)) }
    }

    nonisolated private func fetchFinderInsertionLocation() -> URL? {
        let script = """
        tell application "Finder"
            try
                return POSIX path of (insertion location as alias)
            on error
                return ""
            end try
        end tell
        """
        guard let result = runAppleScript(script)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !result.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: result, isDirectory: true)
    }

    nonisolated private func moveFiles(_ urls: [URL], to targetFolder: URL) {
        let fm = FileManager.default
        var movedCount = 0

        for source in urls {
            let destination = targetFolder.appendingPathComponent(source.lastPathComponent)
            do {
                if fm.fileExists(atPath: destination.path) {
                    // Unique name if file already exists in target
                    let uniqueDest = generateUniqueURL(for: destination)
                    try fm.moveItem(at: source, to: uniqueDest)
                } else {
                    try fm.moveItem(at: source, to: destination)
                }
                movedCount += 1
            } catch {
                finderLogger.error("Failed to move \(source.lastPathComponent): \(error.localizedDescription)")
            }
        }
        finderLogger.info("Successfully moved \(movedCount) of \(urls.count) files to \(targetFolder.path)")
    }

    nonisolated private func generateUniqueURL(for url: URL) -> URL {
        let fm = FileManager.default
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        let dir = url.deletingLastPathComponent()

        var counter = 2
        while true {
            let newName = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            let candidate = dir.appendingPathComponent(newName)
            if !fm.fileExists(atPath: candidate.path) {
                return candidate
            }
            counter += 1
        }
    }

    nonisolated private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: source) else { return nil }
        let output = scriptObject.executeAndReturnError(&error)
        if let error = error {
            finderLogger.error("AppleScript error: \(error)")
            return nil
        }
        return output.stringValue
    }
}
