import AppKit
import Combine
import CoreGraphics
import Foundation
import os.log

@MainActor
final class ScrollInverterService: ObservableObject {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "NewNet", category: "ScrollInverter")

    @Published var isEnabled: Bool = false {
        didSet {
            if isEnabled {
                start()
            } else {
                stop()
            }
        }
    }
    @Published var invertVertical: Bool = true
    @Published var invertHorizontal: Bool = true
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var hasPermissionError: Bool = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var cancellables: Set<AnyCancellable> = []
    private var lastGesturePhaseTimestamp: UInt64 = 0

    init() {
        let storedEnabled = UserDefaults.standard.bool(forKey: "settings.scrollInversionEnabled")
        self.invertVertical = UserDefaults.standard.object(forKey: "settings.scrollInvertVertical") as? Bool ?? true
        self.invertHorizontal = UserDefaults.standard.object(forKey: "settings.scrollInvertHorizontal") as? Bool ?? true
        if storedEnabled {
            self.isEnabled = true
        }

        PermissionsManager.shared.$isAccessibilityGranted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] granted in
                guard let self = self else { return }
                if granted {
                    if self.hasPermissionError {
                        self.hasPermissionError = false
                    }
                    if self.isEnabled && !self.isRunning {
                        self.start()
                    }
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        MainActor.assumeIsolated {
            stop()
        }
    }

    func toggle() {
        isEnabled.toggle()
        UserDefaults.standard.set(isEnabled, forKey: "settings.scrollInversionEnabled")
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }

        guard SystemPermissionsHelper.isAccessibilityGranted else {
            hasPermissionError = true
            Self.logger.warning("Accessibility permission is missing for Scroll Inverter")
            return
        }
        hasPermissionError = false

        let eventMask = (1 << CGEventType.scrollWheel.rawValue)

        let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let service = Unmanaged<ScrollInverterService>.fromOpaque(refcon).takeUnretainedValue()
                return service.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: observer
        ) else {
            hasPermissionError = true
            Self.logger.error("Failed to create CGEvent tap for scroll wheel")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)

        self.eventTap = tap
        self.runLoopSource = source
        self.isRunning = true
        CGEvent.tapEnable(tap: tap, enable: true)

        Self.logger.info("Scroll Inverter event tap successfully installed")
    }

    func stop() {
        guard isRunning else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            self.runLoopSource = nil
        }
        self.eventTap = nil
        self.isRunning = false

        Self.logger.info("Scroll Inverter event tap removed")
    }

    // MARK: - Event Tap Callback

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .scrollWheel else {
            return Unmanaged.passUnretained(event)
        }

        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        let momentumPhase = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        let scrollPhase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
        let scrollCount = event.getIntegerValueField(.scrollWheelEventScrollCount)

        let now = mach_absolute_time()

        // Phased gestures (trackpad or Magic Mouse swipe) always carry momentum or scroll phase
        if momentumPhase != 0 || scrollPhase != 0 {
            lastGesturePhaseTimestamp = now
            return Unmanaged.passUnretained(event)
        }

        // Touch devices can emit a phaseless transition event between gesture end and momentum start
        // that still carries scrollCount. Physical mouse wheels never emit gesture phases.
        if isContinuous && scrollCount != 0 {
            var timebase = mach_timebase_info_data_t()
            mach_timebase_info(&timebase)
            let elapsedNanos = (now - lastGesturePhaseTimestamp) * UInt64(timebase.numer) / UInt64(timebase.denom)
            let elapsedSeconds = Double(elapsedNanos) / 1_000_000_000.0
            if elapsedSeconds <= 0.35 {
                return Unmanaged.passUnretained(event)
            }
        }

        // Physical mouse wheel detected: Apply vertical inversion
        if invertVertical {
            let line1 = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
            let point1 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
            let fixed1 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)

            if line1 != 0 || point1 != 0 || fixed1 != 0 {
                event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -line1)
                event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -point1)
                event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fixed1)
            }
        }

        // Apply horizontal inversion
        if invertHorizontal {
            let line2 = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
            let point2 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
            let fixed2 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)

            if line2 != 0 || point2 != 0 || fixed2 != 0 {
                event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -line2)
                event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: -point2)
                event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -fixed2)
            }
        }

        return Unmanaged.passUnretained(event)
    }
}
