import Foundation
import Darwin

struct NetworkSpeedSnapshot: Equatable {
    var downloadBytesPerSecond: Double
    var uploadBytesPerSecond: Double
    var totalReceivedBytes: UInt64
    var totalSentBytes: UInt64
    var sampledAt: Date

    static let zero = NetworkSpeedSnapshot(
        downloadBytesPerSecond: 0,
        uploadBytesPerSecond: 0,
        totalReceivedBytes: 0,
        totalSentBytes: 0,
        sampledAt: .now
    )
}

struct NetworkUsage: Equatable {
    var receivedBytes: UInt64
    var sentBytes: UInt64

    var totalBytes: UInt64 {
        receivedBytes &+ sentBytes
    }

    static let zero = NetworkUsage(receivedBytes: 0, sentBytes: 0)
}

struct NetworkInterfaceInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let displayName: String
    let isPrimary: Bool
}

struct NetworkHistorySample: Identifiable, Equatable {
    let id: Date
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
}

struct NetworkProcessUsage: Identifiable, Equatable {
    let id: pid_t
    let name: String
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double

    var totalBytesPerSecond: Double {
        downloadBytesPerSecond + uploadBytesPerSecond
    }
}

enum NetworkConnectionStatus: Equatable {
    case connected
    case disconnected
    case unavailable

    var title: String {
        switch self {
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .unavailable: return "Unavailable"
        }
    }
}
