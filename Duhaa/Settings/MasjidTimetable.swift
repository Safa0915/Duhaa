import Foundation

/// A user's local masjid jamāʿah (iqāmah) times — the congregation times posted at
/// their mosque, which differ from the calculated adhān times. Entirely optional:
/// every prayer stays `nil` until the user adds it. Stored as minutes since local
/// midnight (wall-clock), so the times read the same regardless of device time zone.
struct MasjidTimetable: Codable, Equatable, Sendable {
    var name: String = ""
    var fajr: Int?
    var dhuhr: Int?
    var asr: Int?
    var maghrib: Int?
    var isha: Int?
    var jumuah: Int?    // Friday congregation — shown in place of Dhuhr on Fridays

    /// True once at least one jamāʿah time has been entered.
    var hasAnyTime: Bool {
        [fajr, dhuhr, asr, maghrib, isha, jumuah].contains { $0 != nil }
    }

    /// The jamāʿah time (minutes since midnight) for one of the five daily prayers.
    func minutes(for prayer: Prayer) -> Int? {
        switch prayer {
        case .fajr:    fajr
        case .dhuhr:   dhuhr
        case .asr:     asr
        case .maghrib: maghrib
        case .isha:    isha
        }
    }

    /// Format minutes-since-midnight as a 12-hour clock ("6:20 AM"), matching the
    /// app's en_US_POSIX "h:mm a" style and independent of the device locale.
    static func clock(_ minutes: Int) -> String {
        let m = ((minutes % 1440) + 1440) % 1440
        let hour24 = m / 60, minute = m % 60
        let period = hour24 < 12 ? "AM" : "PM"
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        return String(format: "%d:%02d %@", hour12, minute, period)
    }
}
