import Foundation
import CryptoKit

protocol LastFMServiceProtocol: Sendable {
    func generateAuthToken(apiKey: String) async throws -> String
    func createSession(apiKey: String, apiSecret: String, token: String) async throws -> (username: String, sessionKey: String)
    func updateNowPlaying(track: TrackMetadata, apiKey: String, apiSecret: String, sessionKey: String) async throws
    func scrobble(track: TrackMetadata, timestamp: Date, apiKey: String, apiSecret: String, sessionKey: String) async throws
}

final class LastFMService: LastFMServiceProtocol, Sendable {
    static let shared = LastFMService()

    private let endpoint = URL(string: "https://ws.audioscrobbler.com/2.0/")!
    private let urlSession: URLSession

    init(session: URLSession = .shared) {
        self.urlSession = session
    }

    func generateAuthToken(apiKey: String) async throws -> String {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "method", value: "auth.getToken"),
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components.url else {
            throw LastFMError.invalidURL
        }

        let (data, response) = try await urlSession.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw LastFMError.serverError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        struct TokenResponse: Decodable {
            let token: String
        }

        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        return decoded.token
    }

    func createSession(apiKey: String, apiSecret: String, token: String) async throws -> (username: String, sessionKey: String) {
        var params: [String: String] = [
            "method": "auth.getSession",
            "api_key": apiKey,
            "token": token
        ]
        params["api_sig"] = Self.calculateSignature(parameters: params, secret: apiSecret)
        params["format"] = "json"

        let data = try await post(parameters: params)

        struct SessionResponse: Decodable {
            struct Session: Decodable {
                let name: String
                let key: String
            }
            let session: Session?
            let error: Int?
            let message: String?
        }

        let decoded = try JSONDecoder().decode(SessionResponse.self, from: data)
        if let error = decoded.error, let msg = decoded.message {
            throw LastFMError.apiError(code: error, message: msg)
        }
        guard let session = decoded.session else {
            throw LastFMError.noSession
        }

        return (session.name, session.key)
    }

    func updateNowPlaying(track: TrackMetadata, apiKey: String, apiSecret: String, sessionKey: String) async throws {
        var params: [String: String] = [
            "method": "track.updateNowPlaying",
            "artist": track.artist,
            "track": track.title,
            "api_key": apiKey,
            "sk": sessionKey
        ]
        if let album = track.album, !album.isEmpty {
            params["album"] = album
        }
        if track.duration > 0 {
            params["duration"] = "\(Int(track.duration))"
        }

        params["api_sig"] = Self.calculateSignature(parameters: params, secret: apiSecret)
        params["format"] = "json"

        let data = try await post(parameters: params)
        try Self.validateResponse(data: data)
    }

    func scrobble(track: TrackMetadata, timestamp: Date, apiKey: String, apiSecret: String, sessionKey: String) async throws {
        var params: [String: String] = [
            "method": "track.scrobble",
            "artist[0]": track.artist,
            "track[0]": track.title,
            "timestamp[0]": "\(Int(timestamp.timeIntervalSince1970))",
            "api_key": apiKey,
            "sk": sessionKey
        ]
        if let album = track.album, !album.isEmpty {
            params["album[0]"] = album
        }
        if track.duration > 0 {
            params["duration[0]"] = "\(Int(track.duration))"
        }

        params["api_sig"] = Self.calculateSignature(parameters: params, secret: apiSecret)
        params["format"] = "json"

        let data = try await post(parameters: params)
        try Self.validateResponse(data: data)
    }

    static func calculateSignature(parameters: [String: String], secret: String) -> String {
        let filtered = parameters.filter { $0.key != "format" && $0.key != "callback" && $0.key != "api_sig" }
        let sorted = filtered.sorted { $0.key < $1.key }
        let concatenated = sorted.reduce("") { $0 + $1.key + $1.value } + secret
        let digest = Insecure.MD5.hash(data: Data(concatenated.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func post(parameters: [String: String]) async throws -> Data {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = parameters.map { key, val in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedVal = val.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? val
            return "\(escapedKey)=\(escapedVal)"
        }.joined(separator: "&")

        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw LastFMError.serverError("HTTP \(code): \(bodyText)")
        }
        return data
    }

    private static func validateResponse(data: Data) throws {
        struct ErrorResponse: Decodable {
            let error: Int?
            let message: String?
        }
        if let err = try? JSONDecoder().decode(ErrorResponse.self, from: data), let code = err.error, let msg = err.message {
            throw LastFMError.apiError(code: code, message: msg)
        }
    }
}

enum LastFMError: LocalizedError, Equatable {
    case invalidURL
    case serverError(String)
    case apiError(code: Int, message: String)
    case noSession

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Last.fm API endpoint URL."
        case .serverError(let msg): return "Last.fm server error: \(msg)"
        case .apiError(let code, let msg): return "Last.fm API error (\(code)): \(msg)"
        case .noSession: return "Could not establish Last.fm session."
        }
    }
}
