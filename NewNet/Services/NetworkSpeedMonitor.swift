import Combine
import Darwin
import Foundation
#if canImport(AppKit)
import AppKit
#endif

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
    private var refreshInterval: TimeInterval = 1
    private var wakeObserver: Any?

    init(usageStore: NetworkUsageStore) {
        self.usageStore = usageStore
        registerWakeObserver()
        start()
    }

    deinit {
        MainActor.assumeIsolated {
            timer?.cancel()
            #if canImport(AppKit)
            if let wakeObserver {
                NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            }
            #endif
        }
    }

    private func start() {
        guard timer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        let milliseconds = max(Int(refreshInterval * 1000), 500)
        timer.schedule(deadline: .now(), repeating: .milliseconds(milliseconds), leeway: .milliseconds(120))
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.sample()
            }
        }
        self.timer = timer
        timer.resume()
    }

    private func registerWakeObserver() {
        #if canImport(AppKit)
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleWake()
            }
        }
        #endif
    }

    private func handleWake() {
        lastSampleDate = nil
        lastTotals = nil
        if let timer {
            timer.cancel()
            self.timer = nil
        }
        start()
    }

    func setRefreshInterval(_ interval: TimeInterval) {
        let clamped = max(interval, 0.5)
        guard abs(clamped - refreshInterval) > 0.1 else { return }
        refreshInterval = clamped

        guard let timer else { return }
        let milliseconds = max(Int(refreshInterval * 1000), 500)
        timer.schedule(
            deadline: .now(),
            repeating: .milliseconds(milliseconds),
            leeway: .milliseconds(200)
        )
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

        self.snapshot = snapshot
        self.usage = usage
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
