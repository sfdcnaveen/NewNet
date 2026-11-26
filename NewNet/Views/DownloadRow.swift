import SwiftUI

struct DownloadRow: View {
    let item: DownloadItem
    let onPause: () -> Void
    let onResume: () -> Void
    let onPlay: () -> Void
    let onShowInFinder: () -> Void
    let onDelete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                leadingIcon

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.fileName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if let tag = simplifiedFormatTag {
                            HStack(spacing: 3) {
                                Image(systemName: formatIcon)
                                    .font(.system(size: 8))
                                Text(tag)
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .liquidGlassPill(tint: item.ytDLPConfiguration?.contentPreference == .gif ? .accentColor : nil)
                            .foregroundStyle(.secondary)
                        }

                        Text(statusText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(statusColor)

                        if item.state == .completed && item.downloadedBytes > 0 {
                            Text("•")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                            Text(ByteCountFormatter.compactFileSize(item.downloadedBytes))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        } else if item.state == .failed, let error = item.errorDescription {
                            Text("•")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                            Text(error)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 8)

                trailingActions
            }

            if item.isActive {
                VStack(spacing: 4) {
                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)
                        .tint(Color.accentColor)
                        .frame(height: 3)
                        .clipShape(Capsule())
                        .animation(DesignTokens.Animation.progress, value: item.progress)

                    HStack {
                        Text(activeStatusText)
                        Spacer()
                        if item.totalBytesExpected > 0 {
                            Text("\(Int(item.progress * 100))%")
                        }
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .liquidGlassCard(cornerRadius: DesignTokens.Radius.medium, isHovered: isHovering, isActive: item.isActive)
        .onHover { isHovering = $0 }
        .animation(DesignTokens.Animation.hover, value: isHovering)
        .animation(DesignTokens.Animation.transition, value: item.state)
    }

    private var leadingIcon: some View {
        ZStack {
            Circle()
                .fill(leadingColor.opacity(0.12))
            Image(systemName: leadingSymbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(leadingColor)
        }
        .frame(width: 28, height: 28)
    }

    @ViewBuilder
    private var trailingActions: some View {
        if item.state == .completed {
            HStack(spacing: 6) {
                Button(action: onPlay) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(LiquidGlassButtonStyle(tint: .accentColor, isCircular: true))
                .help("Play in default player")

                Button(action: onShowInFinder) {
                    Image(systemName: "folder")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(LiquidGlassButtonStyle(isCircular: true))
                .help("Show in Finder")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(LiquidGlassButtonStyle(tint: .secondary, isCircular: true))
                .help("Remove from list")
            }
        } else if item.state == .failed {
            HStack(spacing: 6) {
                Button(action: action) {
                    Image(systemName: actionSymbol)
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(LiquidGlassButtonStyle(tint: .accentColor, isCircular: true))
                .help("Retry download")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(LiquidGlassButtonStyle(tint: .secondary, isCircular: true))
                .help("Remove from list")
            }
        } else {
            HStack(spacing: 6) {
                Button(action: action) {
                    Image(systemName: actionSymbol)
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(LiquidGlassButtonStyle(tint: .accentColor, isCircular: true))
                .help(item.state == .paused ? "Resume download" : "Pause download")

                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(LiquidGlassButtonStyle(tint: .secondary, isCircular: true))
                .help("Cancel download")
            }
        }
    }

    private var simplifiedFormatTag: String? {
        if let config = item.ytDLPConfiguration {
            if config.audioFormat == "m4r" || config.displayName.localizedCaseInsensitiveContains("m4r") || item.fileName.lowercased().hasSuffix(".m4r") {
                return "M4R"
            }
            if config.contentPreference == .gif {
                return "GIF"
            }
            if config.contentPreference == .audio {
                if config.audioFormat == "mp3" || config.displayName.localizedCaseInsensitiveContains("mp3") {
                    return "MP3"
                }
                return "Audio"
            }
            return config.displayName
        }
        let ext = item.destinationURL.pathExtension.uppercased()
        if !ext.isEmpty && ext != "DOWNLOAD" && ext != "PART" {
            return ext
        }
        return nil
    }

    private var formatIcon: String {
        guard let tag = simplifiedFormatTag else { return "doc" }
        switch tag {
        case "M4R": return "bell.fill"
        case "MP3", "Audio", "M4A", "AAC", "FLAC", "WAV": return "music.note"
        case "GIF": return "film.stack"
        default: return "play.rectangle"
        }
    }

    private var statusText: String {
        switch item.state {
        case .queued: return "Queued"
        case .preparing: return "Preparing"
        case .downloading: return "Downloading"
        case .paused: return "Paused"
        case .completing: return item.engine == .ytDLP ? "Finalizing media" : "Merging segments"
        case .completed: return "Completed"
        case .failed: return "Failed"
        }
    }

    private var activeStatusText: String {
        switch item.state {
        case .queued, .preparing: return "Preparing download..."
        case .downloading: return "Downloading..."
        case .completing: return item.engine == .ytDLP ? "Finalizing media..." : "Merging segments..."
        default: return statusText
        }
    }

    private var statusColor: Color {
        switch item.state {
        case .failed: return .red
        case .paused: return .orange
        default: return .secondary
        }
    }

    private var leadingSymbol: String {
        switch item.state {
        case .failed: return "exclamationmark"
        case .completed: return "checkmark"
        case .paused: return "pause"
        default: return "arrow.down"
        }
    }

    private var leadingColor: Color {
        switch item.state {
        case .failed: return .red
        case .completed: return .secondary
        case .paused: return .orange
        default: return .accentColor
        }
    }

    private var actionSymbol: String {
        switch item.state {
        case .preparing, .downloading, .completing: return "pause.fill"
        case .failed: return "arrow.clockwise"
        default: return "play.fill"
        }
    }

    private func action() {
        if item.state == .downloading || item.state == .preparing || item.state == .completing {
            onPause()
        } else {
            onResume()
        }
    }
}
