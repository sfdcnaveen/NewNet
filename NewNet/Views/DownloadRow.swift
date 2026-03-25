import SwiftUI

struct DownloadRow: View {
    let item: DownloadItem
    let onPause: () -> Void
    let onResume: () -> Void
    let onOpen: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                        .fill(Color.white.opacity(isHovering ? 0.18 : 0.08))
                )
            }

            DownloadProgressBar(progress: item.progress)

            HStack {
                Text(ByteCountFormatter.compactFileSize(item.downloadedBytes))
                Spacer()
                if item.totalBytesExpected > 0 {
                    Text("\(Int(item.progress * 100))% of \(ByteCountFormatter.compactFileSize(item.totalBytesExpected))")
                }
            }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(isHovering ? 0.08 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.18), value: isHovering)
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
        case .completed:
            return .green
        case .paused:
            return .orange
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
        case .completed:
            return .green
        case .paused:
            return .orange
        default:
            return .blue
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

private struct DownloadProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            let clamped = max(0, min(progress, 1))

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.95),
                                Color.cyan.opacity(0.78)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, geometry.size.width * clamped))
            }
        }
        .frame(height: 7)
    }
}
