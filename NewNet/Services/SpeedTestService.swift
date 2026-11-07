import Combine
import Foundation

struct SpeedTestResult: Codable, Equatable, Identifiable {
    let id: UUID
    let date: Date
    let latencyMilliseconds: Double
    let jitterMilliseconds: Double
    let downloadMegabitsPerSecond: Double
    let uploadMegabitsPerSecond: Double
    let serverDescription: String
}

@MainActor
final class SpeedTestService: ObservableObject {
    enum Phase: Equatable {
        case idle
        case latency
        case download
        case upload
        case complete
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var latencyMilliseconds: Double?
    @Published private(set) var jitterMilliseconds: Double?
    @Published private(set) var downloadMegabitsPerSecond: Double?
    @Published private(set) var uploadMegabitsPerSecond: Double?
    @Published private(set) var progress: Double = 0
    @Published private(set) var history: [SpeedTestResult] = []

    private let defaults: UserDefaults
    private var task: Task<Void, Never>?
    private let endpoint = URL(string: "https://speed.cloudflare.com")!
    private let historyKey = "network.speedTest.history"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: historyKey), let saved = try? JSONDecoder().decode([SpeedTestResult].self, from: data) {
            history = saved
        }
    }

    var isRunning: Bool {
        switch phase { case .latency, .download, .upload: return true; default: return false }
    }

    func start() {
        guard !isRunning else { return }
        task?.cancel()
        task = Task { [weak self] in
            await self?.run()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        phase = .idle
        progress = 0
    }

    private func run() async {
        do {
            phase = .latency
            progress = 0.05
            let samples = try await measureLatencySamples()
            try Task.checkCancellation()
            latencyMilliseconds = samples.average
            jitterMilliseconds = samples.jitter

            phase = .download
            progress = 0.25
            let download = try await measureDownload()
            try Task.checkCancellation()
            downloadMegabitsPerSecond = download

            phase = .upload
            progress = 0.65
            let upload = try await measureUpload()
            try Task.checkCancellation()
            uploadMegabitsPerSecond = upload

            let result = SpeedTestResult(
                id: UUID(),
                date: .now,
                latencyMilliseconds: samples.average,
                jitterMilliseconds: samples.jitter,
                downloadMegabitsPerSecond: download,
                uploadMegabitsPerSecond: upload,
                serverDescription: "Cloudflare global speed endpoint"
            )
            history.insert(result, at: 0)
            history = Array(history.prefix(10))
            if let data = try? JSONEncoder().encode(history) { defaults.set(data, forKey: historyKey) }
            progress = 1
            phase = .complete
        } catch is CancellationError {
            phase = .idle
            progress = 0
        } catch {
            phase = .failed(error.localizedDescription)
            progress = 0
        }
        task = nil
    }

    private func measureLatencySamples() async throws -> (average: Double, jitter: Double) {
        var values: [Double] = []
        for _ in 0..<5 {
            try Task.checkCancellation()
            let start = ContinuousClock.now
            var request = URLRequest(url: endpoint.appendingPathComponent("__down?bytes=0"))
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (_, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode ?? 0 >= 200 else { throw URLError(.badServerResponse) }
            let duration = start.duration(to: .now)
            values.append(Double(duration.components.seconds) * 1_000 + Double(duration.components.attoseconds) / 1_000_000_000_000_000)
        }
        guard !values.isEmpty else { throw URLError(.cannotLoadFromNetwork) }
        let average = values.reduce(0, +) / Double(values.count)
        let jitter = values.dropFirst().enumerated().reduce(0) { partial, pair in
            partial + abs(pair.element - values[pair.offset])
        } / Double(max(values.count - 1, 1))
        return (average, jitter)
    }

    private func measureDownload() async throws -> Double {
        let byteCount = 25_000_000
        let start = ContinuousClock.now
        let url = endpoint.appendingPathComponent("__down?bytes=\(byteCount)")
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode ?? 0 >= 200, !data.isEmpty else { throw URLError(.badServerResponse) }
        let duration = start.duration(to: .now)
        let elapsed = max(Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1_000_000_000_000_000_000, 0.001)
        return Double(data.count * 8) / elapsed / 1_000_000
    }

    private func measureUpload() async throws -> Double {
        let payload = Data(repeating: 0, count: 10_000_000)
        var request = URLRequest(url: endpoint.appendingPathComponent("__up"))
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let start = ContinuousClock.now
        let (_, response) = try await URLSession.shared.upload(for: request, from: payload)
        guard (response as? HTTPURLResponse)?.statusCode ?? 0 >= 200 else { throw URLError(.badServerResponse) }
        let duration = start.duration(to: .now)
        let elapsed = max(Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1_000_000_000_000_000_000, 0.001)
        return Double(payload.count * 8) / elapsed / 1_000_000
    }
}
