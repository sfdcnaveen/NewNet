import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let maxSegments = "settings.maxSegments"
        static let speedLimitKBps = "settings.speedLimitKBps"
        static let clipboardMonitoringEnabled = "settings.clipboardMonitoringEnabled"
        static let autoResumeDownloads = "settings.autoResumeDownloads"
        static let launchAtLogin = "settings.launchAtLogin"
        static let powerSavingEnabled = "settings.powerSavingEnabled"
        static let analyticsEnabled = "settings.analyticsEnabled"
        static let menuBarPanelScale = "settings.menuBarPanelScale"
        static let ytDLPPath = "settings.ytDLPPath"
        static let youtubeDLPath = "settings.youtubeDLPath"
        static let galleryDLPath = "settings.galleryDLPath"
        static let youGetPath = "settings.youGetPath"
        static let svtplayDLPath = "settings.svtplayDLPath"
        static let aria2cPath = "settings.aria2cPath"
        static let wgetPath = "settings.wgetPath"
        static let getSaucePath = "settings.getSaucePath"
        static let luxPath = "settings.luxPath"
        static let preferredMediaType = "settings.preferredMediaType"
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

    @Published var analyticsEnabled: Bool {
        didSet {
            defaults.set(analyticsEnabled, forKey: Keys.analyticsEnabled)
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

    @Published var galleryDLPath: String {
        didSet {
            defaults.set(galleryDLPath.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.galleryDLPath)
        }
    }

    @Published var youtubeDLPath: String {
        didSet {
            defaults.set(youtubeDLPath.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.youtubeDLPath)
        }
    }

    @Published var youGetPath: String {
        didSet {
            defaults.set(youGetPath.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.youGetPath)
        }
    }

    @Published var svtplayDLPath: String {
        didSet {
            defaults.set(svtplayDLPath.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.svtplayDLPath)
        }
    }

    @Published var aria2cPath: String {
        didSet {
            defaults.set(aria2cPath.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.aria2cPath)
        }
    }

    @Published var wgetPath: String {
        didSet {
            defaults.set(wgetPath.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.wgetPath)
        }
    }

    @Published var getSaucePath: String {
        didSet {
            defaults.set(getSaucePath.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.getSaucePath)
        }
    }

    @Published var luxPath: String {
        didSet {
            defaults.set(luxPath.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.luxPath)
        }
    }

    @Published var preferredMediaType: DownloadContentPreference {
        didSet {
            defaults.set(preferredMediaType.rawValue, forKey: Keys.preferredMediaType)
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
        analyticsEnabled = defaults.object(forKey: Keys.analyticsEnabled) as? Bool ?? true
        let storedMenuBarPanelScale = defaults.object(forKey: Keys.menuBarPanelScale) as? Double ?? 1.0
        menuBarPanelScale = min(max(storedMenuBarPanelScale, 0.85), 1.25)
        ytDLPPath = defaults.string(forKey: Keys.ytDLPPath) ?? ""
        youtubeDLPath = defaults.string(forKey: Keys.youtubeDLPath) ?? ""
        galleryDLPath = defaults.string(forKey: Keys.galleryDLPath) ?? ""
        youGetPath = defaults.string(forKey: Keys.youGetPath) ?? ""
        svtplayDLPath = defaults.string(forKey: Keys.svtplayDLPath) ?? ""
        aria2cPath = defaults.string(forKey: Keys.aria2cPath) ?? ""
        wgetPath = defaults.string(forKey: Keys.wgetPath) ?? ""
        getSaucePath = defaults.string(forKey: Keys.getSaucePath) ?? ""
        luxPath = defaults.string(forKey: Keys.luxPath) ?? ""
        preferredMediaType = DownloadContentPreference(
            rawValue: defaults.string(forKey: Keys.preferredMediaType) ?? ""
        ) ?? .auto
    }

    func overridePath(for tool: ExternalTool) -> String {
        switch tool {
        case .ytDLP:
            ytDLPPath
        case .galleryDL:
            galleryDLPath
        case .youtubeDL:
            youtubeDLPath
        case .youGet:
            youGetPath
        case .svtplayDL:
            svtplayDLPath
        case .aria2c:
            aria2cPath
        case .wget:
            wgetPath
        case .getSauce:
            getSaucePath
        case .lux:
            luxPath
        }
    }

    func setOverridePath(_ value: String, for tool: ExternalTool) {
        switch tool {
        case .ytDLP:
            ytDLPPath = value
        case .galleryDL:
            galleryDLPath = value
        case .youtubeDL:
            youtubeDLPath = value
        case .youGet:
            youGetPath = value
        case .svtplayDL:
            svtplayDLPath = value
        case .aria2c:
            aria2cPath = value
        case .wget:
            wgetPath = value
        case .getSauce:
            getSaucePath = value
        case .lux:
            luxPath = value
        }
    }
}
