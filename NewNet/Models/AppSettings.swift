import Combine
import Foundation
import SwiftUI

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
        static let isLastFMEnabled = "settings.isLastFMEnabled"
        static let isListenBrainzEnabled = "settings.isListenBrainzEnabled"
        static let lastFMUsername = "settings.lastFMUsername"
        static let listenBrainzUsername = "settings.listenBrainzUsername"
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
        tabOrder = Self.normalizedTabOrder(storedTabOrder.compactMap(NewNetTab.init(rawValue:)))
        isLastFMEnabled = defaults.bool(forKey: Keys.isLastFMEnabled)
        isListenBrainzEnabled = defaults.bool(forKey: Keys.isListenBrainzEnabled)
        lastFMUsername = defaults.string(forKey: Keys.lastFMUsername) ?? ""
        listenBrainzUsername = defaults.string(forKey: Keys.listenBrainzUsername) ?? ""
    }

    func restoreDefaultTabOrder() {
        tabOrder = NewNetTab.defaultOrder
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
