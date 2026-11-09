import Foundation

protocol ListenBrainzServiceProtocol: Sendable {
    func validateToken(_ token: String) async throws -> (valid: Bool, username: String)
    func updateNowPlaying(track: TrackMetadata, token: String) async throws
    func scrobble(track: TrackMetadata, timestamp: Date, token: String) async throws
}

final class ListenBrainzService: ListenBrainzServiceProtocol, Sendable {
    static let shared = ListenBrainzService()

    private let baseURL = URL(string: "https://api.listenbrainz.org/1/")!
    private let urlSession: URLSession

    init(session: URLSession = .shared) {
        self.urlSession = session
    }

    func validateToken(_ token: String) async throws -> (valid: Bool, username: String) {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else {
            throw ListenBrainzError.emptyToken
        }

        let url = baseURL.appendingPathComponent("validate-token")
        var request = URLRequest(url: url)
        request.setValue("Token \(cleanToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ListenBrainzError.invalidResponse
        }

        struct ValidateResponse: Decodable {
            let code: Int?
            let message: String?
            let valid: Bool
            let user_name: String?
        }

        let decoded = try JSONDecoder().decode(ValidateResponse.self, from: data)
        guard httpResponse.statusCode == 200, decoded.valid, let username = decoded.user_name else {
            throw ListenBrainzError.invalidToken(decoded.message ?? "Invalid user token")
        }

        return (true, username)
    }

    func updateNowPlaying(track: TrackMetadata, token: String) async throws {
        try await submit(
            listenType: "playing_now",
            track: track,
            timestamp: nil,
            token: token
        )
    }

    func scrobble(track: TrackMetadata, timestamp: Date, token: String) async throws {
        try await submit(
            listenType: "single",
            track: track,
            timestamp: timestamp,
            token: token
        )
    }

    private func submit(
        listenType: String,
        track: TrackMetadata,
        timestamp: Date?,
        token: String
    ) async throws {
        let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else {
            throw ListenBrainzError.emptyToken
        }

        let url = baseURL.appendingPathComponent("submit-listens")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(cleanToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var trackMeta: [String: Any] = [
            "artist_name": track.artist,
            "track_name": track.title
        ]
        if let album = track.album, !album.isEmpty {
            trackMeta["release_name"] = album
        }

        var additionalInfo: [String: Any] = [
            "media_player": track.player.rawValue,
            "submission_client": "NewNet"
        ]
        if track.duration > 0 {
            additionalInfo["duration_ms"] = Int(track.duration * 1000)
        }
        trackMeta["additional_info"] = additionalInfo

        var payloadItem: [String: Any] = [
            "track_metadata": trackMeta
        ]
        if let timestamp = timestamp {
            payloadItem["listened_at"] = Int(timestamp.timeIntervalSince1970)
        }

        let bodyObject: [String: Any] = [
            "listen_type": listenType,
            "payload": [payloadItem]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: bodyObject)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ListenBrainzError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw ListenBrainzError.submissionFailed(errorText)
        }
    }
}

enum ListenBrainzError: LocalizedError, Equatable {
    case emptyToken
    case invalidToken(String)
    case invalidResponse
    case submissionFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyToken: return "ListenBrainz user token cannot be empty."
        case .invalidToken(let msg): return "ListenBrainz token validation failed: \(msg)"
        case .invalidResponse: return "Received invalid response from ListenBrainz API."
        case .submissionFailed(let msg): return "ListenBrainz submission failed: \(msg)"
        }
    }
}
