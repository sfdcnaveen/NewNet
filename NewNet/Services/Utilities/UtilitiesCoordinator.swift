import AppKit
import Combine
import Foundation

@MainActor
final class UtilitiesCoordinator: ObservableObject {
    let keepAwake: KeepAwakeService
    let clipboardHistory: ClipboardHistoryService
    let quitOnClose: QuitOnCloseService
    let scrollInverter: ScrollInverterService
    let finderCutPaste: FinderCutPasteService
    let settings: AppSettings

    private var cancellables: Set<AnyCancellable> = []

    init(settings: AppSettings, clipboardStorageURL: URL? = nil) {
        self.settings = settings
        self.keepAwake = KeepAwakeService()
        self.clipboardHistory = ClipboardHistoryService(storageURL: clipboardStorageURL)
        self.quitOnClose = QuitOnCloseService()
        self.scrollInverter = ScrollInverterService()
        self.finderCutPaste = FinderCutPasteService()

        bindSettings()
    }

    private func bindSettings() {
        // Keep Awake
        keepAwake.preventLidSleep = settings.keepAwakePreventDisplaySleep

        settings.$keepAwakePreventDisplaySleep
            .receive(on: DispatchQueue.main)
            .sink { [weak self] val in
                self?.keepAwake.preventLidSleep = val
            }
            .store(in: &cancellables)

        keepAwake.$preventLidSleep
            .receive(on: DispatchQueue.main)
            .sink { [weak self] val in
                if self?.settings.keepAwakePreventDisplaySleep != val {
                    self?.settings.keepAwakePreventDisplaySleep = val
                }
            }
            .store(in: &cancellables)

        // Forward objectWillChange from child services so views update automatically
        keepAwake.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        clipboardHistory.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        quitOnClose.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        scrollInverter.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        finderCutPaste.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
    }
}
