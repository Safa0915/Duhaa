import Foundation
import Observation

/// Logs which days were fasted. Mirrors PrayerTracker's spirit — it only ever
/// counts what's done. Persisted to UserDefaults; injectable for tests.
@Observable
final class FastingTracker {
    private var fasted: Set<String>   // dayKeys ("yyyy-MM-dd")

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "duha.fasting.days"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        fasted = Set(defaults.stringArray(forKey: key) ?? [])
    }

    func isFasted(_ dayKey: String) -> Bool { fasted.contains(dayKey) }

    @discardableResult
    func toggle(_ dayKey: String) -> Bool {
        let nowFasted: Bool
        if fasted.contains(dayKey) { fasted.remove(dayKey); nowFasted = false }
        else { fasted.insert(dayKey); nowFasted = true }
        defaults.set(Array(fasted), forKey: key)
        return nowFasted
    }

    /// Total fasted days, all time.
    var total: Int { fasted.count }

    /// Fasted days that fall in a given Hijri month + year — i.e. "fasts this
    /// Ramadan". Day keys are parsed in `timeZone` and converted with UmmAlQura.
    func count(hijriMonth: Int, hijriYear: Int, offsetDays: Int, timeZone: TimeZone) -> Int {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.timeZone = timeZone
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = timeZone
        parser.dateFormat = "yyyy-MM-dd"
        return fasted.reduce(0) { acc, dayKey in
            guard let date = parser.date(from: dayKey) else { return acc }
            let adjusted = cal.date(byAdding: .day, value: offsetDays, to: date) ?? date
            let comps = cal.dateComponents([.year, .month], from: adjusted)
            return acc + (comps.month == hijriMonth && comps.year == hijriYear ? 1 : 0)
        }
    }
}
