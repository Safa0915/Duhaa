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
    @State private var query = ""

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isSearching: Bool { !trimmed.isEmpty }

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    searchResults
                } else {
                    continueReadingSection
                    Section {
                        ForEach(Quran.shared.surahs) { surahLink($0) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .background(Palette.appBg.ignoresSafeArea())
            .navigationTitle("Quran")
            .searchable(text: $query, prompt: "Search surahs or verses")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { BookmarksView() } label: { Image(systemName: "bookmark") }
                        .tint(Palette.gold)
                }
            }
        }
        .preferredColorScheme(Palette.active.colorScheme)
        .tint(Palette.gold)
    }

    // MARK: Continue reading

    @ViewBuilder private var continueReadingSection: some View {
        if let number = bookmarks.lastReadSurah, let surah = Quran.surah(number) {
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

    @ViewBuilder private var searchResults: some View {
        let surahs = surahMatches
        let verses = verseMatches
        if !surahs.isEmpty {
            Section("Surahs") { ForEach(surahs) { surahLink($0) } }
        }
        if !verses.isEmpty {
            Section("Verses") {
                ForEach(verses) { match in
                    NavigationLink {
                        SurahReaderView(surah: match.surah, scrollTo: match.ayah.number)
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

    private var surahMatches: [Surah] {
        Quran.shared.surahs.filter {
            $0.englishName.localizedStandardContains(trimmed)
            || $0.translation.localizedStandardContains(trimmed)
            || $0.arabicName.contains(trimmed)
            || "\($0.number)" == trimmed
        }
    }

    private var verseMatches: [VerseMatch] {
        guard trimmed.count >= 2 else { return [] }
        var out: [VerseMatch] = []
        outer: for surah in Quran.shared.surahs {
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
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(Palette.gold.opacity(0.4), lineWidth: 1.2)
                    .frame(width: 34, height: 34)
                Text("\(surah.number)")
                    .duhaaFont(12, .semibold)
                    .foregroundStyle(Palette.gold)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(surah.englishName)
                    .duhaaFont(16, .medium)
                    .foregroundStyle(.primary)
                Text("\(surah.translation) · \(surah.revelation) · \(surah.ayahs.count) ayahs")
                    .duhaaFont(12)
                    .foregroundStyle(Palette.blue.opacity(0.7))
            }
            Spacer()
            Text(surah.arabicName)
                .font(QuranFont.uthmani(20))
                .foregroundStyle(Palette.gold)
        }
        .padding(.vertical, 4)
    }
}
