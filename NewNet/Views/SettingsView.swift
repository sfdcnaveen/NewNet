import SwiftUI
import Sparkle

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

    @State private var inputLastFMUsername = ""
    @State private var inputLastFMSessionKey = ""
    @State private var inputListenBrainzToken = ""
    @State private var isValidatingListenBrainz = false
    @State private var listenBrainzError: String?

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: themeBinding) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
            }
            
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
                    TextField("/opt/homebrew/bin/yt-dlp", text: ytDLPPathBinding)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 220)
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
                    Text("Reorder tabs to customize their appearance in the menu bar panel:")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    ForEach(Array(settings.tabOrder.enumerated()), id: \.element.id) { index, tab in
                        HStack(spacing: 10) {
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
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .liquidGlassControl()
                    }

                    HStack {
                        Spacer()
                        Button("Restore Default Order") {
                            settings.restoreDefaultTabOrder()
                        }
                        .controlSize(.small)
                    }
                    .padding(.top, 4)
                }
            }

            Section("Music Scrobbling") {
                Toggle("Scrobble to Last.fm", isOn: lastFMEnabledBinding)
                    .disabled(!scrobbleCoordinator.lastFMStatus.isConnected && !settings.isLastFMEnabled)

                if scrobbleCoordinator.lastFMStatus.isConnected {
                    LabeledContent("Last.fm Account") {
                        HStack {
                            Text(scrobbleCoordinator.lastFMStatus.username ?? settings.lastFMUsername)
                                .foregroundStyle(.secondary)
                            Button("Disconnect") {
                                scrobbleCoordinator.disconnectLastFM()
                            }
                            .buttonStyle(.link)
                            .controlSize(.small)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Connect Last.fm")
                            .font(.system(size: 11, weight: .semibold))
                        HStack {
                            TextField("Username", text: $inputLastFMUsername)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 110)
                            SecureField("Session Key", text: $inputLastFMSessionKey)
                                .textFieldStyle(.roundedBorder)
                            Button("Connect") {
                                connectLastFM()
                            }
                            .disabled(inputLastFMUsername.isEmpty || inputLastFMSessionKey.isEmpty)
                        }
                        Text("Credentials are saved securely in your macOS Keychain.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Divider()

                Toggle("Scrobble to ListenBrainz", isOn: listenBrainzEnabledBinding)
                    .disabled(!scrobbleCoordinator.listenBrainzStatus.isConnected && !settings.isListenBrainzEnabled)

                if scrobbleCoordinator.listenBrainzStatus.isConnected {
                    LabeledContent("ListenBrainz Account") {
                        HStack {
                            Text(scrobbleCoordinator.listenBrainzStatus.username ?? settings.listenBrainzUsername)
                                .foregroundStyle(.secondary)
                            Button("Disconnect") {
                                scrobbleCoordinator.disconnectListenBrainz()
                            }
                            .buttonStyle(.link)
                            .controlSize(.small)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Connect ListenBrainz")
                            .font(.system(size: 11, weight: .semibold))
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
                    .padding(.vertical, 4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("Privacy First", systemImage: "lock.shield")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("API tokens and session keys are stored securely in macOS Keychain. Listening activity is only transmitted to your connected services. No telemetry, no analytics.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 4)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding(10)
        .task {
            installedYTDLPVersion = await ytDLPService.installedVersion(settings: settings)
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

    private var themeBinding: Binding<AppTheme> {
        Binding(
            get: { settings.appTheme },
            set: { settings.appTheme = $0 }
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

    private func connectLastFM() {
        let username = inputLastFMUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let sessionKey = inputLastFMSessionKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty, !sessionKey.isEmpty else { return }
        scrobbleCoordinator.connectLastFMWithSession(username: username, sessionKey: sessionKey)
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
