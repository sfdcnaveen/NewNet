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

        let momentumPhase = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        let scrollPhase = event.getIntegerValueField(.scrollWheelEventScrollPhase)

        // Detect physical mouse wheels using momentumPhase == 0 && scrollPhase == 0 instead of rejecting continuous events
        guard momentumPhase == 0 && scrollPhase == 0 else {
            return Unmanaged.passUnretained(event)
        }

        // Invert scrollWheelEventDeltaAxis1 and scrollWheelEventFixedPtDeltaAxis1 (using getDoubleValueField / setDoubleValueField)
        let delta1 = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
        let fixed1 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let point1 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)

        if delta1 != 0 || fixed1 != 0 || point1 != 0 {
            event.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: -delta1)
            event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fixed1)
            if point1 != 0 {
                event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -point1)
            }
        }

        return Unmanaged.passUnretained(event)
    }
}
