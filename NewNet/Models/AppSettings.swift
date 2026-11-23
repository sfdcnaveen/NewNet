import Combine
import Foundation
import SwiftUI
import AppKit

enum BrowserCookieSource: String, CaseIterable, Identifiable, Sendable {
    case safari = "Safari"
    case chrome = "Google Chrome"
    case brave = "Brave"
    case edge = "Microsoft Edge"
    case firefox = "Firefox"
    case custom = "Custom File"
    case none = "None"

    nonisolated var id: String { rawValue }

    nonisolated var displayName: String { rawValue }

    nonisolated var ytDLPBrowserArg: String? {
        switch self {
        case .safari: return "safari"
        case .chrome: return "chrome"
        case .brave: return "brave"
        case .edge: return "edge"
        case .firefox: return "firefox"
        case .custom, .none: return nil
        }
    }

    nonisolated var iconName: String {
        switch self {
        case .safari: return "safari"
        case .chrome, .brave, .edge, .firefox: return "globe"
        case .custom: return "doc.text"
        case .none: return "slash.circle"
        }
    }

    @MainActor
    var isInstalled: Bool {
        switch self {
        case .none, .custom, .safari:
            return true
        case .chrome:
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") != nil
        case .brave:
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.brave.Browser") != nil
        case .edge:
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.edgemac") != nil
        case .firefox:
            return NSWorkspace.shared.urlForApplication(withBundleIdentifier: "org.mozilla.firefox") != nil
        }
    }

    @MainActor
    static var availableSources: [BrowserCookieSource] {
        allCases.filter(\.isInstalled)
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    var id: String { rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let maxSegments = "settings.maxSegments"
        static let speedLimitKBps = "settings.speedLimitKBps"
        static let clipboardMonitoringEnabled = "settings.clipboardMonitoringEnabled"
        static let autoResumeDownloads = "settings.autoResumeDownloads"
        static let launchAtLogin = "settings.launchAtLogin"
        static let powerSavingEnabled = "settings.powerSavingEnabled"
        static let menuBarPanelScale = "settings.menuBarPanelScale"
        static let ytDLPPath = "settings.ytDLPPath"
        static let preferredMediaType = "settings.preferredMediaType"
        static let appTheme = "settings.appTheme"
        static let showActiveApplications = "settings.showActiveApplications"
        static let tabOrder = "settings.tabOrder"
        static let hiddenTabs = "settings.hiddenTabs"
        static let isLastFMEnabled = "settings.isLastFMEnabled"
        static let isListenBrainzEnabled = "settings.isListenBrainzEnabled"
        static let lastFMUsername = "settings.lastFMUsername"
        static let listenBrainzUsername = "settings.listenBrainzUsername"
        static let keepAwakeDurationMinutes = "settings.keepAwakeDurationMinutes"
        static let keepAwakePreventDisplaySleep = "settings.keepAwakePreventDisplaySleep"
        static let clipboardHistoryEnabled = "settings.clipboardHistoryEnabled"
        static let clipboardHistoryLimit = "settings.clipboardHistoryLimit"
        static let scrollInversionEnabled = "settings.scrollInversionEnabled"
        static let scrollInvertVertical = "settings.scrollInvertVertical"
        static let scrollInvertHorizontal = "settings.scrollInvertHorizontal"
        static let finderCutPasteEnabled = "settings.finderCutPasteEnabled"
        static let autoQuitEnabled = "settings.autoQuitEnabled"
        static let autoQuitExceptions = "settings.autoQuitExceptions"
        static let browserCookieSource = "settings.browserCookieSource"
        static let customCookiesPath = "settings.customCookiesPath"
    }

    nonisolated static var safariCookiesURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies")
    }

    nonisolated static var isSafariCookiesReadable: Bool {
        FileManager.default.isReadableFile(atPath: safariCookiesURL.path)
    }

    private let defaults: UserDefaults

    @Published var maxSegments: Int {
        didSet {
            let clamped = min(max(maxSegments, 1), 8)
            if maxSegments != clamped {
                maxSegments = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.maxSegments)
        }
    }

    @Published var speedLimitKBps: Int {
        didSet {
            let clamped = max(speedLimitKBps, 0)
            if speedLimitKBps != clamped {
                speedLimitKBps = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.speedLimitKBps)
        }
    }

    @Published var clipboardMonitoringEnabled: Bool {
        didSet {
            defaults.set(clipboardMonitoringEnabled, forKey: Keys.clipboardMonitoringEnabled)
        }
    }

    @Published var autoResumeDownloads: Bool {
        didSet {
            defaults.set(autoResumeDownloads, forKey: Keys.autoResumeDownloads)
        }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        }
    }

    @Published var powerSavingEnabled: Bool {
        didSet {
            defaults.set(powerSavingEnabled, forKey: Keys.powerSavingEnabled)
        }
    }

    @Published var menuBarPanelScale: Double {
        didSet {
            let clamped = min(max(menuBarPanelScale, 0.85), 1.25)
            if menuBarPanelScale != clamped {
                menuBarPanelScale = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.menuBarPanelScale)
        }
    }

    @Published var ytDLPPath: String {
        didSet {
            defaults.set(ytDLPPath.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.ytDLPPath)
        }
    }

    @Published var preferredMediaType: DownloadContentPreference {
        didSet {
            defaults.set(preferredMediaType.rawValue, forKey: Keys.preferredMediaType)
        }
    }

    @Published var appTheme: AppTheme {
        didSet {
            defaults.set(appTheme.rawValue, forKey: Keys.appTheme)
        }
    }

    @Published var showActiveApplications: Bool {
        didSet {
            defaults.set(showActiveApplications, forKey: Keys.showActiveApplications)
        }
    }

    @Published var tabOrder: [NewNetTab] {
        didSet {
            let normalized = Self.normalizedTabOrder(tabOrder)
            if tabOrder != normalized {
                tabOrder = normalized
                return
            }
            defaults.set(normalized.map(\.rawValue), forKey: Keys.tabOrder)
        }
    }

    @Published var hiddenTabRawValues: [String] {
        didSet {
            defaults.set(hiddenTabRawValues, forKey: Keys.hiddenTabs)
        }
    }

    var visibleTabs: [NewNetTab] {
        let visible = tabOrder.filter { !hiddenTabRawValues.contains($0.rawValue) }
        return visible.isEmpty ? [tabOrder.first ?? .network] : visible
    }

    func isTabVisible(_ tab: NewNetTab) -> Bool {
        !hiddenTabRawValues.contains(tab.rawValue)
    }

    func toggleTabVisibility(_ tab: NewNetTab) {
        if isTabVisible(tab) {
            // Guard: Keep at least 1 tab visible at all times
            guard visibleTabs.count > 1 else { return }
            hiddenTabRawValues.append(tab.rawValue)
        } else {
            hiddenTabRawValues.removeAll { $0 == tab.rawValue }
        }
    }

    @Published var isLastFMEnabled: Bool {
        didSet {
            defaults.set(isLastFMEnabled, forKey: Keys.isLastFMEnabled)
        }
    }

    @Published var isListenBrainzEnabled: Bool {
        didSet {
            defaults.set(isListenBrainzEnabled, forKey: Keys.isListenBrainzEnabled)
        }
    }

    @Published var lastFMUsername: String {
        didSet {
            defaults.set(lastFMUsername, forKey: Keys.lastFMUsername)
        }
    }

    @Published var listenBrainzUsername: String {
        didSet {
            defaults.set(listenBrainzUsername, forKey: Keys.listenBrainzUsername)
        }
    }

    @Published var keepAwakeDurationMinutes: Int {
        didSet {
            defaults.set(keepAwakeDurationMinutes, forKey: Keys.keepAwakeDurationMinutes)
        }
    }

    @Published var keepAwakePreventDisplaySleep: Bool {
        didSet {
            defaults.set(keepAwakePreventDisplaySleep, forKey: Keys.keepAwakePreventDisplaySleep)
        }
    }

    @Published var clipboardHistoryEnabled: Bool {
        didSet {
            defaults.set(clipboardHistoryEnabled, forKey: Keys.clipboardHistoryEnabled)
        }
    }

    @Published var clipboardHistoryLimit: Int {
        didSet {
            let clamped = min(max(clipboardHistoryLimit, 10), 200)
            if clipboardHistoryLimit != clamped {
                clipboardHistoryLimit = clamped
                return
            }
            defaults.set(clamped, forKey: Keys.clipboardHistoryLimit)
        }
    }

    @Published var scrollInversionEnabled: Bool {
        didSet {
            defaults.set(scrollInversionEnabled, forKey: Keys.scrollInversionEnabled)
        }
    }

    @Published var scrollInvertVertical: Bool {
        didSet {
            defaults.set(scrollInvertVertical, forKey: Keys.scrollInvertVertical)
        }
    }

    @Published var scrollInvertHorizontal: Bool {
        didSet {
            defaults.set(scrollInvertHorizontal, forKey: Keys.scrollInvertHorizontal)
        }
    }

    @Published var finderCutPasteEnabled: Bool {
        didSet {
            defaults.set(finderCutPasteEnabled, forKey: Keys.finderCutPasteEnabled)
        }
    }

    @Published var autoQuitEnabled: Bool {
        didSet {
            defaults.set(autoQuitEnabled, forKey: Keys.autoQuitEnabled)
        }
    }

    @Published var autoQuitExceptions: [String] {
        didSet {
            defaults.set(autoQuitExceptions, forKey: Keys.autoQuitExceptions)
        }
    }

    @Published var browserCookieSource: BrowserCookieSource {
        didSet {
            defaults.set(browserCookieSource.rawValue, forKey: Keys.browserCookieSource)
        }
    }

    @Published var customCookiesPath: String {
        didSet {
            defaults.set(customCookiesPath.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.customCookiesPath)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedSegments = defaults.object(forKey: Keys.maxSegments) as? Int ?? 4
        let storedSpeedLimit = defaults.object(forKey: Keys.speedLimitKBps) as? Int ?? 0

        maxSegments = min(max(storedSegments, 1), 8)
        speedLimitKBps = max(storedSpeedLimit, 0)
        clipboardMonitoringEnabled = defaults.object(forKey: Keys.clipboardMonitoringEnabled) as? Bool ?? true
        autoResumeDownloads = defaults.object(forKey: Keys.autoResumeDownloads) as? Bool ?? true
        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? LaunchAtLoginManager.isEnabled
        powerSavingEnabled = defaults.object(forKey: Keys.powerSavingEnabled) as? Bool ?? true
        let storedMenuBarPanelScale = defaults.object(forKey: Keys.menuBarPanelScale) as? Double ?? 1.0
        menuBarPanelScale = min(max(storedMenuBarPanelScale, 0.85), 1.25)
        ytDLPPath = defaults.string(forKey: Keys.ytDLPPath) ?? ""
        preferredMediaType = DownloadContentPreference(
            rawValue: defaults.string(forKey: Keys.preferredMediaType) ?? ""
        ) ?? .auto
        appTheme = AppTheme(
            rawValue: defaults.string(forKey: Keys.appTheme) ?? ""
        ) ?? .system
        showActiveApplications = defaults.object(forKey: Keys.showActiveApplications) as? Bool ?? true
        let storedTabOrder = defaults.stringArray(forKey: Keys.tabOrder) ?? []
        let resolvedTabOrder = Self.normalizedTabOrder(storedTabOrder.compactMap(NewNetTab.init(rawValue:)))
        tabOrder = resolvedTabOrder
        let storedHiddenTabs = defaults.stringArray(forKey: Keys.hiddenTabs) ?? []
        let validHidden = storedHiddenTabs.filter { NewNetTab(rawValue: $0) != nil }
        if validHidden.count >= resolvedTabOrder.count {
            hiddenTabRawValues = []
        } else {
            hiddenTabRawValues = validHidden
        }
        isLastFMEnabled = defaults.bool(forKey: Keys.isLastFMEnabled)
        isListenBrainzEnabled = defaults.bool(forKey: Keys.isListenBrainzEnabled)
        lastFMUsername = defaults.string(forKey: Keys.lastFMUsername) ?? ""
        listenBrainzUsername = defaults.string(forKey: Keys.listenBrainzUsername) ?? ""
        keepAwakeDurationMinutes = defaults.object(forKey: Keys.keepAwakeDurationMinutes) as? Int ?? 0
        keepAwakePreventDisplaySleep = defaults.bool(forKey: Keys.keepAwakePreventDisplaySleep)
        clipboardHistoryEnabled = defaults.object(forKey: Keys.clipboardHistoryEnabled) as? Bool ?? true
        clipboardHistoryLimit = defaults.object(forKey: Keys.clipboardHistoryLimit) as? Int ?? 50
        scrollInversionEnabled = defaults.bool(forKey: Keys.scrollInversionEnabled)
        scrollInvertVertical = defaults.object(forKey: Keys.scrollInvertVertical) as? Bool ?? true
        scrollInvertHorizontal = defaults.bool(forKey: Keys.scrollInvertHorizontal)
        finderCutPasteEnabled = defaults.bool(forKey: Keys.finderCutPasteEnabled)
        autoQuitEnabled = defaults.bool(forKey: Keys.autoQuitEnabled)
        autoQuitExceptions = defaults.stringArray(forKey: Keys.autoQuitExceptions) ?? []
        let storedCookieSource = defaults.string(forKey: Keys.browserCookieSource)
        browserCookieSource = BrowserCookieSource(rawValue: storedCookieSource ?? "") ?? .safari
        customCookiesPath = defaults.string(forKey: Keys.customCookiesPath) ?? ""
    }

    func restoreDefaultTabOrder() {
        tabOrder = NewNetTab.defaultOrder
        hiddenTabRawValues = []
    }

    func moveTab(from source: IndexSet, to destination: Int) {
        tabOrder.move(fromOffsets: source, toOffset: destination)
    }

    private static func normalizedTabOrder(_ order: [NewNetTab]) -> [NewNetTab] {
        var result: [NewNetTab] = []
        for tab in order where !result.contains(tab) {
            result.append(tab)
        }
        for tab in NewNetTab.defaultOrder where !result.contains(tab) {
            result.append(tab)
        }
        return result
    }




}
