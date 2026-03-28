import AppKit
import Combine
import Foundation

@MainActor
final class ClipboardMonitor: ObservableObject {
    @Published private(set) var detectedURL: URL?

    private let pasteboard: NSPasteboard
    private let settings: AppSettings
    private var changeCount: Int
    private var timer: Timer?
    private var lastDetectedString: String?
    private var pollInterval: TimeInterval = 2
    private var cancellables: Set<AnyCancellable> = []

    init(settings: AppSettings, pasteboard: NSPasteboard = .general) {
        self.settings = settings
        self.pasteboard = pasteboard
        changeCount = pasteboard.changeCount

        settings.$clipboardMonitoringEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled {
                    self.start()
                } else {
                    self.stop()
                }
            }
            .store(in: &cancellables)

        if settings.clipboardMonitoringEnabled {
            start()
        }
    }

    deinit {
        timer?.invalidate()
    }

    func dismissSuggestion() {
        detectedURL = nil
    }

    private func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
        timer?.tolerance = min(pollInterval * 0.25, 1)
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        detectedURL = nil
    }

    private func poll() {
        guard settings.clipboardMonitoringEnabled else {
            detectedURL = nil
            changeCount = pasteboard.changeCount
            return
        }

        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount

        guard let rawString = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            rawString != lastDetectedString,
            let url = URL(string: rawString),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme)
        else {
            return
        }

        lastDetectedString = rawString
        detectedURL = url
    }

    func setPollInterval(_ interval: TimeInterval) {
        let clamped = max(interval, 1)
        guard abs(clamped - pollInterval) > 0.1 else { return }
        pollInterval = clamped
        if settings.clipboardMonitoringEnabled {
            start()
        }
    }
}
