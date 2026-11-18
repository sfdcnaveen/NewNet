import AppKit
import Combine
import Foundation
import IOKit.ps
import IOKit.pwr_mgt
import os.log

@MainActor
final class KeepAwakeService: ObservableObject {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "NewNet", category: "KeepAwake")

    @Published private(set) var isActive: Bool = false
    @Published private(set) var remainingSeconds: Int? = nil
    @Published var preventLidSleep: Bool = false {
        didSet {
            if isActive {
                applyAssertions()
            } else if !preventLidSleep {
                setPmsetDisableSleep(false)
            }
        }
    }
    // Backward compatibility alias
    var preventDisplaySleep: Bool {
        get { preventLidSleep }
        set { preventLidSleep = newValue }
    }
    @Published var durationMinutes: Int = 0 { // 0 = indefinite
        didSet {
            if isActive && oldValue != durationMinutes {
                startSession(minutes: durationMinutes)
            }
        }
    }
    @Published private(set) var batteryPercentage: Int? = nil
    @Published private(set) var isCharging: Bool = true

    private var systemAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0
    private var lidAssertionID: IOPMAssertionID = 0
    private var hasSystemAssertion: Bool = false
    private var hasDisplayAssertion: Bool = false
    private var hasLidAssertion: Bool = false

    private var countdownTimer: Timer?
    private var batteryTimer: Timer?
    private var endDate: Date?

    init() {
        // Clear any orphaned sleepDisabled setting from unexpected app exit
        if UserDefaults.standard.bool(forKey: "settings.sleepDisabledFlag") {
            setPmsetDisableSleep(false)
        }

        updateBatteryStatus()
        startBatteryMonitoring()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    deinit {
        MainActor.assumeIsolated {
            releaseAssertions()
            setPmsetDisableSleep(false, synchronous: true)
            countdownTimer?.invalidate()
            batteryTimer?.invalidate()
        }
    }

    // MARK: - Public API

    func toggle(minutes: Int? = nil) {
        if isActive {
            deactivate()
        } else {
            activate(minutes: minutes ?? durationMinutes)
        }
    }

    func activate(minutes: Int = 0) {
        durationMinutes = minutes
        startSession(minutes: minutes)
    }

    func addMinutes(_ minutes: Int) {
        guard minutes > 0 else { return }
        if isActive {
            if let current = remainingSeconds {
                let updated = current + (minutes * 60)
                remainingSeconds = updated
                endDate = Date().addingTimeInterval(TimeInterval(updated))
                Self.logger.info("Extended Keep Awake by \(minutes)m. New remaining: \(self.remainingTimeFormatted)")
            } else {
                // Was indefinite, switch to timed countdown with specified minutes
                activate(minutes: minutes)
            }
        } else {
            activate(minutes: minutes)
        }
    }

    func deactivate() {
        releaseAssertions()
        isActive = false
        remainingSeconds = nil
        endDate = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        Self.logger.info("Keep Awake deactivated")
    }

    var remainingTimeFormatted: String {
        guard let seconds = remainingSeconds, seconds > 0 else {
            return "Indefinite"
        }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }

    // MARK: - Private Session Management

    private func startSession(minutes: Int) {
        applyAssertions()
        isActive = true

        countdownTimer?.invalidate()
        countdownTimer = nil

        if minutes > 0 {
            let totalSeconds = minutes * 60
            remainingSeconds = totalSeconds
            endDate = Date().addingTimeInterval(TimeInterval(totalSeconds))

            countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.tick()
                }
            }
            countdownTimer?.tolerance = 0.2
        } else {
            remainingSeconds = nil
            endDate = nil
        }

        Self.logger.info("Keep Awake activated for \(minutes == 0 ? "indefinite" : "\(minutes)m")")
    }

    private func tick() {
        guard let target = endDate else { return }
        let left = Int(target.timeIntervalSinceNow)
        if left <= 0 {
            deactivate()
        } else {
            remainingSeconds = left
        }
    }

    // MARK: - IOKit Power Assertions & Clamshell Mode

    private func applyAssertions() {
        // Prevent system idle sleep
        if !hasSystemAssertion {
            var assertionID = IOPMAssertionID(0)
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "NewNet Keep Awake: Preventing system sleep" as CFString,
                &assertionID
            )
            if result == kIOReturnSuccess {
                systemAssertionID = assertionID
                hasSystemAssertion = true
            } else {
                Self.logger.error("Failed to create system sleep assertion: \(result)")
            }
        }

        // Lid closed mode: prevents sleep even when MacBook clamshell / lid is closed
        if preventLidSleep {
            setPmsetDisableSleep(true)

            if !hasLidAssertion {
                var assertionID = IOPMAssertionID(0)
                let result = IOPMAssertionCreateWithName(
                    kIOPMAssertionTypePreventSystemSleep as CFString,
                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                    "NewNet Keep Awake: Preventing lid-close sleep" as CFString,
                    &assertionID
                )
                if result == kIOReturnSuccess {
                    lidAssertionID = assertionID
                    hasLidAssertion = true
                } else {
                    Self.logger.error("Failed to create lid-close assertion: \(result)")
                }
            }

            if !hasDisplayAssertion {
                var assertionID = IOPMAssertionID(0)
                let result = IOPMAssertionCreateWithName(
                    kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                    "NewNet Keep Awake: Preventing display sleep" as CFString,
                    &assertionID
                )
                if result == kIOReturnSuccess {
                    displayAssertionID = assertionID
                    hasDisplayAssertion = true
                } else {
                    Self.logger.error("Failed to create display sleep assertion: \(result)")
                }
            }
        } else {
            setPmsetDisableSleep(false)

            if hasLidAssertion {
                IOPMAssertionRelease(lidAssertionID)
                hasLidAssertion = false
            }
            if hasDisplayAssertion {
                IOPMAssertionRelease(displayAssertionID)
                hasDisplayAssertion = false
            }
        }
    }

    private func releaseAssertions() {
        setPmsetDisableSleep(false)

        if hasLidAssertion {
            IOPMAssertionRelease(lidAssertionID)
            hasLidAssertion = false
        }
        if hasDisplayAssertion {
            IOPMAssertionRelease(displayAssertionID)
            hasDisplayAssertion = false
        }
        if hasSystemAssertion {
            IOPMAssertionRelease(systemAssertionID)
            hasSystemAssertion = false
        }
    }

    private func setPmsetDisableSleep(_ disable: Bool, synchronous: Bool = false) {
        let flag = disable ? "1" : "0"
        UserDefaults.standard.set(disable, forKey: "settings.sleepDisabledFlag")

        let execute = {
            let sudoProcess = Process()
            sudoProcess.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
            sudoProcess.arguments = ["-n", "/usr/bin/pmset", "disablesleep", flag]
            do {
                try sudoProcess.run()
                sudoProcess.waitUntilExit()
                if sudoProcess.terminationStatus != 0 {
                    let directProcess = Process()
                    directProcess.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
                    directProcess.arguments = ["disablesleep", flag]
                    try? directProcess.run()
                    directProcess.waitUntilExit()
                }
            } catch {
                Self.logger.error("pmset disablesleep failed: \(error.localizedDescription)")
            }
        }

        if synchronous {
            execute()
        } else {
            DispatchQueue.global(qos: .userInitiated).async(execute: execute)
        }
    }

    // MARK: - Battery Protection

    private func startBatteryMonitoring() {
        batteryTimer?.invalidate()
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateBatteryStatus()
            }
        }
    }

    private func updateBatteryStatus() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return
        }

        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
            else { continue }

            if let isChargingVal = desc[kIOPSIsChargingKey as String] as? Bool {
                self.isCharging = isChargingVal
            }
            if let curCap = desc[kIOPSCurrentCapacityKey as String] as? Int,
               let maxCap = desc[kIOPSMaxCapacityKey as String] as? Int,
               maxCap > 0 {
                let percent = Int((Double(curCap) / Double(maxCap)) * 100)
                self.batteryPercentage = percent

                // Safety: if battery drops below 10% and not charging, auto-release to avoid draining
                if !self.isCharging && percent <= 10 && self.isActive {
                    Self.logger.warning("Low battery detected (\(percent)%). Deactivating Keep Awake.")
                    deactivate()
                }
            }
        }
    }

    @objc private func handleAppWillTerminate() {
        releaseAssertions()
        setPmsetDisableSleep(false, synchronous: true)
    }
}
