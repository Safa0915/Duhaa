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
    /// Whether marking this prayer *right now* counts as on time (logged before the
    /// next prayer begins). Used only by the opt-in insights tracker.
    let onTime: Bool
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
    var rows: [PrayerRowData] = []
    /// Sunrise — shown as a slim boundary in the list (end of Fajr / start of Duhaa),
    /// never as a sixth obligatory prayer.
    var sunrise = ""
    var sunrisePassed = false
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
                 hijriIsPrimary: Bool) -> HomeDisplay {
        let tz = location.timeZone
        var d = HomeDisplay()
        d.locationName = location.name
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
        var timeline: [(Prayer, Date)] = []
        if let y = times(location, config, dayOffset: -1) { timeline.append((.isha, y.isha)) }
        timeline += [(.fajr, today.fajr), (.dhuhr, today.dhuhr), (.asr, today.asr),
                     (.maghrib, today.maghrib), (.isha, today.isha)]
        if let t = times(location, config, dayOffset: 1) { timeline.append((.fajr, t.fajr)) }
        timeline.sort { $0.1 < $1.1 }

        let next = timeline.first { $0.1 > now }
        let prev = timeline.last { $0.1 <= now }

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

        // The five list rows.
        let byPrayer: [Prayer: Date] = [
            .fajr: today.fajr, .dhuhr: today.dhuhr, .asr: today.asr,
            .maghrib: today.maghrib, .isha: today.isha,
        ]
        // Each prayer is "on time" until the next prayer begins (gentle, hope-framed:
        // grace over strictness). Isha runs to tomorrow's Fajr.
        let tomorrowFajr = times(location, config, dayOffset: 1)?.fajr
        let windowEnd: [Prayer: Date] = [
            .fajr: today.dhuhr, .dhuhr: today.asr, .asr: today.maghrib,
            .maghrib: today.isha, .isha: tomorrowFajr ?? today.isha.addingTimeInterval(6 * 3600),
        ]
        d.rows = Prayer.allCases.map { prayer in
            let time = byPrayer[prayer]!
            let state: RowState
            if prayer.rawValue == next?.0.rawValue {
                state = .next
            } else {
                state = time <= now ? .passed : .upcoming
            }
            return PrayerRowData(prayer: prayer,
                                 time: clock(time, tz),
                                 state: state,
                                 sub: prayer == .isha ? ishaSub(today, tz) : nil,
                                 onTime: now < (windowEnd[prayer] ?? time))
        }

        d.sunrise = clock(today.sunrise, tz)
        d.sunrisePassed = today.sunrise <= now
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

    // MARK: Isha "ends at Islamic midnight" sub-line

    private func ishaSub(_ t: DuhaaPrayerTimes, _ tz: TimeZone) -> String {
        // High-latitude anomaly (spec §13): when Isha lands after Islamic midnight,
        // the "ends at midnight" framing breaks down — say so gently instead.
        if t.ishaAfterIslamicMidnight {
            return "approximate at this latitude"
        }
        var sub = "ends \(clock(t.islamicMidnight, tz))"
        if now >= t.isha && now < t.islamicMidnight {
            sub += " · ends in \(countdown(to: t.islamicMidnight))"
        }
        return sub
    }

    // MARK: Formatting helpers

    private func countdown(to date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let h = seconds / 3600, m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
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
