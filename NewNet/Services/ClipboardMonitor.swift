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

    init(settings: AppSettings, pasteboard: NSPasteboard = .general) {
        self.settings = settings
        self.pasteboard = pasteboard
        changeCount = pasteboard.changeCount
        start()
    }

    deinit {
        timer?.invalidate()
    }

    func dismissSuggestion() {
        detectedURL = nil
    }

    private func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
        timer?.tolerance = 0.5
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
}
