import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    fileprivate static let basePopoverSize = NSSize(width: 420, height: 620)

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let indicatorView = MenuBarSpeedIndicator(frame: .zero)
    private let popover = NSPopover()
    private var cancellables: Set<AnyCancellable> = []
    private var deferredWidth: CGFloat?
    private var globalMouseMonitor: Any?

    init(
        menuBarViewModel: MenuBarViewModel,
        downloadManagerViewModel: DownloadManagerViewModel,
        settings: AppSettings
    ) {
        super.init()
        configureStatusItem()
        configurePopover(
            menuBarViewModel: menuBarViewModel,
            downloadManagerViewModel: downloadManagerViewModel,
            settings: settings
        )
        bindSnapshot(menuBarViewModel)
        bindSettings(settings)
        observeDismissalEvents()
    }

    deinit {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
        NotificationCenter.default.removeObserver(self)
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.title = ""
        button.image = nil
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp])

        indicatorView.autoresizingMask = [.width, .height]
        button.addSubview(indicatorView)
        updateIndicatorFrame(for: button, width: indicatorView.preferredWidth)
    }

    private func configurePopover(
        menuBarViewModel: MenuBarViewModel,
        downloadManagerViewModel: DownloadManagerViewModel,
        settings: AppSettings
    ) {
        popover.delegate = self
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = Self.popoverSize(for: settings.menuBarPanelScale)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPanelHost(
                menuBarViewModel: menuBarViewModel,
                downloadManagerViewModel: downloadManagerViewModel,
                settings: settings
            )
        )
    }

    private func updatePopoverAppearance() {
        let match = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) ?? .aqua
        popover.appearance = NSAppearance(named: match)
    }

    private func bindSnapshot(_ menuBarViewModel: MenuBarViewModel) {
        menuBarViewModel.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                self?.apply(snapshot: snapshot)
            }
            .store(in: &cancellables)

        apply(snapshot: menuBarViewModel.snapshot)
    }

    private func bindSettings(_ settings: AppSettings) {
        settings.$menuBarPanelScale
            .receive(on: RunLoop.main)
            .sink { [weak self] scale in
                self?.updatePopoverSize(scale: scale)
            }
            .store(in: &cancellables)

        updatePopoverSize(scale: settings.menuBarPanelScale)
    }

    private func observeDismissalEvents() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closePopoverForExternalInteraction),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.closePopoverForExternalInteraction()
            }
        }
    }

    private static func popoverSize(for scale: Double) -> NSSize {
        let clampedScale = min(max(scale, 0.85), 1.25)
        return NSSize(
            width: basePopoverSize.width * clampedScale,
            height: basePopoverSize.height * clampedScale
        )
    }

    private func updatePopoverSize(scale: Double) {
        popover.contentSize = Self.popoverSize(for: scale)
    }

    private func apply(snapshot: NetworkSpeedSnapshot) {
        indicatorView.snapshot = snapshot
        let width = indicatorView.preferredWidth

        if let button = statusItem.button {
            if popover.isShown {
                deferredWidth = width
                updateIndicatorFrame(for: button, width: button.bounds.width)
                return
            }

            applyWidth(width, to: button)
        }
    }

    private func applyWidth(_ width: CGFloat, to button: NSStatusBarButton) {
        deferredWidth = nil

        if statusItem.length != width {
            statusItem.length = width
        }

        updateIndicatorFrame(for: button, width: width)
    }

    private func updateIndicatorFrame(for button: NSStatusBarButton, width: CGFloat) {
        indicatorView.frame = NSRect(
            x: 0,
            y: 0,
            width: width,
            height: button.bounds.height
        )
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
            applyDeferredWidthIfNeeded()
            return
        }

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        updatePopoverAppearance()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    private func closePopoverForExternalInteraction() {
        guard popover.isShown else { return }
        popover.performClose(nil)
        applyDeferredWidthIfNeeded()
    }

    private func applyDeferredWidthIfNeeded() {
        guard let width = deferredWidth, let button = statusItem.button else { return }
        applyWidth(width, to: button)
    }

    func popoverDidClose(_ notification: Notification) {
        applyDeferredWidthIfNeeded()
    }

}

private struct MenuBarPanelHost: View {
    @ObservedObject var settings: AppSettings
    let menuBarViewModel: MenuBarViewModel
    let downloadManagerViewModel: DownloadManagerViewModel

    init(
        menuBarViewModel: MenuBarViewModel,
        downloadManagerViewModel: DownloadManagerViewModel,
        settings: AppSettings
    ) {
        self.menuBarViewModel = menuBarViewModel
        self.downloadManagerViewModel = downloadManagerViewModel
        self.settings = settings
    }

    var body: some View {
        DropdownPanel(
            menuBarViewModel: menuBarViewModel,
            downloadManagerViewModel: downloadManagerViewModel,
            settings: settings
        )
        .frame(
            width: StatusBarController.basePopoverSize.width * settings.menuBarPanelScale,
            height: StatusBarController.basePopoverSize.height * settings.menuBarPanelScale
        )
    }
}
