import AVFoundation
import Foundation
import MediaPlayer
import UIKit

/// The metadata Duhaa publishes to the system "Now Playing" surfaces
/// (Lock Screen, Control Center, AirPods, CarPlay).
struct QuranNowPlayingInfo: Equatable {
    var title: String
    var artist: String
    var elapsedSeconds: TimeInterval
    var durationSeconds: TimeInterval?
    /// The live playback rate — 0 while paused, the user's chosen rate while playing.
    var playbackRate: Double
    var canGoNext: Bool
    var canGoPrevious: Bool
}

/// Seam between `AyahPlayer` and the system media services: publishes Now
/// Playing metadata and surfaces remote commands (Lock Screen / headphone
/// buttons) plus audio-session interruptions back to the player.
@MainActor
protocol QuranNowPlayingIntegrating: AnyObject {
    var onPlayCommand: (() -> Void)? { get set }
    var onPauseCommand: (() -> Void)? { get set }
    var onTogglePlayPauseCommand: (() -> Void)? { get set }
    var onNextTrackCommand: (() -> Void)? { get set }
    var onPreviousTrackCommand: (() -> Void)? { get set }
    /// A system interruption (phone call, Siri, another app's audio) started.
    var onInterruptionBegan: (() -> Void)? { get set }
    /// The interruption ended; `true` means the system suggests resuming.
    var onInterruptionEnded: ((_ shouldResume: Bool) -> Void)? { get set }
    /// The audio route lost its output (headphones unplugged) — convention is to pause.
    var onRouteDisconnected: (() -> Void)? { get set }

    func publish(_ info: QuranNowPlayingInfo)
    func clear()
}

/// Live implementation backed by `MPNowPlayingInfoCenter`,
/// `MPRemoteCommandCenter` and `AVAudioSession` notifications. Artwork is the
/// user's chosen listening ambience rendered by
/// `QuranListeningTheme.nowPlayingArtwork()` — the Lock Screen card matches
/// the in-app player.
@MainActor
final class LiveQuranNowPlayingCenter: QuranNowPlayingIntegrating {
    var onPlayCommand: (() -> Void)?
    var onPauseCommand: (() -> Void)?
    var onTogglePlayPauseCommand: (() -> Void)?
    var onNextTrackCommand: (() -> Void)?
    var onPreviousTrackCommand: (() -> Void)?
    var onInterruptionBegan: (() -> Void)?
    var onInterruptionEnded: ((Bool) -> Void)?
    var onRouteDisconnected: (() -> Void)?

    private var commandTargets: [(MPRemoteCommand, Any)] = []
    private var notificationObservers: [NSObjectProtocol] = []
    private var cachedArtwork: (theme: QuranListeningTheme, artwork: MPMediaItemArtwork)?

    init() {
        registerRemoteCommands()
        observeAudioSessionNotifications()
    }

    deinit {
        for (command, target) in commandTargets {
            command.removeTarget(target)
        }
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func publish(_ info: QuranNowPlayingInfo) {
        var nowPlaying: [String: Any] = [
            MPMediaItemPropertyTitle: info.title,
            MPMediaItemPropertyArtist: info.artist,
            MPMediaItemPropertyAlbumTitle: "Duhaa ضحى",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: info.elapsedSeconds,
            MPNowPlayingInfoPropertyPlaybackRate: info.playbackRate,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]
        if let duration = info.durationSeconds, duration.isFinite, duration > 0 {
            nowPlaying[MPMediaItemPropertyPlaybackDuration] = duration
        }
        nowPlaying[MPMediaItemPropertyArtwork] = ambienceArtwork()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlaying

        let center = MPRemoteCommandCenter.shared()
        center.nextTrackCommand.isEnabled = info.canGoNext
        center.previousTrackCommand.isEnabled = info.canGoPrevious
    }

    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: Remote commands

    private func registerRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        addTarget(center.playCommand) { [weak self] in self?.onPlayCommand?() }
        addTarget(center.pauseCommand) { [weak self] in self?.onPauseCommand?() }
        addTarget(center.togglePlayPauseCommand) { [weak self] in self?.onTogglePlayPauseCommand?() }
        addTarget(center.nextTrackCommand) { [weak self] in self?.onNextTrackCommand?() }
        addTarget(center.previousTrackCommand) { [weak self] in self?.onPreviousTrackCommand?() }
        // No in-player seeking support yet, so don't advertise scrubbing.
        center.changePlaybackPositionCommand.isEnabled = false
        center.changePlaybackRateCommand.isEnabled = false
    }

    private func addTarget(_ command: MPRemoteCommand, handler: @escaping @MainActor () -> Void) {
        let target = command.addTarget { _ in
            // Remote commands can arrive off the main thread.
            Task { @MainActor in handler() }
            return .success
        }
        commandTargets.append((command, target))
    }

    // MARK: Audio-session notifications

    private func observeAudioSessionNotifications() {
        let interruption = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let userInfo = notification.userInfo
            MainActor.assumeIsolated {
                self?.handleInterruption(userInfo)
            }
        }
        notificationObservers.append(interruption)

        let routeChange = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let userInfo = notification.userInfo
            MainActor.assumeIsolated {
                self?.handleRouteChange(userInfo)
            }
        }
        notificationObservers.append(routeChange)
    }

    private func handleInterruption(_ userInfo: [AnyHashable: Any]?) {
        guard let rawType = userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            onInterruptionBegan?()
        case .ended:
            let rawOptions = userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            onInterruptionEnded?(options.contains(.shouldResume))
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ userInfo: [AnyHashable: Any]?) {
        guard let rawReason = userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason) else { return }
        if reason == .oldDeviceUnavailable {
            onRouteDisconnected?()
        }
    }

    // MARK: Artwork

    private func ambienceArtwork() -> MPMediaItemArtwork {
        let raw = UserDefaults.standard.string(forKey: QuranListeningThemeStore.storageKey)
        let theme = raw.flatMap(QuranListeningTheme.init(rawValue:)) ?? .minimalDark
        if let cached = cachedArtwork, cached.theme == theme {
            return cached.artwork
        }
        let image = theme.nowPlayingArtwork()
        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        cachedArtwork = (theme, artwork)
        return artwork
    }
}
