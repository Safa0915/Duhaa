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
    @Environment(QuranReadingProgress.self) private var readingProgress
    @Environment(QuranNotes.self) private var notes
    @Environment(AyahPlayer.self) private var player
    @Environment(FeedbackStore.self) private var feedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var furthestAyah = 0

    // The one-time jump-to-verse: where we are, whether we've already jumped, the
    // currently-glowing ayah, and a quiet fallback message if the ayah is missing.
    @State private var didInitialJump = false
    @State private var highlightedAyah: Int? = nil
    @State private var jumpMessage: String? = nil

    /// The ayah whose tafsir sheet is open, if any.
    @State private var tafsirAyah: Ayah? = nil

    /// Whether the reading-options popover (size slider, translation) is showing.
    @State private var showingReadingOptions = false
    /// Whether the reciter photo gallery is showing.
    @State private var showingReciterPicker = false
    /// Whether the immersive "Listen" player is showing.
    @State private var showingNowPlaying = false
    /// Whether the full-page Mushaf reader is showing.
    @State private var showingMushaf = false
    @State private var showingNoteEditor = false
    @State private var variantArabicText: [Int: String] = [:]

    /// Place the target a little above center so it reads cleanly with context above it.
    private let jumpAnchor = UnitPoint(x: 0.5, y: 0.3)

    // Reading preferences — shared across all surahs.
    @AppStorage("duhaa.quran.reciter") private var reciterID = Reciters.defaultID
    @AppStorage("duhaa.quran.arabicSize") private var arabicSize = 28.0
    @AppStorage("duhaa.quran.showArabic") private var showArabic = true
    @AppStorage("duhaa.quran.showTransliteration") private var showTransliteration = false
    @AppStorage("duhaa.quran.showTranslation") private var showTranslation = true
    @AppStorage("duhaa.quran.readerFont") private var readerFont = "kfgqpc"

    private var selectedReciter: Reciter? {
        Reciters.byID(reciterID) ?? Reciters.byID(Reciters.defaultID)
    }

    private var openingPageNumber: Int? {
        guard let firstAyah = surah.ayahs.first else { return nil }
        return QuranPageIndex.shared.pageNumber(surah: surah.number, ayah: firstAyah.number)
    }

    private var openingPageIsContinuation: Bool {
        guard let firstAyah = surah.ayahs.first else { return false }
        return QuranPageIndex.shared.pageStartNumber(surah: surah.number, ayah: firstAyah.number) == nil
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    header
                    readerContent
                    reflectionSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .duhaaReadableWidth()
            }
            .onAppear {
                FirstUseDiagnostics.event("Quran reader view first appear", "\(surah.number)")
                performInitialJump(using: proxy)
            }
            .onChange(of: player.playingKey) { _, key in
                if key != nil,
                   player.currentSurah?.number == surah.number,
                   let ayahNumber = player.playingAyahNumber {
                    withAnimation(.easeInOut) { proxy.scrollTo(scrollTargetID(for: ayahNumber), anchor: .center) }
                }
            }
        }
        .scrollIndicators(.hidden)
        .background(Palette.appBg.ignoresSafeArea())
        .overlay(alignment: .bottom) { bottomOverlay }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: jumpMessage)
        .task {
            feedback.recordMeaningfulAction(.quranRead)
            FirstUseDiagnostics.event("Quran feature first async startup begins", "reciters-prewarm")
            _ = await Reciters.loadAsync(priority: .utility)
        }
        .task(id: "\(surah.number)-\(readerFont)") {
            await loadVariantArabicText()
        }
        .navigationTitle(surah.englishName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                surahPlayButton
            }
            ToolbarItem(placement: .topBarTrailing) {
                mushafButton
            }
            ToolbarItem(placement: .topBarTrailing) {
                reciterButton
            }
            ToolbarItem(placement: .topBarTrailing) {
                readingOptionsButton
            }
        }
        .sheet(isPresented: $showingReciterPicker) {
            ReciterPickerView(selection: $reciterID)
        }
        .fullScreenCover(isPresented: $showingNowPlaying) {
            if let reciter = selectedReciter {
                NowPlayingView(surah: player.currentSurah ?? surah, reciter: reciter, player: player,
                               startAyah: player.playingAyahNumber ?? scrollTo ?? 1)
            }
        }
        .fullScreenCover(isPresented: $showingMushaf) {
            MushafReaderView(startPage: mushafStartPage)
        }
        .onChange(of: reciterID) {
            // Seamless voice change: restart the current ayah in the new voice.
            guard player.isActive else { return }
            let activeSurah = player.currentSurah ?? surah
            let ayahNumber = player.playingAyahNumber
            player.stop()
            if selectedReciter?.supportsChapterAudio == true {
                player.playChapter(in: activeSurah)
            } else if let ayahNumber {
                player.play(in: activeSurah, from: ayahNumber)
            }
        }
        .onDisappear {
            let readAyah = max(furthestAyah, scrollTo ?? 1)
            bookmarks.recordRead(surah: surah.number, ayah: readAyah)
            readingProgress.recordRead(surah: surah.number, ayah: readAyah)
        }
        .sheet(item: $tafsirAyah) { ayah in
            TafsirView(surah: surah, ayah: ayah)
        }
        .sheet(isPresented: $showingNoteEditor) {
            SurahNoteEditor(surah: surah, notes: notes)
        }
    }

    // MARK: Reflection (private journaling under each surah)

    private var reflectionSection: some View {
        let saved = notes.note(forSurah: surah.number)
        let hasNote = notes.hasNote(forSurah: surah.number)
        return Button {
            showingNoteEditor = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: hasNote ? "note.text" : "square.and.pencil")
                        .duhaaFont(14).foregroundStyle(Palette.gold)
                    Text("Reflection")
                        .duhaaFont(12, .semibold).tracking(0.8)
                        .foregroundStyle(Palette.gold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .duhaaFont(11).foregroundStyle(Palette.blue.opacity(0.5))
                }
                if hasNote {
                    Text(saved)
                        .duhaaFont(15)
                        .foregroundStyle(.primary.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(6)
                } else {
                    Text(ReflectionPrompt.forSurah(surah.number))
                        .duhaaFont(15)
                        .foregroundStyle(.primary.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Tap to write a private note — just for you. 🤍")
                        .duhaaFont(12)
                        .foregroundStyle(Palette.blue.opacity(0.6))
                }
            }
            .padding(16)
            .background(Palette.card)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.cardBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .padding(.top, 28)
        .accessibilityLabel(hasNote ? "Your reflection on this surah" : "Add a reflection on this surah")
        .accessibilityHint("Opens a private note")
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
            proxy.scrollTo(scrollTargetID(for: target), anchor: jumpAnchor)
            scrollPrecisely(to: target, using: proxy, after: 0.35, reveal: true)
            scrollPrecisely(to: target, using: proxy, after: 0.7, reveal: false)
        }
    }

    private func scrollPrecisely(to target: Int, using proxy: ScrollViewProxy,
                                 after delay: TimeInterval, reveal: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let id = scrollTargetID(for: target)
            if reduceMotion {
                proxy.scrollTo(id, anchor: jumpAnchor)
            } else {
                withAnimation(.easeInOut(duration: 0.4)) { proxy.scrollTo(id, anchor: jumpAnchor) }
            }
            if reveal { revealHighlight(target) }
        }
    }

    private func scrollTargetID(for ayahNumber: Int) -> AnyHashable {
        AnyHashable(ayahNumber)
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

    @ViewBuilder
    private var readerContent: some View {
        if let page = openingPageNumber {
            pageMarker(page, isContinuation: openingPageIsContinuation)
        }
        if surah.number != 1 && surah.number != 9 {
            bismillah
        }
        ForEach(surah.ayahs) { ayah in
            if let page = pageStartNumber(before: ayah) {
                pageMarker(page, isContinuation: false)
            }
            ayahView(ayah)
                .id(AnyHashable(ayah.number))
            Divider().overlay(Palette.blue.opacity(0.12))
        }
    }

    @ViewBuilder
    private var bottomOverlay: some View {
        VStack(spacing: 10) {
            if let message = jumpMessage ?? player.failureMessage {
                Text(message)
                    .duhaaFont(13, .medium)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Palette.gold.opacity(0.3), lineWidth: 1))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if player.isActive {
                readerMiniPlayer
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var readerMiniPlayer: some View {
        let activeSurah = player.currentSurah ?? surah
        let ayahNumber = player.playingAyahNumber ?? 1
        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                if let reciter = selectedReciter {
                    ReciterAvatar(reciter: reciter, size: 38)
                        .overlay(Circle().stroke(Palette.gold.opacity(0.45), lineWidth: 1))
                        .onTapGesture {
                            showingNowPlaying = true
                            DuhaaHaptics.tap()
                        }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(activeSurah.englishName)
                        .duhaaFont(13, .semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(player.isPlayingChapterRecording
                         ? "Full surah · \(selectedReciter?.name ?? "Recitation")"
                         : "Ayah \(ayahNumber) of \(activeSurah.ayahs.count) · \(selectedReciter?.name ?? "Recitation")")
                        .duhaaFont(11, .medium)
                        .foregroundStyle(Palette.blue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showingNowPlaying = true
                    DuhaaHaptics.tap()
                }

                Spacer(minLength: 8)

                Button {
                    player.togglePlayPause()
                    DuhaaHaptics.tap()
                } label: {
                    ZStack {
                        Circle().fill(Palette.gold).frame(width: 36, height: 36)
                        if player.isLoading {
                            ProgressView().controlSize(.small).tint(Palette.onAccent)
                        } else {
                            Image(systemName: miniPlayerIsPlaying ? "pause.fill" : "play.fill")
                                .duhaaFont(14, .bold)
                                .foregroundStyle(Palette.onAccent)
                                .offset(x: miniPlayerIsPlaying ? 0 : 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(miniPlayerIsPlaying ? "Pause recitation" : "Play recitation")

                Button {
                    showingNowPlaying = true
                    DuhaaHaptics.tap()
                } label: {
                    Image(systemName: "chevron.up.circle.fill")
                        .duhaaFont(22, .semibold)
                        .foregroundStyle(Palette.gold)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open player")
            }

            miniProgressBar
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Palette.gold.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 16, y: 8)
    }

    private var miniProgressBar: some View {
        GeometryReader { proxy in
            let progress = max(0, min(1, player.progress))
            let headSize: CGFloat = 12
            let filledWidth = proxy.size.width * progress
            let headOffset = min(
                max(0, filledWidth - headSize / 2),
                max(0, proxy.size.width - headSize)
            )

            ZStack(alignment: .leading) {
                Capsule().fill(Palette.blue.opacity(0.16))
                Capsule()
                    .fill(Palette.gold)
                    .frame(width: filledWidth)
                miniProgressHead
                    .frame(width: headSize, height: headSize)
                    .offset(x: headOffset)
            }
        }
        .frame(height: 12)
    }

    private var miniProgressHead: some View {
        ZStack {
            Circle()
                .fill(Palette.gold)
                .shadow(color: Palette.gold.opacity(0.45), radius: 5)
            Image(systemName: "star.fill")
                .duhaaFont(5, .bold)
                .foregroundStyle(Palette.onAccent)
        }
        .accessibilityHidden(true)
    }

    private var miniPlayerIsPlaying: Bool {
        switch player.playbackState {
        case .playing, .ready, .loading, .buffering:
            return true
        default:
            return false
        }
    }

    @ViewBuilder
    private var surahPlayButton: some View {
        if selectedReciter?.supportsAyahAudio == true {
            Button { showingNowPlaying = true } label: {
                Image(systemName: "headphones").foregroundStyle(Palette.gold)
            }
            .accessibilityLabel("Listen")
        } else {
            Button {
                if !player.isPlayingChapter(surah.number) {
                    player.playChapter(in: surah)
                }
                showingNowPlaying = true
            } label: {
                if player.isLoading {
                    ProgressView().controlSize(.small).tint(Palette.gold)
                } else {
                    Image(systemName: "headphones")
                        .foregroundStyle(Palette.gold)
                }
            }
            .accessibilityLabel(player.isLoading ? "Loading recitation" : "Listen")
        }
    }

    /// The mushaf page to open the full-page reader on — the reader's current
    /// position (furthest read, else the jump target, else the surah's start).
    private var mushafStartPage: Int {
        let ayah = furthestAyah > 0 ? furthestAyah : (scrollTo ?? surah.ayahs.first?.number ?? 1)
        return QuranPageIndex.shared.pageNumber(surah: surah.number, ayah: ayah) ?? 1
    }

    /// Opens the full-page Mushaf reader (one page per screen, Arabic only).
    private var mushafButton: some View {
        Button {
            showingMushaf = true
            DuhaaHaptics.tap()
        } label: {
            Image(systemName: "book.pages")
                .foregroundStyle(Palette.gold)
        }
        .accessibilityLabel("Read full page")
    }

    /// Opens the reciter photo gallery. The button itself shows the current
    /// reciter's avatar so the active voice is visible at a glance.
    private var reciterButton: some View {
        Button { showingReciterPicker = true } label: {
            if let reciter = selectedReciter {
                ReciterAvatar(reciter: reciter, size: 28)
                    .overlay(Circle().stroke(Palette.gold.opacity(0.6), lineWidth: 1))
            } else {
                Image(systemName: "person.crop.circle")
                    .foregroundStyle(Palette.gold)
            }
        }
        .accessibilityLabel("Reciter: \(selectedReciter?.name ?? "choose")")
    }

    /// Opens the reading-options popover (a draggable size slider + translation).
    private var readingOptionsButton: some View {
        Button { showingReadingOptions = true } label: {
            Image(systemName: "textformat.size")
                .foregroundStyle(Palette.gold)
        }
        .accessibilityLabel("Reading options")
        .popover(isPresented: $showingReadingOptions) {
            readingOptionsPopover
                .presentationCompactAdaptation(.popover)
        }
    }

    /// A drag-to-resize Arabic size slider and translation visibility.
    private var readingOptionsPopover: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Arabic size").duhaaFont(15, .semibold)
                    Spacer()
                    Text("\(Int(arabicSize)) pt")
                        .duhaaFont(13, .medium)
                        .foregroundStyle(Palette.blue)
                }
                HStack(spacing: 12) {
                    Image(systemName: "textformat.size.smaller")
                        .foregroundStyle(.secondary)
                    Slider(value: $arabicSize, in: 22...40, step: 2)
                        .tint(Palette.gold)
                        .accessibilityLabel("Arabic size")
                        .accessibilityValue("\(Int(arabicSize)) points")
                    Image(systemName: "textformat.size.larger")
                        .foregroundStyle(.secondary)
                }
            }

            Divider().overlay(Palette.blue.opacity(0.15))

            VStack(alignment: .leading, spacing: 12) {
                Text("Show")
                    .duhaaFont(15, .semibold)
                contentToggle("Arabic", isOn: $showArabic)
                contentToggle("Transliteration", isOn: $showTransliteration)
                contentToggle("Translation", isOn: $showTranslation)
                Text("Choose what shows under each ayah. At least one stays on.")
                    .duhaaFont(11)
                    .foregroundStyle(Palette.blue.opacity(0.7))
            }
        }
        .padding(20)
        .frame(width: 300)
    }

    /// Number of display layers currently enabled — used to keep at least one on.
    private var enabledContentCount: Int {
        [showArabic, showTransliteration, showTranslation].filter { $0 }.count
    }

    /// A display toggle that refuses to turn off the *last* enabled layer, so the
    /// ayah is never left completely blank.
    private func contentToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: Binding(
            get: { isOn.wrappedValue },
            set: { newValue in
                if newValue == false && isOn.wrappedValue && enabledContentCount <= 1 { return }
                isOn.wrappedValue = newValue
            }
        )) {
            Text(title).duhaaFont(14)
        }
        .tint(Palette.gold)
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
        arabicDisplayText(QuranFont.bismillah(for: readerFont), defaultColor: Palette.gold.opacity(0.9))
            .font(QuranFont.reader(readerFont, size: 26))
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
            .environment(\.layoutDirection, .rightToLeft)
    }

    private func pageStartNumber(before ayah: Ayah) -> Int? {
        guard ayah.number != surah.ayahs.first?.number else { return nil }
        return QuranPageIndex.shared.pageStartNumber(surah: surah.number, ayah: ayah.number)
    }

    private func pageMarker(_ page: Int, isContinuation: Bool) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                pageRule
                Text("Page \(page)")
                    .duhaaFont(12, .semibold)
                    .tracking(1.2)
                    .foregroundStyle(Palette.gold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Palette.gold.opacity(0.10)))
                    .overlay(Capsule().stroke(Palette.gold.opacity(0.28), lineWidth: 1))
                pageRule
            }

            Text(isContinuation ? "continues from previous page" : "new Quran page begins here")
                .duhaaFont(10, .medium)
                .foregroundStyle(Palette.blue.opacity(0.55))
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isContinuation
                            ? "Quran page \(page), continuing from the previous page"
                            : "Quran page \(page) begins here")
    }

    private var pageRule: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.clear, Palette.gold.opacity(0.45), .clear],
                                 startPoint: .leading,
                                 endPoint: .trailing))
            .frame(height: 1)
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
                        tafsirAyah = ayah
                        DuhaaHaptics.tap()
                    } label: {
                        Image(systemName: "book")
                            .duhaaFont(15)
                            .foregroundStyle(Palette.gold)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tafsir for ayah \(ayah.number)")
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

            if showArabic {
                let arabic = arabicText(for: ayah)
                arabicDisplayText(arabic, defaultColor: .primary)
                    .font(QuranFont.reader(readerFont, size: arabicSize))
                    .lineSpacing(arabicSize / 2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
                    .accessibilityLabel(arabic)
            }

            if showTransliteration,
               let translit = QuranTransliteration.shared.text(surah: surah.number, ayah: ayah.number) {
                Text(translit)
                    .duhaaFont(14.5)
                    .italic()
                    .lineSpacing(3)
                    .foregroundStyle(Palette.blue.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Transliteration: \(translit)")
            }

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

    @MainActor
    private func loadVariantArabicText() async {
        let preference = QuranFontPreference(storageValue: readerFont)
        guard preference.verseTextField != .textUthmani else {
            variantArabicText = [:]
            return
        }

        do {
            let text = try await QuranTextVariantAPI.shared.chapter(surah.number, preference: preference)
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
        return Text(display).foregroundColor(defaultColor)
    }

    @ViewBuilder
    private func playButton(_ ayah: Ayah, isPlaying: Bool) -> some View {
        if selectedReciter?.supportsAyahSeek == true {
            // Full-surah recording that can begin at this ayah (seeks into the file).
            Button {
                player.playChapter(in: surah, fromAyah: ayah.number)
                showingNowPlaying = true
            } label: {
                Image(systemName: "play.circle")
                    .duhaaFont(16)
                    .foregroundStyle(Palette.gold)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play from ayah \(ayah.number)")
        } else if selectedReciter?.supportsChapterAudio == true {
            Button {
                if !player.isPlayingChapter(surah.number) {
                    player.playChapter(in: surah)
                }
                showingNowPlaying = true
            } label: {
                Image(systemName: "music.note.list")
                    .duhaaFont(16)
                    .foregroundStyle(Palette.gold)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open full-surah player")
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

/// A private reflection editor for a surah. Writes straight to `QuranNotes` on
/// save; a blank note clears any previous one. No sharing, no sync — just a quiet
/// space to journal.
private struct SurahNoteEditor: View {
    @Environment(\.dismiss) private var dismiss
    let surah: Surah
    let notes: QuranNotes

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(ReflectionPrompt.forSurah(surah.number))
                    .duhaaFont(15, .medium)
                    .foregroundStyle(Palette.blue.opacity(0.9))
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .duhaaFont(16)
                        .scrollContentBackground(.hidden)
                        .focused($focused)
                        .padding(.horizontal, 16)
                    if text.isEmpty {
                        Text("Write your reflection…")
                            .duhaaFont(16)
                            .foregroundStyle(Palette.secondaryText.opacity(0.6))
                            .padding(.top, 8)
                            .padding(.leading, 21)
                            .allowsHitTesting(false)
                    }
                }

                Text("Private to you, kept on this device. 🤍")
                    .duhaaFont(12)
                    .foregroundStyle(Palette.blue.opacity(0.55))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
            .background(Palette.appBg.ignoresSafeArea())
            .navigationTitle("\(surah.englishName) · Reflection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        notes.setNote(text, forSurah: surah.number)
                        dismiss()
                    }
                    .foregroundStyle(Palette.gold)
                }
            }
        }
        .preferredColorScheme(Palette.active.colorScheme)
        .tint(Palette.gold)
        .onAppear {
            text = notes.note(forSurah: surah.number)
            focused = true
        }
    }
}
