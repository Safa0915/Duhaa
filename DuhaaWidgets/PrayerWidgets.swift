import SwiftUI
import WidgetKit

// MARK: - Small · Next Prayer

struct NextPrayerWidget: Widget {
    let kind = "DuhaaNextPrayer"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            let theme = WidgetTheme(id: entry.snapshot.themeID)
            SmallPrayerView(snapshot: entry.snapshot, theme: theme)
                .containerBackground(for: .widget) { WidgetBackdrop(theme: theme) }
        }
        .configurationDisplayName("Next Prayer")
        .description("Your next prayer at a glance, with today’s progress.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

// MARK: - Medium · Today's Prayers

struct TodaysPrayersWidget: Widget {
    let kind = "DuhaaTodaysPrayers"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            let theme = WidgetTheme(id: entry.snapshot.themeID)
            MediumPrayerView(snapshot: entry.snapshot, theme: theme)
                .containerBackground(for: .widget) { WidgetBackdrop(theme: theme) }
        }
        .configurationDisplayName("Today’s Prayers")
        .description("Next prayer, daily progress, and tap to check off each prayer.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Large · Prayer Day

struct PrayerDayWidget: Widget {
    let kind = "DuhaaPrayerDay"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            let theme = WidgetTheme(id: entry.snapshot.themeID)
            LargePrayerView(snapshot: entry.snapshot, theme: theme)
                .containerBackground(for: .widget) { WidgetBackdrop(theme: theme) }
        }
        .configurationDisplayName("Prayer Day")
        .description("Your full day of prayers, with progress and gentle encouragement.")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Previews (App Store screenshot-worthy states)

#Preview("Small · Classic", as: .systemSmall) {
    NextPrayerWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample(themeID: "dark", completedCount: 2))
}

#Preview("Small · Light Pink", as: .systemSmall) {
    NextPrayerWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample(themeID: "lightPink", completedCount: 2))
}

#Preview("Medium · Classic", as: .systemMedium) {
    TodaysPrayersWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample(themeID: "dark", completedCount: 2))
}

#Preview("Medium · Light Pink", as: .systemMedium) {
    TodaysPrayersWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample(themeID: "lightPink", completedCount: 3))
}

#Preview("Medium · All complete", as: .systemMedium) {
    TodaysPrayersWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample(themeID: "dark", completedCount: 5))
}

#Preview("Large · Classic", as: .systemLarge) {
    PrayerDayWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample(themeID: "dark", completedCount: 3))
}

#Preview("Large · Light Pink", as: .systemLarge) {
    PrayerDayWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample(themeID: "lightPink", completedCount: 1))
}

#Preview("Large · Empty", as: .systemLarge) {
    PrayerDayWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .emptySample(themeID: "dark"))
}
