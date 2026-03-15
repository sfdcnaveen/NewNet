import Combine
import Darwin
import Foundation

final class NetworkSpeedMonitor: ObservableObject {
    @Published private(set) var snapshot: NetworkSpeedSnapshot = .zero
    @Published private(set) var usage: NetworkUsage = .zero

    private struct InterfaceTotals {
        var receivedBytes: UInt64
        var sentBytes: UInt64
    }

    private let queue = DispatchQueue(label: "com.newnet.network-monitor", qos: .utility)
    private let usageStore: NetworkUsageStore

    private var timer: DispatchSourceTimer?
    private var lastSampleDate: Date?
    private var lastTotals: InterfaceTotals?

    init(usageStore: NetworkUsageStore) {
        self.usageStore = usageStore
        start()
    }

    deinit {
        timer?.cancel()
    }

    private func start() {
        guard timer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .seconds(1), leeway: .milliseconds(120))
        timer.setEventHandler { [weak self] in
            self?.sample()
        }
        self.timer = timer
        timer.resume()
    }

    private func sample() {
        let now = Date()
        let totals = Self.readInterfaceTotals()

        let interval = max(now.timeIntervalSince(lastSampleDate ?? now), 1)
        let previous = lastTotals ?? totals

        let snapshot = NetworkSpeedSnapshot(
            downloadBytesPerSecond: Double(totals.receivedBytes &- previous.receivedBytes) / interval,
            uploadBytesPerSecond: Double(totals.sentBytes &- previous.sentBytes) / interval,
            totalReceivedBytes: totals.receivedBytes,
            totalSentBytes: totals.sentBytes,
            sampledAt: now
        )

        let usage = usageStore.usage(for: snapshot)

        lastSampleDate = now
        lastTotals = totals

        DispatchQueue.main.async {
            self.snapshot = snapshot
            self.usage = usage
        }
    }

    private static func readInterfaceTotals() -> InterfaceTotals {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else {
            return InterfaceTotals(receivedBytes: 0, sentBytes: 0)
        }

        defer { freeifaddrs(pointer) }

        var receivedBytes: UInt64 = 0
        var sentBytes: UInt64 = 0
        var current = first

        while true {
            let interface = current.pointee
            let flags = Int32(interface.ifa_flags)
            let name = String(cString: interface.ifa_name)

            let isUsable = (flags & IFF_UP) != 0 &&
                (flags & IFF_RUNNING) != 0 &&
                (flags & IFF_LOOPBACK) == 0 &&
                !name.hasPrefix("awdl") &&
                !name.hasPrefix("llw") &&
                !name.hasPrefix("utun")

            if
                isUsable,
                let dataPointer = interface.ifa_data?.assumingMemoryBound(to: if_data.self)
            {
                let stats = dataPointer.pointee
                receivedBytes += UInt64(stats.ifi_ibytes)
                sentBytes += UInt64(stats.ifi_obytes)
            }

            guard let next = interface.ifa_next else { break }
            current = next
        }

        return InterfaceTotals(receivedBytes: receivedBytes, sentBytes: sentBytes)
    }
}
