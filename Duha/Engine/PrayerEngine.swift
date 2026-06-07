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

// MARK: - Result

/// The computed times for one day at one location. All values are absolute
/// `Date` instants — format them in the location's time zone for display.
struct DuhaPrayerTimes: Equatable {
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
                      config: PrayerConfig = PrayerConfig()) -> DuhaPrayerTimes? {

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

        return DuhaPrayerTimes(
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
}
