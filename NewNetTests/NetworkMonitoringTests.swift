import XCTest
import CryptoKit
@testable import NewNet

@MainActor
final class NetworkMonitoringTests: XCTestCase {
    func testNetworkProcessParserKeepsCommaInProcessName() {
        let output = "time,,bytes_in,bytes_out,\n12:00:00,Codex (Aperitif,123.456,1000,200,\n"
        let samples = NetworkSpeedMonitor.parseProcessOutput(output)

        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples.first?.name, "Codex (Aperitif,123")
        XCTAssertEqual(samples.first?.downloadBytesPerSecond, 1000)
        XCTAssertEqual(samples.first?.uploadBytesPerSecond, 200)
    }

    func testNetworkProcessUsageTotal() {
        let usage = NetworkProcessUsage(id: 1, name: "Test", downloadBytesPerSecond: 10, uploadBytesPerSecond: 5)
        XCTAssertEqual(usage.totalBytesPerSecond, 15)
    }
}

@MainActor
final class TabOrderAndNavigationTests: XCTestCase {
    private var testDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "test.newnet.tabs.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() async throws {
        testDefaults.removePersistentDomain(forName: suiteName)
        try await super.tearDown()
    }

    func testDefaultTabOrder() {
        let settings = AppSettings(defaults: testDefaults)
        XCTAssertEqual(settings.tabOrder, [.network, .ytdlp, .music, .clipboard, .utilities])
    }

    func testReorderTabs() {
        let settings = AppSettings(defaults: testDefaults)
        settings.tabOrder = [.music, .network, .ytdlp, .clipboard, .utilities]
        XCTAssertEqual(settings.tabOrder, [.music, .network, .ytdlp, .clipboard, .utilities])

        // Verify persistence across new instance
        let reloaded = AppSettings(defaults: testDefaults)
        XCTAssertEqual(reloaded.tabOrder, [.music, .network, .ytdlp, .clipboard, .utilities])
    }

    func testRestoreDefaultTabOrder() {
        let settings = AppSettings(defaults: testDefaults)
        settings.tabOrder = [.ytdlp, .music, .network, .clipboard, .utilities]
        XCTAssertEqual(settings.tabOrder, [.ytdlp, .music, .network, .clipboard, .utilities])

        settings.restoreDefaultTabOrder()
        XCTAssertEqual(settings.tabOrder, [.network, .ytdlp, .music, .clipboard, .utilities])
    }

    func testTabOrderDeduplicationAndFallback() {
        // Storing invalid/partial tab list in UserDefaults
        testDefaults.set(["music", "invalid_tab", "music"], forKey: "settings.tabOrder")
        let settings = AppSettings(defaults: testDefaults)

        // Missing default tabs should be appended automatically without duplicates
        XCTAssertEqual(settings.tabOrder, [.music, .network, .ytdlp, .clipboard, .utilities])
    }

    func testTabVisibilityToggleAndPersistence() {
        let settings = AppSettings(defaults: testDefaults)
        XCTAssertTrue(settings.isTabVisible(.music))
        XCTAssertEqual(settings.visibleTabs.count, 5)

        // Hide .music
        settings.toggleTabVisibility(.music)
        XCTAssertFalse(settings.isTabVisible(.music))
        XCTAssertEqual(settings.visibleTabs, [.network, .ytdlp, .clipboard, .utilities])

        // Verify persistence across new instance
        let reloaded = AppSettings(defaults: testDefaults)
        XCTAssertFalse(reloaded.isTabVisible(.music))
        XCTAssertEqual(reloaded.visibleTabs, [.network, .ytdlp, .clipboard, .utilities])

        // Unhide .music
        reloaded.toggleTabVisibility(.music)
        XCTAssertTrue(reloaded.isTabVisible(.music))
        XCTAssertEqual(reloaded.visibleTabs, [.network, .ytdlp, .music, .clipboard, .utilities])
    }

    func testCannotHideAllTabs() {
        let settings = AppSettings(defaults: testDefaults)
        // Hide 4 tabs
        settings.toggleTabVisibility(.network)
        settings.toggleTabVisibility(.ytdlp)
        settings.toggleTabVisibility(.music)
        settings.toggleTabVisibility(.clipboard)
        XCTAssertEqual(settings.visibleTabs, [.utilities])

        // Attempting to hide the last visible tab should be blocked
        settings.toggleTabVisibility(.utilities)
        XCTAssertEqual(settings.visibleTabs, [.utilities])
        XCTAssertTrue(settings.isTabVisible(.utilities))
    }

    func testRestoreDefaultOrderUnhidesAllTabs() {
        let settings = AppSettings(defaults: testDefaults)
        settings.tabOrder = [.utilities, .clipboard, .music, .ytdlp, .network]
        settings.toggleTabVisibility(.music)
        settings.toggleTabVisibility(.ytdlp)
        XCTAssertEqual(settings.visibleTabs, [.utilities, .clipboard, .network])

        settings.restoreDefaultTabOrder()
        XCTAssertEqual(settings.tabOrder, [.network, .ytdlp, .music, .clipboard, .utilities])
        XCTAssertEqual(settings.visibleTabs, [.network, .ytdlp, .music, .clipboard, .utilities])
        XCTAssertTrue(settings.isTabVisible(.music))
        XCTAssertTrue(settings.isTabVisible(.ytdlp))
    }
}

@MainActor
final class KeychainManagerTests: XCTestCase {
    private let testService = "com.newnet.test.\(UUID().uuidString)"
    private var keychain: KeychainManager!

    override func setUp() async throws {
        try await super.setUp()
        keychain = KeychainManager(service: testService)
    }

    override func tearDown() async throws {
        keychain.delete(key: "test_key")
        try await super.tearDown()
    }

    func testSaveAndRetrieveCredential() {
        let saved = keychain.save(key: "test_key", value: "secret_token_123")
        XCTAssertTrue(saved)

        let retrieved = keychain.get(key: "test_key")
        XCTAssertEqual(retrieved, "secret_token_123")
    }

    func testDeleteCredential() {
        keychain.save(key: "test_key", value: "secret_to_delete")
        let deleted = keychain.delete(key: "test_key")
        XCTAssertTrue(deleted)

        let retrieved = keychain.get(key: "test_key")
        XCTAssertNil(retrieved)
    }

    func testOverwriteCredential() {
        keychain.save(key: "test_key", value: "old_value")
        keychain.save(key: "test_key", value: "new_value")

        let retrieved = keychain.get(key: "test_key")
        XCTAssertEqual(retrieved, "new_value")
    }
}

@MainActor
final class LastFMServiceTests: XCTestCase {
    func testCalculateSignature() {
        // Last.fm signature: sorted alphabetically, concatenated, append secret, md5
        let params: [String: String] = [
            "method": "auth.getSession",
            "api_key": "my_api_key",
            "token": "my_token",
            "format": "json" // Must be excluded from signature
        ]
        let secret = "my_secret"

        let sig = LastFMService.calculateSignature(parameters: params, secret: secret)

        // Expected concatenation: "api_keymy_api_keymethodauth.getSessiontokenmy_tokenmy_secret"
        let expectedString = "api_keymy_api_keymethodauth.getSessiontokenmy_tokenmy_secret"
        let expectedDigest = Insecure.MD5.hash(data: Data(expectedString.utf8))
        let expectedSig = expectedDigest.map { String(format: "%02x", $0) }.joined()

        XCTAssertEqual(sig, expectedSig)
    }

    func testSignatureExcludesFormatAndCallback() {
        let params: [String: String] = [
            "track": "Song",
            "artist": "Artist",
            "format": "json",
            "callback": "cb"
        ]
        let secret = "sec"
        let sig = LastFMService.calculateSignature(parameters: params, secret: secret)

        let expectedString = "artistArtisttrackSongsec"
        let expectedDigest = Insecure.MD5.hash(data: Data(expectedString.utf8))
        let expectedSig = expectedDigest.map { String(format: "%02x", $0) }.joined()

        XCTAssertEqual(sig, expectedSig)
    }
}

@MainActor
final class ListenBrainzServiceTests: XCTestCase {
    func testEmptyTokenThrows() async {
        let service = ListenBrainzService()
        do {
            _ = try await service.validateToken("   ")
            XCTFail("Should have thrown ListenBrainzError.emptyToken")
        } catch let error as ListenBrainzError {
            XCTAssertEqual(error, .emptyToken)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Mocks for Scrobble Coordinator Testing

@MainActor
private final class MockMusicDetection: MusicDetectionServiceProtocol {
    var stubbedResult: DetectionResult = DetectionResult(track: nil, state: .stopped, player: .appleMusic)
    var togglePlayPauseCount = 0
    var nextTrackCount = 0
    var previousTrackCount = 0

    func detectCurrentPlayback() async -> DetectionResult {
        return stubbedResult
    }

    func togglePlayPause(player: MusicPlayerApp?) async {
        togglePlayPauseCount += 1
    }

    func nextTrack(player: MusicPlayerApp?) async {
        nextTrackCount += 1
    }

    func previousTrack(player: MusicPlayerApp?) async {
        previousTrackCount += 1
    }
}

private final class MockLastFM: LastFMServiceProtocol, @unchecked Sendable {
    var nowPlayingCallCount = 0
    var scrobbleCallCount = 0
    var lastScrobbledTrack: TrackMetadata?
    var shouldFail = false

    func generateAuthToken(apiKey: String) async throws -> String {
        return "mock_token"
    }

    func createSession(apiKey: String, apiSecret: String, token: String) async throws -> (username: String, sessionKey: String) {
        return ("mock_user", "mock_session_key")
    }

    func updateNowPlaying(track: TrackMetadata, apiKey: String, apiSecret: String, sessionKey: String) async throws {
        nowPlayingCallCount += 1
    }

    func scrobble(track: TrackMetadata, timestamp: Date, apiKey: String, apiSecret: String, sessionKey: String) async throws {
        if shouldFail {
            throw LastFMError.serverError("Simulated failure")
        }
        scrobbleCallCount += 1
        lastScrobbledTrack = track
    }
}

private final class MockListenBrainz: ListenBrainzServiceProtocol, @unchecked Sendable {
    var nowPlayingCallCount = 0
    var scrobbleCallCount = 0
    var lastScrobbledTrack: TrackMetadata?
    var shouldFail = false

    func validateToken(_ token: String) async throws -> (valid: Bool, username: String) {
        if shouldFail {
            throw ListenBrainzError.invalidToken("Invalid")
        }
        return (true, "mock_lb_user")
    }

    func updateNowPlaying(track: TrackMetadata, token: String) async throws {
        nowPlayingCallCount += 1
    }

    func scrobble(track: TrackMetadata, timestamp: Date, token: String) async throws {
        if shouldFail {
            throw ListenBrainzError.submissionFailed("Simulated LB failure")
        }
        scrobbleCallCount += 1
        lastScrobbledTrack = track
    }
}

@MainActor
final class ScrobbleCoordinatorTests: XCTestCase {
    private var testDefaults: UserDefaults!
    private var suiteName: String!
    private var settings: AppSettings!
    private var keychain: KeychainManager!
    private var mockDetection: MockMusicDetection!
    private var mockLastFM: MockLastFM!
    private var mockListenBrainz: MockListenBrainz!
    private var coordinator: ScrobbleCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "test.newnet.scrobble.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
        settings = AppSettings(defaults: testDefaults)
        keychain = KeychainManager(service: "com.newnet.test.\(UUID().uuidString)")
        mockDetection = MockMusicDetection()
        mockLastFM = MockLastFM()
        mockListenBrainz = MockListenBrainz()

        coordinator = ScrobbleCoordinator(
            settings: settings,
            detectionService: mockDetection,
            lastFMService: mockLastFM,
            listenBrainzService: mockListenBrainz,
            keychain: keychain
        )
    }

    override func tearDown() async throws {
        testDefaults.removePersistentDomain(forName: suiteName)
        try await super.tearDown()
    }

    func testTrackDetectionAndNowPlaying() async {
        coordinator.connectLastFMWithSession(username: "testuser", sessionKey: "test_sk")
        settings.isLastFMEnabled = true

        let track = TrackMetadata(
            title: "Midnight City",
            artist: "M83",
            album: "Hurry Up, We're Dreaming",
            duration: 243.0,
            player: .appleMusic
        )

        mockDetection.stubbedResult = DetectionResult(
            track: track,
            state: .playing(position: 10.0),
            player: .appleMusic
        )

        await coordinator.pollPlayback()

        XCTAssertEqual(coordinator.currentTrack?.title, "Midnight City")
        XCTAssertEqual(coordinator.currentTrack?.artist, "M83")
        XCTAssertTrue(coordinator.playbackState.isPlaying)

        // Give Task a brief tick to fire now playing
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(mockLastFM.nowPlayingCallCount, 1)
    }

    func testEligibilityAndDuplicatePrevention() async {
        coordinator.connectLastFMWithSession(username: "testuser", sessionKey: "test_sk")
        settings.isLastFMEnabled = true

        let track = TrackMetadata(
            title: "Get Lucky",
            artist: "Daft Punk",
            duration: 100.0,
            player: .spotify
        )

        // Initial play at pos 0
        mockDetection.stubbedResult = DetectionResult(
            track: track,
            state: .playing(position: 0.0),
            player: .spotify
        )
        await coordinator.pollPlayback()

        // Track is 100s, threshold is 30s. At pos 20, not eligible yet
        mockDetection.stubbedResult = DetectionResult(
            track: track,
            state: .playing(position: 20.0),
            player: .spotify
        )
        await coordinator.pollPlayback()
        XCTAssertEqual(mockLastFM.scrobbleCallCount, 0)

        // At pos 32s, threshold (30s) exceeded -> Scrobble triggers!
        mockDetection.stubbedResult = DetectionResult(
            track: track,
            state: .playing(position: 32.0),
            player: .spotify
        )
        await coordinator.pollPlayback()

        // Wait for scrobble Task
        try? await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(mockLastFM.scrobbleCallCount, 1)
        XCTAssertEqual(mockLastFM.lastScrobbledTrack?.title, "Get Lucky")

        // Subsequent poll of the same track continuing must NOT scrobble again (Duplicate Prevention)
        mockDetection.stubbedResult = DetectionResult(
            track: track,
            state: .playing(position: 70.0),
            player: .spotify
        )
        await coordinator.pollPlayback()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(mockLastFM.scrobbleCallCount, 1, "Duplicate scrobble must be prevented")
    }

    func testScrobbleFailureDoesNotDuplicateHistory() async {
        coordinator.connectLastFMWithSession(username: "testuser", sessionKey: "test_sk")
        settings.isLastFMEnabled = true
        mockLastFM.shouldFail = true

        let track = TrackMetadata(
            title: "Aeroplane",
            artist: "Sushin Shyam",
            duration: 147.0,
            player: .appleMusic
        )

        // Initial play at pos 0
        mockDetection.stubbedResult = DetectionResult(track: track, state: .playing(position: 0.0), player: .appleMusic)
        await coordinator.pollPlayback()

        // At pos 35s, threshold exceeded -> Scrobble triggers but fails
        mockDetection.stubbedResult = DetectionResult(track: track, state: .playing(position: 35.0), player: .appleMusic)
        await coordinator.pollPlayback()
        try? await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertEqual(coordinator.scrobbleHistory.count, 1)
        XCTAssertEqual(coordinator.scrobbleHistory.first?.lastFMResult?.success, false)

        // Subsequent polls must NOT trigger scrobble again or add duplicate history entries
        mockDetection.stubbedResult = DetectionResult(track: track, state: .playing(position: 37.0), player: .appleMusic)
        await coordinator.pollPlayback()
        try? await Task.sleep(nanoseconds: 100_000_000)

        mockDetection.stubbedResult = DetectionResult(track: track, state: .playing(position: 40.0), player: .appleMusic)
        await coordinator.pollPlayback()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(coordinator.scrobbleHistory.count, 1, "Failed scrobbles must NOT duplicate in history")
        XCTAssertEqual(mockLastFM.scrobbleCallCount, 0, "Failed scrobble must not be retried every poll tick")
    }

    func testLastFMBrowserAuthFlow() async throws {
        let authURL = try await coordinator.startLastFMBrowserAuth(apiKey: "custom_key", apiSecret: "custom_secret")
        XCTAssertTrue(authURL.absoluteString.contains("api_key=custom_key"))
        XCTAssertTrue(authURL.absoluteString.contains("token=mock_token"))

        let username = try await coordinator.completeLastFMBrowserAuth()
        XCTAssertEqual(username, "mock_user")
        XCTAssertTrue(coordinator.lastFMStatus.isConnected)
        XCTAssertEqual(keychain.get(key: ScrobbleCoordinator.keyLastFMSessionKey), "mock_session_key")
        XCTAssertEqual(keychain.get(key: ScrobbleCoordinator.keyLastFMAPIKey), "custom_key")
        XCTAssertEqual(keychain.get(key: ScrobbleCoordinator.keyLastFMAPISecret), "custom_secret")
    }

    func testPlaybackControls() async {
        coordinator.togglePlayPause()
        try? await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertEqual(mockDetection.togglePlayPauseCount, 1)

        coordinator.nextTrack()
        try? await Task.sleep(nanoseconds: 450_000_000)
        XCTAssertEqual(mockDetection.nextTrackCount, 1)

        coordinator.previousTrack()
        try? await Task.sleep(nanoseconds: 450_000_000)
        XCTAssertEqual(mockDetection.previousTrackCount, 1)
    }

    func testShortTrackNotEligible() async {
        coordinator.connectLastFMWithSession(username: "testuser", sessionKey: "test_sk")
        settings.isLastFMEnabled = true

        // Track under 30 seconds
        let shortTrack = TrackMetadata(
            title: "Intro",
            artist: "The xx",
            duration: 20.0,
            player: .appleMusic
        )

        mockDetection.stubbedResult = DetectionResult(
            track: shortTrack,
            state: .playing(position: 15.0),
            player: .appleMusic
        )
        await coordinator.pollPlayback()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(mockLastFM.scrobbleCallCount, 0, "Tracks under 30 seconds must not be scrobbled")
    }

    func testProviderIndependence() async {
        // Connect both Last.fm and ListenBrainz
        coordinator.connectLastFMWithSession(username: "test_lastfm", sessionKey: "sk")
        _ = try? await coordinator.connectListenBrainz(token: "lb_token")

        settings.isLastFMEnabled = true
        settings.isListenBrainzEnabled = true

        // Simulate Last.fm network error while ListenBrainz succeeds
        mockLastFM.shouldFail = true
        mockListenBrainz.shouldFail = false

        let track = TrackMetadata(
            title: "Starboy",
            artist: "The Weeknd",
            duration: 60.0,
            player: .appleMusic
        )

        mockDetection.stubbedResult = DetectionResult(track: track, state: .playing(position: 0), player: .appleMusic)
        await coordinator.pollPlayback()

        mockDetection.stubbedResult = DetectionResult(track: track, state: .playing(position: 35), player: .appleMusic)
        await coordinator.pollPlayback()

        try? await Task.sleep(nanoseconds: 250_000_000)

        // ListenBrainz succeeded even though Last.fm failed
        XCTAssertEqual(mockListenBrainz.scrobbleCallCount, 1)
        XCTAssertEqual(mockLastFM.scrobbleCallCount, 0)
    }

    func testDisconnectRemovesCredentialsAndDisables() {
        coordinator.connectLastFMWithSession(username: "lfm_user", sessionKey: "lfm_sk")
        XCTAssertTrue(coordinator.lastFMStatus.isConnected)
        XCTAssertEqual(keychain.get(key: ScrobbleCoordinator.keyLastFMSessionKey), "lfm_sk")

        coordinator.disconnectLastFM()
        XCTAssertFalse(coordinator.lastFMStatus.isConnected)
        XCTAssertFalse(settings.isLastFMEnabled)
        XCTAssertNil(keychain.get(key: ScrobbleCoordinator.keyLastFMSessionKey))
    }
}

@MainActor
final class YTDLPServiceHostTests: XCTestCase {
    func testCanHandleRedditAndSocialUrls() {
        let service = YTDLPService()
        XCTAssertTrue(service.canHandle(URL(string: "https://www.reddit.com/r/videos/comments/xyz/test/")!))
        XCTAssertTrue(service.canHandle(URL(string: "https://redd.it/xyz123")!))
        XCTAssertTrue(service.canHandle(URL(string: "https://v.redd.it/xyz123")!))
        XCTAssertTrue(service.canHandle(URL(string: "https://tiktok.com/@user/video/123")!))
        XCTAssertTrue(service.canHandle(URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!))
        XCTAssertFalse(service.canHandle(URL(string: "https://example.com/file.zip")!))
    }

    func testIsRedditDetection() {
        XCTAssertTrue(YTDLPService.isReddit(url: URL(string: "https://www.reddit.com/r/TeluguMusicMelodies/comments/1jhucee")!))
        XCTAssertTrue(YTDLPService.isReddit(url: URL(string: "https://reddit.com/r/videos/s/7I6q5d2a9x")!))
        XCTAssertTrue(YTDLPService.isReddit(url: URL(string: "https://v.redd.it/381tdwqjceqe1")!))
        XCTAssertTrue(YTDLPService.isReddit(url: URL(string: "https://redd.it/1jhucee")!))
        XCTAssertFalse(YTDLPService.isReddit(url: URL(string: "https://youtube.com/watch?v=123")!))
    }

    func testBuildAudioOptionsReturnsThreeOptions() {
        let service = YTDLPService()
        let formats = [
            YTDLPInspectionFormat(
                formatId: "140",
                formatNote: "medium",
                ext: "m4a",
                tbr: 128,
                abr: 128,
                vcodec: "none",
                acodec: "mp4a.40.2"
            ),
            YTDLPInspectionFormat(
                formatId: "251",
                formatNote: "high",
                ext: "webm",
                tbr: 160,
                abr: 160,
                vcodec: "none",
                acodec: "opus"
            ),
            YTDLPInspectionFormat(
                formatId: "18",
                ext: "mp4",
                tbr: 300,
                vcodec: "avc1",
                acodec: "mp4a.40.2"
            )
        ]

        let options = service.buildAudioOptions(from: formats)
        XCTAssertEqual(options.count, 3, "There must be three audio options (Full MP3, iPhone M4R, and MP3 Ringtone)")

        let fullOption = options[0]
        XCTAssertEqual(fullOption.id, "audio-mp3-high")
        XCTAssertEqual(fullOption.label, "MP3 Audio High")
        XCTAssertEqual(fullOption.configuration.formatExpression, "251")
        XCTAssertEqual(fullOption.configuration.contentPreference, .audio)
        XCTAssertTrue(fullOption.configuration.extractAudio)
        XCTAssertEqual(fullOption.configuration.audioFormat, "mp3")
        XCTAssertNil(fullOption.configuration.clipStart)
        XCTAssertNil(fullOption.configuration.clipEnd)

        let m4rRingtoneOption = options[1]
        XCTAssertEqual(m4rRingtoneOption.id, "audio-ringtone-m4r-29s")
        XCTAssertEqual(m4rRingtoneOption.label, "iPhone Ringtone (M4R)")
        XCTAssertEqual(m4rRingtoneOption.configuration.formatExpression, "251")
        XCTAssertEqual(m4rRingtoneOption.configuration.contentPreference, .audio)
        XCTAssertTrue(m4rRingtoneOption.configuration.extractAudio)
        XCTAssertEqual(m4rRingtoneOption.configuration.audioFormat, "m4r")
        XCTAssertEqual(m4rRingtoneOption.configuration.clipStart, 0)
        XCTAssertEqual(m4rRingtoneOption.configuration.clipEnd, 29)

        let mp3RingtoneOption = options[2]
        XCTAssertEqual(mp3RingtoneOption.id, "audio-ringtone-29s")
        XCTAssertEqual(mp3RingtoneOption.label, "MP3 Ringtone")
        XCTAssertEqual(mp3RingtoneOption.configuration.formatExpression, "251")
        XCTAssertEqual(mp3RingtoneOption.configuration.contentPreference, .audio)
        XCTAssertTrue(mp3RingtoneOption.configuration.extractAudio)
        XCTAssertEqual(mp3RingtoneOption.configuration.audioFormat, "mp3")
        XCTAssertEqual(mp3RingtoneOption.configuration.clipStart, 0)
        XCTAssertEqual(mp3RingtoneOption.configuration.clipEnd, 29)
    }

    func testBuildAudioOptionsFallbackWhenEmpty() {
        let service = YTDLPService()
        let options = service.buildAudioOptions(from: [])
        XCTAssertEqual(options.count, 3)
        XCTAssertEqual(options[0].id, "audio-mp3-high")
        XCTAssertEqual(options[0].label, "MP3 Audio High")
        XCTAssertEqual(options[0].configuration.formatExpression, "bestaudio/best")
        XCTAssertEqual(options[1].id, "audio-ringtone-m4r-29s")
        XCTAssertEqual(options[1].label, "iPhone Ringtone (M4R)")
        XCTAssertEqual(options[1].configuration.formatExpression, "bestaudio/best")
        XCTAssertEqual(options[1].configuration.audioFormat, "m4r")
        XCTAssertEqual(options[2].id, "audio-ringtone-29s")
        XCTAssertEqual(options[2].label, "MP3 Ringtone")
        XCTAssertEqual(options[2].configuration.formatExpression, "bestaudio/best")
    }

    func testM4RIPhoneRingtoneYTDLPArguments() {
        let service = YTDLPService()
        let settings = AppSettings()
        let m4rConfig = YTDLPDownloadConfiguration(
            formatExpression: "251",
            displayName: "iPhone Ringtone (M4R)",
            detailText: "Native Apple 256k AAC",
            contentPreference: .audio,
            extractAudio: true,
            audioFormat: "m4r",
            clipStart: 0,
            clipEnd: 29
        )
        let item = DownloadItem(
            sourceURL: URL(string: "https://youtube.com/watch?v=123")!,
            fileName: "song.m4r",
            contentPreference: .audio,
            ytDLPConfiguration: m4rConfig
        )

        let args = service.arguments(for: item, settings: settings)
        XCTAssertTrue(args.contains("--extract-audio"))
        XCTAssertTrue(args.contains("--audio-format"))
        if let formatIdx = args.firstIndex(of: "--audio-format") {
            XCTAssertEqual(args[formatIdx + 1], "m4a", "m4r is extracted as m4a with 256k AAC prior to rename")
        }
        XCTAssertTrue(args.contains("--postprocessor-args"))
        if let ppaIdx = args.firstIndex(of: "--postprocessor-args") {
            XCTAssertEqual(args[ppaIdx + 1], "ExtractAudio:-b:a 256k", "AAC must be encoded at 256 kbps")
        }
        XCTAssertTrue(args.contains("--download-sections"))
        if let secIdx = args.firstIndex(of: "--download-sections") {
            XCTAssertEqual(args[secIdx + 1], "*0-29")
        }
        XCTAssertTrue(service.requiresFFmpeg(for: item))
    }

    func testRequiresFFmpegForAudioAndRingtone() {
        let service = YTDLPService()
        let ringtoneConfig = YTDLPDownloadConfiguration(
            formatExpression: "251",
            displayName: "Ringtone",
            detailText: "29s",
            contentPreference: .audio,
            extractAudio: true,
            audioFormat: "mp3",
            clipStart: 0,
            clipEnd: 29
        )
        let item = DownloadItem(
            sourceURL: URL(string: "https://youtube.com/watch?v=123")!,
            fileName: "song.mp3",
            contentPreference: .audio,
            ytDLPConfiguration: ringtoneConfig
        )
        XCTAssertTrue(service.requiresFFmpeg(for: item))
    }

    func testTimeFormattingParsingAndFormatting() {
        // MM:SS parsing
        XCTAssertEqual(TimeFormatting.parseTimestamp("1:12"), 72)
        XCTAssertEqual(TimeFormatting.parseTimestamp("2:22"), 142)
        XCTAssertEqual(TimeFormatting.parseTimestamp("01:12"), 72)
        XCTAssertEqual(TimeFormatting.parseTimestamp("0:05"), 5)
        XCTAssertEqual(TimeFormatting.parseTimestamp("0:00"), 0)

        // Raw seconds
        XCTAssertEqual(TimeFormatting.parseTimestamp("72"), 72)
        XCTAssertEqual(TimeFormatting.parseTimestamp("142.5"), 142.5)

        // H:MM:SS
        XCTAssertEqual(TimeFormatting.parseTimestamp("1:02:15"), 3735)

        // Invalid cases
        XCTAssertNil(TimeFormatting.parseTimestamp(""))
        XCTAssertNil(TimeFormatting.parseTimestamp("   "))
        XCTAssertNil(TimeFormatting.parseTimestamp("-5"))
        XCTAssertNil(TimeFormatting.parseTimestamp("invalid"))

        // Formatting back to MM:SS
        XCTAssertEqual(TimeFormatting.formatTimestamp(72), "1:12")
        XCTAssertEqual(TimeFormatting.formatTimestamp(142), "2:22")
        XCTAssertEqual(TimeFormatting.formatTimestamp(5), "0:05")
        XCTAssertEqual(TimeFormatting.formatTimestamp(0), "0:00")
        XCTAssertEqual(TimeFormatting.formatTimestamp(3735), "1:02:15")
    }

    func testAudioCutterDownloadSectionsArguments() {
        let service = YTDLPService()
        let settings = AppSettings()
        let cutConfig = YTDLPDownloadConfiguration(
            formatExpression: "bestaudio/best",
            displayName: "MP3 Audio [1:12 - 2:22]",
            detailText: "Trimmed Audio",
            contentPreference: .audio,
            extractAudio: true,
            audioFormat: "mp3",
            clipStart: 72,
            clipEnd: 142
        )
        let item = DownloadItem(
            sourceURL: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!,
            fileName: "song.mp3",
            contentPreference: .audio,
            ytDLPConfiguration: cutConfig
        )

        let args = service.arguments(for: item, settings: settings)
        XCTAssertTrue(args.contains("--download-sections"), "Arguments must contain --download-sections")
        if let index = args.firstIndex(of: "--download-sections") {
            XCTAssertEqual(args[index + 1], "*72-142", "Must specify exact *72-142 time range")
        }
        XCTAssertTrue(args.contains("--extract-audio"), "Must extract audio")
        XCTAssertTrue(args.contains("mp3"), "Must output mp3")
        XCTAssertTrue(service.requiresFFmpeg(for: item), "Trimmed audio requires FFmpeg")
    }

    func testCustomYTDLPPathOverrideResolution() {
        let settings = AppSettings()
        let service = YTDLPService()
        
        // Custom valid executable path (e.g. /bin/ls)
        settings.ytDLPPath = "/bin/ls"
        let resolved = service.resolvedBinaryURL(settings: settings)
        XCTAssertEqual(resolved?.path(percentEncoded: false), "/bin/ls")

        // Reset
        settings.ytDLPPath = ""
    }

    func testYTDLPLatestVersionFallback() async throws {
        let service = YTDLPService()
        let version = try await service.latestVersion()
        XCTAssertFalse(version.isEmpty)
    }

    @MainActor
    func testHumanizeYouTubeBotCheckError() {
        let rawBotError = "ERROR: [youtube] yfHDJWWm0LE: Sign in to confirm you’re not a bot. Use --cookies-from-browser or --cookies for the authentication. See  https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp  for how to manually pass cookies. Also see  https://github.com/yt-dlp/yt-dlp/wiki/Extractors#exporting-youtube-cookies  for tips on effectively exporting YouTube cookies"

        // Default / no settings
        let humanizedDefault = YTDLPHumanError.humanize(rawBotError, settings: nil)
        XCTAssertTrue(humanizedDefault.contains("YouTube requires verification"))
        XCTAssertTrue(humanizedDefault.contains("Browser Cookies in NewNet Settings"))
        XCTAssertFalse(humanizedDefault.contains("https://"))
        XCTAssertFalse(humanizedDefault.contains("--cookies-from-browser"))

        // Chrome configured
        let chromeSettings = AppSettings()
        chromeSettings.browserCookieSource = .chrome
        let humanizedChrome = YTDLPHumanError.humanize(rawBotError, settings: chromeSettings)
        XCTAssertTrue(humanizedChrome.contains("Google Chrome"))
        XCTAssertTrue(humanizedChrome.contains("signed in to YouTube"))
    }

    func testHumanizeSafariOperationNotPermittedError() {
        let rawSafariError = "ERROR: [Errno 1] Operation not permitted: '/Users/nn/Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies'"
        let humanized = YTDLPHumanError.humanize(rawSafariError)
        XCTAssertTrue(humanized.contains("Full Disk Access"))
        XCTAssertTrue(humanized.contains("Safari cookies"))
        XCTAssertTrue(humanized.contains("System Settings"))
    }

    func testHumanizeAgeRestrictionAndPrivateErrors() {
        let ageError = "ERROR: [youtube] 12345: Sign in to confirm your age. This video may be inappropriate for some users."
        let humanizedAge = YTDLPHumanError.humanize(ageError)
        XCTAssertTrue(humanizedAge.contains("age-restricted"))
        XCTAssertFalse(humanizedAge.contains("ERROR: [youtube]"))

        let privateError = "ERROR: [youtube] 12345: Private video. Sign in if you've been granted access to this video"
        let humanizedPrivate = YTDLPHumanError.humanize(privateError)
        XCTAssertTrue(humanizedPrivate.contains("private or members-only"))

        let geoError = "ERROR: [youtube] 12345: The uploader has not made this video available in your country"
        let humanizedGeo = YTDLPHumanError.humanize(geoError)
        XCTAssertTrue(humanizedGeo.contains("geographic restrictions"))
    }

    @MainActor
    func testBrowserCookieArguments() {
        let settings = AppSettings()
        let service = YTDLPService()
        let item = DownloadItem(
            sourceURL: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!,
            fileName: "video.mp4",
            contentPreference: .video
        )

        // None
        settings.browserCookieSource = .none
        XCTAssertNil(YTDLPService.cookieArguments(settings: settings))

        // Chrome
        settings.browserCookieSource = .chrome
        let chromeArgs = YTDLPService.cookieArguments(settings: settings)
        XCTAssertEqual(chromeArgs, ["--cookies-from-browser", "chrome"])

        let downloadArgs = service.arguments(for: item, settings: settings)
        XCTAssertTrue(downloadArgs.contains("--cookies-from-browser"))
        XCTAssertTrue(downloadArgs.contains("chrome"))

        // Firefox
        settings.browserCookieSource = .firefox
        let firefoxArgs = YTDLPService.cookieArguments(settings: settings)
        XCTAssertEqual(firefoxArgs, ["--cookies-from-browser", "firefox"])

        // Reset
        settings.browserCookieSource = .safari
    }
}

@MainActor
final class UtilitiesServicesTests: XCTestCase {

    // MARK: - Keep Awake Tests

    func testKeepAwakeActivationAndDeactivation() {
        let service = KeepAwakeService()
        XCTAssertFalse(service.isActive)
        XCTAssertNil(service.remainingSeconds)

        // Indefinite
        service.activate(minutes: 0)
        XCTAssertTrue(service.isActive)
        XCTAssertNil(service.remainingSeconds)
        XCTAssertEqual(service.remainingTimeFormatted, "Indefinite")

        // Deactivate
        service.deactivate()
        XCTAssertFalse(service.isActive)
        XCTAssertNil(service.remainingSeconds)

        // Timed
        service.activate(minutes: 30)
        XCTAssertTrue(service.isActive)
        XCTAssertNotNil(service.remainingSeconds)
        XCTAssertGreaterThan(service.remainingSeconds ?? 0, 0)
        XCTAssertTrue(service.remainingTimeFormatted.contains(":"))

        service.deactivate()
        XCTAssertFalse(service.isActive)
    }

    func testKeepAwakeToggle() {
        let service = KeepAwakeService()
        XCTAssertFalse(service.isActive)

        service.toggle(minutes: 15)
        XCTAssertTrue(service.isActive)

        service.toggle()
        XCTAssertFalse(service.isActive)
    }

    func testKeepAwakeAddMinutesAndLidClosedMode() {
        let service = KeepAwakeService()
        XCTAssertFalse(service.isActive)

        // Starting from inactive by adding minutes activates the session
        service.addMinutes(15)
        XCTAssertTrue(service.isActive)
        let initialRemaining = service.remainingSeconds ?? 0
        XCTAssertGreaterThan(initialRemaining, 0)

        // Adding 30 minutes extends remaining time
        service.addMinutes(30)
        let extendedRemaining = service.remainingSeconds ?? 0
        XCTAssertGreaterThan(extendedRemaining, initialRemaining + (25 * 60))

        // Lid sleep mode toggle
        XCTAssertFalse(service.preventLidSleep)
        service.preventLidSleep = true
        XCTAssertTrue(service.preventLidSleep)
        XCTAssertTrue(service.preventDisplaySleep) // alias consistency

        service.deactivate()
        XCTAssertFalse(service.isActive)
    }

    func testKeepAwakeLidClosedAndDisplayAssertions() {
        let service = KeepAwakeService()
        XCTAssertFalse(service.isActive)
        XCTAssertFalse(service.hasDisplayAssertion)
        XCTAssertFalse(service.hasSystemAssertion)
        XCTAssertFalse(service.hasLidAssertion)

        // Scenario 1: Keep Awake Enabled, Lid-closed mode Disabled
        // Expected: Display & System assertions active (Macbook stays awake unless lid is closed), Lid assertion inactive
        service.preventLidSleep = false
        service.activate(minutes: 0)
        XCTAssertTrue(service.isActive)
        XCTAssertTrue(service.hasDisplayAssertion, "Display assertion must be active when Keep Awake is enabled with lid-closed mode disabled")
        XCTAssertTrue(service.hasSystemAssertion, "System idle assertion must be active")
        XCTAssertFalse(service.hasLidAssertion, "Lid-close assertion must NOT be active when lid-closed mode is disabled")

        // Scenario 2: Keep Awake Enabled, Lid-closed mode Enabled
        // Expected: Display, System, and Lid assertions all active (Macbook stays awake even if lid is closed)
        service.preventLidSleep = true
        XCTAssertTrue(service.isActive)
        XCTAssertTrue(service.hasDisplayAssertion)
        XCTAssertTrue(service.hasSystemAssertion)
        XCTAssertTrue(service.hasLidAssertion, "Lid-close assertion must be active when lid-closed mode is enabled")

        // Toggling Lid-closed mode back to Disabled while Keep Awake is still active
        service.preventLidSleep = false
        XCTAssertTrue(service.isActive)
        XCTAssertTrue(service.hasDisplayAssertion, "Display assertion must remain active")
        XCTAssertTrue(service.hasSystemAssertion, "System assertion must remain active")
        XCTAssertFalse(service.hasLidAssertion, "Lid-close assertion must be released")

        // Deactivation releases all assertions
        service.deactivate()
        XCTAssertFalse(service.isActive)
        XCTAssertFalse(service.hasDisplayAssertion)
        XCTAssertFalse(service.hasSystemAssertion)
        XCTAssertFalse(service.hasLidAssertion)
    }

    // MARK: - Clipboard History Tests

    func testClipboardHistoryItemCreationAndFiltering() {
        let textItem = ClipboardItem(text: "Hello World", kind: .text)
        let linkItem = ClipboardItem(text: "https://example.com/test", kind: .link)
        let fileItem = ClipboardItem(text: "test.pdf", kind: .files, filePaths: ["/Users/test/test.pdf"])
        let imageItem = ClipboardItem(text: "photo.jpg", kind: .image, filePaths: ["/Users/test/photo.jpg"])

        XCTAssertEqual(textItem.kind, .text)
        XCTAssertEqual(linkItem.kind, .link)
        XCTAssertEqual(fileItem.kind, .files)
        XCTAssertEqual(imageItem.kind, .image)
        XCTAssertEqual(textItem.charCount, 11)
    }

    func testClipboardServicePinningAndDeletion() {
        let service = ClipboardHistoryService()
        service.clearAllIncludingPinned()
        XCTAssertEqual(service.items.count, 0)

        let item1 = ClipboardItem(id: UUID(), text: "Item 1", kind: .text, createdAt: Date().addingTimeInterval(-100))
        let item2 = ClipboardItem(id: UUID(), text: "Item 2", kind: .text, createdAt: Date())

        service.record(item: item1)
        service.record(item: item2)

        XCTAssertEqual(service.items.count, 2)

        if let first = service.items.first {
            XCTAssertFalse(first.isPinned)
            service.togglePin(first)
            XCTAssertTrue(service.items.first?.isPinned ?? false)

            service.deleteItem(first)
            XCTAssertFalse(service.items.contains { $0.id == first.id })
        }
    }

    // MARK: - Scroll Inverter Tests

    func testScrollInverterToggleAndSettings() {
        let service = ScrollInverterService()
        let initial = service.isEnabled

        service.toggle()
        XCTAssertEqual(service.isEnabled, !initial)

        // Test axis flags
        service.invertVertical = true
        service.invertHorizontal = true
        XCTAssertTrue(service.invertVertical)
        XCTAssertTrue(service.invertHorizontal)

        service.isEnabled = false
    }

    // MARK: - Finder Cut & Paste Tests

    func testFinderCutPasteToggleAndInitialState() {
        let service = FinderCutPasteService()
        XCTAssertTrue(service.markedURLs.isEmpty)

        service.isEnabled = false
        XCTAssertFalse(service.isEnabled)
        XCTAssertFalse(service.isRunning)
    }

    // MARK: - Quit on Close Tests

    func testQuitOnCloseExceptions() {
        let service = QuitOnCloseService()
        let testBundle = "com.test.uniqueApp"

        service.addException(bundleIdentifier: testBundle)
        XCTAssertTrue(service.exceptions.contains(testBundle))

        service.removeException(bundleIdentifier: testBundle)
        XCTAssertFalse(service.exceptions.contains(testBundle))
    }

    func testQuitOnCloseBrowserAndFinderExclusion() {
        let service = QuitOnCloseService()

        // Finder and own app excluded
        XCTAssertTrue(service.isExcluded(bundleID: "com.apple.finder"))
        XCTAssertTrue(service.isExcluded(bundleID: Bundle.main.bundleIdentifier ?? "NihanviBuilds.NewNet"))

        // Standard browsers excluded
        XCTAssertTrue(service.isExcluded(bundleID: "com.apple.Safari"))
        XCTAssertTrue(service.isExcluded(bundleID: "com.google.Chrome"))
        XCTAssertTrue(service.isExcluded(bundleID: "org.mozilla.firefox"))
        XCTAssertTrue(service.isExcluded(bundleID: "com.brave.Browser"))
        XCTAssertTrue(service.isExcluded(bundleID: "company.thebrowser.Browser"))

        // Standard user apps are NOT excluded by default
        XCTAssertFalse(service.isExcluded(bundleID: "com.apple.calculator"))
        XCTAssertFalse(service.isExcluded(bundleID: "com.apple.TextEdit"))

        // Adding user exception
        service.addException(bundleIdentifier: "com.apple.TextEdit")
        XCTAssertTrue(service.isExcluded(bundleID: "com.apple.TextEdit"))
        service.removeException(bundleIdentifier: "com.apple.TextEdit")
        XCTAssertFalse(service.isExcluded(bundleID: "com.apple.TextEdit"))
    }

    // MARK: - NewNetTab Tests

    func testNewNetTabIncludesUtilitiesAndClipboard() {
        XCTAssertTrue(NewNetTab.allCases.contains(.clipboard))
        XCTAssertTrue(NewNetTab.allCases.contains(.utilities))
        XCTAssertEqual(NewNetTab.clipboard.title, "Clipboard")
        XCTAssertEqual(NewNetTab.utilities.title, "Utilities")
        XCTAssertEqual(NewNetTab.clipboard.systemImage, "doc.on.clipboard")
        XCTAssertEqual(NewNetTab.utilities.systemImage, "wrench.and.screwdriver")
    }

    @MainActor
    func testMenuBarSpeedIndicatorKeepAwakeIndicator() {
        let indicator = MenuBarSpeedIndicator(frame: .zero)
        let initialWidth = indicator.preferredWidth
        XCTAssertFalse(indicator.isKeepAwakeActive)

        indicator.isKeepAwakeActive = true
        let activeWidth = indicator.preferredWidth
        // Width must expand to accommodate the coffee cup icon (14pt + 4pt spacing = 18pt)
        XCTAssertGreaterThan(activeWidth, initialWidth)
        XCTAssertEqual(activeWidth - initialWidth, 18, accuracy: 1)

        indicator.isKeepAwakeActive = false
        XCTAssertEqual(indicator.preferredWidth, initialWidth)
    }

    // MARK: - Coordinator Integration

    func testUtilitiesCoordinatorInitialization() {
        let settings = AppSettings()
        let coordinator = UtilitiesCoordinator(settings: settings)

        XCTAssertNotNil(coordinator.keepAwake)
        XCTAssertNotNil(coordinator.clipboardHistory)
        XCTAssertNotNil(coordinator.quitOnClose)
        XCTAssertNotNil(coordinator.scrollInverter)
        XCTAssertNotNil(coordinator.finderCutPaste)
    }

    // MARK: - Accessibility Permission Tests

    func testAccessibilityPermissionStatusAndHelper() {
        let granted = AccessibilityPermissionStatus.granted
        let notGranted = AccessibilityPermissionStatus.notGranted
        let unknown = AccessibilityPermissionStatus.unknown

        XCTAssertEqual(granted, .granted)
        XCTAssertEqual(notGranted, .notGranted)
        XCTAssertEqual(unknown, .unknown)

        // Verify SystemPermissionsHelper reflection of PermissionsManager
        let currentStatus = SystemPermissionsHelper.status
        let isGranted = SystemPermissionsHelper.isAccessibilityGranted
        XCTAssertEqual(isGranted, currentStatus == .granted)

        // Nonisolated queries
        let passiveChecked = SystemPermissionsHelper.checkAccessibility(prompt: false)
        XCTAssertEqual(passiveChecked, isGranted)
        _ = SystemPermissionsHelper.checkListenEventAccess(prompt: false)

        // Stop polling cleanly in test environment
        PermissionsManager.shared.stopPolling()
    }
}

