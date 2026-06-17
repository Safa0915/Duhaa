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

    func prepare(url: URL) async throws
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

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?

    func prepare(url: URL) async throws {
        cleanupObservers()
        FirstUseDiagnostics.event("Quran buffering started", url.absoluteString)

        let item = FirstUseDiagnostics.measure("Quran AVPlayerItem creation", url.absoluteString) {
            AVPlayerItem(url: url)
        }

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

        timeControlObservation = player?.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            guard player.timeControlStatus == .playing else { return }
            Task { @MainActor in
                FirstUseDiagnostics.event("Quran first playback observed")
                self?.onFirstPlayback?()
            }
        }
    }

    func play() {
        FirstUseDiagnostics.event("Quran play() called")
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func stop() {
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
    }
}

/// Streams per-ayah Quran recitation from the Quran Foundation CDN (the user's
/// chosen reciter) and auto-advances through the surah. Reader-scoped
/// (`@State` in SurahReaderView) so it stops when you leave the surah.
@MainActor
@Observable
final class AyahPlayer {
    /// The ayah currently playing as "surah:ayah", or nil when stopped.
    private(set) var playingKey: String?
    private(set) var playbackState: QuranAudioPlaybackState = .idle
    private(set) var failureMessage: String?

    @ObservationIgnored private let audioSession: QuranAudioSessionManaging
    @ObservationIgnored private let urlResolver: QuranAudioURLResolving
    @ObservationIgnored private let audioPlayer: QuranAudioPlaying
    @ObservationIgnored private var surah: Surah?
    @ObservationIgnored private var playbackTask: Task<Void, Never>?
    @ObservationIgnored private var generation = 0

    init(audioSession: QuranAudioSessionManaging = LiveQuranAudioSessionManager(),
         urlResolver: QuranAudioURLResolving = LiveQuranAudioURLResolver(),
         audioPlayer: QuranAudioPlaying? = nil) {
        FirstUseDiagnostics.event("Quran audio controller init start")
        self.audioSession = audioSession
        self.urlResolver = urlResolver
        self.audioPlayer = audioPlayer ?? AVQuranAudioPlayer()
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
        guard let playingKey else { return nil }
        return Int(playingKey.split(separator: ":").last ?? "")
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
        self.surah = surah
        beginPlayback(.ayah(surah: surah.number, ayah: ayahNumber))
    }

    func playChapter(in surah: Surah) {
        self.surah = nil
        beginPlayback(.chapter(surah: surah.number))
    }

    func pause() {
        playbackTask?.cancel()
        audioPlayer.pause()
        playbackState = .paused
    }

    func stop() {
        generation += 1
        playbackTask?.cancel()
        playbackTask = nil
        audioPlayer.stop()
        playingKey = nil
        playbackState = .idle
        failureMessage = nil
        Task { [audioSession] in
            await audioSession.deactivate()
        }
    }

    // MARK: Internals

    private func beginPlayback(_ request: QuranAudioRequest) {
        generation += 1
        let currentGeneration = generation
        playbackTask?.cancel()
        failureMessage = nil
        playingKey = request.key
        playbackState = .loading
        FirstUseDiagnostics.event("Quran play button tapped", request.key)
        FirstUseDiagnostics.event("Quran loading UI shown", request.key)

        playbackTask = Task { [weak self] in
            await Task.yield()
            await self?.prepareAndPlay(request, generation: currentGeneration)
        }
    }

    private func prepareAndPlay(_ request: QuranAudioRequest, generation: Int) async {
        FirstUseDiagnostics.event("Quran first async startup begins", request.key)

        do {
            guard isCurrent(generation, request) else { return }
            try await audioSession.configureAndActivate()
            guard isCurrent(generation, request) else { return }

            let playableURL = try await urlResolver.resolveURL(for: request)
            guard isCurrent(generation, request) else { return }

            playbackState = .buffering
            try await audioPlayer.prepare(url: playableURL)
            guard isCurrent(generation, request) else { return }

            audioPlayer.play()
        } catch is CancellationError {
            return
        } catch {
            fail(error)
        }
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
    }

    private func advanceOrStop() {
        guard let surah,
              let playingKey,
              let ayah = Int(playingKey.split(separator: ":").last ?? "") else {
            stop()
            return
        }
        let next = ayah + 1
        if next <= surah.ayahs.count {
            beginPlayback(.ayah(surah: surah.number, ayah: next))
        } else {
            stop()
        }
    }

    private func fail(_ error: Error) {
        generation += 1
        playbackTask?.cancel()
        playbackTask = nil
        audioPlayer.stop()
        playingKey = nil
        let message = (error as? LocalizedError)?.errorDescription ?? "Couldn’t start this recitation."
        failureMessage = message
        playbackState = .failed(message)
        FirstUseDiagnostics.event("Quran audio failed", message)
    }

    private func isCurrent(_ generation: Int, _ request: QuranAudioRequest) -> Bool {
        !Task.isCancelled && self.generation == generation && playingKey == request.key
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
