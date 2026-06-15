import SwiftUI

/// The saved ayahs. Tapping one opens its surah scrolled to that ayah.
struct BookmarksView: View {
    @Environment(QuranBookmarks.self) private var bookmarks

    var body: some View {
        Group {
            if bookmarks.all.isEmpty {
                ContentUnavailableView("No bookmarks yet",
                                       systemImage: "bookmark",
                                       description: Text("Tap the bookmark icon on any ayah to save it here."))
            } else {
                List {
                    ForEach(bookmarks.all) { ref in
                        if let surah = Quran.surah(ref.surah),
                           let ayah = surah.ayahs.first(where: { $0.number == ref.ayah }) {
                            NavigationLink {
                                SurahReaderView(surah: surah, scrollTo: ref.ayah, highlightTarget: true)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(surah.englishName) · \(ref.surah):\(ref.ayah)")
                                        .duhaaFont(14, .semibold)
                                        .foregroundStyle(Palette.gold)
                                    Text(ayah.english)
                                        .duhaaFont(13)
                                        .foregroundStyle(.primary.opacity(0.75))
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 3)
                            }
                            .listRowBackground(Palette.card)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
        }
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle("Bookmarks")
        .navigationBarTitleDisplayMode(.inline)
    }
}
