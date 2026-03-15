import Foundation

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
        receivedBytes + sentBytes
    }

    static let zero = NetworkUsage(receivedBytes: 0, sentBytes: 0)
}
