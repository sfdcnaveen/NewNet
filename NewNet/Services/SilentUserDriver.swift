import Foundation
import Sparkle

class SilentUserDriver: NSObject, SPUUserDriver {
    var onUpdateFound: ((SUAppcastItem, @escaping (SPUUserUpdateChoice) -> Void) -> Void)?
    var onDownloadProgress: ((Double) -> Void)?
    var onReadyToInstall: ((@escaping (SPUUserUpdateChoice) -> Void) -> Void)?
    var onError: ((Error) -> Void)?

    private var expectedLength: UInt64 = 0
    private var receivedLength: UInt64 = 0

    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {}

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        if let onUpdateFound = onUpdateFound {
            onUpdateFound(appcastItem, reply)
        } else {
            reply(.install)
        }
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}
    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {}
    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) { acknowledgement() }
    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        onError?(error)
        acknowledgement()
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        expectedLength = 0
        receivedLength = 0
        onDownloadProgress?(0.0)
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        self.expectedLength = expectedContentLength
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        receivedLength += length
        if expectedLength > 0 {
            let progress = Double(receivedLength) / Double(expectedLength)
            onDownloadProgress?(progress)
        }
    }

    func showDownloadDidStartExtractingUpdate() {
        onDownloadProgress?(1.0)
    }

    func showExtractionReceivedProgress(_ progress: Double) {}

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        if let onReadyToInstall = onReadyToInstall {
            onReadyToInstall(reply)
        } else {
            reply(.install)
        }
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {}
    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) { acknowledgement() }
    func showUpdateInFocus() {}
    func dismissUpdateInstallation() {}
}
