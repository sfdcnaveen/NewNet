import Foundation
import AppKit

struct DetectionResult: Sendable {
    let track: TrackMetadata?
    let state: PlaybackState
    let player: MusicPlayerApp
}

@MainActor
protocol MusicDetectionServiceProtocol: Sendable {
    func detectCurrentPlayback() async -> DetectionResult
}

@MainActor
final class MusicDetectionService: MusicDetectionServiceProtocol {
    func detectCurrentPlayback() async -> DetectionResult {
        let isMusicRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty
        let isSpotifyRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty

        if isMusicRunning {
            if let result = await Task.detached(priority: .utility, operation: { () -> DetectionResult? in
                return Self.queryAppleMusic()
            }).value {
                return result
            }
        }

        if isSpotifyRunning {
            if let result = await Task.detached(priority: .utility, operation: { () -> DetectionResult? in
                return Self.querySpotify()
            }).value {
                return result
            }
        }

        return DetectionResult(track: nil, state: .stopped, player: .other)
    }

    private nonisolated static func queryAppleMusic() -> DetectionResult? {
        let scriptSource = """
        tell application "Music"
            try
                set pState to player state
                if pState is playing or pState is paused then
                    set tName to name of current track
                    set tArtist to artist of current track
                    set tAlbum to album of current track
                    set tDuration to duration of current track
                    set tPos to player position
                    set tStateStr to (pState as string)
                    return tName & "|||" & tArtist & "|||" & tAlbum & "|||" & (tDuration as string) & "|||" & (tPos as string) & "|||" & tStateStr
                else
                    return "STOPPED"
                end if
            on error
                return "ERROR"
            end try
        end tell
        """

        guard let script = NSAppleScript(source: scriptSource) else { return nil }
        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)
        if errorInfo != nil { return nil }
        guard let output = descriptor.stringValue, !output.isEmpty, output != "ERROR" else { return nil }

        if output == "STOPPED" {
            return DetectionResult(track: nil, state: .stopped, player: .appleMusic)
        }

        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }

        let name = parts[0]
        let artist = parts[1]
        let album = parts[2].isEmpty ? nil : parts[2]
        let duration = Double(parts[3].replacingOccurrences(of: ",", with: ".")) ?? 0
        let position = Double(parts[4].replacingOccurrences(of: ",", with: ".")) ?? 0
        let stateStr = parts[5].lowercased()

        let state: PlaybackState = stateStr.contains("play") ? .playing(position: position) : .paused(position: position)
        let track = TrackMetadata(
            title: name,
            artist: artist,
            album: album,
            albumArtist: nil,
            duration: duration,
            player: .appleMusic,
            artworkData: nil,
            artworkURL: nil
        )

        return DetectionResult(track: track, state: state, player: .appleMusic)
    }

    private nonisolated static func querySpotify() -> DetectionResult? {
        let scriptSource = """
        tell application "Spotify"
            try
                set pState to player state
                if pState is playing or pState is paused then
                    set tName to name of current track
                    set tArtist to artist of current track
                    set tAlbum to album of current track
                    set tDuration to (duration of current track) / 1000.0
                    set tPos to player position
                    set tStateStr to (pState as string)
                    set tArt to artwork url of current track
                    return tName & "|||" & tArtist & "|||" & tAlbum & "|||" & (tDuration as string) & "|||" & (tPos as string) & "|||" & tStateStr & "|||" & tArt
                else
                    return "STOPPED"
                end if
            on error
                return "ERROR"
            end try
        end tell
        """

        guard let script = NSAppleScript(source: scriptSource) else { return nil }
        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)
        if errorInfo != nil { return nil }
        guard let output = descriptor.stringValue, !output.isEmpty, output != "ERROR" else { return nil }

        if output == "STOPPED" {
            return DetectionResult(track: nil, state: .stopped, player: .spotify)
        }

        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }

        let name = parts[0]
        let artist = parts[1]
        let album = parts[2].isEmpty ? nil : parts[2]
        let duration = Double(parts[3].replacingOccurrences(of: ",", with: ".")) ?? 0
        let position = Double(parts[4].replacingOccurrences(of: ",", with: ".")) ?? 0
        let stateStr = parts[5].lowercased()
        let artworkURLStr = parts.count > 6 ? parts[6] : nil
        let artworkURL = artworkURLStr.flatMap { URL(string: $0) }

        let state: PlaybackState = stateStr.contains("play") ? .playing(position: position) : .paused(position: position)
        let track = TrackMetadata(
            title: name,
            artist: artist,
            album: album,
            albumArtist: nil,
            duration: duration,
            player: .spotify,
            artworkData: nil,
            artworkURL: artworkURL
        )

        return DetectionResult(track: track, state: state, player: .spotify)
    }
}
