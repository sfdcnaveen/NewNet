import Foundation

struct SpeedTestResult: Codable, Identifiable {
    let id: UUID
    let ping: Double       // ms
    let download: Double   // Mbps
    let upload: Double     // Mbps
    let server: String
    let date: Date

    init(
        id: UUID = UUID(),
        ping: Double,
        download: Double,
        upload: Double,
        server: String,
        date: Date = Date()
    ) {
        self.id = id
        self.ping = ping
        self.download = download
        self.upload = upload
        self.server = server
        self.date = date
    }
}

enum SpeedTestError: Error {
    case invalidResponse
    case networkFailure
    case timeout
    case serverUnavailable
}

struct SpeedTestEndpoints {
    let serverName: String
    let pingURL: URL
    let downloadURL: URL
    let uploadURL: URL

    static var placeholder: SpeedTestEndpoints {
        SpeedTestEndpoints(
            serverName: "Example Test Server",
            pingURL: URL(string: "https://example.com/ping")!,
            downloadURL: URL(string: "https://example.com/largefile.bin")!,
            uploadURL: URL(string: "https://example.com/upload")!
        )
    }
}
