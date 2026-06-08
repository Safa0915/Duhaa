import SwiftUI

/// Reads one surah: a header, the Bismillah (where it applies), then each ayah
/// with Arabic (RTL), the Sahih International English, and a bookmark toggle.
struct SurahReaderView: View {
    let surah: Surah
    /// If set, scroll to this ayah on appear (used when opening a bookmark).
    var scrollTo: Int? = nil

    @Environment(QuranBookmarks.self) private var bookmarks
    @State private var furthestAyah = 0

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
        }
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle(surah.englishName)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            bookmarks.recordRead(surah: surah.number, ayah: max(furthestAyah, scrollTo ?? 1))
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(surah.arabicName)
                .font(QuranFont.uthmani(30))
                .foregroundStyle(Palette.gold)
            Text(surah.englishName)
                .duhaFont(18, .semibold)
                .foregroundStyle(.primary)
            Text("\(surah.translation) · \(surah.revelation) · \(surah.ayahs.count) ayahs")
                .duhaFont(12)
                .foregroundStyle(Palette.blue.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }

    private var bismillah: some View {
        Text(Quran.shared.bismillah.arabic)
            .font(QuranFont.uthmani(24))
            .foregroundStyle(Palette.gold.opacity(0.9))
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
            .environment(\.layoutDirection, .rightToLeft)
    }

    private func ayahView(_ ayah: Ayah) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle().stroke(Palette.gold.opacity(0.4), lineWidth: 1.2)
                        .frame(width: 30, height: 30)
                    Text("\(ayah.number)")
                        .duhaFont(12, .semibold)
                        .foregroundStyle(Palette.gold)
                }
                Spacer()
                Button {
                    bookmarks.toggle(surah.number, ayah.number)
                } label: {
                    Image(systemName: bookmarks.isBookmarked(surah.number, ayah.number) ? "bookmark.fill" : "bookmark")
                        .duhaFont(16)
                        .foregroundStyle(Palette.gold)
                }
                .buttonStyle(.plain)
            }

            Text(ayah.arabic)
                .font(QuranFont.uthmani(28))
                .lineSpacing(14)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)
                .foregroundStyle(.primary)

            Text(ayah.english)
                .duhaFont(15)
                .lineSpacing(3)
                .foregroundStyle(.primary.opacity(0.75))
        }
        .padding(.vertical, 16)
        .onAppear { furthestAyah = max(furthestAyah, ayah.number) }
    }
}
