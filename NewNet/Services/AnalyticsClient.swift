import Foundation
import OSLog

actor AnalyticsClient {
    private struct EventPayload: Codable, Sendable {
        let event: String
        let distinctID: String
        let timestamp: String
        let properties: [String: String]

        enum CodingKeys: String, CodingKey {
            case event
            case distinctID = "distinct_id"
            case timestamp
            case properties
        }
    }

    static let shared = AnalyticsClient()

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "NewNet", category: "analytics")
    private let defaults: UserDefaults
    private let queueFileURL: URL

    private let enabledKey = "settings.analyticsEnabled"
    private let anonymousIDKey = "analytics.anonymousID"
    private let installTrackedKey = "analytics.installTracked"

    private var eventQueue: [EventPayload]
    private var flushTask: Task<Void, Never>?
    private var retryDelayNanoseconds: UInt64 = 2_000_000_000

    init(defaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        self.defaults = defaults

        let supportDirectory = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        let analyticsDirectory = supportDirectory
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "NewNet", isDirectory: true)
            .appendingPathComponent("Analytics", isDirectory: true)

        try? fileManager.createDirectory(at: analyticsDirectory, withIntermediateDirectories: true)

        queueFileURL = analyticsDirectory.appendingPathComponent("events-queue.json")
        eventQueue = Self.loadQueue(from: queueFileURL)
    }

    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: enabledKey)

        if !enabled {
            eventQueue.removeAll()
            persistQueue()
            logger.info("Analytics disabled by user")
        } else {
            logger.info("Analytics enabled by user")
            scheduleFlushIfNeeded()
        }
    }

    func trackInstallIfNeeded() {
        guard isEnabled else { return }
        guard !defaults.bool(forKey: installTrackedKey) else { return }

        defaults.set(true, forKey: installTrackedKey)
        track(event: "app_installed")
    }

    func trackAppOpened() {
        track(event: "app_opened")
    }

    func trackFeatureUsed(_ feature: String, metadata: [String: String] = [:]) {
        var properties = metadata
        properties["feature"] = feature
        track(event: "feature_used", properties: properties)
    }

    private func track(event: String, properties: [String: String] = [:]) {
        guard isEnabled else { return }

        let payload = EventPayload(
            event: event,
            distinctID: anonymousID,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            properties: defaultProperties().merging(properties) { current, _ in current }
        )

        eventQueue.append(payload)
        persistQueue()
        scheduleFlushIfNeeded()
    }

    private var isEnabled: Bool {
        defaults.object(forKey: enabledKey) as? Bool ?? true
    }

    private var anonymousID: String {
        if let existingID = defaults.string(forKey: anonymousIDKey), !existingID.isEmpty {
            return existingID
        }

        let newID = UUID().uuidString.lowercased()
        defaults.set(newID, forKey: anonymousIDKey)
        return newID
    }

    private func defaultProperties() -> [String: String] {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"

        return [
            "app_version": appVersion,
            "build_number": buildNumber,
            "platform": "macOS"
        ]
    }

    private func scheduleFlushIfNeeded() {
        guard flushTask == nil else { return }

        flushTask = Task { [weak self] in
            await self?.flushLoop()
        }
    }

    private func flushLoop() async {
        defer { flushTask = nil }

        while !eventQueue.isEmpty {
            guard isEnabled else {
                eventQueue.removeAll()
                persistQueue()
                return
            }

            guard let endpoint = analyticsEndpoint else {
                return
            }

            do {
                let next = eventQueue[0]
                try await send(next, to: endpoint)
                eventQueue.removeFirst()
                persistQueue()
                retryDelayNanoseconds = 2_000_000_000
            } catch {
                logger.debug("Analytics event send failed: \(error.localizedDescription, privacy: .public)")
                try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
                retryDelayNanoseconds = min(retryDelayNanoseconds * 2, 300_000_000_000)
            }
        }
    }

    private var analyticsEndpoint: URL? {
        guard let endpointString = Bundle.main.object(forInfoDictionaryKey: "AnalyticsEndpointURL") as? String,
              !endpointString.isEmpty,
              let url = URL(string: endpointString),
              url.scheme == "https"
        else {
            return nil
        }

        return url
    }

    private func send(_ payload: EventPayload, to endpoint: URL) async throws {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            throw URLError(.badServerResponse)
        }
    }

    private func persistQueue() {
        guard let data = try? JSONEncoder().encode(eventQueue) else { return }
        try? data.write(to: queueFileURL, options: .atomic)
    }

    private static func loadQueue(from fileURL: URL) -> [EventPayload] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([EventPayload].self, from: data)) ?? []
    }
}
