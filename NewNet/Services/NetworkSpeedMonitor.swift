import Combine
import Darwin
import Foundation
import SystemConfiguration
#if canImport(AppKit)
import AppKit
#endif

@MainActor
final class NetworkSpeedMonitor: ObservableObject {
    @Published private(set) var snapshot: NetworkSpeedSnapshot = .zero
    @Published private(set) var usage: NetworkUsage = .zero
    @Published private(set) var interfaces: [NetworkInterfaceInfo] = []
    @Published private(set) var activeInterfaceName: String?
    @Published private(set) var connectionStatus: NetworkConnectionStatus = .unavailable
    @Published private(set) var history: [NetworkHistorySample] = []
    @Published private(set) var processUsage: [NetworkProcessUsage] = []
    @Published private(set) var isProcessMonitoringAvailable = true
    @Published private(set) var processMonitoringMessage: String?

    private struct InterfaceTotals {
        var receivedBytes: UInt64
        var sentBytes: UInt64
        var names: [String]
        var primaryName: String?
    }

    private let queue = DispatchQueue(label: "com.newnet.network-monitor", qos: .utility)
    private let processQueue = DispatchQueue(label: "com.newnet.network-process-monitor", qos: .utility)
    private let usageStore: NetworkUsageStore
    private var timer: DispatchSourceTimer?
    private var processTimer: DispatchSourceTimer?
    private var lastSampleDate: Date?
    private var lastTotals: InterfaceTotals?
    private var refreshInterval: TimeInterval = 1
    private var wakeObserver: Any?
    private var processMonitoringEnabled = false
    private var lastProcessSampleDate: Date?
    private var lastProcessCounters: [pid_t: NetworkProcessUsage] = [:]

    init(usageStore: NetworkUsageStore) {
        self.usageStore = usageStore
        registerWakeObserver()
        start()
    }

    deinit {
        MainActor.assumeIsolated {
            timer?.cancel()
            processTimer?.cancel()
            #if canImport(AppKit)
            if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
            #endif
        }
    }

    private func start() {
        guard timer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(max(Int(refreshInterval * 1000), 500)), leeway: .milliseconds(120))
        timer.setEventHandler { [weak self] in Task { @MainActor in self?.sample() } }
        self.timer = timer
        timer.resume()
    }

    private func registerWakeObserver() {
        #if canImport(AppKit)
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor in self?.resetBaselineAndRestart() }
        }
        #endif
    }

    private func resetBaselineAndRestart() {
        lastSampleDate = nil
        lastTotals = nil
        timer?.cancel()
        timer = nil
        start()
    }

    func setRefreshInterval(_ interval: TimeInterval) {
        let clamped = max(interval, 0.5)
        guard abs(clamped - refreshInterval) > 0.1 else { return }
        refreshInterval = clamped
        timer?.schedule(deadline: .now(), repeating: .milliseconds(max(Int(clamped * 1000), 500)), leeway: .milliseconds(200))
    }

    func setProcessMonitoringEnabled(_ enabled: Bool) {
        processMonitoringEnabled = enabled
        processTimer?.cancel()
        processTimer = nil
        processUsage = []
        lastProcessSampleDate = nil
        lastProcessCounters = [:]
        guard enabled else { return }
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/nettop") else {
            isProcessMonitoringAvailable = false
            processMonitoringMessage = "macOS nettop is unavailable on this system."
            return
        }

        isProcessMonitoringAvailable = true
        processMonitoringMessage = nil
        let timer = DispatchSource.makeTimerSource(queue: processQueue)
        timer.schedule(deadline: .now(), repeating: .seconds(5), leeway: .milliseconds(500))
        timer.setEventHandler { [weak self] in
            let samples = Self.readProcessSamples()
            Task { @MainActor in
                guard let self, self.processMonitoringEnabled else { return }
                if let samples {
                    let now = Date()
                    let elapsed = max(now.timeIntervalSince(self.lastProcessSampleDate ?? now), 0.001)
                    let rates = samples.compactMap { sample -> NetworkProcessUsage? in
                        guard let previous = self.lastProcessCounters[sample.id] else { return nil }
                        let down = sample.downloadBytesPerSecond >= previous.downloadBytesPerSecond
                            ? (sample.downloadBytesPerSecond - previous.downloadBytesPerSecond) / elapsed : 0
                        let up = sample.uploadBytesPerSecond >= previous.uploadBytesPerSecond
                            ? (sample.uploadBytesPerSecond - previous.uploadBytesPerSecond) / elapsed : 0
                        guard down > 0 || up > 0 else { return nil }
                        return NetworkProcessUsage(id: sample.id, name: sample.name, downloadBytesPerSecond: down, uploadBytesPerSecond: up)
                    }
                    self.processUsage = Array(rates.sorted { $0.totalBytesPerSecond > $1.totalBytesPerSecond }.prefix(8))
                    self.processMonitoringMessage = rates.isEmpty ? "Measuring application network activity…" : nil
                    self.lastProcessSampleDate = now
                    self.lastProcessCounters = Dictionary(uniqueKeysWithValues: samples.map { ($0.id, $0) })
                } else {
                    self.isProcessMonitoringAvailable = false
                    self.processMonitoringMessage = "macOS did not expose per-process network flows."
                }
            }
        }
        processTimer = timer
        timer.resume()
    }

    private func sample() {
        let now = Date()
        guard let totals = Self.readInterfaceTotals() else {
            connectionStatus = .unavailable
            activeInterfaceName = nil
            interfaces = []
            return
        }

        let info = Self.interfaceInfo(from: totals)
        interfaces = info
        activeInterfaceName = info.first(where: { $0.isPrimary })?.displayName ?? info.first?.displayName
        connectionStatus = info.isEmpty ? .disconnected : .connected

        guard let previous = lastTotals,
              let previousDate = lastSampleDate,
              totals.names == previous.names,
              totals.receivedBytes >= previous.receivedBytes,
              totals.sentBytes >= previous.sentBytes else {
            lastTotals = totals
            lastSampleDate = now
            return
        }

        let interval = max(now.timeIntervalSince(previousDate), 0.001)
        let down = Double(totals.receivedBytes - previous.receivedBytes) / interval
        let up = Double(totals.sentBytes - previous.sentBytes) / interval
        let nextSnapshot = NetworkSpeedSnapshot(downloadBytesPerSecond: down, uploadBytesPerSecond: up, totalReceivedBytes: totals.receivedBytes, totalSentBytes: totals.sentBytes, sampledAt: now)
        snapshot = nextSnapshot
        usage = usageStore.usage(for: nextSnapshot)
        history.append(NetworkHistorySample(id: now, downloadBytesPerSecond: down, uploadBytesPerSecond: up))
        if history.count > 60 { history.removeFirst(history.count - 60) }
        lastTotals = totals
        lastSampleDate = now
    }

    private static func readInterfaceTotals() -> InterfaceTotals? {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard sysctl(&mib, 6, nil, &length, nil, 0) == 0, length > 0 else { return nil }
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, 6, &buffer, &length, nil, 0) == 0 else { return nil }

        var perInterface: [String: (received: UInt64, sent: UInt64)] = [:]
        buffer.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            let headerSize = MemoryLayout<if_msghdr>.size
            while offset + headerSize <= length {
                let header = base.advanced(by: offset).assumingMemoryBound(to: if_msghdr.self).pointee
                let messageLength = Int(header.ifm_msglen)
                guard messageLength > 0, offset + messageLength <= length else { break }
                if Int32(header.ifm_type) == RTM_IFINFO2, offset + MemoryLayout<if_msghdr2>.size <= length {
                    let info = base.advanced(by: offset).assumingMemoryBound(to: if_msghdr2.self).pointee
                    var nameBuffer = [CChar](repeating: 0, count: Int(IFNAMSIZ))
                    if if_indextoname(UInt32(info.ifm_index), &nameBuffer) != nil {
                        perInterface[String(cString: nameBuffer)] = (info.ifm_data.ifi_ibytes, info.ifm_data.ifi_obytes)
                    }
                }
                offset += messageLength
            }
        }

        let primaries = primaryInterfaceNames()
        let names = perInterface.keys.filter { isUsableInterface($0) }.sorted()
        guard !names.isEmpty else { return InterfaceTotals(receivedBytes: 0, sentBytes: 0, names: [], primaryName: nil) }
        let selectedNames = primaries.isEmpty ? names : names.filter { primaries.contains($0) }
        let countedNames = selectedNames.isEmpty ? names : selectedNames
        let received = countedNames.reduce(UInt64.zero) { $0 &+ (perInterface[$1]?.received ?? 0) }
        let sent = countedNames.reduce(UInt64.zero) { $0 &+ (perInterface[$1]?.sent ?? 0) }
        return InterfaceTotals(receivedBytes: received, sentBytes: sent, names: countedNames, primaryName: primaries.first(where: { countedNames.contains($0) }))
    }

    private static func interfaceInfo(from totals: InterfaceTotals) -> [NetworkInterfaceInfo] {
        let names = Dictionary(uniqueKeysWithValues: (SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] ?? []).compactMap { interface -> (String, String)? in
            guard let name = SCNetworkInterfaceGetBSDName(interface) as String?, let display = SCNetworkInterfaceGetLocalizedDisplayName(interface) as String? else { return nil }
            return (name, display)
        })
        return totals.names.map { name in NetworkInterfaceInfo(id: name, name: name, displayName: names[name] ?? name, isPrimary: name == totals.primaryName) }
    }

    private static func primaryInterfaceNames() -> [String] {
        guard let store = SCDynamicStoreCreate(nil, "com.newnet.network-monitor" as CFString, nil, nil) else { return [] }
        return ["State:/Network/Global/IPv4", "State:/Network/Global/IPv6"].compactMap { key in
            (SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any])?["PrimaryInterface"] as? String
        }
    }

    private static func isUsableInterface(_ name: String) -> Bool {
        !name.hasPrefix("lo") && !name.hasPrefix("awdl") && !name.hasPrefix("llw") && !name.hasPrefix("utun")
    }

    private static func readProcessSamples() -> [NetworkProcessUsage]? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        process.arguments = ["-P", "-d", "-x", "-t", "external", "-J", "bytes_in,bytes_out", "-L", "1", "-s", "1"]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run(); process.waitUntilExit() } catch { return nil }
        guard process.terminationStatus == 0 else { return nil }
        let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        return parseProcessOutput(output)
    }

    static func parseProcessOutput(_ output: String) -> [NetworkProcessUsage] {
        output.split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
            let columns = line.split(separator: ",", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard columns.count >= 5, columns[0] != "time" else { return nil }
            let downIndex = columns.count - 3
            let upIndex = columns.count - 2
            let processField = columns[1..<downIndex].joined(separator: ",")
            guard let separator = processField.lastIndex(of: ".") else { return nil }
            let pidText = processField[processField.index(after: separator)...]
            guard let pid = pid_t(pidText) else { return nil }
            let name = String(processField[..<separator]).isEmpty ? "pid \(pid)" : String(processField[..<separator])
            let down = max(Double(columns[downIndex]) ?? 0, 0)
            let up = max(Double(columns[upIndex]) ?? 0, 0)
            guard down > 0 || up > 0 else { return nil }
            return NetworkProcessUsage(id: pid, name: name, downloadBytesPerSecond: down, uploadBytesPerSecond: up)
        }
    }
}
