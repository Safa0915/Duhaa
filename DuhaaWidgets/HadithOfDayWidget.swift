import SwiftUI
import WidgetKit

/// Widget 7 — Daily Reflection (Home Screen, systemMedium + systemLarge).
/// Pairs the curated Quran verse and the sourced hadith of the day in one calm
/// surface. Medium keeps both messages glanceable; large gives the Quran a little
/// Arabic space while preserving the hadith source and grade.
struct DailyReflectionWidget: Widget {
    let kind = "DuhaaDailyReflection"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            let theme = WidgetTheme(id: entry.snapshot.themeID)
            DailyReflectionView(
                verse: entry.snapshot.dailyVerse,
                hadith: entry.snapshot.dailyHadith,
                theme: theme
            )
            .containerBackground(for: .widget) { WidgetBackdrop(theme: theme) }
            .widgetURL(URL(string: "duhaa://reflection"))
        }
        .configurationDisplayName("Verse & Hadith")
        .description("Today's Quran verse and uplifting hadith in one widget.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private struct DailyReflectionView: View {
    let verse: VerseStamp?
    let hadith: HadithStamp?
    let theme: WidgetTheme
    @Environment(\.widgetFamily) private var family

    private var isLarge: Bool { family == .systemLarge }
    private var hasBoth: Bool { verse != nil && hadith != nil }

    var body: some View {
        if verse != nil || hadith != nil {
            VStack(alignment: .leading, spacing: isLarge ? 10 : 7) {
                header

                if let verse {
                    quranSection(verse)
                }

                if hasBoth {
                    separator
                }

                if let hadith {
                    hadithSection(hadith)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityText)
        } else {
            WidgetFallback(theme: theme, message: "Open Duhaa for today's verse and hadith")
        }
    }

    private var header: some View {
        Label("TODAY'S LIGHT", systemImage: "sparkles")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(theme.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }

    private func quranSection(_ verse: VerseStamp) -> some View {
        VStack(alignment: .leading, spacing: isLarge ? 5 : 3) {
            sectionTitle("QURAN", systemImage: "book.closed")

            if isLarge {
                Text(verse.arabic)
                    .font(.system(size: 19))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(hasBoth ? 2 : 4)
                    .minimumScaleFactor(0.65)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
            }

            Text(verse.en)
                .font(.system(size: isLarge ? 14 : 13, weight: .medium))
                .foregroundStyle(theme.primaryText)
                .lineLimit(hasBoth ? 2 : (isLarge ? 6 : 4))
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .leading)

            footerLine(systemImage: "text.book.closed", text: verse.citation)
        }
    }

    private func hadithSection(_ hadith: HadithStamp) -> some View {
        VStack(alignment: .leading, spacing: isLarge ? 5 : 3) {
            sectionTitle("HADITH", systemImage: "quote.bubble", trailing: hadith.grade)

            Text(hadith.en)
                .font(.system(size: isLarge ? 14 : 13, weight: .medium))
                .foregroundStyle(theme.primaryText)
                .lineLimit(hasBoth ? (isLarge ? 4 : 2) : (isLarge ? 7 : 4))
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .leading)

            // narrator · source · grader — a grade is never shown without its grader.
            footerLine(systemImage: "quote.bubble", text: "\(hadith.narrator) · \(hadith.source) · \(hadith.grader)")
        }
    }

    private func sectionTitle(_ title: String, systemImage: String, trailing: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.accent.opacity(0.18), in: Capsule())
                    .foregroundStyle(theme.accent)
            }
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(theme.secondaryText.opacity(0.24))
            .frame(height: 1)
    }

    private func footerLine(systemImage: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 10))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Spacer(minLength: 0)
        }
        .foregroundStyle(theme.secondaryText)
    }

    private var accessibilityText: String {
        var parts = ["Daily reflection."]
        if let verse {
            parts.append("Quran: \(verse.en) \(verse.surahName), \(verse.reference).")
        }
        if let hadith {
            parts.append("Hadith: \(hadith.en) Narrated by \(hadith.narrator). \(hadith.source). Graded \(hadith.gradeLine).")
        }
        return parts.joined(separator: " ")
    }
}

#Preview("Classic", as: .systemMedium) {
    DailyReflectionWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample(themeID: "dark"))
}

#Preview("Large", as: .systemLarge) {
    DailyReflectionWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample(themeID: "dark"))
}

#Preview("Light Pink", as: .systemMedium) {
    DailyReflectionWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample(themeID: "lightPink"))
}
