import Foundation

/// Shared Umm al-Qura Hijri date helpers, offset-adjusted for local moon-sighting
/// (mirrors the `hijriOffsetDays` setting, §12). Centralizes the date math the home
/// header, Ramadan card, Journey calendar and the fasting features all rely on, so
/// they stay consistent with one another.
enum HijriCalendar {
    static func calendar(timeZone: TimeZone) -> Calendar {
        var c = Calendar(identifier: .islamicUmmAlQura)
        c.timeZone = timeZone
        return c
    }

    /// The Gregorian `date` nudged by `offsetDays` before reading it as Hijri.
    static func adjusted(_ date: Date, timeZone: TimeZone, offsetDays: Int) -> Date {
        calendar(timeZone: timeZone).date(byAdding: .day, value: offsetDays, to: date) ?? date
    }

    static func components(_ date: Date, timeZone: TimeZone, offsetDays: Int) -> DateComponents {
        let cal = calendar(timeZone: timeZone)
        return cal.dateComponents([.year, .month, .day],
                                  from: adjusted(date, timeZone: timeZone, offsetDays: offsetDays))
    }

    static func string(_ date: Date, timeZone: TimeZone, offsetDays: Int,
                       format: String = "d MMMM yyyy") -> String {
        let cal = calendar(timeZone: timeZone)
        let f = DateFormatter()
        f.calendar = cal
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = format
        return f.string(from: adjusted(date, timeZone: timeZone, offsetDays: offsetDays))
    }

    /// The Ayyām al-Bīḍ — the "white days," the 13th, 14th and 15th of every Hijri
    /// month, on which fasting is recommended (Sunnah).
    static func isWhiteDay(_ date: Date, timeZone: TimeZone, offsetDays: Int) -> Bool {
        let day = components(date, timeZone: timeZone, offsetDays: offsetDays).day ?? 0
        return (13...15).contains(day)
    }
}
