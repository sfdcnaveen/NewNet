import Foundation

final class NetworkUsageStore {
    private struct UsageBaseline: Codable {
        var dayStamp: String
        var receivedBaseline: UInt64
        var sentBaseline: UInt64
    }

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let calendar = Calendar.current

    private var cachedBaseline: UsageBaseline?

    init(fileManager: FileManager = .default) {
        let supportURL = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let baseURL = (supportURL ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("NewNet", isDirectory: true)

        try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        fileURL = baseURL.appendingPathComponent("usage-baseline.json")

        if
            let data = try? Data(contentsOf: fileURL),
            let baseline = try? decoder.decode(UsageBaseline.self, from: data)
        {
            cachedBaseline = baseline
        }
    }

    func usage(for snapshot: NetworkSpeedSnapshot) -> NetworkUsage {
        let dayStamp = dayIdentifier(for: snapshot.sampledAt)

        if cachedBaseline?.dayStamp != dayStamp {
            let freshBaseline = UsageBaseline(
                dayStamp: dayStamp,
                receivedBaseline: snapshot.totalReceivedBytes,
                sentBaseline: snapshot.totalSentBytes
            )
            cachedBaseline = freshBaseline
            persist()
        }

        guard let baseline = cachedBaseline else {
            return .zero
        }

        if snapshot.totalReceivedBytes < baseline.receivedBaseline ||
            snapshot.totalSentBytes < baseline.sentBaseline
        {
            let refreshedBaseline = UsageBaseline(
                dayStamp: dayStamp,
                receivedBaseline: snapshot.totalReceivedBytes,
                sentBaseline: snapshot.totalSentBytes
            )
            cachedBaseline = refreshedBaseline
            persist()
            return .zero
        }

        return NetworkUsage(
            receivedBytes: snapshot.totalReceivedBytes &- baseline.receivedBaseline,
            sentBytes: snapshot.totalSentBytes &- baseline.sentBaseline
        )
    }

    private func dayIdentifier(for date: Date) -> String {
        let startOfDay = calendar.startOfDay(for: date)
        return ISO8601DateFormatter().string(from: startOfDay)
    }

    private func persist() {
        guard let cachedBaseline else { return }
        guard let data = try? encoder.encode(cachedBaseline) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
