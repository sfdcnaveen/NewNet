import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    private enum Keys {
        static let maxSegments = "settings.maxSegments"
        static let speedLimitKBps = "settings.speedLimitKBps"
        static let clipboardMonitoringEnabled = "settings.clipboardMonitoringEnabled"
        static let autoResumeDownloads = "settings.autoResumeDownloads"
        static let ytDLPPath = "settings.ytDLPPath"
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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedSegments = defaults.object(forKey: Keys.maxSegments) as? Int ?? 4
        let storedSpeedLimit = defaults.object(forKey: Keys.speedLimitKBps) as? Int ?? 0

        maxSegments = min(max(storedSegments, 1), 8)
        speedLimitKBps = max(storedSpeedLimit, 0)
        clipboardMonitoringEnabled = defaults.object(forKey: Keys.clipboardMonitoringEnabled) as? Bool ?? true
        autoResumeDownloads = defaults.object(forKey: Keys.autoResumeDownloads) as? Bool ?? true
        ytDLPPath = defaults.string(forKey: Keys.ytDLPPath) ?? ""
        preferredMediaType = DownloadContentPreference(
            rawValue: defaults.string(forKey: Keys.preferredMediaType) ?? ""
        ) ?? .auto
    }
}
