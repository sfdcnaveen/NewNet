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

    override func setUp() {
        super.setUp()
        suiteName = "test.newnet.tabs.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefaultTabOrder() {
        let settings = AppSettings(defaults: testDefaults)
        XCTAssertEqual(settings.tabOrder, [.network, .ytdlp, .music])
    }

    func testReorderTabs() {
        let settings = AppSettings(defaults: testDefaults)
        settings.tabOrder = [.music, .network, .ytdlp]
        XCTAssertEqual(settings.tabOrder, [.music, .network, .ytdlp])

        // Verify persistence across new instance
        let reloaded = AppSettings(defaults: testDefaults)
        XCTAssertEqual(reloaded.tabOrder, [.music, .network, .ytdlp])
    }

    func testRestoreDefaultTabOrder() {
        let settings = AppSettings(defaults: testDefaults)
        settings.tabOrder = [.ytdlp, .music, .network]
        XCTAssertEqual(settings.tabOrder, [.ytdlp, .music, .network])

        settings.restoreDefaultTabOrder()
        XCTAssertEqual(settings.tabOrder, [.network, .ytdlp, .music])
    }

    func testTabOrderDeduplicationAndFallback() {
        // Storing invalid/partial tab list in UserDefaults
        testDefaults.set(["music", "invalid_tab", "music"], forKey: "settings.tabOrder")
        let settings = AppSettings(defaults: testDefaults)

        // Missing default tabs (network, ytdlp) should be appended automatically without duplicates
        XCTAssertEqual(settings.tabOrder, [.music, .network, .ytdlp])
    }
}

final class KeychainManagerTests: XCTestCase {
    private let testService = "com.newnet.test.\(UUID().uuidString)"
    private var keychain: KeychainManager!

    override func setUp() {
        super.setUp()
        keychain = KeychainManager(service: testService)
    }

    override func tearDown() {
        keychain.delete(key: "test_key")
        super.tearDown()
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

    override func setUp() {
        super.setUp()
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

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
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
}

