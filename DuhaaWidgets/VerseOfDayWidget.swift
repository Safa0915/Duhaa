import SwiftUI
import WidgetKit

/// Legacy standalone Verse of the Day widget view.
///
/// The widget bundle now exposes `DailyReflectionWidget`, which combines this
/// verse with the day's hadith. This standalone implementation is kept out of the
/// bundle for reference/previews while the combined surface settles.
///
/// Verse of the Day (Home Screen, systemMedium + systemLarge).
/// Surfaces a short, hopeful Quran verse picked by the app from its curated
/// rotation (the Ad-Duhaa spirit — mercy and ease), on the full-color backdrop.
/// The English meaning is the hero (medium); the large family adds the Arabic
/// above it. Tapping deep-links into the Quran. Arabic uses the system font here
/// (the Uthmani font in the extension is a future enhancement, matching the Hadith
/// widget); Lock-Screen families are excluded — verse prose renders too tightly.
struct VerseOfDayWidget: Widget {
    let kind = "DuhaaVerseOfDay"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            let theme = WidgetTheme(id: entry.snapshot.themeID)
            VerseOfDayWidgetView(verse: entry.snapshot.dailyVerse, theme: theme)
                .containerBackground(for: .widget) { WidgetBackdrop(theme: theme) }
                .widgetURL(URL(string: "duhaa://verse"))
        }
        .configurationDisplayName("Verse of the Day")
        .description("A short, hopeful verse from the Quran for today.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private struct VerseOfDayWidgetView: View {
    let verse: VerseStamp?
    let theme: WidgetTheme
    @Environment(\.widgetFamily) private var family

    private var isLarge: Bool { family == .systemLarge }

    var body: some View {
        if let verse {
            VStack(alignment: .leading, spacing: isLarge ? 10 : 6) {
                header

                if isLarge {
                    Text(verse.arabic)
                        .font(.system(size: 22))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(3).minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                }

                Text(verse.en)
                    .font(.system(size: isLarge ? 16 : 14, weight: .medium))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(isLarge ? 6 : 4)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
                footer(verse)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Verse of the day. \(verse.en) \(verse.surahName), verse \(verse.reference).")
        } else {
            WidgetFallback(theme: theme, message: "Open Duhaa for today's verse")
        }
    }

    private var header: some View {
        Label("VERSE OF THE DAY", systemImage: "sparkles")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(theme.accent)
            .lineLimit(1).minimumScaleFactor(0.85)
    }

    private func footer(_ verse: VerseStamp) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "book.closed").font(.system(size: 9))
            Text(verse.citation)
                .font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .foregroundStyle(theme.secondaryText)
    }
}

#Preview("Classic", as: .systemMedium) {
    VerseOfDayWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample(themeID: "dark"))
}

#Preview("Large", as: .systemLarge) {
    VerseOfDayWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample(themeID: "dark"))
}

#Preview("Light Pink", as: .systemMedium) {
    VerseOfDayWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample(themeID: "lightPink"))
}
