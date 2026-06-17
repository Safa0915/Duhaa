import Foundation

/// The single persistence boundary shared by the app and the widget extension.
///
/// **Completion** is stored in the *exact* same keys and JSON shape the app's
/// `PrayerTracker` uses (`duhaa.tracker.marks` / `duhaa.tracker.lateMarks`), so
/// the two processes are automatically in sync — neither owns a private copy.
/// **Times** are stored under a separate widget key the app writes and the widget
/// reads. Everything lives in the App-Group suite (`UserDefaults.duhaaShared`).
struct SharedPrayerStore {

    /// The store the App Intents use. A `var` so tests can point it at an isolated
    /// suite; production stays on the shared App-Group suite.
    static var current = SharedPrayerStore(defaults: .duhaaShared)

    let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    // MARK: Completion (tracker-compatible)

    /// The prayers marked as prayed for `dayKey`.
    func completedIDs(on dayKey: String) -> Set<PrayerID> {
        let raw = decode(Key.marks)[dayKey] ?? []
        return Set(raw.compactMap(PrayerID.init(trackerKey:)))
    }

    func isCompleted(_ id: PrayerID, on dayKey: String) -> Bool {
        decode(Key.marks)[dayKey]?.contains(id.trackerKey) ?? false
    }

    /// The subset of `dayKey`'s prayed prayers that were marked *late* (for the
    /// on-time / late split). Reads the same `lateMarks` the app's tracker writes.
    func lateIDs(on dayKey: String) -> Set<PrayerID> {
        let raw = decode(Key.lateMarks)[dayKey] ?? []
        return Set(raw.compactMap(PrayerID.init(trackerKey:)))
    }

    /// Set a single prayer's completion for a day. Mirrors the app's default of
    /// marking *on time* (so the prayer is removed from `lateMarks`), preserving
    /// the on-time/late nuance the insights view relies on.
    func setCompleted(_ completed: Bool, _ id: PrayerID, on dayKey: String) {
        var marks = decode(Key.marks)
        var late = decode(Key.lateMarks)
        var day = Set(marks[dayKey] ?? [])
        var lateDay = Set(late[dayKey] ?? [])

        if completed {
            day.insert(id.trackerKey)
            lateDay.remove(id.trackerKey)        // widget marks count as on time
        } else {
            day.remove(id.trackerKey)
            lateDay.remove(id.trackerKey)
        }
        marks[dayKey] = day.isEmpty ? nil : Array(day)
        late[dayKey] = lateDay.isEmpty ? nil : Array(lateDay)
        encode(marks, Key.marks)
        encode(late, Key.lateMarks)
    }

    /// Flip a prayer's completion and return the new state (true = now prayed).
    @discardableResult
    func toggleCompleted(_ id: PrayerID, on dayKey: String) -> Bool {
        let nowPrayed = !isCompleted(id, on: dayKey)
        setCompleted(nowPrayed, id, on: dayKey)
        return nowPrayed
    }

    func completionCount(on dayKey: String) -> Int {
        decode(Key.marks)[dayKey]?.count ?? 0
    }

    // MARK: Times payload (app → widget)

    func saveTimes(_ payload: PrayerTimesPayload) {
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: Key.timesPayload)
        }
    }

    func loadTimes() -> PrayerTimesPayload? {
        guard let data = defaults.data(forKey: Key.timesPayload) else { return nil }
        return try? JSONDecoder().decode(PrayerTimesPayload.self, from: data)
    }

    // MARK: Snapshot convenience

    /// Build the snapshot the widget renders for `now`, pulling both the times
    /// payload and the live completion set from the shared suite.
    func snapshot(now: Date = Date()) -> PrayerWidgetSnapshot {
        let payload = loadTimes()
        let tz = payload?.timeZone ?? .current
        let dayKey = SharedDayKey.make(now, tz)
        return .make(payload: payload,
                     completed: completedIDs(on: dayKey),
                     late: lateIDs(on: dayKey),
                     now: now,
                     weekly: weeklyStates(now: now),
                     fallbackThemeID: themeID())
    }

    /// The five-state grid for the last 7 days (oldest → today) — for the weekly
    /// consistency widget. Past days are fully closed (unprayed → missed); today
    /// uses the payload's times so a prayer isn't "missed" until its window closes.
    /// Gentle by design: this is consistency, never a fragile streak.
    func weeklyStates(now: Date = Date()) -> [PrayerDayStates] {
        let payload = loadTimes()
        let tz = payload?.timeZone ?? .current
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let todayKey = SharedDayKey.make(now, tz)
        let marks = decode(Key.marks)
        let lateMarks = decode(Key.lateMarks)
        let today = payload?.day(containing: now)
        let tomorrowFajr = payload?.dayAfter(now)?.fajr

        return (0..<7).reversed().compactMap { offset -> PrayerDayStates? in
            guard let dayDate = cal.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let key = SharedDayKey.make(dayDate, tz)
            let isToday = key == todayKey
            let prayed = Set(marks[key] ?? [])
            let lateSet = Set(lateMarks[key] ?? [])
            let states: [PrayerState] = PrayerID.ordered.enumerated().map { idx, id in
                let didPray = prayed.contains(id.trackerKey)
                let wasLate = lateSet.contains(id.trackerKey)
                let passed: Bool
                if isToday, let today {
                    let ordered = today.ordered
                    let close = idx + 1 < ordered.count
                        ? ordered[idx + 1].time
                        : (tomorrowFajr ?? cal.startOfDay(for: now).addingTimeInterval(86_400))
                    passed = now >= close
                } else {
                    passed = true               // a past day is fully closed
                }
                return PrayerState.derive(prayed: didPray, late: wasLate, windowPassed: passed)
            }
            return PrayerDayStates(dayKey: key, weekdayLetter: Self.weekdayLetter(dayDate, tz),
                                   isToday: isToday, states: states)
        }
    }

    private static func weekdayLetter(_ date: Date, _ tz: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.timeZone = tz
        f.dateFormat = "EEEEE"
        return f.string(from: date)
    }

    /// The active theme id (written into the payload by the app; falls back to the
    /// raw `duhaa.theme` value, then Classic).
    func themeID() -> String {
        loadTimes()?.themeID ?? defaults.string(forKey: Key.theme) ?? "dark"
    }

    // MARK: Raw codec (matches PrayerTracker's `[dayKey: [String]]` shape)

    private func decode(_ key: String) -> [String: [String]] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return [:] }
        return decoded
    }

    private func encode(_ value: [String: [String]], _ key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    // MARK: Migration

    /// One-time copy of legacy tracker data (default: `.standard`) into the
    /// App-Group `suite`, so existing users keep every prayer they've ever marked.
    /// Idempotent: gated by a flag in the destination suite and skipped if the
    /// suite already holds marks. Never wipes anything. `source` is injectable for
    /// tests; production migrates from `.standard`.
    static func migrateLegacyData(into suite: UserDefaults, from source: UserDefaults = .standard) {
        // Same-domain (the safety-net fallback) — nothing to migrate.
        guard suite != source else { return }
        guard suite.bool(forKey: Key.migratedV1) == false else { return }

        let keysToCopy = [Key.marks, Key.lateMarks, Key.lastOpened, Key.theme]
        let suiteHasMarks = suite.data(forKey: Key.marks) != nil
        if !suiteHasMarks {
            for key in keysToCopy where suite.object(forKey: key) == nil {
                if let value = source.object(forKey: key) {
                    suite.set(value, forKey: key)
                }
            }
        }
        suite.set(true, forKey: Key.migratedV1)
    }

    // MARK: Keys

    enum Key {
        // Shared with PrayerTracker (do not rename — cross-process contract).
        static let marks = "duhaa.tracker.marks"
        static let lateMarks = "duhaa.tracker.lateMarks"
        static let lastOpened = "duhaa.tracker.lastOpened"
        static let theme = "duhaa.theme"
        // Widget-only.
        static let timesPayload = "duhaa.widget.timesPayload.v1"
        static let migratedV1 = "duhaa.shared.migratedTrackerV1"
    }
}
