import Foundation

/// How confident we are in the times the widget is about to show.
enum WidgetCalculationStatus: String, Codable, Hashable, Sendable {
    /// Times cover the current day — show everything.
    case ok
    /// The app's saved window no longer reaches today (app not opened in a while).
    case stale
    /// No usable times at all (first run / no location yet).
    case unavailable
}

/// One prayer as rendered in a widget: identity, time, and the state flags the
/// views and VoiceOver labels read from. Pure data — no view logic.
struct PrayerSnapshotItem: Codable, Hashable, Identifiable, Sendable {
    let id: PrayerID
    let displayName: String
    let time: Date?
    let isCompleted: Bool
    let isCurrent: Bool
    let isNext: Bool
    let isPast: Bool
    let canToggle: Bool
    let shortTimeString: String
    /// The five-ready state used by the tracker + grid widgets.
    let state: PrayerState
}

/// The single immutable snapshot a widget entry renders from. The widget builds
/// it once per timeline entry from the shared times payload + the shared
/// completion set, so all the "what's next / what's done" logic lives here and is
/// fully unit-testable off-device.
struct PrayerWidgetSnapshot: Codable, Hashable, Sendable {
    /// The "yyyy-MM-dd" day this snapshot's completion toggles belong to.
    var dayKey: String
    /// The instant this snapshot represents (the timeline entry's date).
    var date: Date
    var locationDisplayName: String?
    var prayers: [PrayerSnapshotItem]
    var nextPrayerID: PrayerID?
    var nextPrayerTime: Date?
    var nextPrayerIsTomorrow: Bool
    var currentPrayerID: PrayerID?
    /// Bounds of the window `now` falls in — for the elapsed ring / progress bar.
    var currentWindowStart: Date?
    var currentWindowEnd: Date?
    var completedPrayerIDs: [PrayerID]
    var dailyCompletionCount: Int
    var totalPrayerCount: Int
    var completionProgress: Double
    var sunriseTime: Date?
    var sunriseString: String
    var hijri: HijriStamp?
    var dailyDua: DuaStamp?
    var weekly: [PrayerDayStates]
    var themeID: String
    var lastUpdated: Date
    var status: WidgetCalculationStatus
    var message: String?

    var hasTimes: Bool { status == .ok }

    /// "2 / 5" style progress string.
    var progressText: String { "\(dailyCompletionCount) / \(totalPrayerCount)" }

    /// The next prayer's display name, if any (handles tomorrow's Fajr roll-over).
    var nextDisplayName: String? { nextPrayerID?.displayName }

    /// Fraction elapsed through the current prayer window (0…1), for the ring/bar.
    var windowProgress: Double {
        guard let start = currentWindowStart, let end = currentWindowEnd, end > start else { return 0 }
        return max(0, min(1, date.timeIntervalSince(start) / end.timeIntervalSince(start)))
    }

    func item(_ id: PrayerID) -> PrayerSnapshotItem? { prayers.first { $0.id == id } }
}

// MARK: - Builder (the testable core)

extension PrayerWidgetSnapshot {

    /// Build the snapshot for a given instant from raw shared inputs.
    ///
    /// - Parameters:
    ///   - payload: the app-written times window (may be `nil` / not cover today).
    ///   - completed: the prayers already marked for the relevant day.
    ///   - late: the subset of `completed` marked late (for the on-time/late split).
    ///   - now: the instant to evaluate (a timeline entry's date).
    ///   - weekly: the last-7-days grid (built by the store; empty when unavailable).
    ///   - fallbackThemeID: theme to use when the payload is missing.
    static func make(payload: PrayerTimesPayload?,
                     completed: Set<PrayerID>,
                     late: Set<PrayerID> = [],
                     now: Date,
                     weekly: [PrayerDayStates] = [],
                     fallbackThemeID: String = "dark") -> PrayerWidgetSnapshot {

        let timeZone = payload?.timeZone ?? .current
        let dayKey = SharedDayKey.make(now, timeZone)
        let themeID = payload?.themeID ?? fallbackThemeID
        let lastUpdated = payload?.lastUpdated ?? now

        // No usable window for today → graceful fallback (still surfaces the day's
        // completion ring; just no times). We never return a blank/crashing widget.
        guard let payload, let today = payload.day(containing: now) else {
            let status: WidgetCalculationStatus = (payload?.days.isEmpty == false) ? .stale : .unavailable
            let names = PrayerID.ordered.map { id -> PrayerSnapshotItem in
                let prayed = completed.contains(id)
                return PrayerSnapshotItem(
                    id: id, displayName: id.displayName, time: nil,
                    isCompleted: prayed, isCurrent: false, isNext: false, isPast: false,
                    canToggle: true, shortTimeString: "—",
                    // Without times we can't tell missed from upcoming → don't judge.
                    state: prayed ? (late.contains(id) ? .late : .onTime) : .upcoming)
            }
            return PrayerWidgetSnapshot(
                dayKey: dayKey, date: now, locationDisplayName: payload?.locationDisplayName,
                prayers: names,
                nextPrayerID: nil, nextPrayerTime: nil, nextPrayerIsTomorrow: false,
                currentPrayerID: nil, currentWindowStart: nil, currentWindowEnd: nil,
                completedPrayerIDs: ordered(completed),
                dailyCompletionCount: completed.count, totalPrayerCount: 5,
                completionProgress: progress(completed.count),
                sunriseTime: nil, sunriseString: "—",
                hijri: payload?.hijri, dailyDua: payload?.dailyDua, weekly: weekly,
                themeID: themeID, lastUpdated: lastUpdated, status: status,
                message: status == .unavailable
                    ? "Open Duhaa to set up prayer times"
                    : "Open Duhaa to refresh today’s times")
        }

        let ordered = today.ordered                      // [(PrayerID, Date)] Fajr→Isha
        let timeFmt = shortTimeFormatter(timeZone)
        let tomorrow = payload.dayAfter(now)

        // Next: first future prayer today, else tomorrow's Fajr if we have it.
        let futureToday = ordered.first { $0.time > now }
        let nextID: PrayerID?
        let nextTime: Date?
        let nextIsTomorrow: Bool
        if let f = futureToday {
            nextID = f.id; nextTime = f.time; nextIsTomorrow = false
        } else if let t = tomorrow {
            nextID = .fajr; nextTime = t.fajr; nextIsTomorrow = true
        } else {
            nextID = nil; nextTime = nil; nextIsTomorrow = false
        }

        // Current: the most recent prayer whose time has arrived today.
        let currentEntry = ordered.last { $0.time <= now }
        let currentID = currentEntry?.id

        // The window `now` is in, for the elapsed ring/bar.
        var cal = Calendar(identifier: .gregorian); cal.timeZone = timeZone
        let windowStart = currentEntry?.time ?? cal.startOfDay(for: now)
        let windowEnd = nextTime

        // A prayer's window closes when the following prayer begins (Isha → tomorrow
        // Fajr). Nothing is "missed" until its window truly closes.
        func windowClose(after index: Int) -> Date {
            if index + 1 < ordered.count { return ordered[index + 1].time }
            return tomorrow?.fajr ?? cal.startOfDay(for: now).addingTimeInterval(86_400)
        }

        let items: [PrayerSnapshotItem] = ordered.enumerated().map { index, entry in
            let prayed = completed.contains(entry.id)
            let isLate = late.contains(entry.id)
            let passed = now >= windowClose(after: index)
            return PrayerSnapshotItem(
                id: entry.id,
                displayName: entry.id.displayName,
                time: entry.time,
                isCompleted: prayed,
                isCurrent: entry.id == currentID,
                isNext: !nextIsTomorrow && entry.id == nextID,
                isPast: entry.time <= now,
                canToggle: true,
                shortTimeString: timeFmt.string(from: entry.time),
                state: PrayerState.derive(prayed: prayed, late: isLate, windowPassed: passed))
        }

        let sunrise = today.sunrise

        return PrayerWidgetSnapshot(
            dayKey: dayKey, date: now,
            locationDisplayName: payload.locationDisplayName,
            prayers: items,
            nextPrayerID: nextID, nextPrayerTime: nextTime, nextPrayerIsTomorrow: nextIsTomorrow,
            currentPrayerID: currentID, currentWindowStart: windowStart, currentWindowEnd: windowEnd,
            completedPrayerIDs: Self.ordered(completed),
            dailyCompletionCount: completed.count, totalPrayerCount: 5,
            completionProgress: Self.progress(completed.count),
            sunriseTime: sunrise,
            sunriseString: sunrise.map { timeFmt.string(from: $0) } ?? "—",
            hijri: payload.hijri, dailyDua: payload.dailyDua, weekly: weekly,
            themeID: themeID, lastUpdated: lastUpdated, status: .ok, message: nil)
    }

    // MARK: Group views (Morning / Evening times widgets)

    /// Fajr + (sunrise) + Dhuhr. Sunrise is surfaced as a synthetic row.
    var morningItems: [PrayerSnapshotItem] { [item(.fajr), item(.dhuhr)].compactMap { $0 } }
    var eveningItems: [PrayerSnapshotItem] { [item(.asr), item(.maghrib), item(.isha)].compactMap { $0 } }

    /// The single most relevant upcoming prayer within a group (for the group's
    /// circular variant): the first not-yet-passed one, else the last.
    func mostRelevant(in ids: [PrayerID]) -> PrayerSnapshotItem? {
        let group = ids.compactMap { item($0) }
        return group.first { !$0.isPast } ?? group.last
    }

    // MARK: Helpers

    static func progress(_ count: Int) -> Double {
        max(0, min(1, Double(count) / 5.0))
    }

    static func ordered(_ set: Set<PrayerID>) -> [PrayerID] {
        PrayerID.ordered.filter { set.contains($0) }
    }

    private static func shortTimeFormatter(_ tz: TimeZone) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = "h:mm a"
        return f
    }
}

// MARK: - Preview / placeholder samples

extension PrayerWidgetSnapshot {
    /// A neutral placeholder for the widget gallery & redacted states.
    static func placeholder(themeID: String = "dark") -> PrayerWidgetSnapshot {
        sample(themeID: themeID, completedCount: 2)
    }

    /// A realistic sample for previews. `completedCount` marks the first N prayers.
    static func sample(themeID: String = "dark",
                       completedCount: Int = 2,
                       reference: Date = Date(timeIntervalSince1970: 1_718_000_000)) -> PrayerWidgetSnapshot {
        let tz = TimeZone(identifier: "America/New_York") ?? .current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let start = cal.startOfDay(for: reference)
        func at(_ h: Int, _ m: Int) -> Date {
            cal.date(bySettingHour: h, minute: m, second: 0, of: start) ?? start
        }
        func day(_ d: Date) -> PrayerTimesPayload.Day {
            let s = cal.startOfDay(for: d)
            func t(_ h: Int, _ m: Int) -> Date { cal.date(bySettingHour: h, minute: m, second: 0, of: s) ?? s }
            return PrayerTimesPayload.Day(
                dayKey: SharedDayKey.make(d, tz),
                fajr: t(4, 21), dhuhr: t(12, 58), asr: t(16, 47),
                maghrib: t(20, 26), isha: t(21, 54), sunrise: t(5, 56))
        }
        let payload = PrayerTimesPayload(
            days: [day(reference), day(reference.addingTimeInterval(86_400))],
            locationDisplayName: "New York, USA",
            timeZoneID: tz.identifier, themeID: themeID, lastUpdated: reference,
            hijri: HijriStamp(day: 2, monthName: "Muharram", year: 1448),
            dailyDua: DuaStamp(index: 0, title: "After the Adhan",
                               arabic: "اللَّهُمَّ رَبَّ هَٰذِهِ الدَّعْوَةِ التَّامَّةِ",
                               latin: "Allāhumma Rabba hādhihi-d-da‘wati-t-tāmmah",
                               en: "O Allah, Lord of this perfect call…",
                               source: "Bukhari 614", status: "Verified"))
        let completed = Set(PrayerID.ordered.prefix(max(0, min(5, completedCount))))
        let lateSet: Set<PrayerID> = completedCount >= 2 ? [.fajr] : []
        let now = at(14, 5)   // mid-afternoon: Asr next, Dhuhr current
        return make(payload: payload, completed: completed, late: lateSet, now: now,
                    weekly: sampleWeekly(tz: tz, reference: reference), fallbackThemeID: themeID)
    }

    /// The empty/no-data fallback sample.
    static func emptySample(themeID: String = "dark") -> PrayerWidgetSnapshot {
        make(payload: nil, completed: [], now: Date(), fallbackThemeID: themeID)
    }

    private static func sampleWeekly(tz: TimeZone, reference: Date) -> [PrayerDayStates] {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let letters = ["W", "T", "F", "S", "S", "M", "T"]
        let patterns: [[PrayerState]] = [
            [.onTime, .onTime, .late, .onTime, .missed],
            [.onTime, .onTime, .onTime, .onTime, .onTime],
            [.late, .missed, .onTime, .onTime, .onTime],
            [.onTime, .onTime, .onTime, .missed, .late],
            [.onTime, .late, .onTime, .onTime, .onTime],
            [.onTime, .onTime, .onTime, .onTime, .late],
            [.onTime, .onTime, .late, .upcoming, .upcoming],
        ]
        return (0..<7).map { i in
            let d = cal.date(byAdding: .day, value: i - 6, to: reference) ?? reference
            return PrayerDayStates(dayKey: SharedDayKey.make(d, tz), weekdayLetter: letters[i],
                                   isToday: i == 6, states: patterns[i])
        }
    }
}
