import SwiftUI

/// The Prayer Journey — a warm, hopeful look back at what's been prayed (spec §5).
/// Streaks, a monthly heatmap, and milestones you can't lose. It only ever
/// celebrates what's done; it never shows or counts what was missed.
struct JourneyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PrayerTracker.self) private var tracker
    @Environment(LocationProvider.self) private var location

    /// Any day inside the month currently shown in the calendar.
    @State private var monthAnchor = Date()

    private var tz: TimeZone { location.active.timeZone }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    streakHero
                    statsRow
                    monthCard
                    milestonesCard
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            .scrollContentBackground(.hidden)
            .background(Palette.appBg.ignoresSafeArea())
            .navigationTitle("Your Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(Palette.gold)
                }
            }
        }
        .preferredColorScheme(Palette.active.colorScheme)
        .tint(Palette.gold)
    }

    // MARK: Streak hero

    private var streakHero: some View {
        let streak = tracker.currentStreak(asOf: Date(), timeZone: tz)
        return VStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .duhaFont(38)
                .foregroundStyle(streak > 0 ? Palette.gold : Palette.gold.opacity(0.3))
                .shadow(color: streak > 0 ? Palette.gold.opacity(0.5) : .clear, radius: 12)
            Text(streak == 0 ? "Begin today" : "\(streak)")
                .duhaFont(streak == 0 ? 28 : 54, .bold)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(streakLabel(streak))
                .duhaFont(14)
                .foregroundStyle(Palette.blue.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    private func streakLabel(_ s: Int) -> String {
        switch s {
        case 0:  "Every journey starts with one prayer."
        case 1:  "Day one. You showed up."
        default: "day streak — keep it gently going."
        }
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile("\(tracker.bestStreak())", "Best streak", "flame")
            statTile("\(tracker.daysShownUp())", "Days prayed", "calendar")
            statTile("\(tracker.totalPrayed())", "Prayers", "checkmark.seal")
        }
    }

    private func statTile(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).duhaFont(15).foregroundStyle(Palette.gold.opacity(0.9))
            Text(value).duhaFont(22, .bold).foregroundStyle(.primary)
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(label).duhaFont(11).foregroundStyle(Palette.blue.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Palette.card)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Palette.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Month heatmap

    private var monthCard: some View {
        VStack(spacing: 14) {
            HStack {
                Button { shiftMonth(-1) } label: {
                    Image(systemName: "chevron.left").duhaFont(15, .semibold)
                }
                .foregroundStyle(Palette.gold)
                Spacer()
                Text(monthTitle).duhaFont(15, .semibold).foregroundStyle(.primary)
                Spacer()
                Button { shiftMonth(1) } label: {
                    Image(systemName: "chevron.right").duhaFont(15, .semibold)
                }
                .foregroundStyle(canGoForward ? Palette.gold : Palette.gold.opacity(0.25))
                .disabled(!canGoForward)
            }

            HStack(spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .duhaFont(10, .semibold)
                        .foregroundStyle(Palette.blue.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                ForEach(monthCells) { cell in dayCell(cell) }
            }
        }
        .padding(16)
        .background(Palette.card)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func dayCell(_ cell: DayCell) -> some View {
        Group {
            if let day = cell.day {
                let frac = Double(cell.count) / 5.0
                ZStack {
                    Circle()
                        .fill(cell.count == 0 ? Color.clear : Palette.gold.opacity(0.25 + 0.75 * frac))
                    Circle()
                        .stroke(cell.isToday ? Palette.gold : Color.primary.opacity(cell.count == 0 ? 0.12 : 0),
                                lineWidth: cell.isToday ? 1.8 : 1)
                    Text("\(day)")
                        .duhaFont(12, cell.isToday ? .bold : .regular)
                        .foregroundStyle(cell.count >= 3 ? Palette.onAccent : Color.primary.opacity(0.75))
                }
                .frame(height: 38)
                .opacity(cell.isFuture ? 0.3 : 1)
            } else {
                Color.clear.frame(height: 38)
            }
        }
    }

    // MARK: Milestones

    private var milestonesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MILESTONES")
                .duhaFont(11, .semibold).tracking(1.2)
                .foregroundStyle(Palette.blue.opacity(0.65))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(milestones) { milestoneCard($0) }
            }
        }
    }

    private func milestoneCard(_ m: Milestone) -> some View {
        let earned = m.progress >= m.goal
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: m.icon)
                    .duhaFont(18)
                    .foregroundStyle(earned ? Palette.gold : Color.secondary)
                Spacer()
                if earned {
                    Image(systemName: "checkmark.circle.fill")
                        .duhaFont(14).foregroundStyle(Palette.gold)
                }
            }
            Text(m.title)
                .duhaFont(14, .semibold)
                .foregroundStyle(earned ? Color.primary : Color.primary.opacity(0.6))
            Text(earned ? m.detail : "\(min(m.progress, m.goal)) / \(m.goal)")
                .duhaFont(11)
                .foregroundStyle(Palette.blue.opacity(0.7))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(earned ? Palette.gold.opacity(0.08) : Palette.card)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(earned ? Palette.gold.opacity(0.4) : Palette.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var milestones: [Milestone] {
        let total = tracker.totalPrayed()
        let best = tracker.bestStreak()
        let perfect = tracker.perfectDays()
        return [
            Milestone(id: "first",   title: "First Step",  detail: "Your first prayer",       icon: "sparkles",          progress: total,   goal: 1),
            Milestone(id: "day",     title: "A Full Day",  detail: "All five in one day",     icon: "sun.max.fill",      progress: perfect, goal: 1),
            Milestone(id: "week",    title: "Showing Up",  detail: "A 7-day streak",          icon: "flame.fill",        progress: best,    goal: 7),
            Milestone(id: "forty",   title: "Forty",       detail: "40 prayers logged",       icon: "star.fill",         progress: total,   goal: 40),
            Milestone(id: "month",   title: "Steadfast",   detail: "A 30-day streak",         icon: "crown.fill",        progress: best,    goal: 30),
            Milestone(id: "hundred", title: "Hundred",     detail: "100 prayers, alhamdulillah", icon: "star.circle.fill", progress: total, goal: 100),
        ]
    }

    // MARK: Footer

    private var footer: some View {
        Text("Duha counts only what you've prayed — never what you've missed. Every prayer is a fresh beginning.")
            .duhaFont(12)
            .foregroundStyle(Palette.blue.opacity(0.6))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.top, 4)
    }

    // MARK: Calendar math

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = tz
        return c
    }

    private var weekdaySymbols: [String] { ["S", "M", "T", "W", "T", "F", "S"] }

    private var monthTitle: String {
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = tz
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: monthAnchor)
    }

    private var canGoForward: Bool {
        let cal = calendar
        let thisMonth = cal.dateComponents([.year, .month], from: Date())
        let shown = cal.dateComponents([.year, .month], from: monthAnchor)
        guard let a = cal.date(from: thisMonth), let b = cal.date(from: shown) else { return false }
        return b < a
    }

    private func shiftMonth(_ delta: Int) {
        if delta > 0 && !canGoForward { return }
        if let next = calendar.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = next
        }
    }

    private var monthCells: [DayCell] {
        let cal = calendar
        let comps = cal.dateComponents([.year, .month], from: monthAnchor)
        guard let first = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: first) else { return [] }
        let leading = cal.component(.weekday, from: first) - 1   // Sunday = 1 → no blanks
        let todayKey = PrayerTracker.dayKey(Date(), tz)
        var cells: [DayCell] = []
        var idx = 0
        for _ in 0..<leading {
            cells.append(DayCell(id: idx, day: nil, count: 0, isToday: false, isFuture: false)); idx += 1
        }
        for d in range {
            guard let date = cal.date(byAdding: .day, value: d - 1, to: first) else { continue }
            let key = PrayerTracker.dayKey(date, tz)
            let isToday = key == todayKey
            cells.append(DayCell(id: idx, day: d, count: tracker.count(dayKey: key),
                                 isToday: isToday, isFuture: date > Date() && !isToday))
            idx += 1
        }
        return cells
    }
}

private struct DayCell: Identifiable {
    let id: Int
    let day: Int?
    let count: Int
    let isToday: Bool
    let isFuture: Bool
}

private struct Milestone: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let progress: Int
    let goal: Int
}
