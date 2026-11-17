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

    init(settings: AppSettings) {
        self.settings = settings
        self.keepAwake = KeepAwakeService()
        self.clipboardHistory = ClipboardHistoryService()
        self.quitOnClose = QuitOnCloseService()
        self.scrollInverter = ScrollInverterService()
        self.finderCutPaste = FinderCutPasteService()

        bindSettings()
    }

    private func bindSettings() {
        // Keep Awake
        keepAwake.preventDisplaySleep = settings.keepAwakePreventDisplaySleep

        // Forward objectWillChange from child services so views update automatically
        keepAwake.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        clipboardHistory.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        quitOnClose.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        scrollInverter.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        finderCutPaste.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
    }
}
