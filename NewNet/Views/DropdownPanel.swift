import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DropdownPanel: View {
    @ObservedObject var menuBarViewModel: MenuBarViewModel
    @ObservedObject var downloadManagerViewModel: DownloadManagerViewModel
    @ObservedObject var speedTestViewModel: SpeedTestViewModel
    @ObservedObject var settings: AppSettings

    @Environment(\.colorScheme) private var colorScheme
    @State private var isDropTarget = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            panelCard {
                if let pendingSelection = downloadManagerViewModel.pendingMediaSelection {
                    MediaFormatSelectionScreen(
                        pendingSelection: pendingSelection,
                        downloadManagerViewModel: downloadManagerViewModel
                    )
                } else {
                    mainPanel
                }
            }

            if isDropTarget && downloadManagerViewModel.pendingMediaSelection == nil {
                Text("Drop URL to download")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(glassFill(light: 0.78, dark: 0.12))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(glassStroke(light: 0.12, dark: 0.08), lineWidth: 1)
                    )
                    .padding(20)
                    .transition(.opacity)
            }
        }
        .padding(8)
        .contentShape(Rectangle())
        .onDrop(of: [.url, .fileURL, .text], isTargeted: $isDropTarget) { providers in
            downloadManagerViewModel.handleDrop(providers: providers)
        }
        .animation(.easeOut(duration: 0.18), value: isDropTarget)
    }

    private var mainPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                menuDivider
                usageSection
                menuDivider
                speedTestSection
                menuDivider
                addDownloadSection
                menuDivider
                downloadsSection
                menuDivider
                menuActions
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .scrollIndicators(.hidden)
    }

    private func panelCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(menuBackground)
            .overlay(menuOutline)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(glassStroke(light: 0.12, dark: 0.12), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("NewNet")
                    .font(.system(size: 18, weight: .semibold))

                Text("Faster direct and media downloads")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusCapsule
        }
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Network Usage")

            HStack(spacing: 10) {
                compactUsageMetric(
                    symbol: "arrow.down.circle.fill",
                    tint: .blue,
                    amount: ByteCountFormatter.compactFileSize(menuBarViewModel.usage.receivedBytes)
                )

                compactUsageMetric(
                    symbol: "arrow.up.circle.fill",
                    tint: .green,
                    amount: ByteCountFormatter.compactFileSize(menuBarViewModel.usage.sentBytes)
                )
            }

            HStack(spacing: 10) {
                Image(systemName: "sum")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)

                Text(ByteCountFormatter.compactFileSize(menuBarViewModel.usage.totalBytes))
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()

                Spacer()

                Text("today")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .menuItemBackground()
        }
        .padding(.vertical, 12)
    }

    private var speedTestSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Speed Test")

            HStack(spacing: 10) {
                Button {
                    speedTestViewModel.runSpeedTest()
                } label: {
                    HStack(spacing: 8) {
                        if speedTestViewModel.isTesting {
                            LoadingGlyph()
                        }

                        Text(speedTestViewModel.isTesting ? "Testing..." : "Run Speed Test")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(minWidth: 140)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue.opacity(speedTestViewModel.isTesting ? 0.75 : 0.95))
                )
                .disabled(speedTestViewModel.isTesting)

                Spacer()

                if let result = speedTestViewModel.lastResult {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(result.server)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(result.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let result = speedTestViewModel.lastResult {
                HStack(spacing: 12) {
                    speedMetric(title: "Ping", value: String(format: "%.0f ms", result.ping))
                    speedMetric(title: "Download", value: String(format: "%.1f Mbps", result.download))
                    speedMetric(title: "Upload", value: String(format: "%.1f Mbps", result.upload))
                }
            } else if !speedTestViewModel.isTesting {
                Text("No speed test yet.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let error = speedTestViewModel.errorMessage {
                Text(error)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $speedTestViewModel.autoTestEnabled) {
                    Text("Auto Test")
                        .font(.system(size: 12, weight: .semibold))
                }
                .toggleStyle(.switch)

                Stepper(
                    value: $speedTestViewModel.autoTestIntervalMinutes,
                    in: 2...60,
                    step: 1
                ) {
                    Text("Every \(speedTestViewModel.autoTestIntervalMinutes) min")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .disabled(!speedTestViewModel.autoTestEnabled)
            }
            .menuItemBackground()

            if speedTestViewModel.history.isEmpty {
                Text("No history yet.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(speedTestViewModel.history) { result in
                        HStack {
                            Text(result.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "↓ %.0f ↑ %.0f", result.download, result.upload))
                                .font(.system(size: 12, weight: .semibold))
                                .monospacedDigit()
                        }
                        .menuItemBackground()
                    }
                }
            }
        }
        .padding(.vertical, 12)
    }

    private var addDownloadSection: some View {
        VStack(alignment: .leading, spacing: 10) {
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

                        Image(systemName: "arrow.up.forward")
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
                    .disabled(downloadManagerViewModel.isInspectingURL)
                    .onSubmit {
                        downloadManagerViewModel.submitURL()
                    }

                Button {
                    downloadManagerViewModel.submitURL()
                } label: {
                    HStack(spacing: 6) {
                        if downloadManagerViewModel.isInspectingURL {
                            LoadingGlyph()
                        }

                        Text(downloadManagerViewModel.isInspectingURL ? "Checking" : "Add")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .frame(minWidth: 78)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue.opacity(downloadManagerViewModel.isInspectingURL ? 0.75 : 0.95))
                )
                .disabled(
                    downloadManagerViewModel.isInspectingURL ||
                    downloadManagerViewModel.urlField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }

            DownloadPreferenceControl(
                selection: $downloadManagerViewModel.contentPreference,
                options: DownloadContentPreference.allCases
            )

            if downloadManagerViewModel.isInspectingURL {
                HStack(spacing: 8) {
                    LoadingGlyph()
                    Text("Inspecting available formats")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            if let validationMessage = downloadManagerViewModel.validationMessage {
                Text(validationMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
    }

    private var downloadsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        .padding(.vertical, 12)
    }

    private var menuActions: some View {
        VStack(alignment: .leading, spacing: 4) {
            actionRow(title: "Open Downloads Folder", systemImage: "folder") {
                downloadManagerViewModel.openDownloadsFolder()
            }

            actionRow(title: "Quit NewNet", systemImage: "power", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 12)
    }

    private var menuBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: menuGradientStops,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: menuShadowColor, radius: 24, x: 0, y: 12)
    }

    private var menuOutline: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .strokeBorder(glassStroke(light: 0.08, dark: 0.12), lineWidth: 1)
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(glassFill(light: 0.86, dark: 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(glassStroke(light: 0.12, dark: 0.08), lineWidth: 1)
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
                .fill(glassFill(light: 0.82, dark: 0.08))
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
            .overlay(glassStroke(light: 0.08, dark: 0.08))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.bottom, 2)
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
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(glassFill(light: 0.72, dark: 0.04))
                )
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

    private func speedMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(glassFill(light: 0.72, dark: 0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(glassStroke(light: 0.1, dark: 0.08), lineWidth: 1)
                )
        )
    }

    private var menuGradientStops: [Color] {
        if colorScheme == .dark {
            return [
                Color.black.opacity(0.94),
                Color(nsColor: .windowBackgroundColor).opacity(0.98)
            ]
        }

        return [
            Color.white.opacity(0.9),
            Color.white.opacity(0.68)
        ]
    }

    private var menuShadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.45) : Color.black.opacity(0.18)
    }

    private func glassFill(light: Double, dark: Double) -> Color {
        colorScheme == .dark ? Color.white.opacity(dark) : Color.white.opacity(light)
    }

    private func glassStroke(light: Double, dark: Double) -> Color {
        colorScheme == .dark ? Color.white.opacity(dark) : Color.black.opacity(light)
    }
}

private struct MediaFormatSelectionScreen: View {
    let pendingSelection: PendingMediaSelection
    @ObservedObject var downloadManagerViewModel: DownloadManagerViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            selectionHeader
            divider
            mediaHero
            divider

            VStack(alignment: .leading, spacing: 14) {
                Text("Select Format")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)

                DownloadPreferenceControl(
                    selection: preferenceBinding,
                    options: availablePreferenceOptions
                )

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(pendingSelection.availableOptions) { option in
                            MediaFormatOptionRow(
                                option: option,
                                isSelected: option.id == pendingSelection.selectedOptionID
                            ) {
                                downloadManagerViewModel.setPendingOption(id: option.id)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)

            divider

            HStack(spacing: 10) {
                Button("Back") {
                    downloadManagerViewModel.cancelPendingSelection()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(glassFill(light: 0.8, dark: 0.06))
                )

                Spacer()

                if let selectedOption = pendingSelection.selectedOption {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(selectedOption.label)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Text(selectedOption.detail)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: 170, alignment: .trailing)
                }

                Button("Download") {
                    downloadManagerViewModel.confirmPendingSelection()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue.opacity(0.95))
                )
                .disabled(pendingSelection.selectedOption == nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var selectionHeader: some View {
        HStack(spacing: 12) {
            Button {
                downloadManagerViewModel.cancelPendingSelection()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(glassFill(light: 0.84, dark: 0.08))
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text("Choose Format")
                    .font(.system(size: 17, weight: .semibold))
                Text("NewNet will download exactly what you select.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var mediaHero: some View {
        HStack(alignment: .top, spacing: 14) {
            AsyncImage(url: pendingSelection.mediaInfo.thumbnailURL) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                glassFill(light: 0.7, dark: 0.05),
                                glassFill(light: 0.5, dark: 0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                    )
            }
            .frame(width: 118, height: 82)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text(pendingSelection.mediaInfo.title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                FlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    if let uploader = pendingSelection.mediaInfo.uploader, !uploader.isEmpty {
                        infoChip(text: uploader)
                    }

                    if let extractor = pendingSelection.mediaInfo.extractor, !extractor.isEmpty {
                        infoChip(text: extractor.uppercased())
                    }

                    if let duration = pendingSelection.mediaInfo.duration {
                        infoChip(text: durationString(for: duration))
                    }
                }

                Text("Prefer the exact quality you want instead of the extractor default.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private var availablePreferenceOptions: [DownloadContentPreference] {
        var options: [DownloadContentPreference] = []
        if !pendingSelection.mediaInfo.videoOptions.isEmpty {
            options.append(.video)
        }
        if !pendingSelection.mediaInfo.audioOptions.isEmpty {
            options.append(.audio)
        }
        return options
    }

    private var preferenceBinding: Binding<DownloadContentPreference> {
        Binding(
            get: { pendingSelection.selectedPreference == .audio ? .audio : .video },
            set: { downloadManagerViewModel.setPendingPreference($0) }
        )
    }

    private var divider: some View {
        Divider()
            .overlay(glassStroke(light: 0.08, dark: 0.08))
    }

    private func infoChip(text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(glassFill(light: 0.8, dark: 0.06))
            )
    }

    private func durationString(for duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: duration) ?? ""
    }

    private func glassFill(light: Double, dark: Double) -> Color {
        colorScheme == .dark ? Color.white.opacity(dark) : Color.white.opacity(light)
    }

    private func glassStroke(light: Double, dark: Double) -> Color {
        colorScheme == .dark ? Color.white.opacity(dark) : Color.black.opacity(light)
    }
}

private struct DownloadPreferenceControl: View {
    @Binding var selection: DownloadContentPreference
    let options: [DownloadContentPreference]
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options) { option in
                Button {
                    selection = option
                } label: {
                    Text(option.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selection == option ? Color.white : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(selection == option ? Color.blue.opacity(0.95) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(glassFill(light: 0.78, dark: 0.06))
                )
        )
    }

    private func glassFill(light: Double, dark: Double) -> Color {
        colorScheme == .dark ? Color.white.opacity(dark) : Color.white.opacity(light)
    }
}

private struct MediaFormatOptionRow: View {
    let option: YTDLPDownloadOption
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue.opacity(0.16) : glassFill(light: 0.78, dark: 0.06))
                        .frame(width: 28, height: 28)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.blue : Color.secondary)
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(option.label)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Spacer(minLength: 6)

                        if let estimatedBytes = option.estimatedBytes {
                            Text(ByteCountFormatter.compactFileSize(estimatedBytes))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(glassFill(light: 0.8, dark: 0.06))
                                )
                        }
                    }

                    Text(option.detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .overlay(border)
        }
        .buttonStyle(.plain)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.11) : glassFill(light: 0.7, dark: 0.035))
            )
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(isSelected ? Color.blue.opacity(0.55) : glassStroke(light: 0.1, dark: 0.08), lineWidth: 1)
    }

    private func glassFill(light: Double, dark: Double) -> Color {
        colorScheme == .dark ? Color.white.opacity(dark) : Color.white.opacity(light)
    }

    private func glassStroke(light: Double, dark: Double) -> Color {
        colorScheme == .dark ? Color.white.opacity(dark) : Color.black.opacity(light)
    }
}

private struct LoadingGlyph: View {
    @State private var isAnimating = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(dotColor.opacity(opacity(for: index)))
                    .frame(width: 5, height: 5)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }

    private func opacity(for index: Int) -> Double {
        guard isAnimating else { return 0.35 }
        return 0.35 + (Double(index) * 0.18)
    }

    private var dotColor: Color {
        colorScheme == .dark ? Color.white : Color.primary
    }
}

private struct FlowLayout<Content: View>: View {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    func menuItemBackground() -> some View {
        modifier(MenuItemGlassBackground())
    }
}

private struct MenuItemGlassBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(glassFill(light: 0.72, dark: 0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(glassStroke(light: 0.1, dark: 0.08), lineWidth: 1)
                    )
            )
    }

    private func glassFill(light: Double, dark: Double) -> Color {
        colorScheme == .dark ? Color.white.opacity(dark) : Color.white.opacity(light)
    }

    private func glassStroke(light: Double, dark: Double) -> Color {
        colorScheme == .dark ? Color.white.opacity(dark) : Color.black.opacity(light)
    }
}
