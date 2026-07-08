import SwiftUI
import UIKit

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

    /// Quran.com word-by-word data (per-word Arabic + translation + audio timing)
    /// for the current ayah. Loaded offline-first; `nil` until it arrives or when
    /// the reciter/ayah has none.
    @State private var trace: QuranAyahTrace?

    /// Drives the gentle breathing halo behind the full-surah artwork.
    @State private var artworkPulse = false
    @State private var variantArabicText: [Int: String] = [:]

    /// The chosen listening ambience (persisted across sessions); drives the
    /// backdrop scene and every color on this screen.
    @State private var ambienceStore = QuranListeningThemeStore()
    /// Whether the ambience picker sheet is showing.
    @State private var showingAmbiencePicker = false

    private var ambience: QuranListeningTheme {
        ambienceStore.theme
    }

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

    // MARK: Word-by-word ("Spotify") tracking

    /// Stable identity of the ayah currently being traced (reciter + surah + ayah),
    /// so the trace reloads exactly when the playing ayah changes.
    private var traceID: String {
        "\(reciter.id):\(activeSurah.number):\(currentNumber)"
    }

    /// Content-word count of the current ayah, from the same tokenizer the
    /// highlight uses (so indices line up).
    private var currentWordCount: Int {
        guard let ayah = currentAyah else { return 0 }
        return QuranWordTrace.words(in: arabicText(for: ayah)).count
    }

    /// 0-based index of the word being recited right now. Prefers Quran.com's
    /// per-word audio timing (true karaoke sync); falls back to a linear estimate
    /// from playback progress when a reciter/ayah has no published segments — so
    /// the tracker still follows along for every per-ayah reciter.
    private var activeWordIndex: Int? {
        let count = currentWordCount
        guard count > 0 else { return nil }
        if let segments = trace?.segments, !segments.isEmpty {
            let ms = Int((player.elapsedSeconds * 1000).rounded())
            return QuranWordSegments.activeWordIndex(atMs: ms, segments: segments, wordCount: count)
        }
        return QuranWordTrace.activeWordIndex(progress: progressValue, wordCount: count)
    }

    /// True when we have per-word meanings that line up 1:1 with the bundled text,
    /// so each Arabic word can show its English gloss directly beneath it.
    private var hasWordMeanings: Bool {
        guard let trace else { return false }
        return !trace.words.isEmpty && trace.words.count == currentWordCount
    }

    private var remainingTimeText: String {
        guard let remaining = player.remainingSeconds else {
            return player.isLoading ? String(localized: "Loading time") : String(localized: "Time left soon")
        }
        return String(localized: "\(formatRemainingTime(remaining)) left")
    }

    private var statusText: String {
        switch player.playbackState {
        case .loading:
            return String(localized: "Loading recitation")
        case .buffering, .ready:
            return String(localized: "Buffering")
        case .playing:
            return String(localized: "Now playing")
        case .paused:
            return String(localized: "Paused")
        case .failed:
            return String(localized: "Needs attention")
        case .idle:
            return String(localized: "Ready to listen")
        }
    }

    private var upNextText: String {
        if isChapterMode {
            if let next = Quran.shared.surah(activeSurah.number + 1) {
                return next.englishName
            }
            return String(localized: "End of Quran")
        }
        if currentNumber < activeSurah.ayahs.count {
            return String(localized: "\(activeSurah.englishName) · Ayah \(currentNumber + 1)")
        }
        if let next = Quran.shared.surah(activeSurah.number + 1) {
            return String(localized: "\(next.englishName) · Ayah 1")
        }
        return String(localized: "End of Quran")
    }

    var body: some View {
        ZStack {
            QuranThemedPlayerBackground(theme: ambience)

            VStack(spacing: 8) {
                topBar
                // Full-surah recordings have no word-by-word tracking, so the
                // body becomes a big "album art" hero instead — the small deck
                // would just duplicate it, so it's dropped in that mode.
                if !isChapterMode {
                    reciterDeck
                }
                ayahContent
                playerPanel
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 10)
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
        // Load word-by-word data for the playing ayah (offline-first). Only per-ayah
        // reciters have it; chapter recordings show the surah name, not ayah text.
        .task(id: traceID) {
            guard !isChapterMode, reciter.supportsAyahAudio else {
                trace = nil
                return
            }
            if let cached = QuranWordSegments.cachedTrace(
                reciterID: reciter.id, surah: activeSurah.number, ayah: currentNumber) {
                trace = cached
            } else {
                trace = nil   // drop the previous ayah's data while fetching
                trace = await QuranWordSegments.loadTrace(
                    reciterID: reciter.id, surah: activeSurah.number, ayah: currentNumber)
            }
        }
        .task(id: "\(activeSurah.number)-\(readerFont)") {
            await loadVariantArabicText()
        }
        .sheet(isPresented: $showingAmbiencePicker) {
            QuranThemePickerView(store: ambienceStore)
        }
        .preferredColorScheme(ambience.colorScheme)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .duhaaFont(16, .semibold)
                    .foregroundStyle(ambience.accentColor)
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel("Close player")

            Spacer()
            VStack(spacing: 1) {
                Text(activeSurah.englishName)
                    .duhaaFont(13, .semibold)
                    .foregroundStyle(ambience.preferredTextColor)
                Text(isChapterMode ? "Full surah" : "Ayah \(currentNumber) of \(activeSurah.ayahs.count)")
                    .duhaaFont(10)
                    .foregroundStyle(ambience.secondaryTextColor)
            }
            Spacer()

            HStack(spacing: 16) {
                ambienceButton
                downloadControl
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 1)
    }

    /// Opens the listening-ambience picker (Night Sky, Rain Window, …).
    private var ambienceButton: some View {
        Button {
            showingAmbiencePicker = true
            DuhaaHaptics.tap()
        } label: {
            Image(systemName: "sparkles")
                .duhaaFont(17)
                .foregroundStyle(ambience.accentColor)
        }
        .accessibilityLabel("Listening ambience")
        .accessibilityHint("Choose a visual theme for this player")
    }

    // MARK: Reciter

    private var reciterDeck: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(ambience.accentColor.opacity(0.14), lineWidth: 6)
                    .frame(width: 54, height: 54)
                ReciterAvatar(reciter: reciter, size: 44)
                    .overlay(Circle().stroke(ambience.accentColor.opacity(0.55), lineWidth: 1.4))
                    .shadow(color: ambience.accentColor.opacity(0.14), radius: 8, y: 3)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(activeSurah.englishName)
                    .duhaaFont(15, .bold)
                    .foregroundStyle(ambience.preferredTextColor)
                    .lineLimit(1)
                Text(activeSurah.translation)
                    .duhaaFont(11, .medium)
                    .foregroundStyle(ambience.softAccentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Label(reciter.name, systemImage: "speaker.wave.2.fill")
            }
            .duhaaFont(10, .semibold)
            .foregroundStyle(ambience.accentColor)
            .lineLimit(1)
            .minimumScaleFactor(0.64)
            .frame(maxWidth: 128, alignment: .trailing)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(ambience.accentColor.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(ambience.accentColor.opacity(0.18), lineWidth: 1))
            .accessibilityLabel("\(reciter.name), autoplay next surah")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Ayah text

    private var ayahContent: some View {
        VStack(spacing: showTranslation ? 8 : 0) {
            if isChapterMode {
                chapterContent
            } else if let ayah = currentAyah {
                let arabic = arabicText(for: ayah)
                if showTranslation, hasWordMeanings, let trace {
                    // Word-by-word: each word's English meaning sits directly beneath
                    // the Arabic word, highlighting in sync with the recitation.
                    WordByWordReadAlongView(
                        arabicWords: QuranWordTrace.words(in: arabic),
                        translations: trace.words.map(\.translation),
                        activeIndex: activeWordIndex,
                        readerFont: readerFont,
                        reduceMotion: reduceMotion,
                        ambience: ambience
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 4)
                    .id("wbw-\(activeSurah.number)-\(ayah.number)")
                    .accessibilityLabel(arabic)
                } else {
                    QuranReadAlongTextView(rawArabic: arabic,
                                           activeIndex: activeWordIndex,
                                           readerFont: readerFont,
                                           reduceMotion: reduceMotion,
                                           ambience: ambience)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .id("arabic-\(activeSurah.number)-\(ayah.number)")
                    .accessibilityLabel(arabic)

                    if showTranslation {
                        translationArea(ayah)
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .layoutPriority(1)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: activeSurah.number)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: currentNumber)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: activeWordIndex)
    }

    /// Full-surah recordings can't sync word-by-word, so — like a music app with
    /// no synced lyrics — the screen becomes a premium "now playing" cover: a big
    /// glowing reciter portrait with the surah and reciter beneath it.
    private var chapterContent: some View {
        GeometryReader { proxy in
            // Size the portrait to whatever room the hero has, so it stays big on
            // a large phone and never overflows on a small one.
            let artSize = min(max(proxy.size.height * 0.46, 148), 224, proxy.size.width * 0.66)
            VStack(spacing: 22) {
                reciterArtwork(size: artSize)
                surahTitles
                reciterNamePill
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { artworkPulse = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(activeSurah.englishName), \(activeSurah.translation), \(activeSurah.ayahs.count) ayahs, recited by \(reciter.name)")
    }

    /// The big reciter portrait, lit by a soft gold halo that breathes while the
    /// recitation plays (static under Reduce Motion).
    private func reciterArtwork(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(ambience.accentColor.opacity(0.16))
                .frame(width: size * 1.05, height: size * 1.05)
                .blur(radius: 34)
                .scaleEffect(artworkPulse ? 1.08 : 0.93)
                .animation(reduceMotion ? nil : .easeInOut(duration: 2.8).repeatForever(autoreverses: true),
                           value: artworkPulse)

            Circle()
                .stroke(ambience.accentColor.opacity(0.12), lineWidth: 6)
                .frame(width: size + 18, height: size + 18)

            ReciterAvatar(reciter: reciter, size: size)
                .overlay(
                    Circle().stroke(
                        LinearGradient(colors: [ambience.accentColor.opacity(0.85), ambience.softAccentColor.opacity(0.5)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 2)
                )
                .shadow(color: ambience.accentColor.opacity(0.30), radius: 22, y: 12)
        }
        .accessibilityHidden(true)
    }

    private var surahTitles: some View {
        VStack(spacing: 7) {
            Text(activeSurah.arabicName)
                .font(QuranFont.reader(readerFont, size: 34))
                .foregroundStyle(ambience.accentColor)
                .environment(\.layoutDirection, .rightToLeft)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(activeSurah.englishName)
                .duhaaFont(22, .bold)
                .foregroundStyle(ambience.preferredTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("\(activeSurah.translation) · \(activeSurah.ayahs.count) ayahs")
                .duhaaFont(13, .medium)
                .foregroundStyle(ambience.secondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 12)
    }

    private var reciterNamePill: some View {
        Label(reciter.name, systemImage: "speaker.wave.2.fill")
            .duhaaFont(13, .semibold)
            .foregroundStyle(ambience.accentColor)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(ambience.accentColor.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(ambience.accentColor.opacity(0.2), lineWidth: 1))
    }

    /// Full-ayah translation, shown under the Arabic for reciters/ayahs that have no
    /// per-word meanings (word-by-word uses the interlinear layout instead).
    private func translationArea(_ ayah: Ayah) -> some View {
        ScrollView(showsIndicators: false) {
            Text(ayah.english)
                .duhaaFont(14)
                .lineSpacing(3)
                .foregroundStyle(ambience.preferredTextColor.opacity(0.8))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .id("english-\(activeSurah.number)-\(ayah.number)")
        }
        .frame(maxHeight: 72)
    }

    @MainActor
    private func loadVariantArabicText() async {
        let preference = QuranFontPreference(storageValue: readerFont)
        guard preference.verseTextField != .textUthmani else {
            variantArabicText = [:]
            return
        }

        do {
            let text = try await QuranTextVariantAPI.shared.chapter(activeSurah.number, preference: preference)
            guard !Task.isCancelled else { return }
            variantArabicText = text
        } catch {
            guard !Task.isCancelled else { return }
            variantArabicText = [:]
        }
    }

    private func arabicText(for ayah: Ayah) -> String {
        variantArabicText[ayah.number] ?? ayah.arabic
    }

    // MARK: Progress + controls

    private var playerPanel: some View {
        VStack(spacing: 16) {
            progressBar
            queueRow
            speedControl
            controls
            if case .failed(let message) = player.playbackState {
                Text(message)
                    .duhaaFont(12)
                    .foregroundStyle(ambience.softAccentColor)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18).fill(ambience.panelFill))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(ambience.panelBorder.opacity(0.95), lineWidth: 1)
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
                    Capsule().fill(ambience.softAccentColor.opacity(0.16))
                    Capsule().fill(
                        LinearGradient(colors: [ambience.accentColor, ambience.softAccentColor.opacity(0.8)],
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
            .foregroundStyle(ambience.secondaryTextColor)
        }
    }

    private var progressHead: some View {
        ZStack {
            Circle()
                .fill(ambience.accentColor)
                .shadow(color: ambience.accentColor.opacity(0.55), radius: 8)
            Circle()
                .stroke(ambience.secondaryColor.opacity(0.55), lineWidth: 1)
            Image(systemName: "star.fill")
                .duhaaFont(8, .bold)
                .foregroundStyle(ambience.onAccentColor)
        }
        .accessibilityHidden(true)
    }

    /// Tapping "Up next" skips ahead to whatever it shows — the next surah for
    /// full-surah recordings, the next ayah for per-ayah reciters.
    private var queueRow: some View {
        Button {
            guard player.playNextItem() else { return }
            DuhaaHaptics.tap()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "forward.end.fill")
                    .duhaaFont(15, .semibold)
                    .foregroundStyle(ambience.accentColor)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Up next")
                        .duhaaFont(11, .semibold)
                        .foregroundStyle(ambience.softAccentColor)
                    Text(upNextText)
                        .duhaaFont(13, .semibold)
                        .foregroundStyle(ambience.preferredTextColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
                if player.canPlayNextItem {
                    Image(systemName: "chevron.right")
                        .duhaaFont(12, .semibold)
                        .foregroundStyle(ambience.secondaryTextColor)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(ambience.accentColor.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ambience.accentColor.opacity(0.14), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!player.canPlayNextItem)
        .opacity(player.canPlayNextItem ? 1 : 0.5)
        .accessibilityLabel("Up next, \(upNextText)")
        .accessibilityHint("Skips to the next \(isChapterMode ? "surah" : "ayah")")
    }

    private var speedControl: some View {
        Menu {
            ForEach(AyahPlayer.availablePlaybackRates, id: \.self) { rate in
                Button {
                    player.setPlaybackRate(rate)
                    DuhaaHaptics.tap()
                } label: {
                    Label(playbackSpeedLabel(rate),
                          systemImage: rate == player.playbackRate ? "checkmark" : "circle")
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "speedometer")
                    .duhaaFont(13, .semibold)
                Text("Playback speed")
                    .duhaaFont(12, .semibold)
                Spacer()
                Text(playbackSpeedLabel(player.playbackRate))
                    .duhaaFont(13, .bold)
                Image(systemName: "chevron.up.chevron.down")
                    .duhaaFont(10, .semibold)
            }
            .foregroundStyle(ambience.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(ambience.accentColor.opacity(0.08), in: Capsule())
            .overlay(Capsule().stroke(ambience.accentColor.opacity(0.18), lineWidth: 1))
        }
        .accessibilityLabel("Playback speed")
        .accessibilityValue(playbackSpeedLabel(player.playbackRate))
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
                    Circle().fill(ambience.accentColor).frame(width: 76, height: 76)
                    if player.isLoading {
                        ProgressView().tint(ambience.onAccentColor)
                    } else {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .duhaaFont(29, .bold)
                            .foregroundStyle(ambience.onAccentColor)
                            .offset(x: isPlaying ? 0 : 2)
                    }
                }
                .shadow(color: ambience.accentColor.opacity(0.28), radius: 14, y: 6)
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
            .foregroundStyle(ambience.accentColor)
            .frame(width: 46, height: 46)
            .background(Circle().fill(ambience.accentColor.opacity(0.08)))
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
        guard totalSeconds >= 60 else { return String(localized: "\(totalSeconds)s") }

        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if seconds == 0 {
            return String(localized: "\(minutes)m")
        }
        return String(localized: "\(minutes)m \(String(format: "%02d", seconds))s")
    }

    private func playbackSpeedLabel(_ speed: Double) -> String {
        if speed == 1 {
            return "1x"
        }
        if (speed * 10).rounded() == speed * 10 {
            return String(format: "%.1fx", speed)
        }
        return String(format: "%.2fx", speed)
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
                        .foregroundStyle(ambience.accentColor)
                }
                .accessibilityLabel("Download for offline")
            case .downloading(let progress):
                Button { offline.remove(surah: activeSurah, reciter: reciter) } label: {
                    ZStack {
                        Circle().stroke(ambience.accentColor.opacity(0.25), lineWidth: 2.5)
                        Circle().trim(from: 0, to: max(0.02, progress))
                            .stroke(ambience.accentColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: "stop.fill")
                            .duhaaFont(8)
                            .foregroundStyle(ambience.accentColor)
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
                        .foregroundStyle(ambience.accentColor)
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

/// A shaped, scrollable Quran text view for the Listen screen. SwiftUI's `Text`
/// can color the active word, but it does not expose where that word wrapped; a
/// `UITextView` lets TextKit reveal the active word's real glyph rect so playback
/// can gently follow the current line.
private struct QuranReadAlongTextView: UIViewRepresentable {
    let rawArabic: String
    let activeIndex: Int?
    let readerFont: String
    let reduceMotion: Bool
    let ambience: QuranListeningTheme

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UITextView {
        let textView = CenteringTextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = false
        textView.alwaysBounceVertical = false
        // We manage the vertical inset ourselves to center short ayahs — keep the
        // system from layering safe-area adjustments on top of that math.
        textView.contentInsetAdjustmentBehavior = .never
        textView.textAlignment = .center
        textView.semanticContentAttribute = .forceRightToLeft
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let layout = QuranWordTrace.wordRanges(in: rawArabic)
        let ayahChanged = context.coordinator.ayahKey != rawArabic
        if ayahChanged {
            context.coordinator.ayahKey = rawArabic
            context.coordinator.lastScrolledWordIndex = nil
        }

        let signature = RenderSignature(rawArabic: rawArabic,
                                        activeIndex: activeIndex,
                                        readerFont: readerFont,
                                        ambienceID: ambience.id)
        if context.coordinator.renderSignature != signature {
            let previousOffset = textView.contentOffset
            textView.attributedText = attributedArabicText(display: layout.display,
                                                           ranges: layout.ranges)
            textView.textAlignment = .center
            if ayahChanged {
                textView.setContentOffset(.zero, animated: false)
            } else {
                textView.setContentOffset(previousOffset, animated: false)
            }
            context.coordinator.renderSignature = signature
        }

        guard let activeIndex,
              layout.ranges.indices.contains(activeIndex),
              context.coordinator.lastScrolledWordIndex != activeIndex else { return }

        context.coordinator.lastScrolledWordIndex = activeIndex
        let range = NSRange(layout.ranges[activeIndex], in: layout.display)
        DispatchQueue.main.async {
            scroll(range: range, in: textView)
        }
    }

    final class Coordinator {
        var ayahKey: String?
        var renderSignature: RenderSignature?
        var lastScrolledWordIndex: Int?
    }

    struct RenderSignature: Equatable {
        let rawArabic: String
        let activeIndex: Int?
        let readerFont: String
        let ambienceID: String
    }

    private func attributedArabicText(display: String,
                                      ranges: [Range<String.Index>]) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.baseWritingDirection = .rightToLeft
        paragraph.lineSpacing = 18

        let attributed = NSMutableAttributedString(
            string: display,
            attributes: [
                .font: quranUIFont(size: 40),
                .paragraphStyle: paragraph,
                .foregroundColor: UIColor(ambience.preferredTextColor)
            ]
        )

        for (index, range) in ranges.enumerated() {
            let color: UIColor
            if let activeIndex {
                if index == activeIndex {
                    color = UIColor(ambience.accentColor)
                } else if index < activeIndex {
                    color = UIColor(ambience.preferredTextColor).withAlphaComponent(0.9)
                } else {
                    color = UIColor(ambience.preferredTextColor).withAlphaComponent(0.38)
                }
            } else {
                color = UIColor(ambience.preferredTextColor)
            }
            attributed.addAttribute(.foregroundColor, value: color, range: NSRange(range, in: display))
        }

        var characterIndex = display.startIndex
        while characterIndex < display.endIndex {
            let character = display[characterIndex]
            let color = markColor(character)
            if !isContentCharacter(character), let color {
                let nextIndex = display.index(after: characterIndex)
                attributed.addAttribute(.foregroundColor,
                                        value: color,
                                        range: NSRange(characterIndex..<nextIndex, in: display))
            }
            characterIndex = display.index(after: characterIndex)
        }

        return attributed
    }

    private func quranUIFont(size: CGFloat) -> UIFont {
        let preference = QuranFontPreference(storageValue: readerFont).fallbackUnicodePreference
        let base = preference.unicodeFontName.flatMap { UIFont(name: $0, size: size) }
            ?? UIFont(name: QuranFont.family, size: size)
            ?? .systemFont(ofSize: size, weight: .regular)
        return UIFontMetrics.default.scaledFont(for: base)
    }

    private func scroll(range: NSRange, in textView: UITextView) {
        guard textView.bounds.height > 0, range.location != NSNotFound else { return }

        textView.layoutIfNeeded()
        let layoutManager = textView.layoutManager
        layoutManager.ensureLayout(for: textView.textContainer)

        let maxY = max(0, textView.contentSize.height - textView.bounds.height)
        // The ayah fits — it stays vertically centered (see CenteringTextView); there is
        // nothing to scroll, so don't yank it to the top to "follow" the active word.
        guard maxY > 0 else { return }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var glyphRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textView.textContainer)
        glyphRect.origin.y += textView.textContainerInset.top

        let targetY = glyphRect.midY - textView.bounds.height * 0.42
        let clampedY = min(max(0, targetY), maxY)
        guard abs(textView.contentOffset.y - clampedY) > 2 else { return }

        let update = {
            textView.setContentOffset(CGPoint(x: 0, y: clampedY), animated: false)
        }
        if reduceMotion {
            update()
        } else {
            UIView.animate(withDuration: 0.26,
                           delay: 0,
                           options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut],
                           animations: update)
        }
    }

    private func isContentCharacter(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            switch scalar.properties.generalCategory {
            case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter:
                return true
            default:
                return false
            }
        }
    }

    private func markColor(_ character: Character) -> UIColor? {
        switch character {
        case "ۖ", "ۗ", "ۘ", "ۙ", "ۚ", "ۛ", "ۜ", "۝": UIColor(ambience.accentColor)
        case "۞", "۩": UIColor(ambience.softAccentColor)
        default: nil
        }
    }
}

/// A text view that vertically centers the ayah while it fits the available height,
/// and falls back to natural top-aligned scrolling once a long verse outgrows it.
///
/// Quran ayahs vary enormously in length: a short one (e.g. "وَالضُّحَىٰ") should sit
/// centered in the listening hero, while the longest (al-Baqarah 282) simply can't —
/// so it scrolls. Centering is done by padding the top inset to take up the slack and
/// resting the scroll at that padded origin; once the text overflows, the slack is
/// zero and the existing read-along auto-scroll takes over unchanged.
private final class CenteringTextView: UITextView {
    override func layoutSubviews() {
        super.layoutSubviews()
        let slack = bounds.height - contentSize.height
        let fits = slack > 0
        let topInset = fits ? slack / 2 : 0

        if abs(contentInset.top - topInset) > 0.5 {
            contentInset.top = topInset
        }
        // While it fits, hold the scroll at the inset origin so the verse shows centered.
        if fits {
            let restingY = -topInset
            if abs(contentOffset.y - restingY) > 0.5 {
                setContentOffset(CGPoint(x: contentOffset.x, y: restingY), animated: false)
            }
        }
    }
}

/// Word-by-word ("Spotify" interlinear) reading view: each Arabic word with its
/// English meaning stacked directly beneath it, the words flowing right-to-left and
/// wrapping. The word being recited is highlighted in sync with the audio, and the
/// view auto-scrolls to keep it centered on longer ayahs.
private struct WordByWordReadAlongView: View {
    let arabicWords: [String]
    let translations: [String]
    let activeIndex: Int?
    let readerFont: String
    var arabicSize: CGFloat = 31
    let reduceMotion: Bool
    let ambience: QuranListeningTheme

    private var pairCount: Int { min(arabicWords.count, translations.count) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                WordFlowLayout(horizontalSpacing: 12, verticalSpacing: 16) {
                    ForEach(0..<pairCount, id: \.self) { index in
                        wordCell(index)
                            .id(index)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .onChange(of: activeIndex) { _, newValue in
                guard let newValue else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private func wordCell(_ index: Int) -> some View {
        let isActive = activeIndex == index
        let isPast = (activeIndex ?? -1) > index

        let arabicColor: Color = {
            guard activeIndex != nil else { return ambience.preferredTextColor }
            if isActive { return ambience.accentColor }
            return isPast ? ambience.preferredTextColor.opacity(0.9) : ambience.preferredTextColor.opacity(0.36)
        }()
        let englishColor: Color = {
            guard activeIndex != nil else { return ambience.secondaryTextColor }
            if isActive { return ambience.softAccentColor }
            return isPast ? ambience.secondaryTextColor.opacity(0.85) : ambience.secondaryTextColor.opacity(0.4)
        }()

        return VStack(spacing: 5) {
            Text(arabicWords[index])
                .font(QuranFont.reader(readerFont, size: arabicSize))
                .foregroundStyle(arabicColor)
                .fixedSize()
            Text(translations[index])
                .duhaaFont(11, isActive ? .semibold : .medium)
                .foregroundStyle(englishColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: 132)
                .fixedSize(horizontal: false, vertical: true)
        }
        .scaleEffect(isActive && !reduceMotion ? 1.05 : 1)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: activeIndex)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(arabicWords[index]), \(translations[index])")
    }
}

/// A right-to-left flow layout: places word cells from the right, wraps to a new
/// line when the next cell would overflow the width, and centers each line.
private struct WordFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 12
    var verticalSpacing: CGFloat = 16

    private struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func lines(maxWidth: CGFloat, subviews: Subviews) -> [Line] {
        var lines: [Line] = []
        var line = Line()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let projected = line.indices.isEmpty ? size.width : line.width + horizontalSpacing + size.width
            if !line.indices.isEmpty, projected > maxWidth {
                lines.append(line)
                line = Line()
                line.indices = [index]
                line.width = size.width
                line.height = size.height
            } else {
                line.width = line.indices.isEmpty ? size.width : line.width + horizontalSpacing + size.width
                line.indices.append(index)
                line.height = max(line.height, size.height)
            }
        }
        if !line.indices.isEmpty { lines.append(line) }
        return lines
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let computed = lines(maxWidth: maxWidth, subviews: subviews)
        let height = computed.map(\.height).reduce(0, +)
            + verticalSpacing * CGFloat(max(0, computed.count - 1))
        let width = proposal.width ?? (computed.map(\.width).max() ?? 0)
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let computed = lines(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for line in computed {
            // Start at the right edge of the centered line, then lay words leftward.
            var x = bounds.midX + line.width / 2
            for index in line.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                x -= size.width
                subviews[index].place(at: CGPoint(x: x, y: y),
                                      anchor: .topLeading,
                                      proposal: ProposedViewSize(size))
                x -= horizontalSpacing
            }
            y += line.height + verticalSpacing
        }
    }
}
