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
    @Published var invertHorizontal: Bool = false
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var hasPermissionError: Bool = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        let storedEnabled = UserDefaults.standard.bool(forKey: "settings.scrollInversionEnabled")
        self.invertVertical = UserDefaults.standard.object(forKey: "settings.scrollInvertVertical") as? Bool ?? true
        self.invertHorizontal = UserDefaults.standard.bool(forKey: "settings.scrollInvertHorizontal")
        if storedEnabled {
            self.isEnabled = true
        }

        PermissionsManager.shared.$isAccessibilityGranted
            .dropFirst()
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

        // Discrete events (isContinuous == 0) indicate physical mouse wheels.
        // Continuous events (isContinuous != 0) are emitted by trackpads and Magic Mouse swipe gestures.
        let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        guard !isContinuous else {
            // Trackpad event: do not modify, keep macOS natural scrolling intact
            return Unmanaged.passUnretained(event)
        }

        // Apply vertical inversion
        if invertVertical {
            let pointDelta1 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
            event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -pointDelta1)

            let fixedDelta1 = event.getIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1)
            event.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fixedDelta1)

            let delta1 = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
            event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -delta1)
        }

        // Apply horizontal inversion
        if invertHorizontal {
            let pointDelta2 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
            event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: -pointDelta2)

            let fixedDelta2 = event.getIntegerValueField(.scrollWheelEventFixedPtDeltaAxis2)
            event.setIntegerValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -fixedDelta2)

            let delta2 = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
            event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -delta2)
        }

        return Unmanaged.passUnretained(event)
    }
}
