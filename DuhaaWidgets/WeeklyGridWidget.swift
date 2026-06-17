import SwiftUI
import WidgetKit

/// Widget 5 — 7-Day Prayer Grid. Gentle weekly *consistency* (7 days × 5 prayers),
/// deliberately NOT a streak that resets to zero on a miss — that would conflict
/// with "hope, not guilt". Accessory = monochrome (shape/fill per state); Home
/// systemSmall = full five-state color.
struct WeeklyGridWidget: Widget {
    let kind = "DuhaaWeeklyGrid"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            WeeklyGridView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("This Week")
        .description("Your prayer consistency over the last 7 days.")
        .supportedFamilies([.accessoryRectangular, .systemSmall])
        .contentMarginsDisabled()
    }
}

private struct WeeklyGridView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: PrayerWidgetSnapshot

    var body: some View {
        switch family {
        case .systemSmall:
            let theme = WidgetTheme(id: snapshot.themeID)
            colorGrid(theme)
                .padding(12)
                .containerBackground(for: .widget) { WidgetBackdrop(theme: theme, showsCrescent: false) }
        default:
            monoGrid
                .containerBackground(for: .widget) { Color.clear }
        }
    }

    // MARK: Accessory (monochrome)
    private var monoGrid: some View {
        HStack(spacing: 0) {
            ForEach(snapshot.weekly) { day in
                VStack(spacing: 1.5) {
                    Text(day.weekdayLetter)
                        .font(.system(size: 8, weight: day.isToday ? .bold : .regular))
                        .foregroundStyle(day.isToday ? .primary : .secondary)
                    ForEach(Array(day.states.enumerated()), id: \.offset) { _, state in
                        Image(systemName: state.gridSymbol)
                            .font(.system(size: 8))
                            .widgetAccentable()
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityLabel(weeklyAccessibility)
    }

    // MARK: Home (color)
    private func colorGrid(_ theme: WidgetTheme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("THIS WEEK")
                .font(.system(size: 10, weight: .semibold)).tracking(1)
                .foregroundStyle(theme.secondaryText)
            HStack(spacing: 4) {
                ForEach(snapshot.weekly) { day in
                    VStack(spacing: 3) {
                        ForEach(Array(day.states.enumerated()), id: \.offset) { _, state in
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(theme.color(for: state))
                                .frame(height: 11)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2.5)
                                        .strokeBorder(state == .upcoming ? theme.pillBorder : .clear, lineWidth: 0.5))
                        }
                        Text(day.weekdayLetter)
                            .font(.system(size: 8, weight: day.isToday ? .bold : .regular))
                            .foregroundStyle(day.isToday ? theme.primaryText : theme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityLabel(weeklyAccessibility)
    }

    private var weeklyAccessibility: String {
        let prayed = snapshot.weekly.flatMap { $0.states }.filter { $0.isPrayed }.count
        return "Weekly consistency: \(prayed) prayers kept over the last 7 days."
    }
}

#Preview("Accessory", as: .accessoryRectangular) {
    WeeklyGridWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample())
}

#Preview("Home · Classic", as: .systemSmall) {
    WeeklyGridWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample(themeID: "dark"))
}

#Preview("Home · Light Pink", as: .systemSmall) {
    WeeklyGridWidget()
} timeline: {
    PrayerEntry(date: .now, snapshot: .sample(themeID: "lightPink"))
}
