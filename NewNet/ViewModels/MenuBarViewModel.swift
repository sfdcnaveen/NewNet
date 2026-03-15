import Combine
import Foundation

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var snapshot: NetworkSpeedSnapshot = .zero
    @Published private(set) var usage: NetworkUsage = .zero
    @Published private(set) var clipboardURL: URL?

    private let clipboardMonitor: ClipboardMonitor
    private var cancellables: Set<AnyCancellable> = []

    init(networkMonitor: NetworkSpeedMonitor, clipboardMonitor: ClipboardMonitor) {
        self.clipboardMonitor = clipboardMonitor

        networkMonitor.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.snapshot = $0 }
            .store(in: &cancellables)

        networkMonitor.$usage
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.usage = $0 }
            .store(in: &cancellables)

        clipboardMonitor.$detectedURL
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.clipboardURL = $0 }
            .store(in: &cancellables)
    }

    func dismissClipboardSuggestion() {
        clipboardMonitor.dismissSuggestion()
    }
}
