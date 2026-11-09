import SwiftUI
import AppKit

struct MusicDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
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
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
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
                        }
                        Spacer()
                        playbackBadge
                    }

                    HStack(spacing: 6) {
                        Label(track.player.rawValue, systemImage: track.player.iconName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                if track.duration > 0 {
                    playbackProgressView(track: track)
                }

                mediaControlsSection

                statusBannerView
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "music.note")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No Music Playing")
                            .font(.system(size: 12, weight: .medium))
                        Text("Play a track in Apple Music or Spotify to scrobble.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .liquidGlassCard(cornerRadius: DesignTokens.Radius.medium)
            }
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: DesignTokens.Radius.large)
    }

    private var mediaControlsSection: some View {
        HStack(spacing: 24) {
            Spacer()

            Button {
                scrobbleCoordinator.previousTrack()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .buttonStyle(MediaControlGlyphButtonStyle())
            .help("Previous Track")

            Button {
                scrobbleCoordinator.togglePlayPause()
            } label: {
                Image(systemName: scrobbleCoordinator.playbackState.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.accentColor)
                            .overlay {
                                Circle()
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.60), Color.white.opacity(0.15)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                            .shadow(color: Color.accentColor.opacity(0.40), radius: 8, x: 0, y: 3)
                    )
            }
            .buttonStyle(ScaleButtonStyle())
            .help(scrobbleCoordinator.playbackState.isPlaying ? "Pause" : "Play")

            Button {
                scrobbleCoordinator.nextTrack()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .contentShape(Circle())
            }
            .buttonStyle(MediaControlGlyphButtonStyle())
            .help("Next Track")

            Spacer()
        }
        .padding(.vertical, 6)
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
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(enabled && status.isConnected ? Color.accentColor : Color.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.primary)

                Text(!enabled ? "Disabled" : (status.username ?? "Not connected"))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
            Spacer()

            Circle()
                .fill(enabled && status.isConnected ? Color.green : Color.secondary.opacity(0.4))
                .frame(width: 7, height: 7)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(colorScheme == .dark ? 0.07 : 0.22))
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(
                            (enabled && status.isConnected)
                                ? Color.accentColor.opacity(0.45)
                                : Color.white.opacity(colorScheme == .dark ? 0.12 : 0.40),
                            lineWidth: 0.75
                        )
                }
        }
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
                    .liquidGlassCard(cornerRadius: DesignTokens.Radius.medium)
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
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .liquidGlassCard(cornerRadius: DesignTokens.Radius.small)
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
