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
                    else { player.play(in: surah, from: 1) }
                } label: {
                    Image(systemName: player.isActive ? "pause.circle.fill" : "play.circle")
                        .foregroundStyle(Palette.gold)
                }
                .accessibilityLabel(player.isActive ? "Pause surah" : "Play surah")
            }
        }
        .onDisappear {
            player.stop()
            bookmarks.recordRead(surah: surah.number, ayah: max(furthestAyah, scrollTo ?? 1))
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(surah.arabicName)
                .font(QuranFont.uthmani(30))
                .foregroundStyle(Palette.gold)
            Text(surah.englishName)
                .duhaaFont(18, .semibold)
                .foregroundStyle(.primary)
            Text("\(surah.translation) · \(surah.revelation) · \(surah.ayahs.count) ayahs")
                .duhaaFont(12)
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
        let isPlaying = player.isPlaying(surah.number, ayah.number)
        let isBookmarked = bookmarks.isBookmarked(surah.number, ayah.number)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle().stroke(Palette.gold.opacity(0.4), lineWidth: 1.2)
                        .frame(width: 30, height: 30)
                    Text("\(ayah.number)")
                        .duhaaFont(12, .semibold)
                        .foregroundStyle(Palette.gold)
                }
                Spacer()
                HStack(spacing: 18) {
                    playButton(ayah, isPlaying: isPlaying)
                    Button {
                        bookmarks.toggle(surah.number, ayah.number)
                    } label: {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .duhaaFont(16)
                            .foregroundStyle(Palette.gold)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isBookmarked ? "Remove bookmark for ayah \(ayah.number)" : "Bookmark ayah \(ayah.number)")
                }
            }

            Text(ayah.arabic)
                .font(QuranFont.uthmani(28))
                .lineSpacing(14)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)
                .foregroundStyle(.primary)

            Text(ayah.english)
                .duhaaFont(15)
                .lineSpacing(3)
                .foregroundStyle(.primary.opacity(0.75))
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isPlaying ? Palette.gold.opacity(0.08) : .clear)
        )
        .onAppear { furthestAyah = max(furthestAyah, ayah.number) }
    }

    @ViewBuilder
    private func playButton(_ ayah: Ayah, isPlaying: Bool) -> some View {
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
