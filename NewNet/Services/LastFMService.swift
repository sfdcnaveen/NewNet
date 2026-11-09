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
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            struct ErrorResponse: Decodable {
                let error: Int?
                let message: String?
            }
            if let err = try? JSONDecoder().decode(ErrorResponse.self, from: data), let code = err.error, let msg = err.message {
                throw LastFMError.apiError(code: code, message: msg)
            }
            throw LastFMError.serverError("HTTP \(httpResponse.statusCode)")
        }

        struct TokenResponse: Decodable {
            let token: String?
            let error: Int?
            let message: String?
        }

        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        if let error = decoded.error, let msg = decoded.message {
            throw LastFMError.apiError(code: error, message: msg)
        }
        guard let token = decoded.token else {
            throw LastFMError.noSession
        }
        return token
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
        // Clamp timestamp to at least 15 seconds in the past to prevent Last.fm "Timestamp too new / in future" (Ignored Code 4)
        let safeTimestamp = min(timestamp, Date().addingTimeInterval(-15))

        var params: [String: String] = [
            "method": "track.scrobble",
            "artist": track.artist,
            "track": track.title,
            "timestamp": "\(Int(safeTimestamp.timeIntervalSince1970))",
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
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let bodyString = parameters.map { key, val in
            "\(key.urlFormEncoded)=\(val.urlFormEncoded)"
        }.joined(separator: "&")

        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await urlSession.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            struct ErrorResponse: Decodable {
                let error: Int?
                let message: String?
            }
            if let err = try? JSONDecoder().decode(ErrorResponse.self, from: data), let code = err.error, let msg = err.message {
                throw LastFMError.apiError(code: code, message: msg)
            }
            let code = httpResponse.statusCode
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

        struct ScrobblesResponse: Decodable {
            struct ScrobblesBody: Decodable {
                struct Attr: Decodable {
                    let accepted: Int?
                    let ignored: Int?
                }
                struct ScrobbleEntry: Decodable {
                    struct IgnoredMsg: Decodable {
                        let code: String?
                        let text: String?
                        enum CodingKeys: String, CodingKey {
                            case code
                            case text = "#text"
                        }
                    }
                    let ignoredMessage: IgnoredMsg?
                }
                let attr: Attr?
                let scrobble: ScrobbleEntry?
                enum CodingKeys: String, CodingKey {
                    case attr = "@attr"
                    case scrobble
                }
            }
            let scrobbles: ScrobblesBody?
        }

        if let scrobbleRes = try? JSONDecoder().decode(ScrobblesResponse.self, from: data),
           let scrobbles = scrobbleRes.scrobbles {
            if let attr = scrobbles.attr, (attr.accepted ?? 0) == 0 && (attr.ignored ?? 0) > 0 {
                let code = scrobbles.scrobble?.ignoredMessage?.code ?? "unknown"
                let text = scrobbles.scrobble?.ignoredMessage?.text ?? "Track was ignored by Last.fm"
                throw LastFMError.apiError(code: Int(code) ?? 0, message: "\(text) (Last.fm code \(code))")
            }
        }
    }
}

private extension String {
    var urlFormEncoded: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return self.addingPercentEncoding(withAllowedCharacters: allowed) ?? self
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
