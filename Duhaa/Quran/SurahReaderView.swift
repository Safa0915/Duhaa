import SwiftUI

/// Reads one surah: a header, the Bismillah (where it applies), then each ayah
/// with Arabic (RTL), the ClearQuran English, a bookmark toggle, and a
/// per-ayah play button (streams Mishary Alafasy and auto-advances).
struct SurahReaderView: View {
    let surah: Surah
    /// If set, scroll to this ayah on appear (used when opening a bookmark).
    var scrollTo: Int? = nil

    @Environment(QuranBookmarks.self) private var bookmarks
    @State private var furthestAyah = 0
    @State private var player = AyahPlayer()
    @State private var showingChapterAudioHint = false

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
                if let scrollTo { proxy.scrollTo(scrollTo, anchor: .top) }
            }
            .onChange(of: player.playingKey) { _, key in
                if let key, let ayahNumber = Int(key.split(separator: ":").last ?? "") {
                    withAnimation(.easeInOut) { proxy.scrollTo(ayahNumber, anchor: .center) }
                }
            }
        }
        .scrollIndicators(.hidden)
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle(surah.englishName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if player.isActive { player.stop() }
                    else if selectedReciter?.supportsChapterAudio == true { player.playChapter(in: surah) }
                    else { player.play(in: surah, from: 1) }
                } label: {
                    Image(systemName: player.isActive ? "pause.circle.fill" : "play.circle")
                        .foregroundStyle(Palette.gold)
                }
                .accessibilityLabel(player.isActive ? "Pause surah" : "Play surah")
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
                .fill(isPlaying ? Palette.gold.opacity(0.08) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isPlaying ? Palette.gold.opacity(0.35) : .clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: isPlaying)
        .onAppear { furthestAyah = max(furthestAyah, ayah.number) }
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
