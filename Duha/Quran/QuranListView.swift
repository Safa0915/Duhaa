import SwiftUI

/// The Quran tab: the 114 surahs, searchable, plus a bookmarks shortcut.
struct QuranListView: View {
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { surah in
                    NavigationLink {
                        SurahReaderView(surah: surah)
                    } label: {
                        row(surah)
                    }
                    .listRowBackground(Palette.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.appBg.ignoresSafeArea())
            .navigationTitle("Quran")
            .searchable(text: $query, prompt: "Surah name or number")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        BookmarksView()
                    } label: {
                        Image(systemName: "bookmark")
                    }
                    .tint(Palette.gold)
                }
            }
        }
        .preferredColorScheme(Palette.active.colorScheme)
        .tint(Palette.gold)
    }

    private var filtered: [Surah] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return Quran.shared.surahs }
        return Quran.shared.surahs.filter {
            $0.englishName.lowercased().contains(q)
            || $0.translation.lowercased().contains(q)
            || $0.arabicName.contains(q)
            || "\($0.number)" == q
        }
    }

    private func row(_ surah: Surah) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().stroke(Palette.gold.opacity(0.4), lineWidth: 1.2)
                    .frame(width: 34, height: 34)
                Text("\(surah.number)")
                    .duhaFont(12, .semibold)
                    .foregroundStyle(Palette.gold)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(surah.englishName)
                    .duhaFont(16, .medium)
                    .foregroundStyle(.primary)
                Text("\(surah.translation) · \(surah.revelation) · \(surah.ayahs.count) ayahs")
                    .duhaFont(12)
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
