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
            HStack(alignment: .top) {
                Text(dua.title)
                    .duhaFont(15, .semibold)
                    .foregroundStyle(Palette.gold)
                Spacer()
                if !dua.note.isEmpty {
                    Text(dua.note)
                        .duhaFont(11, .medium)
                        .foregroundStyle(Palette.blue)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Palette.blue.opacity(0.12))
                        .clipShape(Capsule())
                }
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
                    .duhaFont(13.5, italic: true)
                    .foregroundStyle(Palette.blue.opacity(0.9))
            }

            if !dua.en.isEmpty {
                Text(dua.en)
                    .duhaFont(14.5)
                    .foregroundStyle(.primary.opacity(0.85))
            }

            if !dua.source.isEmpty {
                Text(dua.source)
                    .duhaFont(12, .medium)
                    .foregroundStyle(Palette.blue.opacity(0.65))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Palette.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}
