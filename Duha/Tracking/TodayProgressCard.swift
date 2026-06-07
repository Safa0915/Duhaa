import SwiftUI

/// A quiet, beautiful progress view (spec §5): today's five prayers as dots, a
/// warm adaptive line, and a 7-day ring strip. Celebrates what's done; never
/// tallies what's missed.
struct TodayProgressCard: View {
    @Environment(PrayerTracker.self) private var tracker
    let dayKey: String
    let week: [DayRef]

    private var prayedCount: Int { tracker.count(dayKey: dayKey) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("TODAY")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(Palette.blue.opacity(0.65))
                Spacer()
                Text("\(prayedCount) / 5")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(prayedCount == 5 ? Palette.gold : .primary.opacity(0.85))
            }

            HStack(spacing: 10) {
                ForEach(Prayer.allCases, id: \.self) { prayer in
                    let done = tracker.isMarked(prayer, dayKey: dayKey)
                    Circle()
                        .fill(done ? Palette.gold : Color.primary.opacity(0.07))
                        .frame(width: 13, height: 13)
                        .overlay(Circle().stroke(done ? .clear : Color.primary.opacity(0.18), lineWidth: 1))
                        .shadow(color: done ? Palette.gold.opacity(0.5) : .clear, radius: 4)
                }
                Spacer()
            }

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Palette.blue.opacity(0.85))

            Divider().overlay(Color.primary.opacity(0.06))

            HStack(spacing: 0) {
                ForEach(week) { day in
                    VStack(spacing: 6) {
                        let fraction = CGFloat(tracker.count(dayKey: day.key)) / 5
                        ZStack {
                            Circle()
                                .stroke(Color.primary.opacity(0.1), lineWidth: 2.5)
                                .frame(width: 24, height: 24)
                            Circle()
                                .trim(from: 0, to: fraction)
                                .stroke(Palette.gold, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 24, height: 24)
                            if day.isToday {
                                Circle().fill(Palette.gold).frame(width: 4, height: 4)
                            }
                        }
                        Text(day.letter)
                            .font(.system(size: 10, weight: day.isToday ? .semibold : .regular))
                            .foregroundStyle(Palette.blue.opacity(day.isToday ? 0.9 : 0.4))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .background(Palette.card)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.cardBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var message: String {
        switch prayedCount {
        case 0:    return "A new day. Begin whenever you're ready."
        case 1, 2: return "A gentle start — one at a time."
        case 3, 4: return "Beautiful — you're carrying the day."
        default:   return "All five today. Alhamdulillah."
        }
    }
}
