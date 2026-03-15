import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DropdownPanel: View {
    @ObservedObject var menuBarViewModel: MenuBarViewModel
    @ObservedObject var downloadManagerViewModel: DownloadManagerViewModel
    @ObservedObject var settings: AppSettings

    @State private var isDropTarget = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                menuDivider
                usageSection
                menuDivider
                addDownloadSection
                menuDivider
                downloadsSection
                menuDivider
                menuActions
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(menuBackground)
            .overlay(menuOutline)
            .padding(8)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .overlay(alignment: .topTrailing) {
            if isDropTarget {
                Text("Drop URL to download")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(16)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .onDrop(of: [.url, .fileURL, .text], isTargeted: $isDropTarget) { providers in
            downloadManagerViewModel.handleDrop(providers: providers)
        }
        .animation(.spring(duration: 0.28), value: isDropTarget)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "network")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.95),
                                    Color.cyan.opacity(0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("NewNet")
                    .font(.system(size: 18, weight: .semibold))
            }

            Spacer()

            statusCapsule
        }
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Network Usage")

            HStack(spacing: 8) {
                compactUsageMetric(
                    symbol: "arrow.down.circle.fill",
                    tint: .blue,
                    amount: ByteCountFormatter.compactFileSize(Int64(menuBarViewModel.usage.receivedBytes))
                )

                compactUsageMetric(
                    symbol: "arrow.up.circle.fill",
                    tint: .green,
                    amount: ByteCountFormatter.compactFileSize(Int64(menuBarViewModel.usage.sentBytes))
                )
            }

            HStack(spacing: 10) {
                Image(systemName: "sum")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                Text(ByteCountFormatter.compactFileSize(Int64(menuBarViewModel.usage.totalBytes)))
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()

                Spacer()

                Text("today")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .menuItemBackground()
        }
        .padding(.vertical, 10)
    }

    private var addDownloadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Add Download")

            if let clipboardURL = menuBarViewModel.clipboardURL, settings.clipboardMonitoringEnabled {
                Button {
                    downloadManagerViewModel.fillURLField(with: clipboardURL)
                    menuBarViewModel.dismissClipboardSuggestion()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.blue)
                            .frame(width: 24)

                        Text("Use Copied Link")
                            .font(.system(size: 15, weight: .medium))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .menuItemBackground()
            }

            HStack(spacing: 8) {
                TextField("Paste or drop a link", text: $downloadManagerViewModel.urlField)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(inputBackground)
                    .onSubmit {
                        downloadManagerViewModel.submitURL()
                    }

                Button("Add") {
                    downloadManagerViewModel.submitURL()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(.blue)
            }

            Picker("Media type", selection: $downloadManagerViewModel.contentPreference) {
                ForEach(DownloadContentPreference.allCases) { preference in
                    Text(preference.title).tag(preference)
                }
            }
            .pickerStyle(.segmented)

            if let validationMessage = downloadManagerViewModel.validationMessage {
                Text(validationMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 10)
    }

    private var downloadsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                sectionTitle("Recent Downloads")

                Spacer()

                if downloadManagerViewModel.canClearRecentDownloads {
                    Button("Clear List") {
                        downloadManagerViewModel.clearRecentDownloads()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red)
                }
            }

            if downloadManagerViewModel.recentDownloads.isEmpty {
                Text("No downloads yet.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(downloadManagerViewModel.recentDownloads) { item in
                        DownloadRow(
                            item: item,
                            onPause: { downloadManagerViewModel.pause(item) },
                            onResume: { downloadManagerViewModel.resume(item) },
                            onOpen: { downloadManagerViewModel.open(item) }
                        )
                    }
                }
            }
        }
        .padding(.vertical, 10)
    }

    private var menuActions: some View {
        VStack(alignment: .leading, spacing: 2) {
            actionRow(title: "Open Downloads Folder", systemImage: "folder") {
                downloadManagerViewModel.openDownloadsFolder()
            }

            actionRow(title: "Quit NewNet", systemImage: "power", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 10)
    }

    private var menuBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.9),
                        Color(nsColor: .windowBackgroundColor).opacity(0.97)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
    }

    private var menuOutline: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private var statusCapsule: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(activeIndicatorColor)
                .frame(width: 8, height: 8)

            Text(activeDownloadCount == 0 ? "Idle" : "\(activeDownloadCount) Active")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var activeDownloadCount: Int {
        downloadManagerViewModel.activeDownloads.count
    }

    private var activeIndicatorColor: Color {
        activeDownloadCount == 0 ? .secondary : .green
    }

    private var menuDivider: some View {
        Divider()
            .overlay(Color.white.opacity(0.08))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)
    }

    private func menuSummaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(.primary)
        .menuItemBackground()
    }

    private func compactUsageMetric(
        symbol: String,
        tint: Color,
        amount: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(tint)

            Text(amount)
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func actionRow(title: String, systemImage: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 15, weight: .medium))

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? .red : .primary)
        .menuItemBackground()
    }

}

private extension View {
    func menuItemBackground() -> some View {
        padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
    }
}

private extension Text {
    func menuValueStyle() -> some View {
        font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }
}
