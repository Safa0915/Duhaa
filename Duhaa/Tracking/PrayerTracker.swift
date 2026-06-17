import Foundation
import Observation
import WidgetKit

/// Records which prayers the user has marked as prayed, per day. Persisted to
/// UserDefaults. ZERO guilt mechanics (spec §5): it only ever counts what's
/// done — it never tallies or surfaces what was missed.
@Observable
final class PrayerTracker {
    /// dayKey ("yyyy-MM-dd") → set of prayed prayer raw values.
    private var marks: [String: Set<String>]
    /// dayKey → subset of prayed prayers that were marked *late* (after the prayer's
    /// window). Always a subset of `marks`. Used only by the opt-in insights view.
    private var lateMarks: [String: Set<String>]
    /// The last day the app recorded being opened, for the gentle welcome-back.
    private var lastOpenedDay: String?

    @ObservationIgnored private let defaults: UserDefaults

    /// `defaults` is injectable so tests can use an isolated suite. Production uses
    /// the App-Group suite so the home-screen widget reads/writes the very same
    /// completion data — no separate copy (see `SharedPrayerStore`).
    init(defaults: UserDefaults = .duhaaShared) {
        self.defaults = defaults
        marks = Self.decodeMarks(defaults.data(forKey: Key.marks))
        lateMarks = Self.decodeMarks(defaults.data(forKey: Key.lateMarks))
        lastOpenedDay = defaults.string(forKey: Key.lastOpened)
    }

    /// Re-read completion from the shared store. Call when the app returns to the
    /// foreground so prayers checked off from the widget appear in the app. Cheap;
    /// only reassigns when something actually changed (avoids needless redraws).
    func reloadFromStore() {
        let freshMarks = Self.decodeMarks(defaults.data(forKey: Key.marks))
        let freshLate = Self.decodeMarks(defaults.data(forKey: Key.lateMarks))
        if freshMarks != marks { marks = freshMarks }
        if freshLate != lateMarks { lateMarks = freshLate }
    }

    private static func decodeMarks(_ data: Data?) -> [String: Set<String>] {
        guard let data,
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return [:] }
        return decoded.mapValues { Set($0) }
    }

    // MARK: Marking

    func isMarked(_ prayer: Prayer, dayKey: String) -> Bool {
        marks[dayKey]?.contains(prayer.rawValue) ?? false
    }

    /// Toggle a prayer's prayed state; returns the new state (true = now prayed).
    /// `onTime` records whether it was prayed within its window (for the opt-in
    /// insights view). It is harmless metadata — nothing surfaces it unless the
    /// user has turned insights on.
    @discardableResult
    func toggle(_ prayer: Prayer, dayKey: String, onTime: Bool = true) -> Bool {
        var set = marks[dayKey] ?? []
        var late = lateMarks[dayKey] ?? []
        let nowPrayed: Bool
        if set.contains(prayer.rawValue) {
            set.remove(prayer.rawValue)
            late.remove(prayer.rawValue)
            nowPrayed = false
        } else {
            set.insert(prayer.rawValue)
            if onTime { late.remove(prayer.rawValue) } else { late.insert(prayer.rawValue) }
            nowPrayed = true
        }
        marks[dayKey] = set.isEmpty ? nil : set
        lateMarks[dayKey] = late.isEmpty ? nil : late
        persist()
        return nowPrayed
    }

    func count(dayKey: String) -> Int { marks[dayKey]?.count ?? 0 }

    // MARK: Journey stats (spec §5 — celebrate what's done, never tally misses)

    /// Total prayers ever marked.
    func totalPrayed() -> Int { marks.values.reduce(0) { $0 + $1.count } }

    /// Days with at least one prayer marked.
    func daysShownUp() -> Int { marks.values.reduce(0) { $0 + ($1.isEmpty ? 0 : 1) } }

    /// Days where all five were marked.
    func perfectDays() -> Int { marks.values.reduce(0) { $0 + ($1.count >= 5 ? 1 : 0) } }

    // MARK: Insights (opt-in only — on-time / late / missed)

    /// On-time / late / missed across the COMPLETED days from `startDay` through
    /// yesterday. Today is in progress, so it's never judged. Excused days (e.g.
    /// menstruation) are skipped entirely — prayer is lifted, so it's never a miss.
    func insights(startDay: String, todayKey: String, excused: Set<Int> = []) -> PrayerInsights {
        guard let start = Self.dayNumber(startDay),
              let today = Self.dayNumber(todayKey),
              today > start else { return PrayerInsights(onTime: 0, late: 0, missed: 0) }

        var onTime = 0, late = 0, missed = 0
        for n in start..<today {                       // completed days only
            if excused.contains(n) { continue }
            let key = Self.keyFromDayNumber(n)
            let prayed = marks[key] ?? []
            let lateCount = (lateMarks[key] ?? []).intersection(prayed).count
            onTime += prayed.count - lateCount
            late += lateCount
            missed += max(0, 5 - prayed.count)
        }
        return PrayerInsights(onTime: onTime, late: late, missed: missed)
    }

    /// Consecutive days (ending today) with at least one prayer. A day that hasn't
    /// begun yet never breaks the streak — it counts through yesterday until you pray.
    /// `excused` days (e.g. menstruation) bridge the streak: they neither break it
    /// nor count toward it — prayer is lifted, so it's never a miss.
    func currentStreak(asOf date: Date, timeZone: TimeZone, excused: Set<Int> = []) -> Int {
        let active = activeDayNumbers()
        guard var n = Self.dayNumber(PrayerTracker.dayKey(date, timeZone)) else { return 0 }
        if !active.contains(n) && !excused.contains(n) { n -= 1 }   // grace for today
        var streak = 0
        while true {
            if active.contains(n) { streak += 1; n -= 1 }
            else if excused.contains(n) { n -= 1 }   // bridge over excused days
            else { break }
        }
        return streak
    }

    /// The longest run of consecutive active days ever — a badge you can't lose.
    /// `excused` days bridge runs without counting (see `currentStreak`).
    func bestStreak(excused: Set<Int> = []) -> Int {
        let active = activeDayNumbers()
        guard let lo = active.min(), let hi = active.max() else { return 0 }
        var best = 0, run = 0
        var n = lo
        while n <= hi {
            if active.contains(n) { run += 1; best = max(best, run) }
            else if excused.contains(n) { /* bridge: keep the run alive */ }
            else { run = 0 }
            n += 1
        }
        return best
    }

    private func activeDayNumbers() -> Set<Int> {
        var set = Set<Int>()
        for (key, prayed) in marks where !prayed.isEmpty {
            if let n = Self.dayNumber(key) { set.insert(n) }
        }
        return set
    }

    /// A timezone-stable day index (days since 1970) for a "yyyy-MM-dd" key.
    private static func dayNumber(_ key: String) -> Int? {
        guard let date = dayParser.date(from: key) else { return nil }
        return Int((date.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    /// Inverse of `dayNumber` — the "yyyy-MM-dd" key for a day index.
    private static func keyFromDayNumber(_ n: Int) -> String {
        dayParser.string(from: Date(timeIntervalSince1970: TimeInterval(n) * 86_400))
    }

    private static let dayParser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    // MARK: Welcome-back

    /// Record that the app opened today. Returns the day gap since the previous
    /// open (nil on first run or same day) so the UI can offer a warm welcome.
    @discardableResult
    func recordOpen(today: String) -> Int? {
        defer {
            lastOpenedDay = today
            defaults.set(today, forKey: Key.lastOpened)
        }
        guard let last = lastOpenedDay, last != today else { return nil }
        let f = Self.keyFormatter
        guard let lastDate = f.date(from: last), let todayDate = f.date(from: today) else { return nil }
        return Calendar(identifier: .gregorian).dateComponents([.day], from: lastDate, to: todayDate).day
    }

    // MARK: Day keys (single source of truth for the "yyyy-MM-dd" format)

    static func dayKey(_ date: Date, _ timeZone: TimeZone) -> String {
        let f = keyFormatter
        f.timeZone = timeZone
        return f.string(from: date)
    }

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private func persist() {
        if let data = try? JSONEncoder().encode(marks.mapValues { Array($0) }) {
            defaults.set(data, forKey: Key.marks)
        }
        if let data = try? JSONEncoder().encode(lateMarks.mapValues { Array($0) }) {
            defaults.set(data, forKey: Key.lateMarks)
        }
        // App → widget: when the app changes completion, refresh the widgets.
        // Guarded to the real shared suite so tests (isolated suites) never poke
        // WidgetKit. Identity compare is valid — `duhaaShared` is a single cached
        // instance.
        if defaults === UserDefaults.duhaaShared {
            WidgetReloader.reload()
        }
    }

    private enum Key {
        static let marks = "duhaa.tracker.marks"
        static let lateMarks = "duhaa.tracker.lateMarks"
        static let lastOpened = "duhaa.tracker.lastOpened"
    }
}

/// A tally of how the five daily prayers were kept over a span of days — the basis
/// of the opt-in insights view. Percentages always sum to 100.
struct PrayerInsights {
    let onTime: Int
    let late: Int
    let missed: Int

    var total: Int { onTime + late + missed }
    var hasData: Bool { total > 0 }
    var onTimePct: Int { pct(onTime) }
    var latePct: Int { pct(late) }
    /// Missed takes the remainder so the three always add up to exactly 100%.
    var missedPct: Int { hasData ? max(0, 100 - onTimePct - latePct) : 0 }
    private func pct(_ n: Int) -> Int { total > 0 ? Int((Double(n) / Double(total) * 100).rounded()) : 0 }
}
