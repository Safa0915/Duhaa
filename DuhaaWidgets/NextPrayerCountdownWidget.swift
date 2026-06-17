import SwiftUI
import WidgetKit

/// Widget 1 — Next Prayer Countdown (Lock Screen).
/// Circular: current-prayer abbreviation + an elapsed-in-window ring.
/// Rectangular: next prayer + a live, self-ticking countdown + a thin progress bar.
/// The countdown text uses `Text(timerInterval:)` (free per-second ticks); the ring
/// is stepped by timeline entries (`PrayerTimelinePlanner.ringStepDates`).
struct NextPrayerCountdownWidget: Widget {
    let kind = "DuhaaNextPrayerCountdown"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            NextPrayerCountdownView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Next Prayer")
        .description("Countdown to the next prayer with an elapsed ring.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

private struct NextPrayerCountdownView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: PrayerWidgetSnapshot

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        default:                 rectangular
        }
    }

    private var abbrev: String {
        (snapshot.currentPrayerID ?? snapshot.nextPrayerID)?.abbreviation ?? "—"
    }

    // Abbreviation centered in an elapsed-in-window ring.
    private var circular: some View {
        Gauge(value: snapshot.windowProgress) {
            Text(abbrev)
        } currentValueLabel: {
            Text(abbrev).font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
        .widgetAccentable()
        .accessibilityLabel(accessibilityText)
    }

    // Next prayer + live countdown + thin progress bar.
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "moon.stars.fill").font(.system(size: 11)).widgetAccentable()
                Text(snapshot.nextPrayerIsTomorrow ? "Next · tomorrow" : "Next prayer")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 2)
                if let time = snapshot.nextPrayerTime {
                    Text(time, style: .time).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(snapshot.nextDisplayName ?? "—")
                    .font(.system(size: 16, weight: .semibold))
                    .widgetAccentable()
                if let time = snapshot.nextPrayerTime, time > snapshot.date {
                    Text(timerInterval: snapshot.date...time, countsDown: true)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            ThinBar(progress: snapshot.windowProgress)
        }
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        guard let name = snapshot.nextDisplayName else { return "Next prayer unavailable" }
        let f = DateFormatter(); f.timeStyle = .short
        let when = snapshot.nextPrayerTime.map { ", at \(f.string(from: $0))" } ?? ""
        return "Next prayer \(name)\(when)"
    }
}

/// A 3pt monochrome progress bar for accessory widgets (system-tinted).
struct ThinBar: View {
    let progress: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.25))
                Capsule().fill(.primary).frame(width: geo.size.width * max(0, min(1, progress)))
                    .widgetAccentable()
            }
        }
        .frame(height: 3)
    }
}

#Preview("Circular", as: .accessoryCircular) {
    NextPrayerCountdownWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample(completedCount: 2))
}

#Preview("Rectangular", as: .accessoryRectangular) {
    NextPrayerCountdownWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample(completedCount: 2))
}
