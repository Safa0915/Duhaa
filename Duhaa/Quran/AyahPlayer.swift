import Foundation
import AVFoundation
import Observation

/// Streams per-ayah Quran recitation from the Quran Foundation CDN (the user's
/// chosen reciter) and auto-advances through the surah. Network-dependent; fails
/// quietly when offline. Reader-scoped (@State in SurahReaderView) so it stops
/// when you leave the surah.
@Observable
final class AyahPlayer {
    /// The ayah currently playing as "surah:ayah", or nil when stopped.
    private(set) var playingKey: String?
    /// True while the next clip is still buffering.
    private(set) var isBuffering = false

    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var statusObs: NSKeyValueObservation?
    @ObservationIgnored private var surah: Surah?
    @ObservationIgnored private var playbackTask: Task<Void, Never>?

    func isPlaying(_ surahNumber: Int, _ ayahNumber: Int) -> Bool {
        playingKey == key(surahNumber, ayahNumber)
    }

    var isActive: Bool { playingKey != nil }

    var playingAyahNumber: Int? {
        guard let playingKey else { return nil }
        return Int(playingKey.split(separator: ":").last ?? "")
    }

    func isPlayingChapter(_ surahNumber: Int) -> Bool {
        playingKey == chapterKey(surahNumber)
    }

    /// Tap a single ayah: toggles play/stop for it (then auto-advances).
    func toggle(in surah: Surah, ayah: Ayah) {
        if isPlaying(surah.number, ayah.number) { stop() }
        else { play(in: surah, from: ayah.number) }
    }

    /// Play (or restart) the surah from a given ayah.
    func play(in surah: Surah, from ayahNumber: Int) {
        self.surah = surah
        configureSession()
        startItem(surah: surah.number, ayah: ayahNumber)
    }

    func playChapter(in surah: Surah) {
        self.surah = nil
        configureSession()
        startChapter(surah: surah.number)
    }

    func stop() {
        player?.pause()
        cleanupObservers()
        player?.replaceCurrentItem(with: nil)
        player = nil
        playingKey = nil
        isBuffering = false
        deactivateSession()
    }

    // MARK: Internals

    private func startItem(surah surahNumber: Int, ayah ayahNumber: Int) {
        cleanupObservers()
        playingKey = key(surahNumber, ayahNumber)
        isBuffering = true

        guard let remoteURL = Self.ayahURL(surah: surahNumber, ayah: ayahNumber) else {
            stop()
            return
        }

        let expectedKey = playingKey
        playbackTask = Task { @MainActor [weak self] in
            let playableURL = await QuranAudioCache.playableURL(for: remoteURL)
            guard let self, self.playingKey == expectedKey, !Task.isCancelled else { return }
            self.startPlayerItem(url: playableURL) { [weak self] in
                self?.advance()
            }
        }
    }

    private func startChapter(surah surahNumber: Int) {
        cleanupObservers()
        playingKey = chapterKey(surahNumber)
        isBuffering = true

        guard let remoteURL = Self.chapterURL(surah: surahNumber) else {
            stop()
            return
        }

        let expectedKey = playingKey
        playbackTask = Task { @MainActor [weak self] in
            let playableURL = await QuranAudioCache.playableURL(for: remoteURL)
            guard let self, self.playingKey == expectedKey, !Task.isCancelled else { return }
            self.startPlayerItem(url: playableURL) { [weak self] in
                self?.stop()
            }
        }
    }

    private func startPlayerItem(url: URL, onEnd: @escaping () -> Void) {
        let item = AVPlayerItem(url: url)
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { _ in onEnd() }

        statusObs = item.observe(\.status) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay: self?.isBuffering = false
                case .failed:      self?.stop()
                default:           break
                }
            }
        }

        if player == nil {
            player = AVPlayer(playerItem: item)
        } else {
            player?.replaceCurrentItem(with: item)
        }
        player?.play()
    }

    /// Move to the next ayah, or stop at the end of the surah.
    private func advance() {
        guard let surah, let playingKey,
              let ayah = Int(playingKey.split(separator: ":").last ?? "") else { stop(); return }
        let next = ayah + 1
        if next <= surah.ayahs.count {
            startItem(surah: surah.number, ayah: next)
        } else {
            stop()
        }
    }

    private func cleanupObservers() {
        playbackTask?.cancel()
        playbackTask = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        statusObs?.invalidate()
        statusObs = nil
    }

    private func configureSession() {
        // Play through the silent switch, like a media app, and duck other audio.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func key(_ s: Int, _ a: Int) -> String { "\(s):\(a)" }
    private func chapterKey(_ s: Int) -> String { "\(s):chapter" }

    /// Per-ayah MP3 on the Quran Foundation CDN: SSSAAA.mp3 under the selected
    /// reciter's verified prefix. Read per-item so a reciter change in the
    /// reader's menu applies from the very next ayah.
    static func url(surah: Int, ayah: Int) -> URL {
        ayahURL(surah: surah, ayah: ayah) ?? URL(string: "https://verses.quran.com/Alafasy/mp3/\(String(format: "%03d%03d", surah, ayah)).mp3")!
    }

    static func ayahURL(surah: Int, ayah: Int) -> URL? {
        let id = UserDefaults.standard.object(forKey: "duhaa.quran.reciter") as? Int ?? Reciters.defaultID
        let reciter = Reciters.byID(id) ?? Reciters.byID(Reciters.defaultID)
        return reciter?.ayahURL(surah: surah, ayah: ayah)
    }

    static func chapterURL(surah: Int) -> URL? {
        let id = UserDefaults.standard.object(forKey: "duhaa.quran.reciter") as? Int ?? Reciters.defaultID
        return Reciters.byID(id)?.chapterURL(surah: surah)
    }

    deinit { stop() }
}
