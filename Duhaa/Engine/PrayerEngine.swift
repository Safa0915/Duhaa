import Foundation
import Adhan

// MARK: - Configuration

/// Everything the user can change that affects prayer-time calculation.
///
/// The defaults match the `prayer-verify` Node harness (MWL · Shafi/standard ·
/// middle-of-the-night), so a bare `PrayerConfig()` reproduces its numbers to
/// the minute. Settings (Slice 4) will mutate these.
struct PrayerConfig: Equatable {
    /// Calculation method (angles for Fajr/Isha). MWL is the neutral default.
    var method: CalculationMethod = .muslimWorldLeague

    /// Asr shadow rule. `.shafi` = Shafi'i/Hanbali/Maliki (standard); `.hanafi`
    /// pushes Asr later.
    var madhab: Madhab = .shafi

    /// How Fajr/Isha are resolved where twilight never fully ends. Spec §13:
    /// above ~48°N we apply middle-of-the-night as a stopgap.
    var highLatitudeRule: HighLatitudeRule = .middleOfTheNight

    /// Manual per-prayer nudges in minutes — the v1 high-latitude stopgap and
    /// the user's local-mosque fine-tuning (spec §4, §13).
    var offsets = PrayerOffsets()

    /// A full set of user-entered times. When `manual.enabled`, the engine returns
    /// these verbatim instead of calculating — for people who follow a fixed printed
    /// timetable. Offsets and method/madhab no longer apply in that mode.
    var manual = ManualPrayerTimes()
}

/// Per-prayer manual offsets, in minutes (may be negative).
struct PrayerOffsets: Equatable, Codable {
    var fajr = 0
    var sunrise = 0
    var dhuhr = 0
    var asr = 0
    var maghrib = 0
    var isha = 0
}

/// A user-supplied daily timetable (the same wall-clock times every day), stored as
/// minutes since local midnight. Sunrise is included so the Fajr window and the Duha
/// threshold still read correctly. Defaults are placeholders; the settings screen
/// seeds real values from the calculated times the first time it's switched on.
struct ManualPrayerTimes: Equatable, Codable {
    /// When true, `PrayerEngine` returns these times instead of calculating.
    var enabled = false
    /// Set once the fields have been seeded from the calculated times, so we only
    /// auto-fill on the very first enable — never overwriting the user's own edits.
    var configured = false
    var fajr = 5 * 60            // 5:00 AM
    var sunrise = 6 * 60 + 30    // 6:30 AM
    var dhuhr = 13 * 60          // 1:00 PM
    var asr = 16 * 60 + 30       // 4:30 PM
    var maghrib = 19 * 60        // 7:00 PM
    var isha = 20 * 60 + 30      // 8:30 PM
}

// MARK: - Result

/// The computed times for one day at one location. All values are absolute
/// `Date` instants — format them in the location's time zone for display.
struct DuhaaPrayerTimes: Equatable {
    let fajr: Date
    let sunrise: Date
    let dhuhr: Date
    let asr: Date
    let maghrib: Date
    let isha: Date

    /// Islamic midnight — when Isha ends (Maghrib + half the night). The Isha
    /// card shows this, with a countdown in its final 30 minutes.
    let islamicMidnight: Date

    /// Start of the last third of the night — the Tahajjud window.
    let tahajjud: Date

    /// A high-latitude anomaly: in deep summer up north, Isha can land *after*
    /// Islamic midnight, so "Isha ends at Islamic midnight" stops making sense.
    /// The UI uses this to drop the countdown and lean on the §13 disclaimer.
    var ishaAfterIslamicMidnight: Bool { isha > islamicMidnight }
}

// MARK: - Engine

/// Thin, tested wrapper over Adhan Swift — the single source of prayer times for
/// the whole app. Nothing else should import Adhan or compute times directly.
enum PrayerEngine {

    /// Computes the day's prayer + night times.
    ///
    /// - Parameters:
    ///   - latitude/longitude: location in degrees.
    ///   - date: the calendar day (year/month/day) to compute for.
    ///   - config: calculation settings (defaults reproduce the harness).
    /// - Returns: `nil` only when the astronomical solution fails (e.g. true
    ///   polar day/night that even the high-latitude rule can't resolve) — the
    ///   caller should fall back gracefully rather than crash.
    static func times(latitude: Double,
                      longitude: Double,
                      date: DateComponents,
                      config: PrayerConfig = PrayerConfig(),
                      timeZone: TimeZone = .current) -> DuhaaPrayerTimes? {

        // Manual override: the user follows their own fixed timetable. Build the
        // day's instants straight from their wall-clock times in the location's zone.
        if config.manual.enabled {
            return manualTimes(config.manual, date: date, timeZone: timeZone)
        }

        let coordinates = Coordinates(latitude: latitude, longitude: longitude)

        var params = config.method.params
        params.madhab = config.madhab
        params.highLatitudeRule = config.highLatitudeRule
        // Fold the user's manual offsets into Adhan's own per-prayer adjustments,
        // so the night times (derived from Maghrib & next Fajr) stay consistent.
        params.adjustments.fajr = config.offsets.fajr
        params.adjustments.sunrise = config.offsets.sunrise
        params.adjustments.dhuhr = config.offsets.dhuhr
        params.adjustments.asr = config.offsets.asr
        params.adjustments.maghrib = config.offsets.maghrib
        params.adjustments.isha = config.offsets.isha

        guard let prayers = PrayerTimes(coordinates: coordinates,
                                        date: date,
                                        calculationParameters: params),
              let sunnah = SunnahTimes(from: prayers) else {
            return nil
        }

        return DuhaaPrayerTimes(
            fajr: prayers.fajr,
            sunrise: prayers.sunrise,
            dhuhr: prayers.dhuhr,
            asr: prayers.asr,
            maghrib: prayers.maghrib,
            isha: prayers.isha,
            islamicMidnight: sunnah.middleOfTheNight,
            tahajjud: sunnah.lastThirdOfTheNight
        )
    }

    /// Build a day's times from the user's fixed wall-clock timetable. Islamic
    /// midnight and Tahajjud are derived the same way Adhan's `SunnahTimes` does —
    /// from Maghrib and the *next* day's Fajr — so the night cards stay coherent.
    private static func manualTimes(_ manual: ManualPrayerTimes,
                                    date: DateComponents,
                                    timeZone: TimeZone) -> DuhaaPrayerTimes? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        func instant(_ minutes: Int, dayOffset: Int = 0) -> Date? {
            var comps = DateComponents()
            comps.year = date.year
            comps.month = date.month
            comps.day = date.day
            comps.hour = minutes / 60
            comps.minute = minutes % 60
            guard let base = calendar.date(from: comps) else { return nil }
            return dayOffset == 0 ? base : calendar.date(byAdding: .day, value: dayOffset, to: base)
        }

        guard let fajr = instant(manual.fajr),
              let sunrise = instant(manual.sunrise),
              let dhuhr = instant(manual.dhuhr),
              let asr = instant(manual.asr),
              let maghrib = instant(manual.maghrib),
              let isha = instant(manual.isha),
              let nextFajr = instant(manual.fajr, dayOffset: 1) else { return nil }

        let night = nextFajr.timeIntervalSince(maghrib)
        return DuhaaPrayerTimes(
            fajr: fajr, sunrise: sunrise, dhuhr: dhuhr, asr: asr, maghrib: maghrib, isha: isha,
            islamicMidnight: maghrib.addingTimeInterval(night / 2),
            tahajjud: maghrib.addingTimeInterval(night * 2 / 3)
        )
    }
}
