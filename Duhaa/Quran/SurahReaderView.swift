import SwiftUI

/// Reads one surah: a header, the Bismillah (where it applies), then each ayah
/// with Arabic (RTL), the ClearQuran English, a bookmark toggle, and a
/// per-ayah play button (streams Mishary Alafasy and auto-advances).
struct SurahReaderView: View {
    let surah: Surah
    /// If set, scroll to this ayah on appear (bookmark, search, Verse of the Day).
    var scrollTo: Int? = nil
    /// When true, the target ayah is briefly highlighted in the theme accent after the
    /// jump (used for "jump to a specific verse" entry points; off for resume-reading).
    var highlightTarget: Bool = false

    @Environment(QuranBookmarks.self) private var bookmarks
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var furthestAyah = 0
    @State private var player = AyahPlayer()
    @State private var showingChapterAudioHint = false

    // The one-time jump-to-verse: where we are, whether we've already jumped, the
    // currently-glowing ayah, and a quiet fallback message if the ayah is missing.
    @State private var didInitialJump = false
    @State private var highlightedAyah: Int? = nil
    @State private var jumpMessage: String? = nil

    /// Place the target a little above center so it reads cleanly with context above it.
    private let jumpAnchor = UnitPoint(x: 0.5, y: 0.3)

    // Reading preferences — shared across all surahs.
    @AppStorage("duhaa.quran.reciter") private var reciterID = Reciters.defaultID
    @AppStorage("duhaa.quran.arabicSize") private var arabicSize = 28.0
    @AppStorage("duhaa.quran.showTranslation") private var showTranslation = true
    @AppStorage("duhaa.quran.readerFont") private var readerFont = "kfgqpc"
    @AppStorage("duhaa.quran.tajweedColoring") private var tajweedColoring = false

    private var selectedReciter: Reciter? {
        Reciters.byID(reciterID) ?? Reciters.byID(Reciters.defaultID)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    header
                    if surah.number != 1 && surah.number != 9 {
                        bismillah
                    }
                    ForEach(surah.ayahs) { ayah in
                        ayahView(ayah)
                            .id(ayah.number)
                        Divider().overlay(Palette.blue.opacity(0.12))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .onAppear {
                FirstUseDiagnostics.event("Quran reader view first appear", "\(surah.number)")
                performInitialJump(using: proxy)
            }
            .onChange(of: player.playingKey) { _, key in
                if let key, let ayahNumber = Int(key.split(separator: ":").last ?? "") {
                    withAnimation(.easeInOut) { proxy.scrollTo(ayahNumber, anchor: .center) }
                }
            }
        }
        .scrollIndicators(.hidden)
        .background(Palette.appBg.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let message = jumpMessage ?? player.failureMessage {
                Text(message)
                    .duhaaFont(13, .medium)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Palette.gold.opacity(0.3), lineWidth: 1))
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: jumpMessage)
        .task {
            FirstUseDiagnostics.event("Quran feature first async startup begins", "reciters-prewarm")
            _ = await Reciters.loadAsync(priority: .utility)
        }
        .navigationTitle(surah.englishName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if player.isActive { player.stop() }
                    else if selectedReciter?.supportsChapterAudio == true { player.playChapter(in: surah) }
                    else { player.play(in: surah, from: 1) }
                } label: {
                    if player.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(Palette.gold)
                    } else {
                        Image(systemName: player.isActive ? "pause.circle.fill" : "play.circle")
                            .foregroundStyle(Palette.gold)
                    }
                }
                .accessibilityLabel(player.isLoading ? "Loading recitation" : (player.isActive ? "Pause surah" : "Play surah"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                readingOptionsMenu
            }
        }
        .onChange(of: reciterID) {
            // Seamless voice change: restart the current ayah in the new voice.
            guard player.isActive else { return }
            let ayahNumber = player.playingAyahNumber
            player.stop()
            if selectedReciter?.supportsChapterAudio == true {
                player.playChapter(in: surah)
            } else if let ayahNumber {
                player.play(in: surah, from: ayahNumber)
            }
        }
        .onDisappear {
            player.stop()
            bookmarks.recordRead(surah: surah.number, ayah: max(furthestAyah, scrollTo ?? 1))
        }
        .alert("Classic recording", isPresented: $showingChapterAudioHint) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This Alafasy recording streams by surah in Duhaa. Use the play button at the top to listen.")
        }
    }

    // MARK: Jump to a specific verse (Verse of the Day, bookmark, search)

    /// Scroll to `scrollTo` once, after layout, and (optionally) glow it briefly.
    /// Runs a single time per presentation; manual scrolling afterwards is untouched.
    private func performInitialJump(using proxy: ScrollViewProxy) {
        guard !didInitialJump, let target = scrollTo else { return }
        didInitialJump = true

        // Graceful fallback: the surah is open, but this ayah doesn't exist.
        guard surah.ayahs.contains(where: { $0.number == target }) else {
            if highlightTarget { showJumpMessage("Couldn’t jump to verse.") }
            return
        }

        // First pass on the next runloop tick lets the LazyVStack begin laying out;
        // a second pass once heights are known lands precisely (and reveals the glow).
        // A short retry covers a target that wasn't materialized on the first attempt.
        DispatchQueue.main.async {
            proxy.scrollTo(target, anchor: jumpAnchor)
            scrollPrecisely(to: target, using: proxy, after: 0.35, reveal: true)
            scrollPrecisely(to: target, using: proxy, after: 0.7, reveal: false)
        }
    }

    private func scrollPrecisely(to target: Int, using proxy: ScrollViewProxy,
                                 after delay: TimeInterval, reveal: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if reduceMotion {
                proxy.scrollTo(target, anchor: jumpAnchor)
            } else {
                withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo(target, anchor: jumpAnchor) }
            }
            if reveal { revealHighlight(target) }
        }
    }

    /// Glow the target verse, then fade it after a few seconds (Reduce-Motion-aware).
    private func revealHighlight(_ target: Int) {
        guard highlightTarget else { return }
        if reduceMotion {
            highlightedAyah = target
        } else {
            withAnimation(.easeOut(duration: 0.5)) { highlightedAyah = target }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            guard highlightedAyah == target else { return } // don't clobber a newer state
            if reduceMotion {
                highlightedAyah = nil
            } else {
                withAnimation(.easeInOut(duration: 0.8)) { highlightedAyah = nil }
            }
        }
    }

    private func showJumpMessage(_ message: String) {
        jumpMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            guard jumpMessage == message else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { jumpMessage = nil }
        }
    }

    /// Reciter, Arabic text size, and translation visibility — one quiet menu.
    private var readingOptionsMenu: some View {
        Menu {
            Picker("Reciter", selection: $reciterID) {
                ForEach(Reciters.all) { reciter in
                    Text(reciter.name).tag(reciter.id)
                }
            }
            .pickerStyle(.menu)

            Section("Arabic size") {
                ControlGroup {
                    Button { arabicSize = max(22, arabicSize - 2) } label: {
                        Label("Smaller", systemImage: "textformat.size.smaller")
                    }
                    Button { arabicSize = min(40, arabicSize + 2) } label: {
                        Label("Larger", systemImage: "textformat.size.larger")
                    }
                }
            }

            Toggle(isOn: $showTranslation) {
                Label("Show translation", systemImage: "text.alignleft")
            }
        } label: {
            Image(systemName: "textformat.size")
                .foregroundStyle(Palette.gold)
        }
        .accessibilityLabel("Reading options")
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.stars.fill")
                .duhaaFont(15)
                .foregroundStyle(Palette.gold.opacity(0.7))
            Text(surah.arabicName)
                .font(QuranFont.uthmani(34))
                .foregroundStyle(Palette.gold)
            HStack(spacing: 10) {
                ornament
                Text(surah.englishName)
                    .duhaaFont(18, .semibold)
                    .foregroundStyle(.primary)
                ornament
            }
            Text("\(surah.translation) · \(surah.revelation) · \(surah.ayahs.count) ayahs")
                .duhaaFont(12)
                .foregroundStyle(Palette.blue.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(RoundedRectangle(cornerRadius: 20).fill(Palette.card))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(LinearGradient(colors: [Palette.gold.opacity(0.45), Palette.gold.opacity(0.08)],
                                       startPoint: .top, endPoint: .bottom), lineWidth: 1)
        )
        .padding(.top, 10)
        .padding(.bottom, 18)
        .accessibilityElement(children: .combine)
    }

    /// A thin gold hairline flanking the surah name — quiet mushaf ornamentation.
    private var ornament: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, Palette.gold.opacity(0.55)],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: 36, height: 1)
    }

    private var bismillah: some View {
        arabicDisplayText(Quran.shared.bismillah.arabic, defaultColor: Palette.gold.opacity(0.9))
            .font(QuranFont.reader(readerFont, size: 26))
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
            .environment(\.layoutDirection, .rightToLeft)
    }

    private func ayahView(_ ayah: Ayah) -> some View {
        let isPlaying = player.isPlaying(surah.number, ayah.number)
        let isBookmarked = bookmarks.isBookmarked(surah.number, ayah.number)
        let isHighlighted = highlightedAyah == ayah.number
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle().fill(Palette.gold.opacity(isPlaying ? 0.2 : 0.09))
                    Circle().stroke(Palette.gold.opacity(0.4), lineWidth: 1.2)
                    Text("\(ayah.number)")
                        .duhaaFont(12, .semibold)
                        .foregroundStyle(Palette.gold)
                }
                .frame(width: 30, height: 30)
                Spacer()
                HStack(spacing: 18) {
                    playButton(ayah, isPlaying: isPlaying)
                    Button {
                        bookmarks.toggle(surah.number, ayah.number)
                        DuhaaHaptics.tap()
                    } label: {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .duhaaFont(16)
                            .foregroundStyle(Palette.gold)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isBookmarked ? "Remove bookmark for ayah \(ayah.number)" : "Bookmark ayah \(ayah.number)")
                }
            }

            arabicDisplayText(ayah.arabic, defaultColor: .primary)
                .font(QuranFont.reader(readerFont, size: arabicSize))
                .lineSpacing(arabicSize / 2)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)
                .accessibilityLabel(ayah.arabic)

            if showTranslation {
                Text(ayah.english)
                    .duhaaFont(15)
                    .lineSpacing(3)
                    .foregroundStyle(.primary.opacity(0.75))
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(rowFill(isPlaying: isPlaying, isHighlighted: isHighlighted))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(rowStroke(isPlaying: isPlaying, isHighlighted: isHighlighted),
                        lineWidth: isHighlighted ? 1.2 : 1)
        )
        .animation(.easeInOut(duration: 0.3), value: isPlaying)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: isHighlighted)
        .onAppear { furthestAyah = max(furthestAyah, ayah.number) }
    }

    /// Soft accent fill: the temporary verse highlight wins over the playing tint.
    private func rowFill(isPlaying: Bool, isHighlighted: Bool) -> Color {
        if isHighlighted { return Palette.gold.opacity(0.18) }
        if isPlaying { return Palette.gold.opacity(0.08) }
        return .clear
    }

    /// Subtle accent border — a touch firmer for the highlighted verse than for playback.
    private func rowStroke(isPlaying: Bool, isHighlighted: Bool) -> Color {
        if isHighlighted { return Palette.gold.opacity(0.4) }
        if isPlaying { return Palette.gold.opacity(0.35) }
        return .clear
    }

    private func arabicDisplayText(_ raw: String, defaultColor: Color) -> Text {
        let display = QuranArabicText.display(raw)
        guard tajweedColoring else {
            return Text(display).foregroundColor(defaultColor)
        }

        return display.reduce(Text("")) { partial, character in
            partial + Text(String(character)).foregroundColor(color(forArabicMark: character, defaultColor: defaultColor))
        }
    }

    private func color(forArabicMark character: Character, defaultColor: Color) -> Color {
        switch character {
        case "ۖ", "ۗ", "ۘ", "ۙ", "ۚ", "ۛ", "ۜ", "۝":
            Palette.gold
        case "۞", "۩":
            Palette.blue
        default:
            defaultColor
        }
    }

    @ViewBuilder
    private func playButton(_ ayah: Ayah, isPlaying: Bool) -> some View {
        if selectedReciter?.supportsChapterAudio == true {
            Button {
                showingChapterAudioHint = true
            } label: {
                Image(systemName: "music.note.list")
                    .duhaaFont(16)
                    .foregroundStyle(Palette.gold)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Use surah play button for this recording")
        } else {
            Button {
                player.toggle(in: surah, ayah: ayah)
            } label: {
                if isPlaying && player.isBuffering {
                    ProgressView().controlSize(.small).tint(Palette.gold)
                } else {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle")
                        .duhaaFont(16)
                        .foregroundStyle(Palette.gold)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Pause ayah \(ayah.number)" : "Play ayah \(ayah.number)")
        }
    }
}
