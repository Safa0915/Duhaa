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
