import SwiftUI

/// A matched ayah from a search.
private struct VerseMatch: Identifiable {
    let surah: Surah
    let ayah: Ayah
    var id: String { "\(surah.number):\(ayah.number)" }
}

/// The Quran tab: Continue Reading, the 114 surahs, search across surahs and
/// verses, plus a bookmarks shortcut.
struct QuranListView: View {
    @Environment(QuranBookmarks.self) private var bookmarks
    @Environment(QuranReadingProgress.self) private var progress
    @State private var query = ""
    @State private var quran: QuranData?
    @State private var showingResetConfirm = false

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isSearching: Bool { !trimmed.isEmpty }

    var body: some View {
        Group {
            if let quran {
                quranList(quran)
            } else {
                loadingView
            }
        }
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle("Quran")
        .searchable(text: $query, prompt: "Search surahs or verses")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { BookmarksView() } label: { Image(systemName: "bookmark") }
                    .tint(Palette.gold)
                    .accessibilityLabel("Bookmarks")
            }
        }
        .preferredColorScheme(Palette.active.colorScheme)
        .tint(Palette.gold)
        .task {
            guard quran == nil else { return }
            quran = await Quran.loadAsync()
        }
    }

    // Host provides the NavigationStack (see MainTabView / MoreView).
    private func quranList(_ quran: QuranData) -> some View {
        List {
            if isSearching {
                searchResults(quran)
            } else {
                khatmahSection
                continueReadingSection(quran)
                Section {
                    ForEach(quran.surahs) { surahLink($0) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .duhaaReadableWidth()
        .confirmationDialog("Reset reading progress?",
                            isPresented: $showingResetConfirm, titleVisibility: .visible) {
            Button("Reset progress", role: .destructive) { progress.reset() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This clears your khatmah progress so you can begin again. Completed khatmahs are kept.")
        }
    }

    // MARK: Khatmah progress

    @ViewBuilder private var khatmahSection: some View {
        if progress.hasProgress {
            Section {
                HStack(spacing: 16) {
                    progressRing(progress.overallProgress)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Quran Progress")
                            .duhaaFont(12, .semibold).foregroundStyle(Palette.gold)
                        Text("\(progress.versesRead.formatted()) of \(progress.totalVerses.formatted()) verses")
                            .duhaaFont(14).foregroundStyle(.primary)
                        if progress.completedKhatmahs > 0 {
                            Text("Completed \(progress.completedKhatmahs)× — alhamdulillah 🤍")
                                .duhaaFont(11).foregroundStyle(Palette.blue.opacity(0.8))
                        }
                    }
                    Spacer()
                    Button { showingResetConfirm = true } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .duhaaFont(15).foregroundStyle(Palette.blue.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Reset reading progress")
                }
                .padding(.vertical, 4)
                .listRowBackground(Palette.card)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Quran progress, \(Int(progress.overallProgress * 100)) percent, \(progress.versesRead) of \(progress.totalVerses) verses read")
            }
        }
    }

    private func progressRing(_ fraction: Double) -> some View {
        ZStack {
            Circle().stroke(Palette.gold.opacity(0.15), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0.001, fraction))
                .stroke(Palette.gold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(fraction * 100))%")
                .duhaaFont(11, .semibold).foregroundStyle(Palette.gold)
        }
        .frame(width: 46, height: 46)
    }

    private var loadingView: some View {
        ProgressView()
            .tint(Palette.gold)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Continue reading

    @ViewBuilder private func continueReadingSection(_ quran: QuranData) -> some View {
        if let number = bookmarks.lastReadSurah, let surah = quran.surah(number) {
            Section {
                NavigationLink {
                    SurahReaderView(surah: surah, scrollTo: bookmarks.lastReadAyah)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "book.fill")
                            .duhaaFont(17).foregroundStyle(Palette.gold).frame(width: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Continue Reading")
                                .duhaaFont(12, .semibold).foregroundStyle(Palette.gold)
                            Text("\(surah.englishName) · Ayah \(bookmarks.lastReadAyah)")
                                .duhaaFont(14).foregroundStyle(.primary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .duhaaFont(20).foregroundStyle(Palette.gold.opacity(0.7))
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Palette.card)
            }
        }
    }

    // MARK: Search

    @ViewBuilder private func searchResults(_ quran: QuranData) -> some View {
        let surahs = surahMatches(in: quran)
        let verses = verseMatches(in: quran)
        if !surahs.isEmpty {
            Section("Surahs") { ForEach(surahs) { surahLink($0) } }
        }
        if !verses.isEmpty {
            Section("Verses") {
                ForEach(verses) { match in
                    NavigationLink {
                        SurahReaderView(surah: match.surah, scrollTo: match.ayah.number, highlightTarget: true)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(match.surah.englishName) · \(match.surah.number):\(match.ayah.number)")
                                .duhaaFont(13, .semibold).foregroundStyle(Palette.gold)
                            Text(match.ayah.english)
                                .duhaaFont(13).foregroundStyle(.primary.opacity(0.8))
                                .lineLimit(2)
                        }
                        .padding(.vertical, 3)
                    }
                    .listRowBackground(Palette.card)
                }
            }
        }
        if surahs.isEmpty && verses.isEmpty {
            Section {
                Text("No matches for “\(trimmed)”.").foregroundStyle(.secondary)
            }
        }
    }

    private func surahMatches(in quran: QuranData) -> [Surah] {
        quran.surahs.filter {
            $0.englishName.localizedStandardContains(trimmed)
            || $0.translation.localizedStandardContains(trimmed)
            || $0.arabicName.contains(trimmed)
            || "\($0.number)" == trimmed
        }
    }

    private func verseMatches(in quran: QuranData) -> [VerseMatch] {
        guard trimmed.count >= 2 else { return [] }
        var out: [VerseMatch] = []
        outer: for surah in quran.surahs {
            for ayah in surah.ayahs where ayah.english.localizedStandardContains(trimmed) {
                out.append(VerseMatch(surah: surah, ayah: ayah))
                if out.count >= 40 { break outer }
            }
        }
        return out
    }

    // MARK: Rows

    private func surahLink(_ surah: Surah) -> some View {
        NavigationLink {
            SurahReaderView(surah: surah)
        } label: {
            row(surah)
        }
        .listRowBackground(Palette.card)
    }

    private func row(_ surah: Surah) -> some View {
        let frac = progress.progress(surah: surah.number)
        let complete = progress.isComplete(surah: surah.number)
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(complete ? Palette.gold.opacity(0.9) : Palette.gold.opacity(0.09))
                Circle().stroke(Palette.gold.opacity(0.4), lineWidth: 1.2)
                if complete {
                    Image(systemName: "checkmark")
                        .duhaaFont(13, .bold).foregroundStyle(Palette.onAccent)
                } else {
                    Text("\(surah.number)")
                        .duhaaFont(12, .semibold)
                        .foregroundStyle(Palette.gold)
                }
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 4) {
                Text(surah.englishName)
                    .duhaaFont(16, .medium)
                    .foregroundStyle(.primary)
                Text("\(surah.translation) · \(surah.revelation) · \(surah.ayahs.count) ayahs")
                    .duhaaFont(12)
                    .foregroundStyle(Palette.blue.opacity(0.7))
                // A quiet sliver of progress — only while a surah is partway read.
                if frac > 0 && !complete {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Palette.gold.opacity(0.15))
                            Capsule().fill(Palette.gold.opacity(0.8))
                                .frame(width: geo.size.width * frac)
                        }
                    }
                    .frame(height: 3)
                    .padding(.trailing, 40)
                }
            }
            Spacer()
            Text(surah.arabicName)
                .font(QuranFont.uthmani(20))
                .foregroundStyle(Palette.gold)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel(surah, frac: frac, complete: complete))
    }

    private func rowAccessibilityLabel(_ surah: Surah, frac: Double, complete: Bool) -> String {
        var label = "\(surah.englishName), \(surah.translation), \(surah.ayahs.count) ayahs"
        if complete { label += ", read" }
        else if frac > 0 { label += ", \(Int(frac * 100)) percent read" }
        return label
    }
}
