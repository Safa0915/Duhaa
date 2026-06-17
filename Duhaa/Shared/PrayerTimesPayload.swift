import Foundation

/// A lightweight, Codable bundle of computed prayer times the **app writes** and
/// the **widget reads**. The widget never runs Adhan or any heavy calculation —
/// it just reads these absolute `Date` instants and decides what's next/current.
///
/// The app writes a small rolling window (today + the next couple of days) so the
/// widget keeps working — and rolls into tomorrow at midnight — even if the app
/// isn't opened for a day or two. When the window no longer covers "now", the
/// widget shows a graceful "Open Duhaa" fallback rather than stale times.
struct PrayerTimesPayload: Codable, Hashable, Sendable {

    /// One calendar day's five prayer instants, in the location's time zone.
    struct Day: Codable, Hashable, Sendable {
        let dayKey: String        // "yyyy-MM-dd" in the location's time zone
        let fajr: Date
        let dhuhr: Date
        let asr: Date
        let maghrib: Date
        let isha: Date
        /// Sunrise (end of Fajr) — shown by the Morning times widget. Optional so
        /// payloads written before this field still decode. Defaulted last.
        var sunrise: Date? = nil

        func time(for id: PrayerID) -> Date {
            switch id {
            case .fajr:    return fajr
            case .dhuhr:   return dhuhr
            case .asr:     return asr
            case .maghrib: return maghrib
            case .isha:    return isha
            }
        }

        /// The five prayers paired with their instants, in canonical order.
        var ordered: [(id: PrayerID, time: Date)] {
            PrayerID.ordered.map { ($0, time(for: $0)) }
        }
    }

    var days: [Day]
    var locationDisplayName: String?
    var timeZoneID: String
    var themeID: String
    var lastUpdated: Date
    /// Today's Hijri date (offset-adjusted by the app), for the Hijri widget.
    var hijri: HijriStamp? = nil
    /// Today's du'a (picked by the app from the bundled library), for the Du'a widget.
    var dailyDua: DuaStamp? = nil

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    /// The day bucket whose key matches `dayKey`, if present.
    func day(forKey dayKey: String) -> Day? {
        days.first { $0.dayKey == dayKey }
    }

    /// The day bucket for the calendar day that `now` falls on, in this payload's
    /// time zone (this is "today" from the widget's point of view).
    func day(containing now: Date) -> Day? {
        day(forKey: SharedDayKey.make(now, timeZone))
    }

    /// The day bucket for the day after `now`, if the app wrote it.
    func dayAfter(_ now: Date) -> Day? {
        let next = now.addingTimeInterval(86_400)
        return day(forKey: SharedDayKey.make(next, timeZone))
    }
}

/// Today's Hijri date, computed by the app (respecting the user's offset setting).
struct HijriStamp: Codable, Hashable, Sendable {
    let day: Int
    let monthName: String
    let year: Int

    /// "2 Muharram 1448".
    var formatted: String { "\(day) \(monthName) \(year)" }
    /// "Muh" — for the tight circular widget.
    var monthAbbrev: String { String(monthName.prefix(3)) }
}

/// Today's du'a, picked by the app from the bundled library and surfaced by the
/// Daily Du'a widget. Carries just enough to render + deep-link back into the app.
struct DuaStamp: Codable, Hashable, Sendable {
    let index: Int           // stable position for the `duhaa://dua/<index>` deep link
    let title: String
    let arabic: String
    let latin: String
    let en: String
    let source: String
    let status: String?      // authenticity badge (e.g. "Verified") when present
}
