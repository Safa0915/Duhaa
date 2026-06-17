import SwiftUI
import WidgetKit

/// Widget 3 — Today's Prayer Times, split into two focused Lock-Screen widgets
/// instead of one crammed one. Morning = Fajr/Sunrise/Dhuhr; Evening = Asr/Maghrib/
/// Isha. Each also offers a circular variant showing that group's single most
/// relevant upcoming prayer.

// MARK: - Group model

private enum PrayerGroup {
    case morning, evening

    var title: String { self == .morning ? "Morning" : "Evening" }
    var circularIDs: [PrayerID] { self == .morning ? [.fajr, .dhuhr] : [.asr, .maghrib, .isha] }

    /// Rows to render: (label, time, isPast). Morning injects Sunrise between Fajr & Dhuhr.
    func rows(_ s: PrayerWidgetSnapshot) -> [(label: String, time: String, past: Bool)] {
        switch self {
        case .morning:
            let fajr = s.item(.fajr); let dhuhr = s.item(.dhuhr)
            let sunrisePast = (s.sunriseTime.map { $0 <= s.date }) ?? false
            return [
                (PrayerID.fajr.displayName, fajr?.shortTimeString ?? "—", fajr?.isPast ?? false),
                ("Sunrise", s.sunriseString, sunrisePast),
                (PrayerID.dhuhr.displayName, dhuhr?.shortTimeString ?? "—", dhuhr?.isPast ?? false),
            ]
        case .evening:
            return [PrayerID.asr, .maghrib, .isha].map { id in
                let it = s.item(id)
                return (id.displayName, it?.shortTimeString ?? "—", it?.isPast ?? false)
            }
        }
    }
}

// MARK: - View

private struct PrayerTimesGroupView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: PrayerWidgetSnapshot
    let group: PrayerGroup

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        default:                 rectangular
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(group.title.uppercased())
                .font(.system(size: 9, weight: .semibold)).tracking(0.8)
                .foregroundStyle(.secondary)
                .widgetAccentable()
            ForEach(Array(group.rows(snapshot).enumerated()), id: \.offset) { _, row in
                HStack(spacing: 4) {
                    Text(row.label).font(.system(size: 13, weight: .medium))
                    Spacer(minLength: 4)
                    Text(row.time).font(.system(size: 13)).foregroundStyle(.secondary)
                }
                .opacity(row.past ? 0.55 : 1)
            }
        }
        .accessibilityLabel(group.rows(snapshot).map { "\($0.label) \($0.time)" }.joined(separator: ", "))
    }

    private var circular: some View {
        let item = snapshot.mostRelevant(in: group.circularIDs)
        return VStack(spacing: 1) {
            Text(item?.id.abbreviation ?? "—")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .widgetAccentable()
            Text(item?.shortTimeString ?? "—")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.7).lineLimit(1)
        }
        .accessibilityLabel(item.map { "\($0.displayName) at \($0.shortTimeString)" } ?? "No upcoming prayer")
    }
}

// MARK: - Widgets

struct MorningPrayerTimesWidget: Widget {
    let kind = "DuhaaMorningTimes"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            PrayerTimesGroupView(snapshot: entry.snapshot, group: .morning)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Morning Times")
        .description("Fajr, Sunrise, and Dhuhr.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
        .contentMarginsDisabled()
    }
}

struct EveningPrayerTimesWidget: Widget {
    let kind = "DuhaaEveningTimes"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            PrayerTimesGroupView(snapshot: entry.snapshot, group: .evening)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Evening Times")
        .description("Asr, Maghrib, and Isha.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
        .contentMarginsDisabled()
    }
}

#Preview("Morning · Rect", as: .accessoryRectangular) {
    MorningPrayerTimesWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample())
}

#Preview("Evening · Rect", as: .accessoryRectangular) {
    EveningPrayerTimesWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample())
}

#Preview("Morning · Circular", as: .accessoryCircular) {
    MorningPrayerTimesWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample())
}
