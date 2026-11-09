import Foundation
import Combine
import AppKit

@MainActor
final class ScrobbleCoordinator: ObservableObject {
    @Published private(set) var currentTrack: TrackMetadata?
    @Published private(set) var playbackState: PlaybackState = .stopped
    @Published private(set) var submissionStatus: ScrobbleSubmissionStatus = .idle
    @Published private(set) var scrobbleHistory: [ScrobbleHistoryItem] = []

    @Published private(set) var lastFMStatus: ProviderConnectionStatus = .disconnected
    @Published private(set) var listenBrainzStatus: ProviderConnectionStatus = .disconnected

    private let settings: AppSettings
    private let detectionService: MusicDetectionServiceProtocol
    private let lastFMService: LastFMServiceProtocol
    private let listenBrainzService: ListenBrainzServiceProtocol
    private let keychain: KeychainManager

    private var pollTimer: Timer?
    private var hasScrobbledCurrentTrack = false
    private var hasAttemptedScrobble = false
    private var pendingLastFMAuth: (apiKey: String, apiSecret: String, token: String)?
    private var accumulatedPlayTime: TimeInterval = 0
    private var trackStartedAt: Date?
    private var lastPollDate: Date?
    private var lastObservedPosition: TimeInterval = 0
    private var hasSubmittedNowPlaying = false

    // Keychain keys
    static let keyLastFMSessionKey = "scrobble.lastfm.sessionKey"
    static let keyLastFMUsername = "scrobble.lastfm.username"
    static let keyLastFMAPIKey = "scrobble.lastfm.apiKey"
    static let keyLastFMAPISecret = "scrobble.lastfm.apiSecret"
    static let keyListenBrainzToken = "scrobble.listenbrainz.token"
    static let keyListenBrainzUsername = "scrobble.listenbrainz.username"

    // Default API keys for Last.fm (user can also provide their own in Settings)
    static let defaultLastFMAPIKey = "b25b959554ed76058ac220b7b2e0a026"
    static let defaultLastFMAPISecret = "425b557753ec22a97e90c763fb7a02b0"

    init(
        settings: AppSettings,
        detectionService: MusicDetectionServiceProtocol? = nil,
        lastFMService: LastFMServiceProtocol = LastFMService.shared,
        listenBrainzService: ListenBrainzServiceProtocol = ListenBrainzService.shared,
        keychain: KeychainManager = .shared
    ) {
        self.settings = settings
        self.detectionService = detectionService ?? MusicDetectionService()
        self.lastFMService = lastFMService
        self.listenBrainzService = listenBrainzService
        self.keychain = keychain

        restoreProviderSessions()
        let isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTestCase") != nil
        if !isTesting {
            startPolling()
        }
    }

    deinit {
        MainActor.assumeIsolated {
            pollTimer?.invalidate()
        }
    }

    func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.pollPlayback()
            }
        }
    }

    func pollPlayback() async {
        let result = await detectionService.detectCurrentPlayback()
        handleDetectionResult(result)
    }

    private func handleDetectionResult(_ result: DetectionResult) {
        let now = Date()
        defer { lastPollDate = now }

        guard let detectedTrack = result.track else {
            if currentTrack != nil {
                currentTrack = nil
                playbackState = .stopped
                submissionStatus = .idle
                resetTrackSession()
            }
            return
        }

        let isSameTrack = detectedTrack.isSameTrack(as: currentTrack)
        if !isSameTrack {
            // New track detected
            currentTrack = detectedTrack
            playbackState = result.state
            resetTrackSession()
            trackStartedAt = now
            lastObservedPosition = result.state.position

            if result.state.isPlaying {
                submissionStatus = .detected
                submitNowPlaying(for: detectedTrack)
            } else {
                submissionStatus = .idle
            }
            return
        }

        // Same track continuing
        currentTrack = detectedTrack
        playbackState = result.state

        let currentPos = result.state.position

        // Handle loop / replay of the same track
        if currentPos < 5.0 && lastObservedPosition > 20.0 {
            hasScrobbledCurrentTrack = false
            hasAttemptedScrobble = false
            accumulatedPlayTime = currentPos
            trackStartedAt = now
        }

        guard result.state.isPlaying else {
            // Paused
            lastObservedPosition = currentPos
            return
        }

        if !hasSubmittedNowPlaying {
            submitNowPlaying(for: detectedTrack)
        }

        // Calculate delta playback
        let posDelta = currentPos - lastObservedPosition
        let timeDelta = lastPollDate != nil ? now.timeIntervalSince(lastPollDate!) : 2.0

        if posDelta > 0 {
            accumulatedPlayTime += posDelta
        } else if timeDelta > 0 && timeDelta < 5.0 {
            accumulatedPlayTime += timeDelta
        }
        lastObservedPosition = currentPos

        // Check eligibility: track scrobbles after 30 seconds of playback
        let duration = detectedTrack.duration
        let minDuration: TimeInterval = 30.0
        let threshold: TimeInterval = min(30.0, max(duration, 30.0))

        if duration < minDuration {
            submissionStatus = .idle
            return
        }

        if hasScrobbledCurrentTrack {
            submissionStatus = .scrobbled
        } else if hasAttemptedScrobble {
            // Scrobble was already attempted for this play session; prevent repeating failed submissions every poll
        } else {
            let effectivePlayTime = max(accumulatedPlayTime, currentPos)
            let remaining = max(0, threshold - effectivePlayTime)
            if remaining > 0 {
                submissionStatus = .waitingForEligibility(remainingSeconds: remaining)
            } else {
                // Eligible to scrobble!
                hasAttemptedScrobble = true
                scrobbleTrack(detectedTrack, at: trackStartedAt ?? now.addingTimeInterval(-effectivePlayTime))
            }
        }
    }

    private func resetTrackSession() {
        hasScrobbledCurrentTrack = false
        hasAttemptedScrobble = false
        hasSubmittedNowPlaying = false
        accumulatedPlayTime = 0
        lastObservedPosition = 0
    }

    private func submitNowPlaying(for track: TrackMetadata) {
        hasSubmittedNowPlaying = true

        if settings.isLastFMEnabled, case .connected = lastFMStatus {
            let apiKey = getEffectiveLastFMAPIKey()
            let apiSecret = getEffectiveLastFMAPISecret()
            if let sk = keychain.get(key: Self.keyLastFMSessionKey) {
                Task {
                    do {
                        try await lastFMService.updateNowPlaying(
                            track: track,
                            apiKey: apiKey,
                            apiSecret: apiSecret,
                            sessionKey: sk
                        )
                    } catch {
                        // Non-fatal, now-playing is best-effort
                    }
                }
            }
        }

        if settings.isListenBrainzEnabled, case .connected = listenBrainzStatus {
            if let token = keychain.get(key: Self.keyListenBrainzToken) {
                Task {
                    do {
                        try await listenBrainzService.updateNowPlaying(track: track, token: token)
                    } catch {
                        // Non-fatal, now-playing is best-effort
                    }
                }
            }
        }
    }

    private func scrobbleTrack(_ track: TrackMetadata, at timestamp: Date) {
        let lastFMActive = settings.isLastFMEnabled && lastFMStatus.isConnected
        let listenBrainzActive = settings.isListenBrainzEnabled && listenBrainzStatus.isConnected

        guard lastFMActive || listenBrainzActive else {
            return
        }

        // Clamp timestamp to safely be in the past (never in the future)
        let scrobbleDate = min(timestamp, Date().addingTimeInterval(-20))

        Task {
            var lastFMResult: ProviderScrobbleResult?
            var listenBrainzResult: ProviderScrobbleResult?

            if lastFMActive {
                let apiKey = getEffectiveLastFMAPIKey()
                let apiSecret = getEffectiveLastFMAPISecret()
                if let sk = keychain.get(key: Self.keyLastFMSessionKey) {
                    do {
                        try await lastFMService.scrobble(
                            track: track,
                            timestamp: scrobbleDate,
                            apiKey: apiKey,
                            apiSecret: apiSecret,
                            sessionKey: sk
                        )
                        lastFMResult = ProviderScrobbleResult(success: true, message: nil)
                    } catch {
                        lastFMResult = ProviderScrobbleResult(success: false, message: error.localizedDescription)
                    }
                }
            }

            if listenBrainzActive {
                if let token = keychain.get(key: Self.keyListenBrainzToken) {
                    do {
                        try await listenBrainzService.scrobble(
                            track: track,
                            timestamp: scrobbleDate,
                            token: token
                        )
                        listenBrainzResult = ProviderScrobbleResult(success: true, message: nil)
                    } catch {
                        listenBrainzResult = ProviderScrobbleResult(success: false, message: error.localizedDescription)
                    }
                }
            }

            let historyItem = ScrobbleHistoryItem(
                timestamp: scrobbleDate,
                track: track,
                lastFMResult: lastFMResult,
                listenBrainzResult: listenBrainzResult
            )

            await MainActor.run {
                if let existingIndex = self.scrobbleHistory.firstIndex(where: { $0.track.isSameTrack(as: track) }) {
                    self.scrobbleHistory[existingIndex] = historyItem
                } else {
                    self.scrobbleHistory.insert(historyItem, at: 0)
                }

                if self.scrobbleHistory.count > 50 {
                    self.scrobbleHistory.removeLast()
                }

                // Check overall status
                let hasFailure = (lastFMResult?.success == false) || (listenBrainzResult?.success == false)
                let hasSuccess = (lastFMResult?.success == true) || (listenBrainzResult?.success == true)

                if hasSuccess {
                    self.hasScrobbledCurrentTrack = true
                    self.submissionStatus = .scrobbled
                } else if hasFailure {
                    self.hasScrobbledCurrentTrack = false
                    let errMsg = lastFMResult?.message ?? listenBrainzResult?.message ?? "Submission failed"
                    self.submissionStatus = .failed(reason: errMsg)
                }
            }
        }
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        let player = currentTrack?.player
        Task {
            await detectionService.togglePlayPause(player: player)
            try? await Task.sleep(nanoseconds: 300_000_000)
            await pollPlayback()
        }
    }

    func nextTrack() {
        let player = currentTrack?.player
        Task {
            await detectionService.nextTrack(player: player)
            try? await Task.sleep(nanoseconds: 400_000_000)
            await pollPlayback()
        }
    }

    func previousTrack() {
        let player = currentTrack?.player
        Task {
            await detectionService.previousTrack(player: player)
            try? await Task.sleep(nanoseconds: 400_000_000)
            await pollPlayback()
        }
    }

    // MARK: - Last.fm Browser Authorization

    func startLastFMBrowserAuth(apiKey: String, apiSecret: String) async throws -> URL {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = apiSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty, !trimmedSecret.isEmpty else {
            throw LastFMError.apiError(code: 0, message: "API Key and Shared Secret are required.")
        }

        let token = try await lastFMService.generateAuthToken(apiKey: trimmedKey)
        guard let authURL = URL(string: "https://www.last.fm/api/auth/?api_key=\(trimmedKey)&token=\(token)") else {
            throw LastFMError.invalidURL
        }

        pendingLastFMAuth = (apiKey: trimmedKey, apiSecret: trimmedSecret, token: token)
        return authURL
    }

    func completeLastFMBrowserAuth() async throws -> String {
        guard let pending = pendingLastFMAuth else {
            throw LastFMError.noSession
        }

        lastFMStatus = .connecting
        do {
            let session = try await lastFMService.createSession(
                apiKey: pending.apiKey,
                apiSecret: pending.apiSecret,
                token: pending.token
            )
            connectLastFMWithSession(
                username: session.username,
                sessionKey: session.sessionKey,
                apiKey: pending.apiKey,
                apiSecret: pending.apiSecret
            )
            pendingLastFMAuth = nil
            return session.username
        } catch {
            lastFMStatus = .error(message: error.localizedDescription)
            throw error
        }
    }

    func cancelLastFMBrowserAuth() {
        pendingLastFMAuth = nil
        restoreProviderSessions()
    }

    // MARK: - Last.fm Account Management

    func connectLastFMWithSession(username: String, sessionKey: String, apiKey: String? = nil, apiSecret: String? = nil) {
        keychain.save(key: Self.keyLastFMUsername, value: username)
        keychain.save(key: Self.keyLastFMSessionKey, value: sessionKey)
        if let apiKey = apiKey, !apiKey.isEmpty {
            keychain.save(key: Self.keyLastFMAPIKey, value: apiKey)
        }
        if let apiSecret = apiSecret, !apiSecret.isEmpty {
            keychain.save(key: Self.keyLastFMAPISecret, value: apiSecret)
        }

        settings.lastFMUsername = username
        settings.isLastFMEnabled = true
        lastFMStatus = .connected(username: username)
    }

    func disconnectLastFM() {
        keychain.delete(key: Self.keyLastFMUsername)
        keychain.delete(key: Self.keyLastFMSessionKey)
        keychain.delete(key: Self.keyLastFMAPIKey)
        keychain.delete(key: Self.keyLastFMAPISecret)

        settings.lastFMUsername = ""
        settings.isLastFMEnabled = false
        lastFMStatus = .disconnected
    }

    func getSavedLastFMAPIKey() -> String? {
        return keychain.get(key: Self.keyLastFMAPIKey)
    }

    func getSavedLastFMAPISecret() -> String? {
        return keychain.get(key: Self.keyLastFMAPISecret)
    }

    func getEffectiveLastFMAPIKey() -> String {
        return keychain.get(key: Self.keyLastFMAPIKey) ?? Self.defaultLastFMAPIKey
    }

    func getEffectiveLastFMAPISecret() -> String {
        return keychain.get(key: Self.keyLastFMAPISecret) ?? Self.defaultLastFMAPISecret
    }

    // MARK: - ListenBrainz Account Management

    func connectListenBrainz(token: String) async throws -> String {
        listenBrainzStatus = .connecting
        do {
            let (_, username) = try await listenBrainzService.validateToken(token)
            keychain.save(key: Self.keyListenBrainzToken, value: token)
            keychain.save(key: Self.keyListenBrainzUsername, value: username)

            settings.listenBrainzUsername = username
            settings.isListenBrainzEnabled = true
            listenBrainzStatus = .connected(username: username)
            return username
        } catch {
            listenBrainzStatus = .error(message: error.localizedDescription)
            throw error
        }
    }

    func disconnectListenBrainz() {
        keychain.delete(key: Self.keyListenBrainzToken)
        keychain.delete(key: Self.keyListenBrainzUsername)

        settings.listenBrainzUsername = ""
        settings.isListenBrainzEnabled = false
        listenBrainzStatus = .disconnected
    }

    // MARK: - Persistence Restoration

    private func restoreProviderSessions() {
        if let username = keychain.get(key: Self.keyLastFMUsername),
           let sk = keychain.get(key: Self.keyLastFMSessionKey),
           !username.isEmpty, !sk.isEmpty {
            lastFMStatus = .connected(username: username)
            settings.lastFMUsername = username
        } else {
            lastFMStatus = .disconnected
        }

        if let username = keychain.get(key: Self.keyListenBrainzUsername),
           let token = keychain.get(key: Self.keyListenBrainzToken),
           !username.isEmpty, !token.isEmpty {
            listenBrainzStatus = .connected(username: username)
            settings.listenBrainzUsername = username
        } else {
            listenBrainzStatus = .disconnected
        }
    }
}
