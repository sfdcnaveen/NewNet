import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let indicatorView = MenuBarSpeedIndicator(frame: .zero)
    private let popover = NSPopover()
    private var cancellables: Set<AnyCancellable> = []
    private var deferredWidth: CGFloat?

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
        popover.contentSize = NSSize(width: 420, height: 620)
        popover.contentViewController = NSHostingController(
            rootView: DropdownPanel(
                menuBarViewModel: menuBarViewModel,
                downloadManagerViewModel: downloadManagerViewModel,
                settings: settings
            )
            .frame(width: 420, height: 620)
        )
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
        NSApp.activate(ignoringOtherApps: true)
    }

    private func applyDeferredWidthIfNeeded() {
        guard let width = deferredWidth, let button = statusItem.button else { return }
        applyWidth(width, to: button)
    }

    func popoverDidClose(_ notification: Notification) {
        applyDeferredWidthIfNeeded()
    }
}
