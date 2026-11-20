import SwiftUI
import Sparkle
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var updateManager: UpdateManager
    @ObservedObject var networkMonitor: NetworkSpeedMonitor
    @ObservedObject var speedTestService: SpeedTestService
    @ObservedObject var scrobbleCoordinator: ScrobbleCoordinator
    var utilitiesCoordinator: UtilitiesCoordinator? = nil

    @State private var loginErrorMessage: String?
    @State private var showLoginError = false

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
            // MARK: - 1. General
            Section("General") {
                Toggle("Open NewNet at login", isOn: launchAtLoginBinding)

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

                Picker("App theme", selection: $settings.appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }

                Toggle("Resume downloads after app restart", isOn: autoResumeBinding)
            }

            // MARK: - 2. Navigation & Tabs
            Section("Navigation & Tab Ordering") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Drag or use arrows to customize tab order. Toggle the eye to show or hide tabs in the menu bar:")
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

                            HStack(spacing: 8) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        settings.toggleTabVisibility(tab)
                                    }
                                } label: {
                                    Image(systemName: settings.isTabVisible(tab) ? "eye" : "eye.slash")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(settings.isTabVisible(tab) ? Color.primary : Color.secondary.opacity(0.6))
                                        .frame(width: 20, height: 20)
                                }
                                .buttonStyle(.plain)
                                .help(settings.isTabVisible(tab) ? "Hide tab from menu bar" : "Show tab in menu bar")
                                .disabled(settings.isTabVisible(tab) && settings.visibleTabs.count <= 1)

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
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .opacity(settings.isTabVisible(tab) ? 1.0 : 0.65)
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

            // MARK: - 3. macOS Utilities
            Section("macOS Utilities") {
                // Keep Awake
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "cup.and.saucer.fill")
                            .foregroundStyle(.orange)
                        Text("Keep Awake")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        if let coord = utilitiesCoordinator, coord.keepAwake.isActive {
                            Text(coord.keepAwake.remainingTimeFormatted)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                    }

                    Picker("Default duration", selection: $settings.keepAwakeDurationMinutes) {
                        Text("Indefinite").tag(0)
                        Text("15 Minutes").tag(15)
                        Text("30 Minutes").tag(30)
                        Text("1 Hour").tag(60)
                        Text("2 Hours").tag(120)
                    }

                    Toggle("Keep awake when lid is closed", isOn: $settings.keepAwakePreventDisplaySleep)
                }
                .padding(.vertical, 2)

                // Clipboard History
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "doc.on.clipboard.fill")
                            .foregroundStyle(.blue)
                        Text("Clipboard History")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Toggle("", isOn: $settings.clipboardHistoryEnabled)
                            .labelsHidden()
                    }

                    if settings.clipboardHistoryEnabled {
                        Stepper("History limit: \(settings.clipboardHistoryLimit) items", value: $settings.clipboardHistoryLimit, in: 10...200, step: 10)
                            .font(.system(size: 12))

                        if let coord = utilitiesCoordinator {
                            Button("Clear Clipboard History") {
                                coord.clipboardHistory.clearHistory()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                            .font(.system(size: 11))
                        }
                    }
                }
                .padding(.vertical, 2)

                // Mouse Scroll Inverter
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "computermouse.fill")
                            .foregroundStyle(.cyan)
                        Text("Inverse Mouse Scrolling")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Toggle("", isOn: $settings.scrollInversionEnabled)
                            .labelsHidden()
                    }

                    Text("Reverses physical mouse wheel scrolling without affecting trackpad natural scrolling.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    if settings.scrollInversionEnabled && !SystemPermissionsHelper.isAccessibilityGranted {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Requires Accessibility permission")
                                .font(.system(size: 11))
                            Spacer()
                            Button("Grant") {
                                SystemPermissionsHelper.requestAccessibility()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(.vertical, 2)

                // Finder Cut & Paste
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "scissors")
                            .foregroundStyle(.purple)
                        Text("Finder Cut & Paste")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Toggle("", isOn: $settings.finderCutPasteEnabled)
                            .labelsHidden()
                    }

                    Text("Enables ⌘X to cut and ⌘V to move files directly in Finder.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    if settings.finderCutPasteEnabled && !SystemPermissionsHelper.isAccessibilityGranted {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Requires Accessibility permission")
                                .font(.system(size: 11))
                            Spacer()
                            Button("Grant") {
                                SystemPermissionsHelper.requestAccessibility()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(.vertical, 2)

                // Quit on Close
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "xmark.app.fill")
                            .foregroundStyle(.red)
                        Text("Quit on Close")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Toggle("", isOn: $settings.autoQuitEnabled)
                            .labelsHidden()
                    }

                    Text("Automatically quits applications when their last window is closed.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    if settings.autoQuitEnabled && !SystemPermissionsHelper.isAccessibilityGranted {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Requires Accessibility permission")
                                .font(.system(size: 11))
                            Spacer()
                            Button("Grant") {
                                SystemPermissionsHelper.requestAccessibility()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            // MARK: - 4. Music Scrobbling
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
                                    .buttonStyle(LiquidGlassButtonStyle(tint: .accentColor, isProminent: true, cornerRadius: DesignTokens.Radius.chip))
                                    .controlSize(.small)
                                    .disabled(isConnectingLastFM)

                                    Button("Cancel") {
                                        scrobbleCoordinator.cancelLastFMBrowserAuth()
                                        isAuthorizingLastFM = false
                                        lastFMErrorMessage = nil
                                    }
                                    .buttonStyle(LiquidGlassButtonStyle(cornerRadius: DesignTokens.Radius.chip))
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
                                    .buttonStyle(LiquidGlassButtonStyle(tint: .accentColor, isProminent: true, cornerRadius: DesignTokens.Radius.chip))
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
                                            .buttonStyle(LiquidGlassButtonStyle(tint: .accentColor, isProminent: true, cornerRadius: DesignTokens.Radius.chip))
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
                    .padding(12)
                    .liquidGlassCard(cornerRadius: DesignTokens.Radius.medium)

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
                                    .buttonStyle(LiquidGlassButtonStyle(tint: .accentColor, isProminent: true, cornerRadius: DesignTokens.Radius.chip))
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
                    .padding(12)
                    .liquidGlassCard(cornerRadius: DesignTokens.Radius.medium)

                    // Privacy notice
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
        .padding(DesignTokens.Spacing.small)
        .task {
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

    private var menuBarPanelScaleBinding: Binding<Double> {
        Binding(
            get: { settings.menuBarPanelScale },
            set: { settings.menuBarPanelScale = $0 }
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
