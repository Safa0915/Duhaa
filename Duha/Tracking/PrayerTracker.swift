import Foundation
import Observation

/// Records which prayers the user has marked as prayed, per day. Persisted to
/// UserDefaults. ZERO guilt mechanics (spec §5): it only ever counts what's
/// done — it never tallies or surfaces what was missed.
@Observable
final class PrayerTracker {
    /// dayKey ("yyyy-MM-dd") → set of prayed prayer raw values.
    private var marks: [String: Set<String>]
    /// The last day the app recorded being opened, for the gentle welcome-back.
    private var lastOpenedDay: String?

    @ObservationIgnored private let defaults = UserDefaults.standard

    init() {
        if let data = UserDefaults.standard.data(forKey: Key.marks),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            marks = decoded.mapValues { Set($0) }
        } else {
            marks = [:]
        }
        lastOpenedDay = UserDefaults.standard.string(forKey: Key.lastOpened)
    }

    // MARK: Marking

    func isMarked(_ prayer: Prayer, dayKey: String) -> Bool {
        marks[dayKey]?.contains(prayer.rawValue) ?? false
    }

    /// Toggle a prayer's prayed state; returns the new state (true = now prayed).
    @discardableResult
    func toggle(_ prayer: Prayer, dayKey: String) -> Bool {
        var set = marks[dayKey] ?? []
        let nowPrayed: Bool
        if set.contains(prayer.rawValue) {
            set.remove(prayer.rawValue)
            nowPrayed = false
        } else {
            set.insert(prayer.rawValue)
            nowPrayed = true
        }
        marks[dayKey] = set.isEmpty ? nil : set
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

    /// Consecutive days (ending today) with at least one prayer. A day that hasn't
    /// begun yet never breaks the streak — it counts through yesterday until you pray.
    func currentStreak(asOf date: Date, timeZone: TimeZone) -> Int {
        let active = activeDayNumbers()
        guard var n = Self.dayNumber(PrayerTracker.dayKey(date, timeZone)) else { return 0 }
        if !active.contains(n) { n -= 1 }   // grace for a not-yet-started today
        var streak = 0
        while active.contains(n) { streak += 1; n -= 1 }
        return streak
    }

    /// The longest run of consecutive active days ever — a badge you can't lose.
    func bestStreak() -> Int {
        let days = activeDayNumbers().sorted()
        guard !days.isEmpty else { return 0 }
        var best = 1, run = 1
        for i in 1..<days.count {
            run = days[i] == days[i - 1] + 1 ? run + 1 : 1
            best = max(best, run)
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
        let encodable = marks.mapValues { Array($0) }
        if let data = try? JSONEncoder().encode(encodable) {
            defaults.set(data, forKey: Key.marks)
        }
    }

    private enum Key {
        static let marks = "duha.tracker.marks"
        static let lastOpened = "duha.tracker.lastOpened"
    }
}
