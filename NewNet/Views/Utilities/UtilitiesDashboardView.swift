import AppKit
import SwiftUI

struct UtilitiesDashboardView: View {
    @ObservedObject var coordinator: UtilitiesCoordinator
    @ObservedObject var settings: AppSettings
    var onOpenSettings: (() -> Void)?

    @ObservedObject private var keepAwake: KeepAwakeService
    @ObservedObject private var scrollInverter: ScrollInverterService
    @ObservedObject private var finderCutPaste: FinderCutPasteService
    @ObservedObject private var quitOnClose: QuitOnCloseService
    @ObservedObject private var permissionsManager = PermissionsManager.shared

    @Environment(\.colorScheme) private var colorScheme

    init(coordinator: UtilitiesCoordinator, settings: AppSettings, onOpenSettings: (() -> Void)? = nil) {
        self.coordinator = coordinator
        self.settings = settings
        self.onOpenSettings = onOpenSettings
        self._keepAwake = ObservedObject(wrappedValue: coordinator.keepAwake)
        self._scrollInverter = ObservedObject(wrappedValue: coordinator.scrollInverter)
        self._finderCutPaste = ObservedObject(wrappedValue: coordinator.finderCutPaste)
        self._quitOnClose = ObservedObject(wrappedValue: coordinator.quitOnClose)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section Header
            HStack {
                Text("macOS Utilities")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let onOpenSettings = onOpenSettings {
                    Button {
                        onOpenSettings()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .help("Utilities Settings")
                }
            }

            // Accessibility permission banner (vanishes immediately when granted)
            if !permissionsManager.isAccessibilityGranted {
                accessibilityStatusBanner
            }

            // Keep Awake Card
            keepAwakeCard

            // Mouse Scroll Inverter Card
            scrollInverterCard

            // Finder Cut & Paste Card
            finderCutPasteCard

            // Quit on Close Card
            quitOnCloseCard
        }
        .padding(.vertical, 4)
    }

    // MARK: - Accessibility Status Banner

    private var accessibilityStatusBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Accessibility Permission Required")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Enable NewNet in System Settings to use gesture, mouse, and Finder tools.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 6) {
                Button {
                    permissionsManager.requestAccessibility()
                } label: {
                    Text("Open System Settings")
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(LiquidGlassButtonStyle(cornerRadius: DesignTokens.Radius.chip))

                Button {
                    withAnimation(DesignTokens.Animation.transition) {
                        _ = permissionsManager.refresh(prompt: false)
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Check Again")
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .buttonStyle(LiquidGlassButtonStyle(cornerRadius: DesignTokens.Radius.chip))
                .help("Re-query macOS Accessibility permissions")

                Spacer()

                Button {
                    SystemPermissionsHelper.restartApplication()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 9))
                        Text("Restart NewNet")
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Restart NewNet if macOS requires a process relaunch to apply permissions")
            }
            .padding(.top, 2)
        }
        .padding(10)
        .liquidGlassCard(cornerRadius: DesignTokens.Radius.medium, tint: .orange)
    }

    // MARK: - Keep Awake Card

    private var keepAwakeCard: some View {
        let isAwake = keepAwake.isActive
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(isAwake ? Color.orange.opacity(0.18) : Color.secondary.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: isAwake ? "cup.and.saucer.fill" : "cup.and.saucer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isAwake ? Color.orange : Color.secondary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("Keep Awake")
                            .font(.system(size: 13, weight: .semibold))

                        if isAwake {
                            Text("ACTIVE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.orange))
                        }
                    }

                    Text(isAwake ? "Preventing Mac sleep (\(keepAwake.remainingTimeFormatted))" : "Mac will sleep according to system energy saver")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(DesignTokens.Animation.hover) {
                        keepAwake.toggle()
                    }
                } label: {
                    Image(systemName: isAwake ? "power" : "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isAwake ? Color.red : Color.primary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(LiquidGlassButtonStyle(tint: isAwake ? .red : nil, isCircular: true))
                .help(isAwake ? "Deactivate Keep Awake" : "Activate Keep Awake")
            }

            // Duration selector pills (additive when active countdown)
            HStack(spacing: 6) {
                let isTimed = isAwake && (keepAwake.remainingSeconds != nil)
                let durations: [(title: String, mins: Int)] = [
                    ("∞", 0),
                    (isTimed ? "+15m" : "15m", 15),
                    (isTimed ? "+30m" : "30m", 30),
                    (isTimed ? "+1h" : "1h", 60),
                    (isTimed ? "+2h" : "2h", 120)
                ]

                ForEach(durations, id: \.mins) { item in
                    let isIndefiniteActive = isAwake && keepAwake.remainingSeconds == nil && item.mins == 0
                    Button {
                        withAnimation(DesignTokens.Animation.transition) {
                            if item.mins == 0 {
                                keepAwake.activate(minutes: 0)
                            } else if isTimed {
                                keepAwake.addMinutes(item.mins)
                            } else {
                                keepAwake.activate(minutes: item.mins)
                            }
                        }
                    } label: {
                        Text(item.title)
                            .font(.system(size: 11, weight: isIndefiniteActive ? .semibold : .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .liquidGlassPill(
                                tint: isIndefiniteActive ? Color.orange : nil,
                                isActive: isIndefiniteActive
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Lid closed sleep toggle
                Toggle(isOn: $keepAwake.preventLidSleep) {
                    Text("Lid Closed?")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .toggleStyle(.checkbox)
                .help("Prevents Mac sleep even when the MacBook lid is closed")
            }

            if let battery = keepAwake.batteryPercentage {
                HStack(spacing: 4) {
                    Image(systemName: keepAwake.isCharging ? "bolt.batteryblock.fill" : "battery.75")
                        .font(.system(size: 9))
                    Text("\(battery)% Battery\(keepAwake.isCharging ? " · Charging" : "")")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .liquidGlassCard()
    }

    // MARK: - Scroll Inverter Card

    private var scrollInverterCard: some View {
        let isRunning = scrollInverter.isRunning
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(isRunning ? Color.blue.opacity(0.18) : Color.secondary.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "computermouse")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isRunning ? Color.blue : Color.secondary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("Inverse Mouse Scrolling")
                            .font(.system(size: 13, weight: .semibold))

                        if isRunning {
                            Text("ON")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.blue))
                        }
                    }

                    Text("Inverts mouse wheel direction; trackpad natural scrolling is preserved")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $scrollInverter.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            if (scrollInverter.hasPermissionError || !permissionsManager.isAccessibilityGranted) && scrollInverter.isEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text("Accessibility permission required")
                        .font(.system(size: 11))
                    Spacer()
                    Button("Grant") {
                        permissionsManager.requestAccessibility()
                    }
                    .buttonStyle(LiquidGlassButtonStyle())
                }
                .padding(.top, 4)
            } else if scrollInverter.isEnabled {
                HStack(spacing: 12) {
                    Toggle(isOn: $scrollInverter.invertVertical) {
                        Text("Vertical")
                            .font(.system(size: 11))
                    }
                    .toggleStyle(.checkbox)

                    Toggle(isOn: $scrollInverter.invertHorizontal) {
                        Text("Horizontal")
                            .font(.system(size: 11))
                    }
                    .toggleStyle(.checkbox)
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .liquidGlassCard()
    }

    // MARK: - Finder Cut & Paste Card

    private var finderCutPasteCard: some View {
        let isRunning = finderCutPaste.isRunning
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(isRunning ? Color.purple.opacity(0.18) : Color.secondary.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "scissors")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isRunning ? Color.purple : Color.secondary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("Finder Cut & Paste")
                            .font(.system(size: 13, weight: .semibold))

                        if isRunning {
                            Text("ON")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.purple))
                        }
                    }

                    Text("Enables ⌘X to cut and ⌘V to move files directly in Finder")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $finderCutPaste.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            if !finderCutPaste.markedURLs.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 11))
                        .foregroundStyle(.purple)
                    Text("\(finderCutPaste.markedURLs.count) item(s) marked for move in Finder")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                }
                .padding(.top, 2)
            }

            if (finderCutPaste.hasPermissionError || !permissionsManager.isAccessibilityGranted) && finderCutPaste.isEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text("Accessibility permission required")
                        .font(.system(size: 11))
                    Spacer()
                    Button("Grant") {
                        permissionsManager.requestAccessibility()
                    }
                    .buttonStyle(LiquidGlassButtonStyle())
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .liquidGlassCard()
    }

    // MARK: - Quit on Close Card

    private var quitOnCloseCard: some View {
        let isEnabled = quitOnClose.isEnabled
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(isEnabled ? Color.red.opacity(0.18) : Color.secondary.opacity(0.12))
                        .frame(width: 28, height: 28)
                    Image(systemName: "xmark.app")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isEnabled ? Color.red : Color.secondary)
                }

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("Quit on Close")
                            .font(.system(size: 13, weight: .semibold))

                        if isEnabled {
                            Text("ON")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.red))
                        }
                    }

                    Text("Terminates macOS apps when their last window is closed")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $quitOnClose.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            if (quitOnClose.hasPermissionError || !permissionsManager.isAccessibilityGranted) && isEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text("Accessibility permission required")
                        .font(.system(size: 11))
                    Spacer()
                    Button("Grant") {
                        permissionsManager.requestAccessibility()
                    }
                    .buttonStyle(LiquidGlassButtonStyle())
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .liquidGlassCard()
    }
}
