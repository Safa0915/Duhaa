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

    /// Quran.com word-by-word data (Arabic + translation + timing) for the current
    /// ayah. nil until fetched / when unavailable — then we fall back to the
    /// bundled text, the full translation, and the linear estimate.
    @State private var trace: QuranAyahTrace?

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

    /// True once Quran.com word-by-word data is loaded for this ayah.
    private var hasWordByWord: Bool { (trace?.words.isEmpty == false) }

    private var currentArabicWords: [String] {
        if let trace, !trace.words.isEmpty { return trace.words.map(\.arabic) }
        guard let currentAyah else { return [] }
        return QuranWordTrace.words(in: currentAyah.arabic)
    }

    /// Stable key for the ayah currently being traced (reciter + surah + ayah).
    private var traceID: String {
        isChapterMode
            ? "\(reciter.id):\(activeSurah.number):chapter"
            : "\(reciter.id):\(activeSurah.number):\(currentNumber)"
    }

    private var activeWordIndex: Int? {
        let count = currentArabicWords.count
        guard count > 0 else { return nil }
        // True Quran.com word-by-word timing when we have it…
        if let segments = trace?.segments, !segments.isEmpty {
            let ms = Int((player.elapsedSeconds * 1000).rounded())
            return QuranWordSegments.activeWordIndex(atMs: ms, segments: segments, wordCount: count)
        }
        // …otherwise the linear estimate (offline / reciter without segments).
        return QuranWordTrace.activeWordIndex(progress: progressValue, wordCount: count)
    }

    /// The English meaning of the word currently being recited (word-by-word).
    private var activeWordTranslation: String? {
        guard let trace, let index = activeWordIndex, index >= 0, index < trace.words.count else { return nil }
        let text = trace.words[index].translation.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
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
        .task(id: traceID) {
            guard !isChapterMode else {
                trace = nil
                return
            }
            // Load Quran.com's word-by-word data (Arabic + translation + timing).
            if let cached = QuranWordSegments.cachedTrace(reciterID: reciter.id,
                                                          surah: activeSurah.number, ayah: currentNumber) {
                trace = cached
            } else {
                trace = nil  // drop the previous ayah's data while fetching
                trace = await QuranWordSegments.loadTrace(reciterID: reciter.id,
                                                          surah: activeSurah.number, ayah: currentNumber)
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
        VStack(spacing: 12) {
            if isChapterMode {
                chapterContent
            } else if let ayah = currentAyah {
                ArabicWordTraceView(words: currentArabicWords,
                                    activeIndex: activeWordIndex,
                                    readerFont: readerFont,
                                    fontSize: 42,
                                    reduceMotion: reduceMotion)
                    .id("arabic-\(activeSurah.number)-\(ayah.number)")
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
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: activeWordIndex)
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

    /// Word-by-word: just the current word's meaning (compact, keeps the Arabic
    /// big). Offline / no per-word data: the full ayah translation.
    @ViewBuilder
    private func translationArea(_ ayah: Ayah) -> some View {
        if hasWordByWord {
            Text(activeWordTranslation ?? " ")
                .duhaaFont(19, .semibold)
                .foregroundStyle(Palette.blue)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: activeWordTranslation)
                .accessibilityLabel(activeWordTranslation.map { "Word meaning: \($0)" } ?? "")
        } else {
            ScrollView(showsIndicators: false) {
                Text(ayah.english)
                    .duhaaFont(15)
                    .lineSpacing(4)
                    .foregroundStyle(.primary.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .id("english-\(activeSurah.number)-\(ayah.number)")
            }
            .frame(maxHeight: 78)
        }
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

private struct ArabicWordTraceView: View {
    let words: [String]
    let activeIndex: Int?
    let readerFont: String
    var fontSize: CGFloat = 32
    let reduceMotion: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                RTLWordWrapLayout(spacing: 4, lineSpacing: 10) {
                    ForEach(Array(words.enumerated()), id: \.offset) { item in
                        let index = item.offset
                        let word = item.element
                        Text(word)
                            .font(QuranFont.reader(readerFont, size: fontSize))
                            .lineLimit(1)
                            .foregroundStyle(wordColor(index))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Palette.gold.opacity(index == activeIndex ? 0.16 : 0))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Palette.gold.opacity(index == activeIndex ? 0.5 : 0),
                                            lineWidth: 1)
                            )
                            .shadow(color: Palette.gold.opacity(index == activeIndex ? 0.22 : 0),
                                    radius: 7,
                                    y: 2)
                            .id(index)
                    }
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
            }
            .onAppear {
                scroll(to: activeIndex, proxy: proxy)
            }
            .onChange(of: activeIndex) { _, newValue in
                scroll(to: newValue, proxy: proxy)
            }
        }
        // NOTE: RTLWordWrapLayout already places words right-to-left (from maxX).
        // Adding an RTL layoutDirection here would mirror it a second time and flip
        // the words back to left-to-right — so it is deliberately NOT set.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(words.joined(separator: " "))
    }

    private func wordColor(_ index: Int) -> Color {
        guard let activeIndex else { return .primary }
        if index == activeIndex { return Palette.gold }
        if index < activeIndex { return .primary.opacity(0.9) }
        return .primary.opacity(0.38)
    }

    private func scroll(to index: Int?, proxy: ScrollViewProxy) {
        guard let index else { return }
        let update = { proxy.scrollTo(index, anchor: .center) }
        if reduceMotion {
            update()
        } else {
            withAnimation(.easeInOut(duration: 0.26)) {
                update()
            }
        }
    }
}

private struct RTLWordWrapLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = max(1, proposal.width ?? 320)
        let lines = measuredLines(maxWidth: maxWidth, subviews: subviews)
        let height = lines.enumerated().reduce(CGFloat.zero) { total, item in
            total + item.element.height + (item.offset == 0 ? 0 : lineSpacing)
        }
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout ()) {
        let lines = measuredLines(maxWidth: max(1, bounds.width), subviews: subviews)
        var y = bounds.minY

        for line in lines {
            var x = bounds.maxX
            for entry in line.entries {
                x -= entry.size.width
                subviews[entry.index].place(
                    at: CGPoint(x: x, y: y + (line.height - entry.size.height) / 2),
                    proposal: ProposedViewSize(entry.size)
                )
                x -= spacing
            }
            y += line.height + lineSpacing
        }
    }

    private func measuredLines(maxWidth: CGFloat, subviews: Subviews) -> [Line] {
        var lines: [Line] = []
        var current = Line()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = current.entries.isEmpty
                ? size.width
                : current.width + spacing + size.width

            if !current.entries.isEmpty && nextWidth > maxWidth {
                lines.append(current)
                current = Line()
            }

            current.entries.append((index, size))
            current.width = current.entries.count == 1 ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
        }

        if !current.entries.isEmpty {
            lines.append(current)
        }

        return lines
    }

    private struct Line {
        var entries: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }
}
