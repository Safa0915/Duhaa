import Foundation
import Observation

// MARK: - Supporting types

/// The five daily prayers, in order, with their display names and icons.
enum Prayer: String, CaseIterable {
    case fajr = "Fajr"
    case dhuhr = "Dhuhr"
    case asr = "Asr"
    case maghrib = "Maghrib"
    case isha = "Isha"

    /// SF Symbol used in the prayer list.
    var icon: String {
        switch self {
        case .fajr:    return "sunrise"
        case .dhuhr:   return "sun.max"
        case .asr:     return "sun.min"
        case .maghrib: return "sunset"
        case .isha:    return "moon.stars"
        }
    }
}

enum RowState { case passed, next, upcoming }

/// One rendered row in the prayer list.
struct PrayerRowData: Identifiable {
    let prayer: Prayer
    let time: String
    let state: RowState
    /// Extra line under the name (only Isha uses it: "ends 11:53 PM · …").
    let sub: String?
    /// The local masjid's jamāʿah time for this prayer, formatted, when the user
    /// has added one (else nil). Shown beside the calculated adhān time.
    let iqama: String?
    /// True when `iqama` is the Friday Jumuʿah time (shown on the Dhuhr row).
    let iqamaIsJumuah: Bool
    /// Whether marking this prayer *right now* counts as on time (logged before the
    /// next prayer begins). Used only by the opt-in insights tracker.
    let onTime: Bool
    /// The day this row's mark belongs to. Usually today — except Isha between
    /// midnight and Fajr, which is still *yesterday's* Isha.
    let dayKey: String
    var id: String { prayer.rawValue }
}

/// One day in the 7-day progress strip.
struct DayRef: Identifiable {
    let key: String      // "yyyy-MM-dd"
    let letter: String   // narrow weekday letter, e.g. "M"
    let isToday: Bool
    var id: String { key }
}

/// A single immutable snapshot the view renders from. Building it once per render
/// keeps all the date math in one place (and off the view).
struct HomeDisplay {
    var hasData = false
    var locationName = ""
    var masjidName = ""
    var dayKey = ""
    var week: [DayRef] = []
    /// Smaller date in the header; larger date under the clock. Which is Hijri vs
    /// Gregorian depends on the user's "primary date" setting (§12).
    var headerDate = ""
    var heroDate = ""
    var clock = ""
    var period = ""
    var nextName = ""
    var countdown = ""
    var progress: Double = 0
    var prevLabel = ""
    var nextLabel = ""
    var timeRemainingCountdown = ""
    var timeRemainingTarget = ""
    var timeRemainingProgress: Double = 0
    var timeRemainingPrevLabel = ""
    var timeRemainingNextLabel = ""
    var rows: [PrayerRowData] = []
    var tahajjud = ""
    var islamicMidnight = ""
    // Ramadan (auto-detected from the Hijri month). The card shows only when isRamadan.
    var isRamadan = false
    var ramadanDay = 0
    var hijriYear = 0
    var suhoor = ""          // Fajr (when suhoor ends)
    var iftar = ""           // Maghrib (when the fast opens)
    var ramadanPhase = ""    // "Iftar" or "Suhoor ends"
    var ramadanCountdown = ""
}

// MARK: - Model

/// Turns engine output + the active location + the user's settings into the home
/// screen's display data. Ticks a 1-second clock so the countdown stays live.
@Observable
final class PrayerHomeModel {

    /// "Now", refreshed every second to keep the countdown moving.
    var now = Date()

    @ObservationIgnored private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.now = Date()
        }
    }

    deinit { timer?.invalidate() }

    // MARK: Snapshot the view reads

    func display(for location: ActiveLocation,
                 config: PrayerConfig,
                 hijriOffsetDays: Int,
                 hijriIsPrimary: Bool,
                 masjid: MasjidTimetable = MasjidTimetable()) -> HomeDisplay {
        let tz = location.timeZone
        var d = HomeDisplay()
        d.locationName = location.name
        d.masjidName = masjid.name
        d.dayKey = PrayerTracker.dayKey(now, tz)
        d.week = weekRefs(now, tz, todayKey: d.dayKey)

        let hijriStr = hijri(now, tz, offsetDays: hijriOffsetDays)
        let gregorianStr = format("EEEE, d MMMM yyyy", now, tz)
        d.headerDate = hijriIsPrimary ? gregorianStr : hijriStr
        d.heroDate = hijriIsPrimary ? hijriStr : gregorianStr

        d.clock = format("h:mm", now, tz)
        d.period = format("a", now, tz)

        guard let today = times(location, config, dayOffset: 0) else { return d } // polar fallback
        d.hasData = true

        // A timeline spanning yesterday's Isha → today's five → tomorrow's Fajr,
        // so "previous" and "next" resolve correctly at any hour.
        let yesterday = times(location, config, dayOffset: -1)
        let tomorrow = times(location, config, dayOffset: 1)
        var timeline: [(Prayer, Date)] = []
        if let y = yesterday { timeline.append((.isha, y.isha)) }
        timeline += [(.fajr, today.fajr), (.dhuhr, today.dhuhr), (.asr, today.asr),
                     (.maghrib, today.maghrib), (.isha, today.isha)]
        if let tomorrow { timeline.append((.fajr, tomorrow.fajr)) }
        timeline.sort { $0.1 < $1.1 }

        let next = timeline.first { $0.1 > now }
        let prev = timeline.last { $0.1 <= now }

        // The five list rows.
        func time(for prayer: Prayer) -> Date {
            switch prayer {
            case .fajr: today.fajr
            case .dhuhr: today.dhuhr
            case .asr: today.asr
            case .maghrib: today.maghrib
            case .isha: today.isha
            }
        }
        // Each prayer is "on time" until the next prayer begins (gentle, hope-framed:
        // grace over strictness). Two fiqh boundaries are firm: Fajr ends at sunrise
        // (consensus), and Isha ends at Islamic midnight — matching the "ends ..."
        // note the row itself shows. At extreme latitudes where Isha begins after
        // Islamic midnight, fall back to Fajr so it isn't "late" the moment it starts.
        let tomorrowFajr = tomorrow?.fajr
        let ishaEnd = today.ishaAfterIslamicMidnight
            ? (tomorrowFajr ?? today.isha.addingTimeInterval(6 * 3600))
            : today.islamicMidnight
        let windowEnd: [Prayer: Date] = [
            .fajr: today.sunrise, .dhuhr: today.asr, .asr: today.maghrib,
            .maghrib: today.isha, .isha: ishaEnd,
        ]
        // Between midnight and Fajr, "Isha" can only mean last night's — route its
        // mark to yesterday so streaks and insights land on the correct day. It is
        // on time only until *yesterday's* Islamic midnight (same anomaly fallback).
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let yesterdayKey = cal.date(byAdding: .day, value: -1, to: now)
            .map { PrayerTracker.dayKey($0, tz) } ?? d.dayKey
        let lastNightIshaEnd = yesterday.map { y in
            y.ishaAfterIslamicMidnight ? today.fajr : y.islamicMidnight
        } ?? today.fajr
        let preFajr = now < today.fajr

        if let next {
            d.nextName = next.0.rawValue
            d.countdown = countdown(to: next.1)
            d.nextLabel = "\(next.0.rawValue) \(clock(next.1, tz))"
        }
        if let prev {
            d.prevLabel = "\(prev.0.rawValue) \(clock(prev.1, tz))"
        }
        if let next, let prev {
            let total = next.1.timeIntervalSince(prev.1)
            let elapsed = now.timeIntervalSince(prev.1)
            d.progress = total > 0 ? min(1, max(0, elapsed / total)) : 0
        }

        func setTimeRemaining(target: String, start: Date, end: Date, startLabel: String, endLabel: String) {
            d.timeRemainingTarget = target
            d.timeRemainingCountdown = countdown(to: end)
            d.timeRemainingPrevLabel = startLabel
            d.timeRemainingNextLabel = endLabel
            let total = end.timeIntervalSince(start)
            let elapsed = now.timeIntervalSince(start)
            d.timeRemainingProgress = total > 0 ? min(1, max(0, elapsed / total)) : 0
        }

        if let y = yesterday, preFajr, now >= y.isha, now < lastNightIshaEnd {
            let target = y.ishaAfterIslamicMidnight ? Prayer.fajr.rawValue : "Islamic midnight"
            setTimeRemaining(target: target,
                             start: y.isha,
                             end: lastNightIshaEnd,
                             startLabel: "Isha \(clock(y.isha, tz))",
                             endLabel: "\(target) \(clock(lastNightIshaEnd, tz))")
        } else if now >= today.fajr && now < today.sunrise {
            setTimeRemaining(target: "sunrise",
                             start: today.fajr,
                             end: today.sunrise,
                             startLabel: "Fajr \(clock(today.fajr, tz))",
                             endLabel: "Sunrise \(clock(today.sunrise, tz))")
        } else if now >= today.dhuhr && now < today.asr {
            setTimeRemaining(target: Prayer.asr.rawValue,
                             start: today.dhuhr,
                             end: today.asr,
                             startLabel: "Dhuhr \(clock(today.dhuhr, tz))",
                             endLabel: "Asr \(clock(today.asr, tz))")
        } else if now >= today.asr && now < today.maghrib {
            setTimeRemaining(target: Prayer.maghrib.rawValue,
                             start: today.asr,
                             end: today.maghrib,
                             startLabel: "Asr \(clock(today.asr, tz))",
                             endLabel: "Maghrib \(clock(today.maghrib, tz))")
        } else if now >= today.maghrib && now < today.isha {
            setTimeRemaining(target: Prayer.isha.rawValue,
                             start: today.maghrib,
                             end: today.isha,
                             startLabel: "Maghrib \(clock(today.maghrib, tz))",
                             endLabel: "Isha \(clock(today.isha, tz))")
        } else if now >= today.isha && now < ishaEnd {
            let target = today.ishaAfterIslamicMidnight ? Prayer.fajr.rawValue : "Islamic midnight"
            setTimeRemaining(target: target,
                             start: today.isha,
                             end: ishaEnd,
                             startLabel: "Isha \(clock(today.isha, tz))",
                             endLabel: "\(target) \(clock(ishaEnd, tz))")
        } else if let next {
            let start = now >= today.sunrise && now < today.dhuhr ? today.sunrise : (prev?.1 ?? now)
            let startLabel = now >= today.sunrise && now < today.dhuhr
                ? "Sunrise \(clock(today.sunrise, tz))"
                : (prev.map { "\($0.0.rawValue) \(clock($0.1, tz))" } ?? "")
            setTimeRemaining(target: next.0.rawValue,
                             start: start,
                             end: next.1,
                             startLabel: startLabel,
                             endLabel: "\(next.0.rawValue) \(clock(next.1, tz))")
        }

        // Friday → Jumuʿah replaces the Dhuhr jamāʿah, when both apply.
        let isFriday = weekday(now, tz) == 6
        d.rows = Prayer.allCases.map { prayer in
            let isLastNightsIsha = prayer == .isha && preFajr
            let rowTimes = isLastNightsIsha ? yesterday : today
            let rowStart = isLastNightsIsha ? (yesterday?.isha ?? today.isha) : time(for: prayer)
            let state: RowState
            if prayer.rawValue == next?.0.rawValue {
                state = .next
            } else {
                state = rowStart <= now ? .passed : .upcoming
            }
            let end = isLastNightsIsha ? lastNightIshaEnd : (windowEnd[prayer] ?? rowStart)
            let sub: String? = switch prayer {
            case .isha: rowTimes.map { ishaSub($0, tz) }
            case .fajr: fajrSub(today, tz)
            default: nil
            }
            let useJumuah = prayer == .dhuhr && isFriday && masjid.jumuah != nil
            let iqamaMinutes = useJumuah ? masjid.jumuah : masjid.minutes(for: prayer)
            return PrayerRowData(prayer: prayer,
                                 time: clock(rowStart, tz),
                                 state: state,
                                 sub: sub,
                                 iqama: iqamaMinutes.map { MasjidTimetable.clock($0) },
                                 iqamaIsJumuah: useJumuah,
                                 onTime: now >= rowStart && now < end,
                                 dayKey: isLastNightsIsha ? yesterdayKey : d.dayKey)
        }

        d.tahajjud = clock(today.tahajjud, tz)
        d.islamicMidnight = clock(today.islamicMidnight, tz)

        // Ramadan: auto-detected from the (offset-adjusted) Hijri month.
        let h = hijriComponents(now, tz, offsetDays: hijriOffsetDays)
        d.hijriYear = h.year ?? 0
        d.ramadanDay = h.day ?? 0
        d.isRamadan = (h.month == 9)
        d.suhoor = clock(today.fajr, tz)
        d.iftar = clock(today.maghrib, tz)
        if now < today.fajr {
            d.ramadanPhase = "Suhoor ends"
            d.ramadanCountdown = countdown(to: today.fajr)
        } else if now < today.maghrib {
            d.ramadanPhase = "Iftar"
            d.ramadanCountdown = countdown(to: today.maghrib)
        } else {
            d.ramadanPhase = "Suhoor ends"
            if let tomorrow = times(location, config, dayOffset: 1) {
                d.ramadanCountdown = countdown(to: tomorrow.fajr)
            }
        }
        return d
    }

    // MARK: Engine access

    /// Times for the day `offset` days from now (0 = today), in the location's zone.
    private func times(_ location: ActiveLocation, _ config: PrayerConfig, dayOffset: Int) -> DuhaaPrayerTimes? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = location.timeZone
        guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { return nil }
        let comps = calendar.dateComponents([.year, .month, .day], from: day)
        return PrayerEngine.times(latitude: location.latitude,
                                  longitude: location.longitude,
                                  date: comps,
                                  config: config)
    }

    // MARK: Fajr "ends at sunrise" sub-line

    /// Sunrise — the end of Fajr and the threshold of the Duhaa prayer (the app's
    /// namesake) — lives inside the Fajr row, never as a sixth prayer. The newline
    /// keeps the namesake nod on its own tidy line instead of an awkward mid-wrap.
    private func fajrSub(_ t: DuhaaPrayerTimes, _ tz: TimeZone) -> String {
        "ends at sunrise \(clock(t.sunrise, tz))"
    }

    // MARK: Isha "ends at Islamic midnight" sub-line

    private func ishaSub(_ t: DuhaaPrayerTimes, _ tz: TimeZone) -> String {
        // High-latitude anomaly (spec §13): when Isha lands after Islamic midnight,
        // the "ends at midnight" framing breaks down — say so gently instead.
        if t.ishaAfterIslamicMidnight {
            return "approximate at this latitude"
        }
        return "ends at Islamic midnight \(clock(t.islamicMidnight, tz))"
    }

    // MARK: Formatting helpers

    private func countdown(to date: Date) -> String {
        let seconds = max(0, Int(ceil(date.timeIntervalSince(now))))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m) minute\(m == 1 ? "" : "s")" }
        return "\(s) second\(s == 1 ? "" : "s")"
    }

    private func clock(_ date: Date, _ tz: TimeZone) -> String { format("h:mm a", date, tz) }

    private func format(_ pattern: String, _ date: Date, _ tz: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = pattern
        return f.string(from: date)
    }

    private func weekRefs(_ now: Date, _ tz: TimeZone, todayKey: String) -> [DayRef] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let key = PrayerTracker.dayKey(day, tz)
            return DayRef(key: key, letter: weekdayLetter(day, tz), isToday: key == todayKey)
        }
    }

    /// Gregorian weekday in the location's zone (1 = Sunday … 6 = Friday … 7 = Saturday).
    private func weekday(_ date: Date, _ tz: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        return calendar.component(.weekday, from: date)
    }

    private func weekdayLetter(_ date: Date, _ tz: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.timeZone = tz
        f.dateFormat = "EEEEE"
        return f.string(from: date)
    }

    /// Offset-adjusted Hijri year/month/day components (UmmAlQura), for Ramadan detection.
    private func hijriComponents(_ date: Date, _ tz: TimeZone, offsetDays: Int) -> DateComponents {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.timeZone = tz
        let adjusted = calendar.date(byAdding: .day, value: offsetDays, to: date) ?? date
        return calendar.dateComponents([.year, .month, .day], from: adjusted)
    }

    private func hijri(_ date: Date, _ tz: TimeZone, offsetDays: Int) -> String {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.timeZone = tz
        let adjusted = calendar.date(byAdding: .day, value: offsetDays, to: date) ?? date
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: adjusted)
    }
}
