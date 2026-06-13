import SwiftUI

/// A reference to one ayah.
struct VerseRef: Identifiable, Equatable {
    let surah: Int
    let ayah: Int
    var id: String { "\(surah):\(ayah)" }
}

/// A curated rotation of short, hopeful verses (the Ad-Duhaa spirit — mercy, ease,
/// nearness, not despairing). One is chosen per calendar day.
enum VerseOfDay {
    static let verses: [VerseRef] = [
        VerseRef(surah: 93, ayah: 3), VerseRef(surah: 93, ayah: 4), VerseRef(surah: 93, ayah: 5),
        VerseRef(surah: 93, ayah: 7), VerseRef(surah: 94, ayah: 1), VerseRef(surah: 94, ayah: 5),
        VerseRef(surah: 94, ayah: 6), VerseRef(surah: 39, ayah: 53), VerseRef(surah: 13, ayah: 28),
        VerseRef(surah: 50, ayah: 16), VerseRef(surah: 2, ayah: 152), VerseRef(surah: 2, ayah: 153),
        VerseRef(surah: 2, ayah: 186), VerseRef(surah: 3, ayah: 139), VerseRef(surah: 3, ayah: 159),
        VerseRef(surah: 14, ayah: 7), VerseRef(surah: 40, ayah: 60), VerseRef(surah: 6, ayah: 54),
        VerseRef(surah: 25, ayah: 70), VerseRef(surah: 20, ayah: 114), VerseRef(surah: 16, ayah: 128),
        VerseRef(surah: 29, ayah: 69), VerseRef(surah: 8, ayah: 2), VerseRef(surah: 73, ayah: 8),
        VerseRef(surah: 65, ayah: 3),
    ]

    static func today(_ date: Date = Date()) -> VerseRef {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return verses[((day % verses.count) + verses.count) % verses.count]
    }
}

/// The "Verse of the Day" card on the Prayer home. Tapping opens the ayah in the reader.
struct VerseOfDayCard: View {
    let ref: VerseRef
    let onTap: () -> Void

    private var surah: Surah? { Quran.surah(ref.surah) }
    private var ayah: Ayah? { surah?.ayahs.first { $0.number == ref.ayah } }

    var body: some View {
        if let surah, let ayah {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("VERSE OF THE DAY", systemImage: "sparkles")
                            .duhaaFont(11, .semibold).tracking(1)
                            .foregroundStyle(Palette.gold.opacity(0.9))
                        Spacer()
                        Text("\(surah.englishName) · \(ref.surah):\(ref.ayah)")
                            .duhaaFont(11)
                            .foregroundStyle(Palette.blue.opacity(0.7))
                    }
                    Text(QuranArabicText.display(ayah.arabic))
                        .font(QuranFont.uthmani(22))
                        .lineSpacing(10)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                        .foregroundStyle(.primary)
                        .accessibilityLabel(ayah.arabic)
                    Text(ayah.english)
                        .duhaaFont(14)
                        .foregroundStyle(.primary.opacity(0.82))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(
                    LinearGradient(colors: [Palette.gold.opacity(0.14), Palette.gold.opacity(0.05)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.gold.opacity(0.3), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.duhaaPress)
        }
    }
}
