import SwiftUI
import WidgetKit

/// Widget 4 — Hijri Date (Lock Screen). Inline: "2 Muharram 1448". Circular: big
/// day number over the month abbreviation. The app computes the Hijri date with
/// the user's offset setting and writes it into the shared payload.
struct HijriDateWidget: Widget {
    let kind = "DuhaaHijriDate"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            HijriDateView(hijri: entry.snapshot.hijri)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Hijri Date")
        .description("Today's Islamic date.")
        .supportedFamilies([.accessoryCircular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

private struct HijriDateView: View {
    @Environment(\.widgetFamily) private var family
    let hijri: HijriStamp?

    var body: some View {
        switch family {
        case .accessoryInline: inline
        default:               circular
        }
    }

    private var inline: some View {
        Label(hijri?.formatted ?? "Open Duhaa", systemImage: "moon")
            .widgetAccentable()
    }

    private var circular: some View {
        VStack(spacing: 0) {
            Text(hijri.map { "\($0.day)" } ?? "—")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .widgetAccentable()
            Text(hijri?.monthAbbrev ?? "")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .accessibilityLabel(hijri.map { "\($0.day) \($0.monthName) \($0.year)" } ?? "Hijri date unavailable")
    }
}

#Preview("Inline", as: .accessoryInline) {
    HijriDateWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample())
}

#Preview("Circular", as: .accessoryCircular) {
    HijriDateWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample())
}
