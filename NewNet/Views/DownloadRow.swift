import SwiftUI

struct DownloadRow: View {
    let item: DownloadItem
    let onPause: () -> Void
    let onResume: () -> Void
    let onOpen: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: leadingSymbol)
                    .font(.system(size: 18))
                    .foregroundStyle(leadingColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.fileName)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(statusText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(statusColor)

                        Text(item.engine.displayName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    if let formatSummary = item.ytDLPConfiguration?.displayName, item.engine == .ytDLP {
                        Text(formatSummary)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button(action: action) {
                    Image(systemName: actionSymbol)
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .background(
                    Circle()
                        .fill(glassFill(light: isHovering ? 0.9 : 0.75, dark: isHovering ? 0.18 : 0.08))
                )
            }

            downloadStateFooter
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(rowFill)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(rowStroke, lineWidth: 1)
        )
        .shadow(color: rowShadow, radius: item.isActive ? 12 : 8, x: 0, y: 6)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.18), value: isHovering)
        .animation(.easeOut(duration: 0.2), value: item.state)
    }

    private var statusText: String {
        if let error = item.errorDescription, item.state == .failed {
            return error
        }

        switch item.state {
        case .queued:
            return "Queued"
        case .preparing:
            return "Preparing"
        case .downloading:
            return "Downloading"
        case .paused:
            return "Paused"
        case .completing:
            return item.engine == .ytDLP ? "Finalizing media" : "Merging segments"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }

    private var statusColor: Color {
        switch item.state {
        case .failed:
            return .red
        default:
            return .secondary
        }
    }

    private var leadingSymbol: String {
        switch item.state {
        case .failed:
            return "exclamationmark.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .paused:
            return "pause.circle.fill"
        default:
            return "arrow.down.circle.fill"
        }
    }

    private var leadingColor: Color {
        switch item.state {
        case .failed:
            return .red
        case .completed, .paused:
            return .secondary
        default:
            return .accentColor
        }
    }

    private var actionSymbol: String {
        switch item.state {
        case .preparing, .downloading, .completing:
            return "pause.fill"
        case .completed:
            return "play.fill"
        default:
            return "play.fill"
        }
    }

    private func glassFill(light: Double, dark: Double) -> Color {
        colorScheme == .dark ? Color.white.opacity(dark) : Color.white.opacity(light)
    }

    private func glassStroke(light: Double, dark: Double) -> Color {
        colorScheme == .dark ? Color.white.opacity(dark) : Color.black.opacity(light)
    }

    private var downloadStateFooter: some View {
        HStack(spacing: 10) {
            switch item.state {
            case .queued, .preparing, .downloading, .completing:
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16, height: 16)

                Text(activeStatusText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("In progress")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text("Completed")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if item.downloadedBytes > 0 {
                    Text(ByteCountFormatter.compactFileSize(item.downloadedBytes))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            case .paused:
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.orange)

                Text("Paused")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.red)

                Text("Needs attention")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.red)

                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(glassFill(light: 0.7, dark: 0.05))
                )
        )
    }

    private var activeStatusText: String {
        switch item.state {
        case .queued, .preparing:
            return "Preparing download..."
        case .downloading:
            return "Downloading..."
        case .completing:
            return item.engine == .ytDLP ? "Finalizing media..." : "Merging segments..."
        default:
            return statusText
        }
    }

    private var rowFill: Color {
        Color.clear
    }

    private var rowStroke: Color {
        glassStroke(light: 0.1, dark: 0.08)
    }

    private var rowShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.32) : Color.black.opacity(0.12)
    }

    private func action() {
        if item.state == .completed {
            onOpen()
        } else if item.state == .downloading || item.state == .preparing || item.state == .completing {
            onPause()
        } else {
            onResume()
        }
    }

}
