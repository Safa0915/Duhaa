import SwiftUI
import WidgetKit

/// Widget 6 — Daily Du'a (Home Screen, systemMedium). Surfaces today's du'a from
/// the app's curated library on the full-color backdrop. Tapping deep-links into
/// the app's Du'as tab. Arabic uses the system font here (the Uthmani font in the
/// extension is a future enhancement); Lock-Screen families are intentionally
/// excluded — Arabic renders too tightly there.
struct DailyDuaWidget: Widget {
    let kind = "DuhaaDailyDua"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            let theme = WidgetTheme(id: entry.snapshot.themeID)
            DailyDuaView(dua: entry.snapshot.dailyDua, theme: theme)
                .containerBackground(for: .widget) { WidgetBackdrop(theme: theme) }
                .widgetURL(entry.snapshot.dailyDua.flatMap { URL(string: "duhaa://dua/\($0.index)") })
        }
        .configurationDisplayName("Daily Du'a")
        .description("A du'a for today, from Duhaa's library.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

private struct DailyDuaView: View {
    let dua: DuaStamp?
    let theme: WidgetTheme

    var body: some View {
        if let dua {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(dua.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 4)
                    if let status = dua.status {
                        Text(status)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                            .fixedSize()
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(theme.accent.opacity(0.18), in: Capsule())
                            .foregroundStyle(theme.accent)
                    }
                }
                Text(dua.arabic)
                    .font(.system(size: 19))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .environment(\.layoutDirection, .rightToLeft)
                Text(dua.en)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                HStack(spacing: 5) {
                    Image(systemName: "book.closed").font(.system(size: 9))
                    Text(dua.source).font(.system(size: 10)).lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "hands.sparkles.fill")
                        .font(.system(size: 11)).foregroundStyle(theme.accent.opacity(0.75))
                }
                .foregroundStyle(theme.secondaryText)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Du'a of the day: \(dua.title). \(dua.en). Source \(dua.source).")
        } else {
            WidgetFallback(theme: theme, message: "Open Duhaa for today's du'a")
        }
    }
}

#Preview("Classic", as: .systemMedium) {
    DailyDuaWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample(themeID: "dark"))
}

#Preview("Light Pink", as: .systemMedium) {
    DailyDuaWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample(themeID: "lightPink"))
}
