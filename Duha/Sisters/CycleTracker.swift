import Foundation
import Observation

/// One logged menstruation span. `end == nil` means it's ongoing.
struct CycleEntry: Identifiable, Codable {
    var start: String        // "yyyy-MM-dd"
    var end: String?         // "yyyy-MM-dd" or nil while ongoing
    /// Stable unique identity — start dates can repeat, so they can't be the id.
    /// Not persisted (regenerated on load); CodingKeys excludes it.
    let id = UUID()

    enum CodingKeys: String, CodingKey { case start, end }
}

/// Private, on-device-only logging of menstruation days. Used both to inform the
/// woman and — crucially — to mark those days EXCUSED so the prayer streak is
/// never broken and never shown as "missed" (prayer is lifted during menses).
/// Nothing here is ever synced or shared.
@Observable
final class CycleTracker {
    private(set) var entries: [CycleEntry]

    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let key = "duha.cycle.entries"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([CycleEntry].self, from: data) {
            entries = decoded.sorted { $0.start > $1.start }
        } else {
            entries = []
        }
    }

    // MARK: State

    /// The currently-open span, if a period is in progress.
    var ongoing: CycleEntry? { entries.first { $0.end == nil } }

    var isOnPeriod: Bool { ongoing != nil }

    // MARK: Logging

    /// Begin a period today (no-op if one is already ongoing, or already logged today).
    func startPeriod(today: String) {
        guard ongoing == nil else { return }
        guard !entries.contains(where: { $0.start == today }) else { return }
        entries.insert(CycleEntry(start: today, end: nil), at: 0)
        entries.sort { $0.start > $1.start }
        persist()
    }

    /// Close the ongoing period today.
    func endPeriod(today: String) {
        guard let idx = entries.firstIndex(where: { $0.end == nil }) else { return }
        // Guard against an end before the start.
        entries[idx].end = max(today, entries[idx].start)
        persist()
    }

    func delete(_ entry: CycleEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    // MARK: Integration with the prayer streak

    /// All day-indexes (days since 1970, UTC) that fall inside a logged span.
    /// An ongoing span extends through today. These days are treated as excused
    /// by PrayerTracker so the streak bridges over them.
    func excusedDayNumbers(today: String) -> Set<Int> {
        var set = Set<Int>()
        let todayN = Self.dayNumber(today)
        for entry in entries {
            guard let s = Self.dayNumber(entry.start) else { continue }
            let e = entry.end.flatMap(Self.dayNumber) ?? todayN ?? s
            if e >= s { for n in s...e { set.insert(n) } }
        }
        return set
    }

    // MARK: Prediction (gentle, approximate)

    /// Average days between period starts, if there's enough history.
    var averageCycleLength: Int? {
        let starts = entries.compactMap { Self.dayNumber($0.start) }.sorted()
        guard starts.count >= 2 else { return nil }
        var gaps: [Int] = []
        for i in 1..<starts.count { gaps.append(starts[i] - starts[i - 1]) }
        let avg = gaps.reduce(0, +) / gaps.count
        return (avg >= 20 && avg <= 45) ? avg : nil   // ignore implausible spans
    }

    /// A loose "around" date for the next period start.
    func predictedNextStart() -> String? {
        guard let avg = averageCycleLength,
              let lastStart = entries.compactMap({ Self.dayNumber($0.start) }).max() else { return nil }
        return Self.dateString(from: lastStart + avg)
    }

    // MARK: Day math (UTC, matches PrayerTracker's day keys)

    static func dayNumber(_ key: String) -> Int? {
        guard let date = parser.date(from: key) else { return nil }
        return Int((date.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    static func dateString(from dayNumber: Int) -> String {
        parser.string(from: Date(timeIntervalSince1970: Double(dayNumber) * 86_400))
    }

    private static let parser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) { defaults.set(data, forKey: key) }
    }
}
