import SwiftUI

/// A warm Ramadan card that appears on the home screen during the month of
/// Ramadan (auto-detected from the Hijri date). Shows the next suhoor/iftar with a
/// live countdown, and a gentle "I'm fasting today" log.
struct RamadanCard: View {
    @Environment(FastingTracker.self) private var fasting
    @Environment(LocationProvider.self) private var location
    @Environment(SettingsStore.self) private var settings

    let dayKey: String
    let ramadanDay: Int
    let hijriYear: Int
    let suhoor: String
    let iftar: String
    /// "Iftar" while fasting, otherwise "Suhoor ends".
    let phase: String
    let countdown: String

    private var fastedToday: Bool { fasting.isFasted(dayKey) }

    private var fastsThisRamadan: Int {
        fasting.count(hijriMonth: 9, hijriYear: hijriYear,
                      offsetDays: settings.hijriOffsetDays, timeZone: location.active.timeZone)
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            countdownView
            timesRow
            fastingToggle
        }
        .padding(16)
        .background(
            LinearGradient(colors: [Palette.gold.opacity(0.18), Palette.gold.opacity(0.06)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.gold.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Palette.gold.opacity(0.12), radius: 12)
    }

    private var header: some View {
        HStack {
            Label("RAMADAN", systemImage: "moon.fill")
                .duhaaFont(11, .semibold).tracking(1.2)
                .foregroundStyle(Palette.gold)
            Spacer()
            if ramadanDay > 0 {
                Text("Day \(ramadanDay)")
                    .duhaaFont(11, .semibold)
                    .foregroundStyle(Palette.blue.opacity(0.8))
            }
        }
    }

    private var countdownView: some View {
        VStack(spacing: 2) {
            Text(phase == "Iftar" ? "Iftar in" : "Suhoor ends in")
                .duhaaFont(12)
                .foregroundStyle(.primary.opacity(0.7))
            Text(countdown)
                .duhaaFont(34, .bold)
                .foregroundStyle(Palette.gold)
                .lineLimit(1).minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    private var timesRow: some View {
        HStack(spacing: 0) {
            timeBlock("Suhoor", suhoor, "moon.stars.fill")
            Rectangle().fill(Palette.gold.opacity(0.2)).frame(width: 1, height: 38)
            timeBlock("Iftar", iftar, "sunset.fill")
        }
    }

    private func timeBlock(_ title: String, _ time: String, _ icon: String) -> some View {
        VStack(spacing: 3) {
            Label(title, systemImage: icon)
                .duhaaFont(11, .medium)
                .foregroundStyle(Palette.blue.opacity(0.8))
            Text(time)
                .duhaaFont(17, .semibold)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
    }

    private var fastingToggle: some View {
        Button {
            fasting.toggle(dayKey)
            DuhaaHaptics.tap()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: fastedToday ? "checkmark.circle.fill" : "circle")
                    .duhaaFont(20)
                    .foregroundStyle(fastedToday ? Palette.gold : Color.primary.opacity(0.3))
                    .symbolEffect(.bounce, value: fastedToday)
                Text(fastedToday ? "Fasting logged today — taqabbal Allah 🤍" : "I'm fasting today")
                    .duhaaFont(14, .medium)
                    .foregroundStyle(.primary)
                Spacer()
                if fastsThisRamadan > 0 {
                    Text("\(fastsThisRamadan)")
                        .duhaaFont(13, .bold)
                        .foregroundStyle(Palette.gold)
                }
            }
            .padding(.vertical, 12).padding(.horizontal, 14)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
