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

private struct StubChapterVerseTimings: ChapterVerseTimingProviding {
    let milliseconds: Int?
    func startMilliseconds(reciterID: Int, surah: Int, ayah: Int) async -> Int? { milliseconds }
}

@MainActor
private final class FakeQuranAudioPlayer: QuranAudioPlaying {
    var onReady: (() -> Void)?
    var onFailed: ((Error) -> Void)?
    var onEnded: (() -> Void)?
    var onFirstPlayback: (() -> Void)?
    var onProgress: ((Double) -> Void)?
    var onTimingUpdate: ((TimeInterval, TimeInterval) -> Void)?

    private(set) var preparedURLs: [URL] = []
    private(set) var seekToMsValues: [Int?] = []
    private(set) var playCount = 0
    private(set) var playRates: [Float] = []
    private(set) var pauseCount = 0
    private(set) var stopCount = 0
    private(set) var playbackRate: Float = 1
    var failPrepare = false
    var autoReady = true
    var autoStartPlayback = true

    func prepare(url: URL, seekToMs: Int?) async throws {
        preparedURLs.append(url)
        seekToMsValues.append(seekToMs)
        if failPrepare {
            throw QuranAudioError.playerFailed
        }
        if autoReady {
            onReady?()
        }
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
    }

    func play() {
        playCount += 1
        playRates.append(playbackRate)
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

    func testTogglePlayPausePausesThenResumes() async {
        let harness = makeHarness()
        harness.player.play(in: testSurah, from: 1)
        await waitUntil("playback starts") { harness.player.playbackState == .playing }

        harness.player.togglePlayPause()
        XCTAssertEqual(harness.player.playbackState, .paused)
        XCTAssertEqual(harness.audioPlayer.pauseCount, 1)

        harness.player.togglePlayPause()
        XCTAssertEqual(harness.player.playbackState, .playing)
        XCTAssertEqual(harness.audioPlayer.playCount, 2) // initial play + resume
    }

    func testResumeIsIgnoredWhenNotPaused() async {
        let harness = makeHarness()
        harness.player.play(in: testSurah, from: 1)
        await waitUntil("playback starts") { harness.player.playbackState == .playing }

        harness.player.resume() // already playing — no-op
        XCTAssertEqual(harness.audioPlayer.playCount, 1)
    }

    func testPlaybackRatePersistsAndAppliesToAudioPlayer() {
        let harness = makeHarness()

        harness.player.setPlaybackRate(1.25)

        XCTAssertEqual(harness.player.playbackRate, 1.25, accuracy: 0.001)
        XCTAssertEqual(harness.audioPlayer.playbackRate, 1.25, accuracy: 0.001)
        XCTAssertEqual(UserDefaults.standard.double(forKey: AyahPlayer.playbackRateStorageKey), 1.25, accuracy: 0.001)

        let restored = makeHarness(resetPlaybackRatePreference: false)
        XCTAssertEqual(restored.player.playbackRate, 1.25, accuracy: 0.001)
        XCTAssertEqual(restored.audioPlayer.playbackRate, 1.25, accuracy: 0.001)
    }

    func testPlaybackUsesSelectedRateWhenStartingAndResuming() async {
        let harness = makeHarness()

        harness.player.setPlaybackRate(1.5)
        harness.player.play(in: testSurah, from: 1)
        await waitUntil("playback starts") { harness.player.playbackState == .playing }

        XCTAssertEqual(harness.audioPlayer.playRates, [1.5])

        harness.player.pause()
        harness.player.resume()
        XCTAssertEqual(harness.audioPlayer.playRates, [1.5, 1.5])
    }

    func testChangingPlaybackRateDuringPlaybackAppliesImmediatelyWithoutRestarting() async {
        let harness = makeHarness()

        harness.player.play(in: testSurah, from: 1)
        await waitUntil("playback starts") { harness.player.playbackState == .playing }

        harness.player.setPlaybackRate(0.75)

        XCTAssertEqual(harness.player.playbackRate, 0.75, accuracy: 0.001)
        XCTAssertEqual(harness.audioPlayer.playbackRate, 0.75, accuracy: 0.001)
        XCTAssertEqual(harness.audioPlayer.playCount, 1)
        XCTAssertEqual(harness.audioPlayer.preparedURLs.count, 1)
        XCTAssertEqual(harness.resolver.requests, [.ayah(surah: 1, ayah: 1)])
    }

    func testProgressCallbackUpdatesPlayerAndResetsOnStop() async {
        let harness = makeHarness()
        harness.player.play(in: testSurah, from: 1)
        await waitUntil("playback starts") { harness.player.playbackState == .playing }

        harness.audioPlayer.onProgress?(0.5)
        harness.audioPlayer.onTimingUpdate?(12, 40)
        XCTAssertEqual(harness.player.progress, 0.5, accuracy: 0.001)
        XCTAssertEqual(harness.player.elapsedSeconds, 12, accuracy: 0.001)
        XCTAssertEqual(harness.player.durationSeconds, 40, accuracy: 0.001)
        XCTAssertEqual(harness.player.remainingSeconds ?? -1, 28, accuracy: 0.001)

        harness.player.stop()
        XCTAssertEqual(harness.player.progress, 0)
        XCTAssertEqual(harness.player.elapsedSeconds, 0)
        XCTAssertEqual(harness.player.durationSeconds, 0)
        XCTAssertNil(harness.player.remainingSeconds)
    }

    func testEndOfSurahAutoAdvancesToNextSurah() async {
        let second = testSecondSurah
        let harness = makeHarness(quran: testQuran([testSurah, second]))

        harness.player.play(in: testSurah, from: 3)
        await waitUntil("last ayah starts") {
            harness.player.playbackState == .playing
        }

        harness.audioPlayer.onEnded?()
        await waitUntil("next surah request is queued") {
            harness.resolver.requests.contains(.ayah(surah: 2, ayah: 1))
        }

        XCTAssertEqual(harness.player.playingKey, "2:1")
        XCTAssertEqual(harness.player.currentSurah?.number, 2)
        XCTAssertEqual(harness.player.playingAyahNumber, 1)
    }

    func testFinalSurahEndStopsPlayback() async {
        let harness = makeHarness(quran: testQuran([testSurah]))

        harness.player.play(in: testSurah, from: 3)
        await waitUntil("last ayah starts") {
            harness.player.playbackState == .playing
        }

        harness.audioPlayer.onEnded?()
        XCTAssertEqual(harness.player.playbackState, .idle)
        XCTAssertNil(harness.player.playingKey)
        XCTAssertNil(harness.player.currentSurah)
    }

    func testChapterEndAutoAdvancesToNextSurah() async {
        let second = testSecondSurah
        let harness = makeHarness(quran: testQuran([testSurah, second]))

        harness.player.playChapter(in: testSurah)
        await waitUntil("chapter starts") {
            harness.player.playbackState == .playing
        }

        harness.audioPlayer.onEnded?()
        await waitUntil("next chapter request is queued") {
            harness.resolver.requests.contains(.chapter(surah: 2))
        }

        XCTAssertEqual(harness.player.playingKey, "2:chapter")
        XCTAssertEqual(harness.player.currentSurah?.number, 2)
    }

    func testTransportControlsCanCrossSurahBoundaries() async {
        let second = testSecondSurah
        let harness = makeHarness(quran: testQuran([testSurah, second]))

        harness.player.play(in: testSurah, from: 3)
        await waitUntil("last ayah starts") {
            harness.player.playbackState == .playing
        }

        XCTAssertTrue(harness.player.canPlayNextAyah)
        XCTAssertTrue(harness.player.playNextAyah())
        XCTAssertEqual(harness.player.playingKey, "2:1")

        await waitUntil("next surah starts") {
            harness.player.playbackState == .playing && harness.player.currentSurah?.number == 2
        }

        XCTAssertTrue(harness.player.canPlayPreviousAyah)
        XCTAssertTrue(harness.player.playPreviousAyah())
        XCTAssertEqual(harness.player.playingKey, "1:3")
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

    private var testSecondSurah: Surah {
        Surah(number: 2,
              arabicName: "البقرة",
              englishName: "Al-Baqarah",
              translation: "The Cow",
              revelation: "Medinan",
              ayahs: [
                Ayah(number: 1, arabic: "d", english: "four"),
                Ayah(number: 2, arabic: "e", english: "five")
              ])
    }

    // MARK: Chapter recording — start from a chosen ayah

    func testChapterStartsAtChosenAyahWhenTimingAvailable() async {
        let harness = makeHarness(timingMilliseconds: 5000)
        harness.player.playChapter(in: testSurah, fromAyah: 2)
        await waitUntil("prepared with seek") { harness.audioPlayer.seekToMsValues == [5000] }
        XCTAssertEqual(harness.audioPlayer.seekToMsValues, [5000])
        XCTAssertEqual(harness.audioPlayer.playCount, 1)
    }

    func testChapterFromFirstAyahDoesNotSeek() async {
        let harness = makeHarness(timingMilliseconds: 5000)
        harness.player.playChapter(in: testSurah, fromAyah: 1)
        await waitUntil("prepared") { harness.audioPlayer.preparedURLs.count == 1 }
        XCTAssertEqual(harness.audioPlayer.seekToMsValues, [nil])
    }

    func testChapterWithoutTimingPlaysFromStart() async {
        let harness = makeHarness(timingMilliseconds: nil)
        harness.player.playChapter(in: testSurah, fromAyah: 2)
        await waitUntil("prepared") { harness.audioPlayer.preparedURLs.count == 1 }
        XCTAssertEqual(harness.audioPlayer.seekToMsValues, [nil])
    }

    func testPerAyahPlaybackNeverSeeks() async {
        let harness = makeHarness(timingMilliseconds: 5000)
        harness.player.play(in: testSurah, from: 2)
        await waitUntil("prepared") { harness.audioPlayer.preparedURLs.count == 1 }
        XCTAssertEqual(harness.audioPlayer.seekToMsValues, [nil])
    }

    private func testQuran(_ surahs: [Surah]) -> QuranData {
        QuranData(bismillah: Bismillah(arabic: "", english: ""), surahs: surahs)
    }

    private func makeHarness(result: Result<URL, Error> = .success(URL(string: "https://example.com/audio.mp3")!),
                             delayedResolver: Bool = false,
                             timingMilliseconds: Int? = nil,
                             quran: QuranData? = nil,
                             resetPlaybackRatePreference: Bool = true) -> Harness {
        if resetPlaybackRatePreference {
            UserDefaults.standard.removeObject(forKey: AyahPlayer.playbackRateStorageKey)
        }
        let session = FakeAudioSessionManager()
        let resolver = FakeAudioURLResolver()
        resolver.immediateResult = delayedResolver ? nil : result
        let audioPlayer = FakeQuranAudioPlayer()
        let player = AyahPlayer(audioSession: session,
                                urlResolver: resolver,
                                audioPlayer: audioPlayer,
                                timingProvider: StubChapterVerseTimings(milliseconds: timingMilliseconds),
                                quran: quran ?? testQuran([testSurah]))
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
