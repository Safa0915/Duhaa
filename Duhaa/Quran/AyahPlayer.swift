import AVFoundation
import Foundation
import Observation

enum QuranAudioPlaybackState: Equatable {
    case idle
    case loading
    case buffering
    case ready
    case playing
    case paused
    case failed(String)
}

enum QuranAudioRequest: Equatable {
    case ayah(surah: Int, ayah: Int)
    case chapter(surah: Int)

    var key: String {
        switch self {
        case .ayah(let surah, let ayah):
            return "\(surah):\(ayah)"
        case .chapter(let surah):
            return "\(surah):chapter"
        }
    }

    var surahNumber: Int {
        switch self {
        case .ayah(let surah, _), .chapter(let surah):
            return surah
        }
    }

    var ayahNumber: Int? {
        switch self {
        case .ayah(_, let ayah):
            return ayah
        case .chapter:
            return nil
        }
    }
}

enum QuranAudioError: Error, Equatable, LocalizedError {
    case missingURL
    case playerFailed

    var errorDescription: String? {
        switch self {
        case .missingURL:
            return "Couldn’t find audio for this recitation."
        case .playerFailed:
            return "Couldn’t start this recitation."
        }
    }
}

protocol QuranAudioSessionManaging {
    func configureAndActivate() async throws
    func deactivate() async
}

protocol QuranAudioURLResolving {
    func resolveURL(for request: QuranAudioRequest) async throws -> URL
}

@MainActor
protocol QuranAudioPlaying: AnyObject {
    var onReady: (() -> Void)? { get set }
    var onFailed: ((Error) -> Void)? { get set }
    var onEnded: (() -> Void)? { get set }
    var onFirstPlayback: (() -> Void)? { get set }
    /// Fractional progress (0...1) through the current item, for the player scrubber.
    var onProgress: ((Double) -> Void)? { get set }
    /// Current playback time and item duration, in seconds.
    var onTimingUpdate: ((TimeInterval, TimeInterval) -> Void)? { get set }

    /// Prepare `url` for playback, optionally starting at `seekToMs` milliseconds
    /// in (used to begin a full-surah recording at a chosen ayah).
    func prepare(url: URL, seekToMs: Int?) async throws
    func setPlaybackRate(_ rate: Float)
    func play()
    func pause()
    func stop()
}

struct LiveQuranAudioSessionManager: QuranAudioSessionManaging {
    func configureAndActivate() async throws {
        let configureToken = FirstUseDiagnostics.begin("Quran audio session configure")
        do {
            try await Task.detached(priority: .userInitiated) {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            }.value
            FirstUseDiagnostics.end("Quran audio session configure", token: configureToken)
        } catch {
            FirstUseDiagnostics.end("Quran audio session configure", token: configureToken, "failed")
            throw error
        }

        let activateToken = FirstUseDiagnostics.begin("Quran audio session activate")
        do {
            try await Task.detached(priority: .userInitiated) {
                try AVAudioSession.sharedInstance().setActive(true)
            }.value
            FirstUseDiagnostics.end("Quran audio session activate", token: activateToken)
        } catch {
            FirstUseDiagnostics.end("Quran audio session activate", token: activateToken, "failed")
            throw error
        }
    }

    func deactivate() async {
        await Task.detached(priority: .utility) {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }.value
    }
}

struct LiveQuranAudioURLResolver: QuranAudioURLResolving {
    func resolveURL(for request: QuranAudioRequest) async throws -> URL {
        let resolveToken = FirstUseDiagnostics.begin("Quran reciter/audio URL resolve", request.key)
        let remoteURL = await Task.detached(priority: .userInitiated) {
            switch request {
            case .ayah(let surah, let ayah):
                return AyahPlayer.ayahURL(surah: surah, ayah: ayah)
            case .chapter(let surah):
                return AyahPlayer.chapterURL(surah: surah)
            }
        }.value
        FirstUseDiagnostics.end("Quran reciter/audio URL resolve", token: resolveToken)

        guard let remoteURL else { throw QuranAudioError.missingURL }

        // Offline-first: a permanently-downloaded ayah plays with no network.
        if let offlineURL = QuranOfflineStore.localURLIfDownloaded(for: remoteURL) {
            return offlineURL
        }

        let cacheToken = FirstUseDiagnostics.begin("Quran cache lookup", remoteURL.absoluteString)
        let playableURL = await QuranAudioCache.playableURL(for: remoteURL)
        FirstUseDiagnostics.end("Quran cache lookup", token: cacheToken)
        return playableURL
    }
}

@MainActor
final class AVQuranAudioPlayer: NSObject, QuranAudioPlaying {
    var onReady: (() -> Void)?
    var onFailed: ((Error) -> Void)?
    var onEnded: (() -> Void)?
    var onFirstPlayback: (() -> Void)?
    var onProgress: ((Double) -> Void)?
    var onTimingUpdate: ((TimeInterval, TimeInterval) -> Void)?

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var timeObserverToken: Any?
    private var playbackRate: Float = 1
    private var wantsPlayback = false

    func prepare(url: URL, seekToMs: Int?) async throws {
        cleanupObservers()
        FirstUseDiagnostics.event("Quran buffering started", url.absoluteString)

        let item = FirstUseDiagnostics.measure("Quran AVPlayerItem creation", url.absoluteString) {
            AVPlayerItem(url: url)
        }
        item.audioTimePitchAlgorithm = .spectral

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onEnded?()
            }
        }

        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                switch item.status {
                case .readyToPlay:
                    FirstUseDiagnostics.event("Quran player item ready")
                    self?.onReady?()
                case .failed:
                    FirstUseDiagnostics.event("Quran player item failed",
                                              item.error?.localizedDescription ?? "")
                    self?.onFailed?(item.error ?? QuranAudioError.playerFailed)
                default:
                    FirstUseDiagnostics.event("Quran player item waiting")
                }
            }
        }

        if player == nil {
            FirstUseDiagnostics.measure("Quran AVPlayer creation") {
                player = AVPlayer(playerItem: item)
            }
        } else {
            player?.replaceCurrentItem(with: item)
        }

        // Begin mid-file when asked (chapter recording started at a chosen ayah).
        // AVPlayer defers the seek until the item is ready, then plays from there.
        if let seekToMs {
            let target = CMTime(value: CMTimeValue(seekToMs), timescale: 1000)
            await player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        timeControlObservation = player?.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            guard player.timeControlStatus == .playing else { return }
            Task { @MainActor in
                FirstUseDiagnostics.event("Quran first playback observed")
                self?.onFirstPlayback?()
            }
        }

        addPeriodicTimeObserverIfNeeded()
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = max(0.5, min(2, rate))
        applyPlaybackRateIfNeeded()
    }

    private func applyPlaybackRateIfNeeded(force: Bool = false) {
        guard wantsPlayback, let player else { return }
        guard force || player.timeControlStatus == .playing || player.timeControlStatus == .waitingToPlayAtSpecifiedRate else {
            return
        }
        player.playImmediately(atRate: playbackRate)
    }

    private func addPeriodicTimeObserverIfNeeded() {
        guard timeObserverToken == nil, let player else { return }
        // 0.1s keeps word-by-word highlighting in step with the recitation.
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            // The observer fires on the main queue, so we're already main-actor.
            MainActor.assumeIsolated {
                guard let self, let item = self.player?.currentItem else { return }
                let duration = item.duration.seconds
                guard duration.isFinite, duration > 0 else { return }
                let elapsed = max(0, min(time.seconds, duration))
                self.onProgress?(max(0, min(1, elapsed / duration)))
                self.onTimingUpdate?(elapsed, duration)
            }
        }
    }

    func play() {
        FirstUseDiagnostics.event("Quran play() called")
        wantsPlayback = true
        applyPlaybackRateIfNeeded(force: true)
    }

    func pause() {
        wantsPlayback = false
        player?.pause()
    }

    func stop() {
        wantsPlayback = false
        player?.pause()
        cleanupObservers()
        player?.replaceCurrentItem(with: nil)
    }

    private func cleanupObservers() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        statusObservation?.invalidate()
        statusObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        if let timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
}

/// Streams per-ayah Quran recitation from the Quran Foundation CDN (the user's
/// chosen reciter) and auto-advances through the surah. Reader-scoped
/// (`@State` in SurahReaderView) so it stops when you leave the surah.
@MainActor
@Observable
final class AyahPlayer {
    static let availablePlaybackRates: [Double] = [0.75, 1.0, 1.25, 1.5]
    static let playbackRateStorageKey = "duhaa.quran.playbackRate"

    /// The ayah currently playing as "surah:ayah", or nil when stopped.
    private(set) var playingKey: String?
    private(set) var playbackState: QuranAudioPlaybackState = .idle
    private(set) var failureMessage: String?
    private(set) var playbackRate: Double
    /// Fractional progress (0...1) through the currently-playing ayah.
    private(set) var progress: Double = 0
    /// Current playback time and duration in seconds, when the audio item exposes them.
    private(set) var elapsedSeconds: TimeInterval = 0
    private(set) var durationSeconds: TimeInterval = 0
    /// The active surah for the current audio request. This can advance beyond
    /// the reader screen when autoplay crosses into the next surah.
    private(set) var currentSurah: Surah?
    private(set) var currentRequest: QuranAudioRequest?

    @ObservationIgnored private let audioSession: QuranAudioSessionManaging
    @ObservationIgnored private let urlResolver: QuranAudioURLResolving
    @ObservationIgnored private let audioPlayer: QuranAudioPlaying
    @ObservationIgnored private let timingProvider: ChapterVerseTimingProviding
    @ObservationIgnored private let quran: QuranData
    @ObservationIgnored private var playbackTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0

    init(audioSession: QuranAudioSessionManaging = LiveQuranAudioSessionManager(),
         urlResolver: QuranAudioURLResolving = LiveQuranAudioURLResolver(),
         audioPlayer: QuranAudioPlaying? = nil,
         timingProvider: ChapterVerseTimingProviding = LiveChapterVerseTimings(),
         quran: QuranData = Quran.shared) {
        FirstUseDiagnostics.event("Quran audio controller init start")
        self.audioSession = audioSession
        self.urlResolver = urlResolver
        self.audioPlayer = audioPlayer ?? AVQuranAudioPlayer()
        self.timingProvider = timingProvider
        self.quran = quran
        playbackRate = Self.storedPlaybackRate()
        self.audioPlayer.setPlaybackRate(Float(playbackRate))
        wirePlayerCallbacks()
        FirstUseDiagnostics.event("Quran audio controller init end")
    }

    func isPlaying(_ surahNumber: Int, _ ayahNumber: Int) -> Bool {
        playingKey == key(surahNumber, ayahNumber)
    }

    var isActive: Bool {
        playingKey != nil
    }

    var isLoading: Bool {
        switch playbackState {
        case .loading, .buffering:
            return true
        default:
            return false
        }
    }

    /// Kept for the existing reader UI.
    var isBuffering: Bool { isLoading }

    var playingAyahNumber: Int? {
        currentRequest?.ayahNumber
    }

    var isPlayingChapterRecording: Bool {
        switch currentRequest {
        case .some(.chapter(_)):
            return true
        default:
            return false
        }
    }

    var remainingSeconds: TimeInterval? {
        guard durationSeconds.isFinite, durationSeconds > 0 else { return nil }
        return max(0, durationSeconds - elapsedSeconds)
    }

    func isPlayingChapter(_ surahNumber: Int) -> Bool {
        playingKey == chapterKey(surahNumber)
    }

    /// Tap a single ayah: toggles play/stop for it (then auto-advances).
    func toggle(in surah: Surah, ayah: Ayah) {
        if isPlaying(surah.number, ayah.number) {
            stop()
        } else {
            play(in: surah, from: ayah.number)
        }
    }

    /// Play (or restart) the surah from a given ayah.
    func play(in surah: Surah, from ayahNumber: Int) {
        let clampedAyah = min(max(ayahNumber, 1), surah.ayahs.count)
        beginPlayback(.ayah(surah: surah.number, ayah: clampedAyah), in: surah)
    }

    /// Play a full-surah recording. `fromAyah` (for reciters with gapless timing)
    /// starts it at that ayah by seeking; nil plays from the beginning.
    func playChapter(in surah: Surah, fromAyah ayahNumber: Int? = nil) {
        beginPlayback(.chapter(surah: surah.number), in: surah, seekAyah: ayahNumber)
    }

    func pause() {
        playbackTask?.cancel()
        audioPlayer.pause()
        playbackState = .paused
    }

    /// Resume a paused ayah (no-op unless paused on an active ayah).
    func resume() {
        guard isActive, playbackState == .paused else { return }
        audioPlayer.play()
        playbackState = .playing
    }

    func setPlaybackRate(_ rate: Double) {
        let sanitizedRate = Self.sanitizedPlaybackRate(rate)
        playbackRate = sanitizedRate
        UserDefaults.standard.set(sanitizedRate, forKey: Self.playbackRateStorageKey)
        audioPlayer.setPlaybackRate(Float(sanitizedRate))
    }

    /// One button for the immersive player: pause when playing, resume when
    /// paused, or (re)start the surah when idle/failed.
    func togglePlayPause() {
        switch playbackState {
        case .playing, .ready, .loading, .buffering:
            pause()
        case .paused:
            resume()
        case .idle, .failed:
            restartCurrentRequest()
        }
    }

    var canPlayPreviousAyah: Bool {
        guard let currentSurah, let ayah = playingAyahNumber else { return false }
        return ayah > 1 || previousSurah(before: currentSurah.number) != nil
    }

    var canPlayNextAyah: Bool {
        guard let currentSurah, let ayah = playingAyahNumber else { return false }
        return ayah < currentSurah.ayahs.count || nextSurah(after: currentSurah.number) != nil
    }

    var canPlayPreviousItem: Bool {
        guard let currentSurah else { return false }
        if isPlayingChapterRecording {
            return previousSurah(before: currentSurah.number) != nil
        }
        return canPlayPreviousAyah
    }

    var canPlayNextItem: Bool {
        guard let currentSurah else { return false }
        if isPlayingChapterRecording {
            return nextSurah(after: currentSurah.number) != nil
        }
        return canPlayNextAyah
    }

    @discardableResult
    func playPreviousAyah() -> Bool {
        guard let currentSurah, let ayah = playingAyahNumber else { return false }
        if ayah > 1 {
            play(in: currentSurah, from: ayah - 1)
            return true
        }
        guard let previous = previousSurah(before: currentSurah.number),
              let lastAyah = previous.ayahs.last?.number else { return false }
        play(in: previous, from: lastAyah)
        return true
    }

    @discardableResult
    func playNextAyah() -> Bool {
        guard let currentSurah, let ayah = playingAyahNumber else { return false }
        if ayah < currentSurah.ayahs.count {
            play(in: currentSurah, from: ayah + 1)
            return true
        }
        guard let next = nextSurah(after: currentSurah.number) else { return false }
        play(in: next, from: 1)
        return true
    }

    @discardableResult
    func playPreviousItem() -> Bool {
        if isPlayingChapterRecording {
            guard let currentSurah,
                  let previous = previousSurah(before: currentSurah.number) else { return false }
            playChapter(in: previous)
            return true
        }
        return playPreviousAyah()
    }

    @discardableResult
    func playNextItem() -> Bool {
        if isPlayingChapterRecording {
            guard let currentSurah,
                  let next = nextSurah(after: currentSurah.number) else { return false }
            playChapter(in: next)
            return true
        }
        return playNextAyah()
    }

    func stop() {
        generation += 1
        playbackTask?.cancel()
        playbackTask = nil
        audioPlayer.stop()
        playingKey = nil
        currentRequest = nil
        currentSurah = nil
        playbackState = .idle
        failureMessage = nil
        progress = 0
        elapsedSeconds = 0
        durationSeconds = 0
        Task { [audioSession] in
            await audioSession.deactivate()
        }
    }

    // MARK: Internals

    private func beginPlayback(_ request: QuranAudioRequest, in surah: Surah? = nil, seekAyah: Int? = nil) {
        generation += 1
        let currentGeneration = generation
        playbackTask?.cancel()
        failureMessage = nil
        playingKey = request.key
        currentRequest = request
        currentSurah = surah ?? currentSurah(for: request.surahNumber)
        playbackState = .loading
        progress = 0
        elapsedSeconds = 0
        durationSeconds = 0
        FirstUseDiagnostics.event("Quran play button tapped", request.key)
        FirstUseDiagnostics.event("Quran loading UI shown", request.key)

        playbackTask = Task { [weak self] in
            await Task.yield()
            await self?.prepareAndPlay(request, generation: currentGeneration, seekAyah: seekAyah)
        }
    }

    private func prepareAndPlay(_ request: QuranAudioRequest, generation: Int, seekAyah: Int?) async {
        FirstUseDiagnostics.event("Quran first async startup begins", request.key)

        do {
            guard isCurrent(generation, request) else { return }
            try await audioSession.configureAndActivate()
            guard isCurrent(generation, request) else { return }

            let playableURL = try await urlResolver.resolveURL(for: request)
            guard isCurrent(generation, request) else { return }

            let seekToMs = await chapterSeekMilliseconds(for: request, seekAyah: seekAyah)
            guard isCurrent(generation, request) else { return }

            playbackState = .buffering
            try await audioPlayer.prepare(url: playableURL, seekToMs: seekToMs)
            guard isCurrent(generation, request) else { return }

            audioPlayer.play()
        } catch is CancellationError {
            return
        } catch {
            fail(error)
        }
    }

    /// For a chapter recording asked to start past ayah 1, the ms offset of that
    /// ayah from the user's reciter timing data (nil → play from the start).
    private func chapterSeekMilliseconds(for request: QuranAudioRequest, seekAyah: Int?) async -> Int? {
        guard case .chapter(let surah) = request, let seekAyah, seekAyah > 1 else { return nil }
        let reciterID = UserDefaults.standard.object(forKey: "duhaa.quran.reciter") as? Int ?? Reciters.defaultID
        return await timingProvider.startMilliseconds(reciterID: reciterID, surah: surah, ayah: seekAyah)
    }

    private func wirePlayerCallbacks() {
        audioPlayer.onReady = { [weak self] in
            guard let self, self.isActive else { return }
            self.playbackState = .ready
            FirstUseDiagnostics.event("Quran first audio ready", self.playingKey ?? "")
        }
        audioPlayer.onFirstPlayback = { [weak self] in
            guard let self, self.isActive else { return }
            self.playbackState = .playing
        }
        audioPlayer.onFailed = { [weak self] error in
            self?.fail(error)
        }
        audioPlayer.onEnded = { [weak self] in
            self?.advanceOrStop()
        }
        audioPlayer.onProgress = { [weak self] value in
            guard let self, self.isActive else { return }
            self.progress = value
        }
        audioPlayer.onTimingUpdate = { [weak self] elapsed, duration in
            guard let self, self.isActive else { return }
            self.elapsedSeconds = max(0, elapsed)
            self.durationSeconds = max(0, duration)
        }
    }

    private func advanceOrStop() {
        guard let request = currentRequest else {
            stop()
            return
        }

        switch request {
        case .ayah:
            guard let currentSurah, let ayah = request.ayahNumber else {
                stop()
                return
            }

            let nextAyah = ayah + 1
            if nextAyah <= currentSurah.ayahs.count {
                beginPlayback(.ayah(surah: currentSurah.number, ayah: nextAyah), in: currentSurah)
            } else if let nextSurah = nextSurah(after: currentSurah.number) {
                beginPlayback(.ayah(surah: nextSurah.number, ayah: 1), in: nextSurah)
            } else {
                stop()
            }
        case .chapter(let surahNumber):
            if let nextSurah = nextSurah(after: surahNumber) {
                beginPlayback(.chapter(surah: nextSurah.number), in: nextSurah)
            } else {
                stop()
            }
        }
    }

    private func currentSurah(for number: Int) -> Surah? {
        if currentSurah?.number == number {
            return currentSurah
        }
        return quran.surah(number)
    }

    private func nextSurah(after number: Int) -> Surah? {
        if let index = quran.surahs.firstIndex(where: { $0.number == number }),
           quran.surahs.indices.contains(index + 1) {
            return quran.surahs[index + 1]
        }
        return quran.surah(number + 1)
    }

    private func previousSurah(before number: Int) -> Surah? {
        if let index = quran.surahs.firstIndex(where: { $0.number == number }),
           quran.surahs.indices.contains(index - 1) {
            return quran.surahs[index - 1]
        } else {
            return quran.surah(number - 1)
        }
    }

    private func restartCurrentRequest() {
        guard let currentSurah else { return }
        switch currentRequest {
        case .ayah(_, let ayah):
            play(in: currentSurah, from: ayah)
        case .chapter:
            playChapter(in: currentSurah)
        case nil:
            play(in: currentSurah, from: 1)
        }
    }

    private func fail(_ error: Error) {
        generation += 1
        playbackTask?.cancel()
        playbackTask = nil
        audioPlayer.stop()
        playingKey = nil
        progress = 0
        elapsedSeconds = 0
        durationSeconds = 0
        let message = (error as? LocalizedError)?.errorDescription ?? "Couldn’t start this recitation."
        failureMessage = message
        playbackState = .failed(message)
        FirstUseDiagnostics.event("Quran audio failed", message)
    }

    private func isCurrent(_ generation: Int, _ request: QuranAudioRequest) -> Bool {
        !Task.isCancelled && self.generation == generation && playingKey == request.key
    }

    private static func storedPlaybackRate() -> Double {
        let storedRate = UserDefaults.standard.double(forKey: playbackRateStorageKey)
        guard storedRate > 0 else { return 1 }
        return sanitizedPlaybackRate(storedRate)
    }

    private static func sanitizedPlaybackRate(_ rate: Double) -> Double {
        availablePlaybackRates.min(by: { abs($0 - rate) < abs($1 - rate) }) ?? 1
    }

    private func key(_ surah: Int, _ ayah: Int) -> String { "\(surah):\(ayah)" }
    private func chapterKey(_ surah: Int) -> String { "\(surah):chapter" }

    /// Per-ayah MP3 on the Quran Foundation CDN: SSSAAA.mp3 under the selected
    /// reciter's verified prefix. Read per-item so a reciter change in the
    /// reader's menu applies from the very next ayah.
    nonisolated static func url(surah: Int, ayah: Int) -> URL {
        ayahURL(surah: surah, ayah: ayah)
            ?? URL(string: "https://verses.quran.com/Alafasy/mp3/\(String(format: "%03d%03d", surah, ayah)).mp3")!
    }

    nonisolated static func ayahURL(surah: Int, ayah: Int) -> URL? {
        let id = UserDefaults.standard.object(forKey: "duhaa.quran.reciter") as? Int ?? Reciters.defaultID
        let reciter = Reciters.byID(id) ?? Reciters.byID(Reciters.defaultID)
        return reciter?.ayahURL(surah: surah, ayah: ayah)
    }

    nonisolated static func chapterURL(surah: Int) -> URL? {
        let id = UserDefaults.standard.object(forKey: "duhaa.quran.reciter") as? Int ?? Reciters.defaultID
        return Reciters.byID(id)?.chapterURL(surah: surah)
    }

    deinit {
        playbackTask?.cancel()
        let audioPlayer = audioPlayer
        Task { @MainActor in
            audioPlayer.stop()
        }
    }
}
