import SwiftUI
import Sparkle
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var updateManager: UpdateManager
    @ObservedObject var networkMonitor: NetworkSpeedMonitor
    @ObservedObject var speedTestService: SpeedTestService
    @ObservedObject var scrobbleCoordinator: ScrobbleCoordinator
    private let ytDLPService = YTDLPService()
    private let externalToolsService = ExternalToolsService()
    @State private var loginErrorMessage: String?
    @State private var showLoginError = false
    @State private var isUpdatingYTDLP = false
    @State private var ytdlpUpdateMessage: String?
    @State private var installedYTDLPVersion: String?

    @State private var inputLastFMAPIKey = ""
    @State private var inputLastFMAPISecret = ""
    @State private var isAuthorizingLastFM = false
    @State private var isConnectingLastFM = false
    @State private var lastFMErrorMessage: String?
    @State private var showManualLastFM = false
    @State private var inputLastFMUsername = ""
    @State private var inputLastFMSessionKey = ""
    @State private var inputListenBrainzToken = ""
    @State private var isValidatingListenBrainz = false
    @State private var listenBrainzError: String?
    @State private var draggedTab: NewNetTab?

    var body: some View {
        Form {
            Section("Download Engine") {
                Stepper(value: maxSegmentsBinding, in: 1...8) {
                    HStack {
                        Text("Parallel segments")
                        Spacer()
                        Text("\(settings.maxSegments)")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Speed limit")
                    Spacer()
                    TextField(
                        "Unlimited",
                        value: speedLimitBinding,
                        formatter: NumberFormatter.integerFormatter
                    )
                    .multilineTextAlignment(.trailing)
                    .frame(width: 96)
                    Text("KB/s")
                        .foregroundStyle(.secondary)
                }

                Toggle("Resume downloads after app restart", isOn: autoResumeBinding)
            }

            Section("Startup") {
                Toggle("Open NewNet at login", isOn: launchAtLoginBinding)
            }

            Section("Menu Bar Panel") {
                HStack {
                    Text("Panel size")
                    Spacer()
                    Text("\(Int((settings.menuBarPanelScale * 100).rounded()))%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Slider(value: menuBarPanelScaleBinding, in: 0.85...1.25, step: 0.05) {
                    Text("Panel size")
                } minimumValueLabel: {
                    Text("Smaller")
                        .font(.system(size: 10, weight: .medium))
                } maximumValueLabel: {
                    Text("Larger")
                        .font(.system(size: 10, weight: .medium))
                }
            }

            Section("Network Monitoring") {
                LabeledContent("Status") {
                    Text(networkMonitor.connectionStatus.title)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Active interface") {
                    Text(networkMonitor.activeInterfaceName ?? "None")
                        .foregroundStyle(.secondary)
                }
                Toggle("Measure active applications", isOn: activeApplicationsBinding)
                    .onChange(of: settings.showActiveApplications) { _, enabled in
                        networkMonitor.setProcessMonitoringEnabled(enabled)
                    }
            }

            Section("Updates") {
                if let update = updateManager.availableUpdate, !updateManager.isUpdateNotificationSuppressed {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Version \(update.displayVersionString) is available", systemImage: "arrow.down.app.fill")
                            .font(.headline)

                        if updateManager.isDownloadingUpdate {
                            ProgressView(value: updateManager.updateDownloadProgress)
                        }

                        HStack {
                            Button(updateManager.isDownloadingUpdate ? "Installing…" : "Install Update") {
                                updateManager.installUpdate()
                            }
                            .disabled(updateManager.isDownloadingUpdate)

                            Button("Dismiss") {
                                updateManager.dismissAvailableUpdate()
                            }
                            .buttonStyle(.link)
                        }
                    }
                    .padding(.vertical, 4)
                } else if updateManager.isCheckingForUpdates {
                    Label("Checking for updates…", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.secondary)
                } else if let error = updateManager.lastErrorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if updateManager.isUpdateNotificationSuppressed {
                    HStack {
                        Text("Update postponed")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Show Again") {
                            updateManager.showDismissedUpdateAgain()
                        }
                        .buttonStyle(.link)
                    }
                }

                Button("Check for Updates (System)…") {
                    updateManager.checkForUpdatesManually()
                }
                .disabled(!updateManager.canCheckForUpdates || updateManager.isCheckingForUpdates)

                if let lastCheckDate = updateManager.lastCheckDate {
                    Text("Last checked \(lastCheckDate.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("yt-dlp") {
                HStack(alignment: .firstTextBaseline) {
                    Text("Override path")
                    Spacer()
                    RightAlignedTextField(
                        placeholder: "/opt/homebrew/bin/yt-dlp",
                        text: ytDLPPathBinding
                    )
                    .frame(width: 220, height: 22)
                }

                Picker("Default social-media mode", selection: preferredMediaBinding) {
                    ForEach(DownloadContentPreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }

                LabeledContent("Installed version") {
                    Text(installedYTDLPVersion ?? "Not installed")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                HStack {
                    Text("yt-dlp")

                    Spacer()

                    Button {
                        updateYTDLP()
                    } label: {
                        if isUpdatingYTDLP {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Update yt-dlp")
                        }
                    }
                    .disabled(isUpdatingYTDLP)
                }

                if let ytdlpUpdateMessage {
                    Text(ytdlpUpdateMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

            }

            Section("Smart Features") {
                Toggle("Detect links copied to clipboard", isOn: clipboardBinding)
                Toggle("Battery saver mode", isOn: powerSavingBinding)
            }

            Section("Navigation & Tab Ordering") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Drag or use arrows to customize tab order in the menu bar:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    ForEach(Array(settings.tabOrder.enumerated()), id: \.element.id) { index, tab in
                        HStack(spacing: 10) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.secondary.opacity(0.8))
                                .frame(width: 16)
                                .help("Drag to reorder")

                            Image(systemName: tab.systemImage)
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 20)
                                .foregroundStyle(Color.accentColor)

                            Text(tab.title)
                                .font(.system(size: 12, weight: .medium))

                            Spacer()

                            Button {
                                moveTabUp(at: index)
                            } label: {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .disabled(index == 0)
                            .help("Move up")

                            Button {
                                moveTabDown(at: index)
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .buttonStyle(.plain)
                            .disabled(index == settings.tabOrder.count - 1)
                            .help("Move down")
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .liquidGlassControl(isActive: draggedTab == tab)
                        .onDrag {
                            draggedTab = tab
                            return NSItemProvider(object: tab.rawValue as NSString)
                        }
                        .onDrop(of: [.text], delegate: TabDropDelegate(destinationTab: tab, settings: settings, draggedTab: $draggedTab))
                    }

                    HStack {
                        Spacer()
                        Button("Restore Default Order") {
                            withAnimation {
                                settings.restoreDefaultTabOrder()
                            }
                        }
                        .controlSize(.small)
                    }
                    .padding(.top, 4)
                }
            }

            Section("Music Scrobbling") {
                VStack(spacing: 10) {
                    // Last.fm Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "music.note")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.red)
                            Text("Last.fm")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Toggle("", isOn: lastFMEnabledBinding)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .disabled(!scrobbleCoordinator.lastFMStatus.isConnected && !settings.isLastFMEnabled)
                        }

                        if scrobbleCoordinator.lastFMStatus.isConnected {
                            HStack {
                                Text("Account")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(scrobbleCoordinator.lastFMStatus.username ?? settings.lastFMUsername)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.primary)
                                Button("Disconnect") {
                                    scrobbleCoordinator.disconnectLastFM()
                                    isAuthorizingLastFM = false
                                    lastFMErrorMessage = nil
                                }
                                .buttonStyle(.link)
                                .font(.system(size: 11))
                            }
                        } else if isAuthorizingLastFM {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Waiting for authorization in browser…")
                                        .font(.system(size: 11, weight: .medium))
                                }

                                Text("1. In your browser, log in to Last.fm and click 'Yes, allow access'.\n2. Once approved, return here and click 'Complete Connection'.")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 8) {
                                    Button(isConnectingLastFM ? "Connecting…" : "Complete Connection") {
                                        completeLastFMAuth()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    .disabled(isConnectingLastFM)

                                    Button("Cancel") {
                                        scrobbleCoordinator.cancelLastFMBrowserAuth()
                                        isAuthorizingLastFM = false
                                        lastFMErrorMessage = nil
                                    }
                                    .controlSize(.small)
                                }

                                if let error = lastFMErrorMessage {
                                    Text(error)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.red)
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Connect your Last.fm account using 1-Click Official Browser Authorization.")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 6) {
                                    TextField("API Key", text: $inputLastFMAPIKey)
                                        .textFieldStyle(.roundedBorder)
                                    SecureField("Shared Secret", text: $inputLastFMAPISecret)
                                        .textFieldStyle(.roundedBorder)
                                }

                                HStack {
                                    Button {
                                        startLastFMBrowserAuth()
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: "safari")
                                            Text("Connect Last.fm (Browser)")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    .disabled(inputLastFMAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || inputLastFMAPISecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                                    Spacer()

                                    Link("Get API Key ↗", destination: URL(string: "https://www.last.fm/api/account/create")!)
                                        .font(.system(size: 10))
                                        .buttonStyle(.link)
                                }

                                if let error = lastFMErrorMessage {
                                    Text(error)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.red)
                                }

                                DisclosureGroup("Manual Session Key (Advanced)", isExpanded: $showManualLastFM) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            TextField("Username", text: $inputLastFMUsername)
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 110)
                                            SecureField("Session Key", text: $inputLastFMSessionKey)
                                                .textFieldStyle(.roundedBorder)
                                            Button("Connect") {
                                                connectLastFMManual()
                                            }
                                            .controlSize(.small)
                                            .disabled(inputLastFMUsername.isEmpty || inputLastFMSessionKey.isEmpty)
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)

                                Text("Credentials are saved securely in NewNet's private encrypted vault.")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(10)
                    .liquidGlassControl()

                    // ListenBrainz Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "headphones")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.orange)
                            Text("ListenBrainz")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            Toggle("", isOn: listenBrainzEnabledBinding)
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                                .disabled(!scrobbleCoordinator.listenBrainzStatus.isConnected && !settings.isListenBrainzEnabled)
                        }

                        if scrobbleCoordinator.listenBrainzStatus.isConnected {
                            HStack {
                                Text("Account")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(scrobbleCoordinator.listenBrainzStatus.username ?? settings.listenBrainzUsername)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.primary)
                                Button("Disconnect") {
                                    scrobbleCoordinator.disconnectListenBrainz()
                                }
                                .buttonStyle(.link)
                                .font(.system(size: 11))
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    SecureField("User Token", text: $inputListenBrainzToken)
                                        .textFieldStyle(.roundedBorder)
                                    Button(isValidatingListenBrainz ? "Connecting…" : "Connect") {
                                        connectListenBrainz()
                                    }
                                    .disabled(inputListenBrainzToken.isEmpty || isValidatingListenBrainz)
                                }
                                if let error = listenBrainzError {
                                    Text(error)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.red)
                                }
                                Text("Find your User Token in your ListenBrainz profile.")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .liquidGlassControl()

                    // Privacy notice: Simple, concise, legible in dark mode
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text("Privacy focused, no telemetry, no analytics")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding(10)
        .task {
            installedYTDLPVersion = await ytDLPService.installedVersion(settings: settings)
            if let savedKey = scrobbleCoordinator.getSavedLastFMAPIKey() {
                inputLastFMAPIKey = savedKey
            }
            if let savedSecret = scrobbleCoordinator.getSavedLastFMAPISecret() {
                inputLastFMAPISecret = savedSecret
            }
        }
        .alert("Unable to Update Login Item", isPresented: $showLoginError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loginErrorMessage ?? "NewNet could not update the login item.")
        }
    }

    private var maxSegmentsBinding: Binding<Int> {
        Binding(
            get: { settings.maxSegments },
            set: { settings.maxSegments = $0 }
        )
    }

    private var speedLimitBinding: Binding<Int> {
        Binding(
            get: { settings.speedLimitKBps },
            set: { settings.speedLimitKBps = $0 }
        )
    }

    private var clipboardBinding: Binding<Bool> {
        Binding(
            get: { settings.clipboardMonitoringEnabled },
            set: { settings.clipboardMonitoringEnabled = $0 }
        )
    }

    private var autoResumeBinding: Binding<Bool> {
        Binding(
            get: { settings.autoResumeDownloads },
            set: { settings.autoResumeDownloads = $0 }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLogin },
            set: { newValue in
                do {
                    try LaunchAtLoginManager.setEnabled(newValue)
                    settings.launchAtLogin = LaunchAtLoginManager.isEnabled
                } catch {
                    loginErrorMessage = error.localizedDescription
                    showLoginError = true
                    settings.launchAtLogin = LaunchAtLoginManager.isEnabled
                }
            }
        )
    }

    private var powerSavingBinding: Binding<Bool> {
        Binding(
            get: { settings.powerSavingEnabled },
            set: { settings.powerSavingEnabled = $0 }
        )
    }

    private var menuBarPanelScaleBinding: Binding<Double> {
        Binding(
            get: { settings.menuBarPanelScale },
            set: { settings.menuBarPanelScale = $0 }
        )
    }

    private var ytDLPPathBinding: Binding<String> {
        Binding(
            get: { settings.ytDLPPath },
            set: { settings.ytDLPPath = $0 }
        )
    }

    private var activeApplicationsBinding: Binding<Bool> {
        Binding(
            get: { settings.showActiveApplications },
            set: { settings.showActiveApplications = $0 }
        )
    }

    private func updateYTDLP() {
        isUpdatingYTDLP = true
        ytdlpUpdateMessage = nil

        Task { @MainActor in
            do {
                let latestVersion = try await ytDLPService.latestVersion()
                if installedYTDLPVersion == latestVersion {
                    ytdlpUpdateMessage = "yt-dlp \(latestVersion) is up to date."
                } else {
                    _ = try await ytDLPService.update(settings: settings)
                    installedYTDLPVersion = await ytDLPService.installedVersion(settings: settings) ?? latestVersion
                    ytdlpUpdateMessage = "yt-dlp updated to \(installedYTDLPVersion ?? latestVersion)."
                }
            } catch {
                ytdlpUpdateMessage = error.localizedDescription
            }
            isUpdatingYTDLP = false
        }
    }

    private var preferredMediaBinding: Binding<DownloadContentPreference> {
        Binding(
            get: { settings.preferredMediaType },
            set: { settings.preferredMediaType = $0 }
        )
    }

    private var lastFMEnabledBinding: Binding<Bool> {
        Binding(
            get: { settings.isLastFMEnabled },
            set: { settings.isLastFMEnabled = $0 }
        )
    }

    private var listenBrainzEnabledBinding: Binding<Bool> {
        Binding(
            get: { settings.isListenBrainzEnabled },
            set: { settings.isListenBrainzEnabled = $0 }
        )
    }

    private func moveTabUp(at index: Int) {
        guard index > 0 else { return }
        var order = settings.tabOrder
        order.swapAt(index, index - 1)
        settings.tabOrder = order
    }

    private func moveTabDown(at index: Int) {
        guard index < settings.tabOrder.count - 1 else { return }
        var order = settings.tabOrder
        order.swapAt(index, index + 1)
        settings.tabOrder = order
    }

    private func startLastFMBrowserAuth() {
        lastFMErrorMessage = nil
        Task { @MainActor in
            do {
                let url = try await scrobbleCoordinator.startLastFMBrowserAuth(
                    apiKey: inputLastFMAPIKey,
                    apiSecret: inputLastFMAPISecret
                )
                NSWorkspace.shared.open(url)
                isAuthorizingLastFM = true
            } catch {
                lastFMErrorMessage = error.localizedDescription
            }
        }
    }

    private func completeLastFMAuth() {
        lastFMErrorMessage = nil
        isConnectingLastFM = true
        Task { @MainActor in
            do {
                _ = try await scrobbleCoordinator.completeLastFMBrowserAuth()
                isAuthorizingLastFM = false
            } catch {
                lastFMErrorMessage = error.localizedDescription
            }
            isConnectingLastFM = false
        }
    }

    private func connectLastFMManual() {
        let username = inputLastFMUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let sessionKey = inputLastFMSessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = inputLastFMAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiSecret = inputLastFMAPISecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty, !sessionKey.isEmpty else { return }
        scrobbleCoordinator.connectLastFMWithSession(
            username: username,
            sessionKey: sessionKey,
            apiKey: apiKey.isEmpty ? nil : apiKey,
            apiSecret: apiSecret.isEmpty ? nil : apiSecret
        )
        inputLastFMSessionKey = ""
    }

    private func connectListenBrainz() {
        let token = inputListenBrainzToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        isValidatingListenBrainz = true
        listenBrainzError = nil

        Task { @MainActor in
            do {
                _ = try await scrobbleCoordinator.connectListenBrainz(token: token)
                inputListenBrainzToken = ""
            } catch {
                listenBrainzError = error.localizedDescription
            }
            isValidatingListenBrainz = false
        }
    }
}



private extension NumberFormatter {
    static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 0
        formatter.maximum = 999_999
        return formatter
    }()
}

struct TabDropDelegate: DropDelegate {
    let destinationTab: NewNetTab
    let settings: AppSettings
    @Binding var draggedTab: NewNetTab?

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedTab,
              dragged != destinationTab,
              let from = settings.tabOrder.firstIndex(of: dragged),
              let to = settings.tabOrder.firstIndex(of: destinationTab) else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            settings.tabOrder.swapAt(from, to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedTab = nil
        return true
    }
}

struct RightAlignedTextField: NSViewRepresentable {
    var placeholder: String
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.alignment = .right
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.delegate = context.coordinator
        textField.font = .systemFont(ofSize: NSFont.systemFontSize(for: .regular))
        applyPlaceholder(to: textField)
        textField.stringValue = text
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        applyPlaceholder(to: nsView)
    }

    private func applyPlaceholder(to textField: NSTextField) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        textField.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor.placeholderTextColor,
                .paragraphStyle: paragraph,
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .regular))
            ]
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: RightAlignedTextField

        init(_ parent: RightAlignedTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }
    }
}
