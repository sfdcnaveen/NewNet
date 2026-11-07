import XCTest
@testable import NewNet

@MainActor
final class NetworkMonitoringTests: XCTestCase {
    func testNetworkProcessParserKeepsCommaInProcessName() {
        let output = "time,,bytes_in,bytes_out,\n12:00:00,Codex (Aperitif,123.456,1000,200,\n"
        let samples = NetworkSpeedMonitor.parseProcessOutput(output)

        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples.first?.name, "Codex (Aperitif,123")
        XCTAssertEqual(samples.first?.downloadBytesPerSecond, 1000)
        XCTAssertEqual(samples.first?.uploadBytesPerSecond, 200)
    }

    func testNetworkProcessUsageTotal() {
        let usage = NetworkProcessUsage(id: 1, name: "Test", downloadBytesPerSecond: 10, uploadBytesPerSecond: 5)
        XCTAssertEqual(usage.totalBytesPerSecond, 15)
    }
}
