import SwiftUI

struct DownloadRow: View {
    let item: DownloadItem
    let onPause: () -> Void
    let onResume: () -> Void
    let onOpen: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.medium) {
                
                ZStack {
                    Circle()
                        .fill(leadingColor.opacity(0.15))
                    
                    Image(systemName: leadingSymbol)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(leadingColor)
                }
                .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.fileName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                            Text(item.engine.displayName)
                        }
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                        .foregroundStyle(.secondary)
                        
                        if let formatSummary = item.ytDLPConfiguration?.displayName, item.engine == .ytDLP {
                            HStack(spacing: 4) {
                                Image(systemName: "film")
                                Text(formatSummary)
                            }
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.primary.opacity(0.08)))
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer(minLength: DesignTokens.Spacing.small)
                
                Button(action: action) {
                    Image(systemName: actionSymbol)
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .background(
                    Circle().fill(Color(nsColor: .controlBackgroundColor).opacity(isHovering ? 0.8 : 0.4))
                )
                .overlay(
                    Circle().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
            }
            
            if item.isActive {
                VStack(spacing: 6) {
                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)
                        .tint(Color.accentColor)
                        .frame(height: 4)
                        .animation(DesignTokens.Animation.progress, value: item.progress)
                    
                    HStack {
                        Text(activeStatusText)
                        Spacer()
                        if item.totalBytesExpected > 0 {
                            Text("\(Int(item.progress * 100))%")
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            } else {
                HStack {
                    Text(statusText)
                        .foregroundStyle(statusColor)
                    
                    Spacer()
                    
                    if item.state == .completed {
                        Text(ByteCountFormatter.compactFileSize(item.downloadedBytes))
                            .foregroundStyle(.secondary)
                    } else if item.state == .failed {
                        Text(item.errorDescription ?? "Failed to download")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.medium)
        .padding(.vertical, DesignTokens.Spacing.medium)
        .liquidGlassControl(isHovered: isHovering, isActive: item.isActive)
        .onHover { isHovering = $0 }
        .animation(DesignTokens.Animation.hover, value: isHovering)
        .animation(DesignTokens.Animation.transition, value: item.state)
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
        case .completed: return "folder.fill"
        default: return "play.fill"
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
