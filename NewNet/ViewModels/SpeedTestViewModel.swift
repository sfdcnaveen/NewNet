import Combine
import Foundation

@MainActor
final class SpeedTestViewModel: ObservableObject {
    private enum Keys {
        static let history = "speedTest.history"
        static let autoEnabled = "speedTest.autoEnabled"
        static let autoInterval = "speedTest.autoIntervalMinutes"
    }

    @Published private(set) var isTesting = false
    @Published private(set) var lastResult: SpeedTestResult?
    @Published private(set) var history: [SpeedTestResult] = []
    @Published private(set) var errorMessage: String?
    @Published var autoTestEnabled: Bool {
        didSet {
            defaults.set(autoTestEnabled, forKey: Keys.autoEnabled)
            updateAutoTestTimer()
        }
    }
    @Published var autoTestIntervalMinutes: Int {
        didSet {
            let clamped = min(max(autoTestIntervalMinutes, 2), 60)
            if clamped != autoTestIntervalMinutes {
                autoTestIntervalMinutes = clamped
                return
            }
            defaults.set(autoTestIntervalMinutes, forKey: Keys.autoInterval)
            updateAutoTestTimer()
        }
    }
    @Published private(set) var menuBarQuickText: String?

    private let manager: SpeedTestManager
    private let defaults: UserDefaults
    private var autoTestTimer: Timer?
    private var clearQuickTextTask: Task<Void, Never>?

    init(manager: SpeedTestManager, defaults: UserDefaults = .standard) {
        self.manager = manager
        self.defaults = defaults

        let storedInterval = defaults.object(forKey: Keys.autoInterval) as? Int ?? 5
        autoTestIntervalMinutes = min(max(storedInterval, 2), 60)
        autoTestEnabled = defaults.object(forKey: Keys.autoEnabled) as? Bool ?? false

        loadHistory()
        updateAutoTestTimer()
    }

    func updateEndpoints(_ endpoints: SpeedTestEndpoints) {
        manager.updateEndpoints(endpoints)
        errorMessage = nil
    }

    func runSpeedTest() {
        guard !isTesting else { return }

        isTesting = true
        errorMessage = nil

        Task {
            do {
                let result = try await manager.runFullTest()
                handleSuccess(result)
            } catch {
                handleFailure(error)
            }
        }
    }

    private func handleSuccess(_ result: SpeedTestResult) {
        lastResult = result
        appendHistory(result)
        updateQuickText(with: result)
        isTesting = false
        errorMessage = nil
    }

    private func handleFailure(_ error: Error) {
        isTesting = false
        errorMessage = userFacingMessage(for: error)
    }

    private func updateQuickText(with result: SpeedTestResult) {
        let down = Int(result.download.rounded())
        let up = Int(result.upload.rounded())
        menuBarQuickText = "↓ \(down) Mbps ↑ \(up) Mbps"

        clearQuickTextTask?.cancel()
        clearQuickTextTask = Task {
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            await MainActor.run {
                self.menuBarQuickText = nil
            }
        }
    }

    private func updateAutoTestTimer() {
        autoTestTimer?.invalidate()
        autoTestTimer = nil

        guard autoTestEnabled else { return }

        autoTestTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(autoTestIntervalMinutes * 60),
            repeats: true
        ) { [weak self] _ in
            Task { await self?.runSpeedTest() }
        }
    }

    private func appendHistory(_ result: SpeedTestResult) {
        history.insert(result, at: 0)
        if history.count > 10 {
            history.removeLast(history.count - 10)
        }
        saveHistory()
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        defaults.set(data, forKey: Keys.history)
    }

    private func loadHistory() {
        guard let data = defaults.data(forKey: Keys.history),
              let decoded = try? JSONDecoder().decode([SpeedTestResult].self, from: data) else {
            return
        }
        history = decoded
        lastResult = decoded.first
    }

    private func userFacingMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "Network error"
            case .timedOut:
                return "Test timed out"
            case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return "Server unavailable"
            default:
                return "Test failed, try again"
            }
        }

        if let speedError = error as? SpeedTestError {
            switch speedError {
            case .timeout:
                return "Test timed out"
            case .serverUnavailable:
                return "Server unavailable"
            case .networkFailure:
                return "Network error"
            case .invalidResponse:
                return "Test failed, try again"
            }
        }

        return "Test failed, try again"
    }
}
