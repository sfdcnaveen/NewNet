import Foundation
import AppKit

enum MusicPlayerApp: String, Codable, CaseIterable, Sendable {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case other = "Other"

    var bundleIdentifier: String {
        switch self {
        case .appleMusic: return "com.apple.Music"
        case .spotify: return "com.spotify.client"
        case .other: return ""
        }
    }

    var iconName: String {
        switch self {
        case .appleMusic: return "music.note"
        case .spotify: return "dot.radiowaves.left.and.right"
        case .other: return "speaker.wave.2"
        }
    }
}

enum PlaybackState: Equatable, Sendable {
    case stopped
    case playing(position: TimeInterval)
    case paused(position: TimeInterval)

    var isPlaying: Bool {
        if case .playing = self { return true }
        return false
    }

    var position: TimeInterval {
        switch self {
        case .stopped: return 0
        case .playing(let pos), .paused(let pos): return pos
        }
    }
}

struct TrackMetadata: Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let albumArtist: String?
    let duration: TimeInterval
    let player: MusicPlayerApp
    let artworkData: Data?
    let artworkURL: URL?

    nonisolated init(
        title: String,
        artist: String,
        album: String? = nil,
        albumArtist: String? = nil,
        duration: TimeInterval,
        player: MusicPlayerApp,
        artworkData: Data? = nil,
        artworkURL: URL? = nil
    ) {
        self.id = "\(artist.trimmingCharacters(in: .whitespacesAndNewlines))-\(title.trimmingCharacters(in: .whitespacesAndNewlines))-\(album ?? "")"
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.artist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        self.album = album?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.albumArtist = albumArtist?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.duration = duration
        self.player = player
        self.artworkData = artworkData
        self.artworkURL = artworkURL
    }

    nonisolated func isSameTrack(as other: TrackMetadata?) -> Bool {
        guard let other = other else { return false }
        return title.caseInsensitiveCompare(other.title) == .orderedSame &&
               artist.caseInsensitiveCompare(other.artist) == .orderedSame
    }
}

enum ScrobbleProviderType: String, Codable, CaseIterable, Identifiable, Sendable {
    case lastfm = "Last.fm"
    case listenbrainz = "ListenBrainz"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .lastfm: return "waveform"
        case .listenbrainz: return "headphones"
        }
    }
}

enum ProviderConnectionStatus: Equatable, Sendable {
    case disconnected
    case connecting
    case connected(username: String)
    case error(message: String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var username: String? {
        if case .connected(let name) = self { return name }
        return nil
    }

    var displayTitle: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting…"
        case .connected(let name): return "Connected as \(name)"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

enum ScrobbleSubmissionStatus: Equatable, Sendable {
    case idle
    case detected
    case playing(progress: Double)
    case waitingForEligibility(remainingSeconds: TimeInterval)
    case scrobbled
    case pendingRetry(reason: String)
    case failed(reason: String)

    var badgeText: String {
        switch self {
        case .idle: return "Idle"
        case .detected: return "Detected"
        case .playing(let prog): return "Playing (\(Int(prog * 100))%)"
        case .waitingForEligibility(let rem): return "\(Int(max(rem, 0)))s to scrobble"
        case .scrobbled: return "Scrobbled"
        case .pendingRetry: return "Pending Retry"
        case .failed: return "Failed"
        }
    }
}

struct ProviderScrobbleResult: Codable, Equatable, Sendable {
    let success: Bool
    let message: String?
}

struct ScrobbleHistoryItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let track: TrackMetadata
    let lastFMResult: ProviderScrobbleResult?
    let listenBrainzResult: ProviderScrobbleResult?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        track: TrackMetadata,
        lastFMResult: ProviderScrobbleResult? = nil,
        listenBrainzResult: ProviderScrobbleResult? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.track = track
        self.lastFMResult = lastFMResult
        self.listenBrainzResult = listenBrainzResult
    }
}
