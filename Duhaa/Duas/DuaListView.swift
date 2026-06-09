import SwiftUI

/// The du'as within one category, each as a card: title, repetition note, Arabic
/// (Uthmani font), transliteration, English, and source.
struct DuaListView: View {
    let category: DuaCategory

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(category.duas) { dua in
                    card(dua)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
        }
        .scrollIndicators(.hidden)
        .background(Palette.appBg.ignoresSafeArea())
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func card(_ dua: Dua) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Text(dua.title)
                    .duhaaFont(15, .semibold)
                    .foregroundStyle(Palette.gold)
                Spacer()
                topBadge(dua)
            }

            // A short instruction (e.g. "Say before entering the bathroom"). Repetition
            // counts like "Read 3x" are shown as the capsule above instead, so they
            // never appear here.
            if !dua.note.isEmpty && !dua.noteIsRepetition {
                Text(dua.note)
                    .duhaaFont(13)
                    .foregroundStyle(.primary.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !dua.arabic.isEmpty {
                Text(dua.arabic)
                    .font(QuranFont.uthmani(26))
                    .lineSpacing(12)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
                    .foregroundStyle(.primary)
            }

            if !dua.latin.isEmpty {
                Text(dua.latin)
                    .duhaaFont(13.5, italic: true)
                    .foregroundStyle(Palette.blue.opacity(0.9))
            }

            if !dua.en.isEmpty {
                Text(dua.en)
                    .duhaaFont(14.5)
                    .foregroundStyle(.primary.opacity(0.85))
            }

            if !dua.source.isEmpty {
                Text(dua.source)
                    .duhaaFont(12, .medium)
                    .foregroundStyle(Palette.blue.opacity(0.65))
            }

            // Optional fiqh note — deliberately small and secondary (foot of the card)
            // so it never dominates, per the Before-Wudu requirement.
            if let fiqh = dua.fiqhNote, !fiqh.isEmpty {
                Divider().overlay(Palette.cardBorder).padding(.top, 2)
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "text.book.closed")
                        .duhaaFont(10)
                        .foregroundStyle(Palette.blue.opacity(0.55))
                    Text(fiqh)
                        .duhaaFont(11)
                        .foregroundStyle(.primary.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    /// Top-right badge: the repetition count ("Read 3x") when present (existing look),
    /// otherwise an authenticity status ("Verified"). Renders nothing if neither.
    @ViewBuilder
    private func topBadge(_ dua: Dua) -> some View {
        if dua.noteIsRepetition {
            Text(dua.note)
                .duhaaFont(11, .medium)
                .foregroundStyle(Palette.blue)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Palette.blue.opacity(0.12))
                .clipShape(Capsule())
        } else if let status = dua.status, !status.isEmpty {
            HStack(spacing: 3) {
                Image(systemName: "checkmark.seal.fill").duhaaFont(10)
                Text(status).duhaaFont(11, .medium)
            }
            .foregroundStyle(Palette.gold)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Palette.gold.opacity(0.13))
            .clipShape(Capsule())
        }
    }
}
