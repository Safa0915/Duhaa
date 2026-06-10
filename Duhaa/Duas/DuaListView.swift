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

            // Conditional counts (e.g. "Fajr/Maghrib: 3× each") — too long for the
            // capsule, so a compact line of its own.
            if let counts = dua.countNote, !counts.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "repeat")
                        .duhaaFont(11)
                        .foregroundStyle(Palette.blue.opacity(0.7))
                    Text(counts)
                        .duhaaFont(12, .medium)
                        .foregroundStyle(Palette.blue.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !dua.arabic.isEmpty {
                Text(arabicText(dua.arabic))
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

            // Alternate Sunnah counts stay folded away — present, never pushy.
            if let variations = dua.variations, !variations.isEmpty {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(variations, id: \.self) { v in
                            Text("· \(v)")
                                .duhaaFont(12)
                                .foregroundStyle(.primary.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Text("Sunnah count variations")
                        .duhaaFont(12, .medium)
                        .foregroundStyle(Palette.gold.opacity(0.85))
                }
                .tint(Palette.gold)
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

    /// Du'a Arabic in the Uthmani font — except punctuation. The KFGQPC mushaf
    /// font draws the Arabic comma/semicolon as Quranic stop ornaments (circles),
    /// which look wrong mid-du'a; those characters fall back to the system font
    /// so they read as ordinary «،» and «؛».
    private func arabicText(_ s: String) -> AttributedString {
        var attr = AttributedString(s)
        attr.font = QuranFont.uthmani(26)
        for punctuation in ["،", "؛"] {
            var search = attr.startIndex
            while search < attr.endIndex,
                  let r = attr[search...].range(of: punctuation) {
                attr[r].font = .system(size: 22)
                search = r.upperBound
            }
        }
        return attr
    }

    /// Top-right badge, by priority: repetition text ("Read 3x") → structured
    /// count/prayer-scope ("10× · Fajr & Maghrib"; a bare "1×" is noise, so count
    /// shows only when > 1) → authenticity status. Renders nothing if none apply.
    @ViewBuilder
    private func topBadge(_ dua: Dua) -> some View {
        if dua.noteIsRepetition {
            Text(dua.note)
                .duhaaFont(11, .medium)
                .foregroundStyle(Palette.blue)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Palette.blue.opacity(0.12))
                .clipShape(Capsule())
        } else if (dua.count ?? 1) > 1 || dua.prayerScope != nil {
            Text([(dua.count ?? 1) > 1 ? "\(dua.count!)×" : nil, dua.prayerScope]
                .compactMap(\.self).joined(separator: " · "))
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
