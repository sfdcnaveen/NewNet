import SwiftUI
import Sparkle

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var updateManager: UpdateManager
    @ObservedObject var networkMonitor: NetworkSpeedMonitor
    @ObservedObject var speedTestService: SpeedTestService
    private let ytDLPService = YTDLPService()
    private let externalToolsService = ExternalToolsService()
    @State private var loginErrorMessage: String?
    @State private var showLoginError = false
    @State private var isUpdatingYTDLP = false
    @State private var ytdlpUpdateMessage: String?
    @State private var installedYTDLPVersion: String?

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
