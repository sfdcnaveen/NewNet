import Foundation
import Security

@MainActor
final class SpeedTestManager {
    private let session: URLSession
    private var endpoints: SpeedTestEndpoints

    init(endpoints: SpeedTestEndpoints) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
        self.endpoints = endpoints
    }

    func updateEndpoints(_ endpoints: SpeedTestEndpoints) {
        self.endpoints = endpoints
    }

    func runFullTest() async throws -> SpeedTestResult {
        let ping = try await measurePing(attempts: 4)
        let download = try await measureDownload(parallel: 4)
        let upload = try await measureUpload(parallel: 2, sizeMB: 8)

        return SpeedTestResult(
            ping: ping,
            download: download,
            upload: upload,
            server: endpoints.serverName
        )
    }

    func measurePing(attempts: Int) async throws -> Double {
        guard attempts > 0 else { throw SpeedTestError.invalidResponse }
        var samples: [Double] = []

        for _ in 0..<attempts {
            let request = pingRequest()
            let start = Date()

            do {
                let (_, response) = try await session.data(for: request)
                try validate(response: response)
            } catch {
                let fallbackRequest = pingRequest(method: "GET")
                let (_, response) = try await session.data(for: fallbackRequest)
                try validate(response: response)
            }

            let elapsedMs = Date().timeIntervalSince(start) * 1000.0
            samples.append(elapsedMs)
        }

        let trimmed = trimOutliers(samples)
        guard let average = average(of: trimmed) else {
            throw SpeedTestError.networkFailure
        }
        return average
    }

    func measureDownload(parallel: Int) async throws -> Double {
        let start = Date()
        let streams = max(1, parallel)

        let totalBytes: Int64 = try await withThrowingTaskGroup(of: Int64.self) { group in
            for _ in 0..<streams {
                group.addTask {
                    let request = await self.downloadRequest()
                    let (tempURL, response) = try await self.session.download(for: request)
                    try await self.validate(response: response)
                    let size = try await self.fileSize(at: tempURL)
                    try? FileManager.default.removeItem(at: tempURL)
                    return size
                }
            }

            var sum: Int64 = 0
            for try await bytes in group {
                sum += bytes
            }
            return sum
        }

        let elapsed = Date().timeIntervalSince(start)
        guard elapsed > 0 else { throw SpeedTestError.invalidResponse }
        return bytesToMbps(bytes: totalBytes, seconds: elapsed)
    }

    func measureUpload(parallel: Int, sizeMB: Int) async throws -> Double {
        let payload = randomData(sizeMB: sizeMB)
        let start = Date()
        let streams = max(1, parallel)
        let uploadURL = endpoints.uploadURL
        let session = session

        let totalBytes: Int64 = try await withThrowingTaskGroup(of: Int64.self) { group in
            for _ in 0..<streams {
                group.addTask {
                    var request = URLRequest(url: uploadURL)
                    request.httpMethod = "POST"
                    request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                    request.cachePolicy = .reloadIgnoringLocalCacheData
                    let (_, response) = try await session.upload(for: request, from: payload)
                    try await self.validate(response: response)
                    return Int64(payload.count)
                }
            }

            var sum: Int64 = 0
            for try await bytes in group {
                sum += bytes
            }
            return sum
        }

        let elapsed = Date().timeIntervalSince(start)
        guard elapsed > 0 else { throw SpeedTestError.invalidResponse }
        return bytesToMbps(bytes: totalBytes, seconds: elapsed)
    }

    private func pingRequest(method: String = "HEAD") -> URLRequest {
        var request = URLRequest(url: cacheBustedURL(from: endpoints.pingURL))
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }

    private func downloadRequest() -> URLRequest {
        var request = URLRequest(url: cacheBustedURL(from: endpoints.downloadURL))
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }

    private func cacheBustedURL(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "cacheBust", value: UUID().uuidString))
        components.queryItems = items
        return components.url ?? url
    }

    private func fileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func bytesToMbps(bytes: Int64, seconds: TimeInterval) -> Double {
        let bits = Double(bytes) * 8.0
        return (bits / seconds) / 1_000_000.0
    }

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw SpeedTestError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            throw SpeedTestError.serverUnavailable
        }
    }

    private func randomData(sizeMB: Int) -> Data {
        let count = max(1, sizeMB) * 1024 * 1024
        var data = Data(count: count)
        data.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            _ = SecRandomCopyBytes(kSecRandomDefault, count, baseAddress)
        }
        return data
    }

    private func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func trimOutliers(_ samples: [Double]) -> [Double] {
        guard samples.count > 2 else { return samples }
        let sorted = samples.sorted()
        return Array(sorted.dropFirst().dropLast())
    }
}
