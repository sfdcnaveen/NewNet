import SwiftUI
import AppKit

struct MusicDashboardView: View {
    @ObservedObject var scrobbleCoordinator: ScrobbleCoordinator
    @ObservedObject var settings: AppSettings
    var onOpenSettings: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            currentTrackSection
            providersStatusSection
            recentScrobblesSection
        }
    }

    private var headerSection: some View {
        HStack {
            Text("Music Scrobbling")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if let onOpenSettings = onOpenSettings {
                Button {
                    onOpenSettings()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("Music Scrobbling Settings")
            }
        }
    }

    private var currentTrackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let track = scrobbleCoordinator.currentTrack {
                HStack(alignment: .top, spacing: 12) {
                    artworkView(for: track)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(track.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)

                        Text(track.artist)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if let album = track.album, !album.isEmpty {
                            Text(album)
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }

                        HStack(spacing: 6) {
                            Label(track.player.rawValue, systemImage: track.player.iconName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)

                            Text("•")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)

                            playbackBadge
                        }
                        .padding(.top, 2)
                    }
                    Spacer()
                }

                if track.duration > 0 {
                    playbackProgressView(track: track)
                }

                statusBannerView
            } else {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.secondary.opacity(0.12))
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No Music Playing")
                            .font(.system(size: 12, weight: .medium))
                        Text("Play a track in Apple Music or Spotify to scrobble.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .liquidGlassControl()
            }
        }
        .padding(10)
        .liquidGlassControl()
    }

    private func artworkView(for track: TrackMetadata) -> some View {
        Group {
            if let url = track.artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallbackArtwork(for: track)
                    }
                }
            } else if let data = track.artworkData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
            } else {
                fallbackArtwork(for: track)
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func fallbackArtwork(for track: TrackMetadata) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.accentColor.opacity(0.15))
            .overlay {
                Image(systemName: track.player.iconName)
                    .font(.system(size: 22))
                    .foregroundStyle(Color.accentColor)
            }
    }

    private var playbackBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(scrobbleCoordinator.playbackState.isPlaying ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text(scrobbleCoordinator.playbackState.isPlaying ? "Playing" : "Paused")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func playbackProgressView(track: TrackMetadata) -> some View {
        let pos = scrobbleCoordinator.playbackState.position
        let dur = track.duration
        let progress = dur > 0 ? min(max(pos / dur, 0), 1.0) : 0

        return VStack(spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * CGFloat(progress))
                }
            }
            .frame(height: 4)

            HStack {
                Text(formatDuration(pos))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Text(formatDuration(dur))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var statusBannerView: some View {
        HStack(spacing: 6) {
            switch scrobbleCoordinator.submissionStatus {
            case .idle:
                EmptyView()
            case .detected:
                Image(systemName: "eye.fill")
                    .foregroundStyle(.blue)
                Text("Track detected")
                    .font(.system(size: 10, weight: .medium))
            case .playing:
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(.blue)
                Text(scrobbleCoordinator.submissionStatus.badgeText)
                    .font(.system(size: 10, weight: .medium))
            case .waitingForEligibility(let rem):
                Image(systemName: "timer")
                    .foregroundStyle(.blue)
                Text("Waiting to scrobble: \(Int(max(rem, 0)))s remaining")
                    .font(.system(size: 10, weight: .medium))
            case .scrobbled:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Scrobbled successfully")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.green)
            case .pendingRetry(let reason):
                Image(systemName: "arrow.clockwise.circle.fill")
                    .foregroundStyle(.orange)
                Text("Pending retry: \(reason)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
            case .failed(let reason):
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                Text("Scrobble failed: \(reason)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.red)
            }
            Spacer()
        }
        .padding(.top, 2)
    }

    private var providersStatusSection: some View {
        HStack(spacing: 8) {
            providerPill(
                name: "Last.fm",
                icon: "waveform",
                enabled: settings.isLastFMEnabled,
                status: scrobbleCoordinator.lastFMStatus
            )

            providerPill(
                name: "ListenBrainz",
                icon: "headphones",
                enabled: settings.isListenBrainzEnabled,
                status: scrobbleCoordinator.listenBrainzStatus
            )
        }
    }

    private func providerPill(
        name: String,
        icon: String,
        enabled: Bool,
        status: ProviderConnectionStatus
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(enabled && status.isConnected ? Color.accentColor : .secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 10, weight: .semibold))

                Text(!enabled ? "Disabled" : (status.username ?? "Not connected"))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()

            Circle()
                .fill(enabled && status.isConnected ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .liquidGlassControl()
    }

    private var recentScrobblesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent Scrobbles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            if scrobbleCoordinator.scrobbleHistory.isEmpty {
                Text("No recent scrobbles")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
                    .liquidGlassControl()
            } else {
                VStack(spacing: 6) {
                    ForEach(scrobbleCoordinator.scrobbleHistory.prefix(5)) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.track.player.iconName)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .frame(width: 16)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.track.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                                Text(item.track.artist)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            HStack(spacing: 4) {
                                if let lfm = item.lastFMResult {
                                    Image(systemName: lfm.success ? "waveform" : "waveform.badge.exclamationmark")
                                        .font(.system(size: 9))
                                        .foregroundStyle(lfm.success ? .green : .red)
                                        .help(lfm.success ? "Last.fm: Scrobbled" : "Last.fm failed: \(lfm.message ?? "")")
                                }
                                if let lb = item.listenBrainzResult {
                                    Image(systemName: lb.success ? "headphones" : "headphones.circle.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(lb.success ? .green : .red)
                                        .help(lb.success ? "ListenBrainz: Scrobbled" : "ListenBrainz failed: \(lb.message ?? "")")
                                }
                            }

                            Text(timeAgo(item.timestamp))
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .liquidGlassControl()
                    }
                }
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let s = Int(max(0, seconds))
        let minutes = s / 60
        let remainingSeconds = s % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private func timeAgo(_ date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60 { return "\(diff)s ago" }
        if diff < 3600 { return "\(diff / 60)m ago" }
        return "\(diff / 3600)h ago"
    }
}
