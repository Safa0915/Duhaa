import Foundation

/// The pure, testable core of the widget timeline: given the app-written times
/// payload and "now", it decides which instants the widget should re-render at.
/// Lives in the shared layer (no WidgetKit) so both the widget extension and the
/// unit tests can use it; the `TimelineProvider` that wraps it stays widget-only.
enum PrayerTimelinePlanner {

    /// `now`, every prayer instant still ahead today and tomorrow, and the next
    /// midnight — deduped, sorted, and capped. Always returns at least `now`, so a
    /// missing/short payload still yields a valid single-entry timeline.
    static func refreshDates(from payload: PrayerTimesPayload?, now: Date) -> [Date] {
        var points: Set<Date> = [now]
        if let payload {
            for day in [payload.day(containing: now), payload.dayAfter(now)].compactMap({ $0 }) {
                for entry in day.ordered where entry.time > now {
                    points.insert(entry.time)
                }
            }
            points.insert(nextMidnight(payload: payload, now: now))
            for d in ringStepDates(payload: payload, now: now) { points.insert(d) }
        }
        // Stay well within WidgetKit's per-timeline entry budget.
        return Array(points).sorted().prefix(24).map { $0 }
    }

    /// Up to `maxSteps` evenly-spaced instants between `now` and the next prayer,
    /// so the countdown widget's *elapsed ring* steps forward through the current
    /// window — without per-second entries. The countdown **text** self-ticks via
    /// `Text(timerInterval:)`, so we never need second-granularity entries.
    static func ringStepDates(payload: PrayerTimesPayload?, now: Date, maxSteps: Int = 12) -> [Date] {
        guard let payload, let today = payload.day(containing: now) else { return [] }
        let end = today.ordered.first { $0.time > now }?.time ?? payload.dayAfter(now)?.fajr
        guard let end, end > now else { return [] }
        let total = end.timeIntervalSince(now)
        let stepCount = min(maxSteps, max(1, Int(total / 300)))   // ~5-min cadence, capped
        let step = total / Double(stepCount)
        return (1..<stepCount).map { now.addingTimeInterval(step * Double($0)) }
    }

    /// Start of the next calendar day in the payload's time zone (fallback: +1 hr).
    static func nextMidnight(payload: PrayerTimesPayload?, now: Date) -> Date {
        let tz = payload?.timeZone ?? .current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let startOfToday = cal.startOfDay(for: now)
        return cal.date(byAdding: .day, value: 1, to: startOfToday)
            ?? now.addingTimeInterval(3600)
    }
}
