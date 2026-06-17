import XCTest
@testable import Duhaa

private final class FakeAudioSessionManager: QuranAudioSessionManaging {
    private(set) var activationCount = 0
    private(set) var deactivationCount = 0
    var shouldFail = false

    func configureAndActivate() async throws {
        activationCount += 1
        if shouldFail {
            throw QuranAudioError.playerFailed
        }
    }

    func deactivate() async {
        deactivationCount += 1
    }
}

private final class FakeAudioURLResolver: QuranAudioURLResolving {
    private(set) var requests: [QuranAudioRequest] = []
    var immediateResult: Result<URL, Error>?
    private var continuations: [CheckedContinuation<URL, Error>] = []

    func resolveURL(for request: QuranAudioRequest) async throws -> URL {
        requests.append(request)
        if let immediateResult {
            return try immediateResult.get()
        }
        return try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func succeedNext(with url: URL = URL(string: "https://example.com/audio.mp3")!) {
        continuations.removeFirst().resume(returning: url)
    }

    func failNext(with error: Error = QuranAudioError.missingURL) {
        continuations.removeFirst().resume(throwing: error)
    }

    var pendingCount: Int { continuations.count }
}

@MainActor
private final class FakeQuranAudioPlayer: QuranAudioPlaying {
    var onReady: (() -> Void)?
    var onFailed: ((Error) -> Void)?
    var onEnded: (() -> Void)?
    var onFirstPlayback: (() -> Void)?

    private(set) var preparedURLs: [URL] = []
    private(set) var playCount = 0
    private(set) var pauseCount = 0
    private(set) var stopCount = 0
    var failPrepare = false
    var autoReady = true
    var autoStartPlayback = true

    func prepare(url: URL) async throws {
        preparedURLs.append(url)
        if failPrepare {
            throw QuranAudioError.playerFailed
        }
        if autoReady {
            onReady?()
        }
    }

    func play() {
        playCount += 1
        if autoStartPlayback {
            onFirstPlayback?()
        }
    }

    func pause() {
        pauseCount += 1
    }

    func stop() {
        stopCount += 1
    }
}

@MainActor
final class QuranAudioPlayerTests: XCTestCase {
    private let testURL = URL(string: "https://example.com/audio.mp3")!

    func testQuranAudioCacheOnlyAllowsKnownHTTPSMP3Hosts() throws {
        let verses = try XCTUnwrap(URL(string: "https://verses.quran.com/Alafasy/mp3/001001.mp3"))
        let quranicAudio = try XCTUnwrap(URL(string: "https://download.quranicaudio.com/qdc/example/1.mp3"))
        let wrongScheme = try XCTUnwrap(URL(string: "http://verses.quran.com/Alafasy/mp3/001001.mp3"))
        let wrongHost = try XCTUnwrap(URL(string: "https://example.com/audio.mp3"))
        let wrongExtension = try XCTUnwrap(URL(string: "https://verses.quran.com/Alafasy/mp3/001001.json"))

        XCTAssertTrue(QuranAudioCache.isAllowedRemoteURL(verses))
        XCTAssertTrue(QuranAudioCache.isAllowedRemoteURL(quranicAudio))
        XCTAssertFalse(QuranAudioCache.isAllowedRemoteURL(wrongScheme))
        XCTAssertFalse(QuranAudioCache.isAllowedRemoteURL(wrongHost))
        XCTAssertFalse(QuranAudioCache.isAllowedRemoteURL(wrongExtension))
    }

    func testPressingPlayImmediatelyMovesToLoading() {
        let harness = makeHarness(delayedResolver: true)

        harness.player.play(in: testSurah, from: 1)

        XCTAssertEqual(harness.player.playbackState, .loading)
        XCTAssertEqual(harness.player.playingKey, "1:1")
        XCTAssertTrue(harness.player.isLoading)
    }

    func testAudioURLResolutionHappensThroughAsyncDependency() async {
        let harness = makeHarness(delayedResolver: true)

        harness.player.play(in: testSurah, from: 1)
        await waitUntil("audio URL request is queued") {
            harness.resolver.requests == [.ayah(surah: 1, ayah: 1)]
        }

        XCTAssertEqual(harness.resolver.requests, [.ayah(surah: 1, ayah: 1)])
        XCTAssertEqual(harness.audioPlayer.preparedURLs.count, 0)
    }

    func testAudioSessionActivationIsCalledOnce() async {
        let harness = makeHarness()

        harness.player.play(in: testSurah, from: 1)
        await waitUntil("playback starts") {
            harness.audioPlayer.playCount == 1
        }

        XCTAssertEqual(harness.session.activationCount, 1)
        XCTAssertEqual(harness.audioPlayer.playCount, 1)
        XCTAssertEqual(harness.player.playbackState, .playing)
    }

    func testPlayerCreationIsNotRepeatedForStaleRapidTaps() async {
        let harness = makeHarness(delayedResolver: true)

        harness.player.play(in: testSurah, from: 1)
        harness.player.play(in: testSurah, from: 2)
        harness.player.play(in: testSurah, from: 3)
        await waitUntil("latest request is queued") {
            harness.resolver.requests == [.ayah(surah: 1, ayah: 3)]
        }

        XCTAssertEqual(harness.session.activationCount, 1)
        XCTAssertEqual(harness.resolver.requests, [.ayah(surah: 1, ayah: 3)])

        harness.resolver.succeedNext(with: testURL)
        await waitUntil("latest request prepares player") {
            harness.audioPlayer.preparedURLs.count == 1
        }

        XCTAssertEqual(harness.audioPlayer.preparedURLs.count, 1)
        XCTAssertEqual(harness.player.playingKey, "1:3")
    }

    func testFailedURLProducesFailedState() async {
        let harness = makeHarness(result: .failure(QuranAudioError.missingURL))

        harness.player.play(in: testSurah, from: 1)
        await waitUntil("missing URL failure is shown") {
            if case .failed = harness.player.playbackState { return true }
            return false
        }

        XCTAssertEqual(harness.player.playbackState, .failed("Couldn’t find audio for this recitation."))
        XCTAssertNil(harness.player.playingKey)
        XCTAssertEqual(harness.audioPlayer.playCount, 0)
    }

    func testRepeatedRapidTapsDoNotCreateDuplicatePlayerWork() async {
        let harness = makeHarness(delayedResolver: true)

        harness.player.play(in: testSurah, from: 1)
        harness.player.play(in: testSurah, from: 1)
        harness.player.play(in: testSurah, from: 1)
        await waitUntil("single repeated request is queued") {
            harness.resolver.requests.count == 1
        }

        XCTAssertEqual(harness.resolver.requests.count, 1)
        harness.resolver.succeedNext(with: testURL)
        await waitUntil("single repeated request starts playback") {
            harness.audioPlayer.playCount == 1
        }

        XCTAssertEqual(harness.audioPlayer.preparedURLs.count, 1)
        XCTAssertEqual(harness.audioPlayer.playCount, 1)
    }

    func testStopDuringLoadingCancelsPendingLoad() async {
        let harness = makeHarness(delayedResolver: true)

        harness.player.play(in: testSurah, from: 1)
        await waitUntil("pending request exists") {
            harness.resolver.pendingCount == 1
        }
        harness.player.stop()
        harness.resolver.succeedNext(with: testURL)
        await drainMainActor()

        XCTAssertEqual(harness.player.playbackState, .idle)
        XCTAssertNil(harness.player.playingKey)
        XCTAssertEqual(harness.audioPlayer.preparedURLs.count, 0)
    }

    func testPauseDuringLoadingCancelsPendingLoad() async {
        let harness = makeHarness(delayedResolver: true)

        harness.player.play(in: testSurah, from: 1)
        await waitUntil("pending request exists") {
            harness.resolver.pendingCount == 1
        }
        harness.player.pause()
        harness.resolver.succeedNext(with: testURL)
        await drainMainActor()

        XCTAssertEqual(harness.player.playbackState, .paused)
        XCTAssertEqual(harness.audioPlayer.preparedURLs.count, 0)
    }

    func testChangingAyahReplacesPreviousPendingLoadSafely() async {
        let harness = makeHarness(delayedResolver: true)

        harness.player.play(in: testSurah, from: 1)
        await waitUntil("first request is queued") {
            harness.resolver.requests.count == 1
        }
        harness.player.play(in: testSurah, from: 2)
        await waitUntil("second request is queued") {
            harness.resolver.requests.count == 2
        }

        XCTAssertEqual(harness.resolver.requests, [.ayah(surah: 1, ayah: 1), .ayah(surah: 1, ayah: 2)])
        harness.resolver.succeedNext(with: URL(string: "https://example.com/old.mp3")!)
        await drainMainActor()
        XCTAssertEqual(harness.audioPlayer.preparedURLs.count, 0)

        harness.resolver.succeedNext(with: testURL)
        await waitUntil("replacement request prepares player") {
            harness.audioPlayer.preparedURLs.count == 1
        }
        XCTAssertEqual(harness.audioPlayer.preparedURLs, [testURL])
        XCTAssertEqual(harness.player.playingKey, "1:2")
    }

    func testCachedAudioPathIsPassedToPlayer() async {
        let cachedURL = URL(fileURLWithPath: "/tmp/duhaa-cached-audio.mp3")
        let harness = makeHarness(result: .success(cachedURL))

        harness.player.play(in: testSurah, from: 1)
        await waitUntil("cached URL is prepared") {
            harness.audioPlayer.preparedURLs == [cachedURL]
        }

        XCTAssertEqual(harness.audioPlayer.preparedURLs, [cachedURL])
        XCTAssertTrue(harness.audioPlayer.preparedURLs[0].isFileURL)
    }

    func testMissingAudioURLFailsGracefully() async {
        let harness = makeHarness(result: .failure(QuranAudioError.missingURL))

        harness.player.playChapter(in: testSurah)
        await waitUntil("chapter missing URL failure is shown") {
            if case .failed = harness.player.playbackState { return true }
            return false
        }

        XCTAssertEqual(harness.player.playbackState, .failed("Couldn’t find audio for this recitation."))
        XCTAssertNil(harness.player.playingKey)
    }

    func testPlaybackStateTransitionsToReadyThenPlaying() async {
        let harness = makeHarness()
        harness.audioPlayer.autoStartPlayback = false

        harness.player.play(in: testSurah, from: 1)
        await waitUntil("player becomes ready") {
            harness.player.playbackState == .ready
        }

        XCTAssertEqual(harness.player.playbackState, .ready)
        harness.audioPlayer.onFirstPlayback?()
        XCTAssertEqual(harness.player.playbackState, .playing)
    }

    func testPerformancePlayTapImmediatelyShowsLoadingWithoutResolverCompletion() {
        measure {
            let harness = makeHarness(delayedResolver: true)

            harness.player.play(in: testSurah, from: 1)

            XCTAssertEqual(harness.player.playbackState, .loading)
            harness.player.stop()
        }
    }

    private var testSurah: Surah {
        Surah(number: 1,
              arabicName: "الفاتحة",
              englishName: "Al-Fatihah",
              translation: "The Opening",
              revelation: "Meccan",
              ayahs: [
                Ayah(number: 1, arabic: "a", english: "one"),
                Ayah(number: 2, arabic: "b", english: "two"),
                Ayah(number: 3, arabic: "c", english: "three")
              ])
    }

    private func makeHarness(result: Result<URL, Error> = .success(URL(string: "https://example.com/audio.mp3")!),
                             delayedResolver: Bool = false) -> Harness {
        let session = FakeAudioSessionManager()
        let resolver = FakeAudioURLResolver()
        resolver.immediateResult = delayedResolver ? nil : result
        let audioPlayer = FakeQuranAudioPlayer()
        let player = AyahPlayer(audioSession: session,
                                urlResolver: resolver,
                                audioPlayer: audioPlayer)
        return Harness(player: player,
                       session: session,
                       resolver: resolver,
                       audioPlayer: audioPlayer)
    }

    private func waitUntil(_ description: String,
                           timeout: TimeInterval = 1,
                           file: StaticString = #filePath,
                           line: UInt = #line,
                           _ predicate: () -> Bool) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate(), Date() < deadline {
            await drainMainActor()
        }
        XCTAssertTrue(predicate(), description, file: file, line: line)
    }

    private func drainMainActor() async {
        for _ in 0..<5 {
            await Task.yield()
        }
        try? await Task.sleep(nanoseconds: 1_000_000)
    }

    private struct Harness {
        let player: AyahPlayer
        let session: FakeAudioSessionManager
        let resolver: FakeAudioURLResolver
        let audioPlayer: FakeQuranAudioPlayer
    }
}
