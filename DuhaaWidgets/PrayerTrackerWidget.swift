import SwiftUI
import WidgetKit
import AppIntents

/// Widget 2 — Interactive Prayer Tracker (Lock Screen). The key differentiator:
/// each of the five prayers is tappable straight from the Lock Screen via
/// `TogglePrayerCompletionIntent` — no need to open the app. State is shown by
/// SF-Symbol/fill (monochrome-safe), never color. The Home Screen color version is
/// the existing `TodaysPrayersWidget` / `PrayerDayWidget`.
struct PrayerTrackerWidget: Widget {
    let kind = "DuhaaPrayerTracker"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            PrayerTrackerAccessoryView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Prayer Tracker")
        .description("Mark each prayer complete right from the Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

private struct PrayerTrackerAccessoryView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: PrayerWidgetSnapshot

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        default:                 rectangular
        }
    }

    // "X/5 today" completion ring.
    private var circular: some View {
        Gauge(value: Double(snapshot.dailyCompletionCount),
              in: 0...Double(snapshot.totalPrayerCount)) {
            Image(systemName: "checkmark")
        } currentValueLabel: {
            Text("\(snapshot.dailyCompletionCount)")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
        .accessibilityLabel("\(snapshot.dailyCompletionCount) of \(snapshot.totalPrayerCount) prayers prayed today")
    }

    // Five tappable prayers: F D A M I, each a Button running the toggle intent.
    private var rectangular: some View {
        VStack(spacing: 3) {
            HStack(spacing: 0) {
                ForEach(snapshot.prayers) { item in
                    Button(intent: TogglePrayerCompletionIntent(prayer: item.id, dayKey: snapshot.dayKey)) {
                        VStack(spacing: 2) {
                            Text(String(item.displayName.prefix(1)))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                            Image(systemName: item.state.monoSymbol)
                                .font(.system(size: 16))
                                .widgetAccentable()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(item.displayName), \(item.state.label). Tap to toggle.")
                }
            }
            Text("\(snapshot.progressText) today")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Circular", as: .accessoryCircular) {
    PrayerTrackerWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample(completedCount: 3))
}

#Preview("Rectangular", as: .accessoryRectangular) {
    PrayerTrackerWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample(completedCount: 3))
}
