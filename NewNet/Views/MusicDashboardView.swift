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
        Group {
            if let track = scrobbleCoordinator.currentTrack {
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Label(track.player.rawValue, systemImage: track.player.iconName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        topRightStatusIndicator
                    }

                    VStack(spacing: 3) {
                        Text(track.title)
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                            .multilineTextAlignment(.center)

                        let secondaryText = [track.artist, track.album].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " — ")
                        Text(secondaryText)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)

                    playbackProgressView(track: track)

                    mediaControlsSection
                }
                .padding(14)
                .liquidGlassCard(cornerRadius: 18)
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
    }

    @ViewBuilder
    private var topRightStatusIndicator: some View {
        if !scrobbleCoordinator.playbackState.isPlaying {
            Circle()
                .fill(Color.orange)
                .frame(width: 7, height: 7)
        } else {
            switch scrobbleCoordinator.submissionStatus {
            case .idle:
                EmptyView()
            case .detected:
                Image(systemName: "eye.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.blue)
            case .playing:
                Image(systemName: "music.note")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
            case .waitingForEligibility:
                ProgressView()
                    .controlSize(.mini)
            case .scrobbled:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.green)
            case .pendingRetry:
                ProgressView()
                    .controlSize(.mini)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
        }
    }

    private var mediaControlsSection: some View {
        HStack(spacing: 20) {
            Spacer()

            Button {
                // shuffle toggle
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Shuffle")

            Button {
                scrobbleCoordinator.previousTrack()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 15))
            }
            .buttonStyle(MediaControlGlyphButtonStyle())
            .help("Previous Track")

            Button {
                scrobbleCoordinator.togglePlayPause()
            } label: {
                Image(systemName: scrobbleCoordinator.playbackState.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(Color.accentColor))
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .help(scrobbleCoordinator.playbackState.isPlaying ? "Pause" : "Play")

            Button {
                scrobbleCoordinator.nextTrack()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 15))
            }
            .buttonStyle(MediaControlGlyphButtonStyle())
            .help("Next Track")

            Button {
                // repeat toggle
            } label: {
                Image(systemName: "repeat")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Repeat")

            Spacer()
        }
    }

    private func playbackProgressView(track: TrackMetadata) -> some View {
        let pos = scrobbleCoordinator.playbackState.position
        let dur = track.duration
        let progress = dur > 0 ? min(max(pos / dur, 0), 1.0) : 0

        return VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 4)
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: geo.size.width * CGFloat(progress), height: 4)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 10, height: 10)
                        .shadow(color: Color.black.opacity(0.15), radius: 2)
                        .offset(x: max(0, min(geo.size.width * CGFloat(progress) - 5, geo.size.width - 10)))
                }
            }
            .frame(height: 10)

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
        .glassEffect(
            enabled && status.isConnected
                ? .regular.tint(Color.accentColor.opacity(0.18))
                : .clear,
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
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
