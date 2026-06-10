import Foundation
import AVFoundation
import Observation

/// Streams per-ayah Quran recitation (Mishary Rashid Alafasy) and auto-advances
/// through the surah. Network-dependent; fails quietly when offline. Reader-scoped
/// (@State in SurahReaderView) so it stops when you leave the surah.
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

    func isPlaying(_ surahNumber: Int, _ ayahNumber: Int) -> Bool {
        playingKey == key(surahNumber, ayahNumber)
    }

    var isActive: Bool { playingKey != nil }

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

        let item = AVPlayerItem(url: Self.url(surah: surahNumber, ayah: ayahNumber))
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in self?.advance() }

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

    /// Per-ayah MP3 (everyayah.com, Alafasy 128kbps): files are SSSAAA.mp3.
    static func url(surah: Int, ayah: Int) -> URL {
        let name = String(format: "%03d%03d", surah, ayah)
        return URL(string: "https://everyayah.com/data/Alafasy_128kbps/\(name).mp3")!
    }

    deinit { stop() }
}
