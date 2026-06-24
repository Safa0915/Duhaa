import SwiftUI

/// An immersive, "now playing" listening screen for per-ayah reciters. It is
/// driven by the shared `AyahPlayer`, so playback continues when this closes
/// and the UI follows autoplay when a surah rolls into the next one.
struct NowPlayingView: View {
    let surah: Surah
    let reciter: Reciter
    let player: AyahPlayer
    /// Where to begin if nothing is playing yet.
    var startAyah: Int = 1

    @Environment(QuranOfflineLibrary.self) private var offline
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("duhaa.quran.showTranslation") private var showTranslation = true
    @AppStorage("duhaa.quran.readerFont") private var readerFont = "kfgqpc"

    private var activeSurah: Surah {
        player.currentSurah ?? surah
    }

    private var currentNumber: Int {
        min(max(player.playingAyahNumber ?? startAyah, 1), activeSurah.ayahs.count)
    }

    private var isChapterMode: Bool {
        reciter.supportsChapterAudio || player.isPlayingChapterRecording
    }

    private var currentAyah: Ayah? {
        activeSurah.ayahs.first { $0.number == currentNumber }
    }

    private var progressValue: Double {
        max(0, min(1, player.progress))
    }

    private var remainingTimeText: String {
        guard let remaining = player.remainingSeconds else {
            return player.isLoading ? "Loading time" : "Time left soon"
        }
        return "\(formatRemainingTime(remaining)) left"
    }

    private var statusText: String {
        switch player.playbackState {
        case .loading:
            return "Loading recitation"
        case .buffering, .ready:
            return "Buffering"
        case .playing:
            return "Now playing"
        case .paused:
            return "Paused"
        case .failed:
            return "Needs attention"
        case .idle:
            return "Ready to listen"
        }
    }

    private var upNextText: String {
        if isChapterMode {
            if let next = Quran.shared.surah(activeSurah.number + 1) {
                return next.englishName
            }
            return "End of Quran"
        }
        if currentNumber < activeSurah.ayahs.count {
            return "\(activeSurah.englishName) · Ayah \(currentNumber + 1)"
        }
        if let next = Quran.shared.surah(activeSurah.number + 1) {
            return "\(next.englishName) · Ayah 1"
        }
        return "End of Quran"
    }

    var body: some View {
        ZStack {
            Palette.appBg.ignoresSafeArea()
            RadialGradient(colors: [Palette.gold.opacity(0.16), .clear],
                           center: .top, startRadius: 8, endRadius: 420)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 10)
                reciterDeck
                Spacer(minLength: 12)
                ayahContent
                Spacer(minLength: 12)
                playerPanel
                Spacer(minLength: 12)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            if player.currentRequest == nil || player.currentSurah == nil {
                if reciter.supportsChapterAudio {
                    player.playChapter(in: surah)
                } else {
                    player.play(in: surah, from: startAyah)
                }
            }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .duhaaFont(18, .semibold)
                    .foregroundStyle(Palette.gold)
            }
            .accessibilityLabel("Close player")

            Spacer()
            VStack(spacing: 2) {
                Text(activeSurah.englishName)
                    .duhaaFont(15, .semibold)
                    .foregroundStyle(.primary)
                Text(isChapterMode ? "Full surah" : "Ayah \(currentNumber) of \(activeSurah.ayahs.count)")
                    .duhaaFont(11)
                    .foregroundStyle(Palette.secondaryText)
            }
            Spacer()

            downloadControl
        }
        .padding(.top, 8)
    }

    // MARK: Reciter

    private var reciterDeck: some View {
        VStack(spacing: 9) {
            ZStack {
                Circle()
                    .stroke(Palette.gold.opacity(0.14), lineWidth: 11)
                    .frame(width: 88, height: 88)
                ReciterAvatar(reciter: reciter, size: 70)
                    .overlay(Circle().stroke(Palette.gold.opacity(0.55), lineWidth: 2))
                    .shadow(color: Palette.gold.opacity(0.18), radius: 14, y: 6)
            }

            VStack(spacing: 3) {
                Text(activeSurah.englishName)
                    .duhaaFont(20, .bold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text(activeSurah.translation)
                    .duhaaFont(12, .medium)
                    .foregroundStyle(Palette.blue)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 8) {
                Label(reciter.name, systemImage: "speaker.wave.2.fill")
            }
            .duhaaFont(11, .semibold)
            .foregroundStyle(Palette.gold)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Palette.gold.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(Palette.gold.opacity(0.18), lineWidth: 1))
            .accessibilityLabel("\(reciter.name), autoplay next surah")
        }
    }

    // MARK: Ayah text

    private var ayahContent: some View {
        VStack(spacing: 14) {
            if isChapterMode {
                chapterContent
            } else if let ayah = currentAyah {
                ScrollView(showsIndicators: false) {
                    arabicText(ayah.arabic)
                        .font(QuranFont.reader(readerFont, size: 40))
                        .lineSpacing(22)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .environment(\.layoutDirection, .rightToLeft)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                        .id("arabic-\(activeSurah.number)-\(ayah.number)")
                        .accessibilityLabel(ayah.arabic)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if showTranslation {
                    translationArea(ayah)
                }
            }
        }
        .padding(.vertical, 8)
        .frame(maxHeight: 420)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: activeSurah.number)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: currentNumber)
    }

    /// The ayah as a single, correctly-shaped Quran string — built the same way as
    /// the reader (one concatenated `Text` run) so the Uthmani script and its pause
    /// marks always render perfectly. Never split word-by-word.
    private func arabicText(_ raw: String) -> Text {
        QuranArabicText.display(raw).reduce(Text("")) { partial, character in
            partial + Text(String(character)).foregroundColor(markColor(character))
        }
    }

    /// Tint the waqf (pause) and sajdah marks, matching the reader.
    private func markColor(_ character: Character) -> Color {
        switch character {
        case "ۖ", "ۗ", "ۘ", "ۙ", "ۚ", "ۛ", "ۜ", "۝": Palette.gold
        case "۞", "۩": Palette.blue
        default: .primary
        }
    }

    private var chapterContent: some View {
        VStack(spacing: 12) {
            Text(activeSurah.arabicName)
                .font(QuranFont.reader(readerFont, size: 46))
                .foregroundStyle(Palette.gold)
                .multilineTextAlignment(.center)
                .environment(\.layoutDirection, .rightToLeft)

            Text(activeSurah.translation)
                .duhaaFont(17, .semibold)
                .foregroundStyle(Palette.blue)
                .multilineTextAlignment(.center)

            Text("\(activeSurah.ayahs.count) ayahs")
                .duhaaFont(13, .medium)
                .foregroundStyle(Palette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// The ayah's full English translation, scrollable for longer verses.
    private func translationArea(_ ayah: Ayah) -> some View {
        ScrollView(showsIndicators: false) {
            Text(ayah.english)
                .duhaaFont(16)
                .lineSpacing(4)
                .foregroundStyle(.primary.opacity(0.8))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .id("english-\(activeSurah.number)-\(ayah.number)")
        }
        .frame(maxHeight: 96)
    }

    // MARK: Progress + controls

    private var playerPanel: some View {
        VStack(spacing: 16) {
            progressBar
            queueRow
            controls
            if case .failed(let message) = player.playbackState {
                Text(message)
                    .duhaaFont(12)
                    .foregroundStyle(Palette.blue)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18).fill(Palette.card))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Palette.cardBorder.opacity(0.95), lineWidth: 1)
        )
    }

    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let headSize: CGFloat = 20
                let filledWidth = proxy.size.width * progressValue
                let headOffset = min(
                    max(0, filledWidth - headSize / 2),
                    max(0, proxy.size.width - headSize)
                )

                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.blue.opacity(0.16))
                    Capsule().fill(
                        LinearGradient(colors: [Palette.gold, Palette.blue.opacity(0.8)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: filledWidth)
                    progressHead
                        .frame(width: headSize, height: headSize)
                        .offset(x: headOffset)
                }
            }
            .frame(height: 20)

            HStack {
                Text(statusText)
                Spacer()
                Text(remainingTimeText)
            }
            .duhaaFont(11, .medium)
            .foregroundStyle(Palette.secondaryText)
        }
    }

    private var progressHead: some View {
        ZStack {
            Circle()
                .fill(Palette.gold)
                .shadow(color: Palette.gold.opacity(0.55), radius: 8)
            Circle()
                .stroke(Palette.appBg.opacity(0.55), lineWidth: 1)
            Image(systemName: "star.fill")
                .duhaaFont(8, .bold)
                .foregroundStyle(Palette.onAccent)
        }
        .accessibilityHidden(true)
    }

    private var queueRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "forward.end.fill")
                .duhaaFont(15, .semibold)
                .foregroundStyle(Palette.gold)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("Up next")
                    .duhaaFont(11, .semibold)
                    .foregroundStyle(Palette.blue)
                Text(upNextText)
                    .duhaaFont(13, .semibold)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var controls: some View {
        HStack(spacing: 34) {
            Button {
                guard player.playPreviousItem() else { return }
                DuhaaHaptics.tap()
            } label: {
                controlGlyph("backward.fill", size: 22, isEnabled: player.canPlayPreviousItem)
            }
            .disabled(!player.canPlayPreviousItem)
            .accessibilityLabel(isChapterMode ? "Previous surah" : "Previous ayah")

            Button {
                player.togglePlayPause()
                DuhaaHaptics.tap()
            } label: {
                ZStack {
                    Circle().fill(Palette.gold).frame(width: 76, height: 76)
                    if player.isLoading {
                        ProgressView().tint(Palette.onAccent)
                    } else {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .duhaaFont(29, .bold)
                            .foregroundStyle(Palette.onAccent)
                            .offset(x: isPlaying ? 0 : 2)
                    }
                }
                .shadow(color: Palette.gold.opacity(0.28), radius: 14, y: 6)
            }
            .accessibilityLabel(isPlaying ? "Pause" : "Play")

            Button {
                guard player.playNextItem() else { return }
                DuhaaHaptics.tap()
            } label: {
                controlGlyph("forward.fill", size: 22, isEnabled: player.canPlayNextItem)
            }
            .disabled(!player.canPlayNextItem)
            .accessibilityLabel(isChapterMode ? "Next surah" : "Next ayah")
        }
        .buttonStyle(.plain)
    }

    private func controlGlyph(_ systemName: String, size: CGFloat, isEnabled: Bool) -> some View {
        Image(systemName: systemName)
            .duhaaFont(size, .semibold)
            .foregroundStyle(Palette.gold)
            .frame(width: 46, height: 46)
            .background(Circle().fill(Palette.gold.opacity(0.08)))
            .opacity(isEnabled ? 1 : 0.35)
    }

    private var isPlaying: Bool {
        switch player.playbackState {
        case .playing, .ready, .loading, .buffering:
            return true
        default:
            return false
        }
    }

    private func formatRemainingTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = max(0, Int(seconds.rounded(.up)))
        guard totalSeconds >= 60 else { return "\(totalSeconds)s" }

        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if seconds == 0 {
            return "\(minutes)m"
        }
        return "\(minutes)m \(String(format: "%02d", seconds))s"
    }

    // MARK: Offline download

    @ViewBuilder
    private var downloadControl: some View {
        if reciter.supportsAyahAudio {
            switch offline.state(surah: activeSurah.number, reciterID: reciter.id) {
            case .notDownloaded:
                Button {
                    offline.download(surah: activeSurah, reciter: reciter)
                    DuhaaHaptics.tap()
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .duhaaFont(18)
                        .foregroundStyle(Palette.gold)
                }
                .accessibilityLabel("Download for offline")
            case .downloading(let progress):
                Button { offline.remove(surah: activeSurah, reciter: reciter) } label: {
                    ZStack {
                        Circle().stroke(Palette.gold.opacity(0.25), lineWidth: 2.5)
                        Circle().trim(from: 0, to: max(0.02, progress))
                            .stroke(Palette.gold, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: "stop.fill")
                            .duhaaFont(8)
                            .foregroundStyle(Palette.gold)
                    }
                    .frame(width: 24, height: 24)
                }
                .accessibilityLabel("Downloading, \(Int(progress * 100)) percent. Tap to cancel.")
            case .downloaded:
                Button {
                    offline.remove(surah: activeSurah, reciter: reciter)
                    DuhaaHaptics.tap()
                } label: {
                    Image(systemName: "arrow.down.circle.fill")
                        .duhaaFont(18)
                        .foregroundStyle(Palette.gold)
                }
                .accessibilityLabel("Downloaded for offline. Tap to remove.")
            }
        } else {
            Color.clear
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
        }
    }
}
