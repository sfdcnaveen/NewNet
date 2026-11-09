import AppKit
import SwiftUI

struct NetworkDashboardView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var networkMonitor: NetworkSpeedMonitor
    @ObservedObject var speedTestService: SpeedTestService

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Network")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Label(networkMonitor.connectionStatus.title, systemImage: statusIcon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(statusColor)
            }

            HStack(spacing: 10) {
                metric(title: "Download", value: ByteCountFormatter.compactSpeedString(for: networkMonitor.snapshot.downloadBytesPerSecond), icon: "arrow.down", tint: .accentColor)
                metric(title: "Upload", value: ByteCountFormatter.compactSpeedString(for: networkMonitor.snapshot.uploadBytesPerSecond), icon: "arrow.up", tint: .green)
            }

            if !networkMonitor.history.isEmpty {
                NetworkHistoryGraph(samples: networkMonitor.history)
                    .frame(height: 48)
                    .padding(6)
                    .background {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                            .fill(Color.primary.opacity(0.03))
                    }
                    .accessibilityLabel("Recent network activity graph")
            }

            HStack(spacing: 8) {
                Text(networkMonitor.activeInterfaceName ?? "No active interface")
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text(sessionUsageText)
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Text("Internet speed test")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                if speedTestService.isRunning {
                    ProgressView(value: speedTestService.progress)
                        .frame(width: 70)
                    Button("Cancel") { speedTestService.cancel() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.red)
                } else {
                    Button(speedTestService.downloadMegabitsPerSecond == nil ? "Start Test" : "Test Again") {
                        speedTestService.start()
                    }
                    .buttonStyle(LiquidGlassButtonStyle(cornerRadius: DesignTokens.Radius.chip))
                    .font(.system(size: 11, weight: .medium))
                }
            }

            if let down = speedTestService.downloadMegabitsPerSecond,
               let up = speedTestService.uploadMegabitsPerSecond,
               let latency = speedTestService.latencyMilliseconds {
                Text("↓\(formatted(down, decimals: 1)) Mbps  ↑\(formatted(up, decimals: 1)) Mbps  •  \(formatted(latency, decimals: 0)) ms latency")
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Toggle(
                "Show active applications",
                isOn: Binding(
                    get: { settings.showActiveApplications },
                    set: { settings.showActiveApplications = $0 }
                )
            )
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .onChange(of: settings.showActiveApplications) { _, enabled in
                    networkMonitor.setProcessMonitoringEnabled(enabled)
                }

            if settings.showActiveApplications {
                if networkMonitor.processUsage.isEmpty {
                    Text(networkMonitor.processMonitoringMessage ?? "Measuring application network activity…")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(networkMonitor.processUsage) { process in
                        HStack(spacing: 8) {
                            ProcessIconView(processID: process.id)
                            Text(process.name)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                            Spacer()
                            Text("↓\(ByteCountFormatter.compactSpeedString(for: process.downloadBytesPerSecond)) ↑\(ByteCountFormatter.compactSpeedString(for: process.uploadBytesPerSecond))")
                                .font(.system(size: 10))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .liquidGlassControl(cornerRadius: DesignTokens.Radius.small)
                    }
                }
            }
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: DesignTokens.Radius.large)
        .onAppear {
            networkMonitor.setProcessMonitoringEnabled(settings.showActiveApplications)
        }
        .onDisappear {
            networkMonitor.setProcessMonitoringEnabled(false)
        }
    }

    private var statusIcon: String {
        networkMonitor.connectionStatus == .connected ? "checkmark.circle.fill" : "exclamationmark.circle"
    }

    private var statusColor: Color {
        networkMonitor.connectionStatus == .connected ? .green : .secondary
    }

    private var sessionUsageText: String {
        "↓ \(ByteCountFormatter.compactFileSize(networkMonitor.usage.receivedBytes))  ↑ \(ByteCountFormatter.compactFileSize(networkMonitor.usage.sentBytes))"
    }

    private func metric(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .liquidGlassControl(cornerRadius: DesignTokens.Radius.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatted(_ value: Double, decimals: Int) -> String {
        let format: String
        switch decimals {
        case 0:
            format = "%.0f"
        case 1:
            format = "%.1f"
        case 2:
            format = "%.2f"
        default:
            format = "%.\(decimals)f"
        }

        return String(format: format, value)
    }
}

private struct ProcessIconView: View {
    let processID: pid_t

    var body: some View {
        Group {
            if let icon = processIcon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "app.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 18, height: 18)
        .accessibilityLabel("Icon for process")
    }

    private var processIcon: NSImage? {
        guard let application = NSRunningApplication(processIdentifier: processID) else {
            return nil
        }

        if let icon = application.icon {
            return icon
        }

        if let bundleURL = application.bundleURL {
            return NSWorkspace.shared.icon(forFile: bundleURL.path)
        }

        guard let executableURL = application.executableURL else {
            return nil
        }

        var bundleURL = executableURL
        while bundleURL.path != "/" {
            if bundleURL.pathExtension == "app" {
                return NSWorkspace.shared.icon(forFile: bundleURL.path)
            }
            bundleURL.deleteLastPathComponent()
        }

        return nil
    }
}

private struct NetworkHistoryGraph: View {
    let samples: [NetworkHistorySample]

    var body: some View {
        GeometryReader { proxy in
            let maximum = max(samples.flatMap { [$0.downloadBytesPerSecond, $0.uploadBytesPerSecond] }.max() ?? 1, 1)
            Canvas { context, size in
                drawLine(context: &context, size: size, values: samples.map(\.downloadBytesPerSecond), maximum: maximum, color: .accentColor)
                drawLine(context: &context, size: size, values: samples.map(\.uploadBytesPerSecond), maximum: maximum, color: .green)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func drawLine(context: inout GraphicsContext, size: CGSize, values: [Double], maximum: Double, color: Color) {
        guard values.count > 1 else { return }
        var path = Path()
        for (index, value) in values.enumerated() {
            let x = CGFloat(index) / CGFloat(values.count - 1) * size.width
            let y = size.height - CGFloat(value / maximum) * size.height
            if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        context.stroke(path, with: .color(color), lineWidth: 1.5)
    }
}
