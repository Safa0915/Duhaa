import XCTest
import Adhan
@testable import Duhaa

/// Slice 1 — proves the Swift engine reproduces the `prayer-verify` Node harness
/// to the minute, for 2026-06-07 (MWL · Shafi · middle-of-the-night). That harness
/// is the oracle (see BUILD_PLAN); regenerate its numbers with
/// `node prayer-verify/verify.js` if you ever change the reference date.
final class PrayerEngineTests: XCTestCase {

    /// The exact calendar day the reference numbers below were captured on.
    private let date = DateComponents(year: 2026, month: 6, day: 7)

    /// Format an instant exactly like the harness: 12-hour, zero-padded, in the
    /// city's IANA time zone (e.g. "04:13 AM").
    private func clock(_ instant: Date, _ timeZone: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: timeZone)
        f.dateFormat = "hh:mm a"
        return f.string(from: instant)
    }

    // MARK: Exact-match cases (the oracle)

    func testMecca() {
        assertCity("Mecca", 21.4225, 39.8262, "Asia/Riyadh",
                   fajr: "04:13 AM", sunrise: "05:38 AM", dhuhr: "12:21 PM", asr: "03:38 PM",
                   maghrib: "07:02 PM", isha: "08:21 PM",
                   islamicMidnight: "11:38 PM", tahajjud: "01:09 AM")
    }

    func testLondon() {
        assertCity("London", 51.5074, -0.1278, "Europe/London",
                   fajr: "01:00 AM", sunrise: "04:45 AM", dhuhr: "01:00 PM", asr: "05:21 PM",
                   maghrib: "09:14 PM", isha: "12:59 AM",
                   islamicMidnight: "11:07 PM", tahajjud: "11:45 PM")
    }

    func testNewYork() {
        assertCity("New York", 40.7128, -74.0060, "America/New_York",
                   fajr: "03:21 AM", sunrise: "05:25 AM", dhuhr: "12:56 PM", asr: "04:55 PM",
                   maghrib: "08:25 PM", isha: "10:20 PM",
                   islamicMidnight: "11:53 PM", tahajjud: "01:02 AM")
    }

    func testJakarta() {
        assertCity("Jakarta", -6.2088, 106.8456, "Asia/Jakarta",
                   fajr: "04:44 AM", sunrise: "05:58 AM", dhuhr: "11:52 AM", asr: "03:13 PM",
                   maghrib: "05:45 PM", isha: "06:55 PM",
                   islamicMidnight: "11:15 PM", tahajjud: "01:04 AM")
    }

    func testKarachi() {
        assertCity("Karachi", 24.8607, 67.0011, "Asia/Karachi",
                   fajr: "04:14 AM", sunrise: "05:42 AM", dhuhr: "12:32 PM", asr: "03:53 PM",
                   maghrib: "07:20 PM", isha: "08:43 PM",
                   islamicMidnight: "11:47 PM", tahajjud: "01:16 AM")
    }

    // MARK: Config behaviour

    /// Hanafi Asr uses a longer shadow, so it always falls later than Shafi.
    func testHanafiAsrIsLaterThanShafi() {
        var hanafi = PrayerConfig()
        hanafi.madhab = .hanafi
        let shafi = PrayerEngine.times(latitude: 21.4225, longitude: 39.8262, date: date)
        let han = PrayerEngine.times(latitude: 21.4225, longitude: 39.8262, date: date, config: hanafi)
        XCTAssertNotNil(shafi)
        XCTAssertNotNil(han)
        XCTAssertGreaterThan(han!.asr, shafi!.asr, "Hanafi Asr should be later than Shafi Asr")
    }

    /// A manual per-prayer offset shifts exactly that prayer by exactly that many minutes.
    func testFajrOffsetShiftsFajrByTenMinutes() {
        var plus10 = PrayerConfig()
        plus10.offsets.fajr = 10
        let base = PrayerEngine.times(latitude: 51.5074, longitude: -0.1278, date: date)!
        let bumped = PrayerEngine.times(latitude: 51.5074, longitude: -0.1278, date: date, config: plus10)!
        XCTAssertEqual(bumped.fajr.timeIntervalSince(base.fajr), 600, accuracy: 1,
                       "Fajr +10 min should move it 600 seconds")
    }

    /// Graceful high-latitude handling: London in June has Isha *after* Islamic
    /// midnight; Mecca never does. The engine surfaces this rather than breaking.
    func testHighLatitudeIshaAfterMidnightFlag() {
        let london = PrayerEngine.times(latitude: 51.5074, longitude: -0.1278, date: date)!
        let mecca = PrayerEngine.times(latitude: 21.4225, longitude: 39.8262, date: date)!
        XCTAssertTrue(london.ishaAfterIslamicMidnight,
                      "London (June) should flag Isha falling after Islamic midnight")
        XCTAssertFalse(mecca.ishaAfterIslamicMidnight, "Mecca should not")
    }

    // MARK: Manual override

    /// When manual mode is on, the engine returns the user's exact wall-clock times
    /// (in the location's zone) and ignores calculation entirely.
    func testManualTimesAreReturnedVerbatim() {
        var config = PrayerConfig()
        config.manual.enabled = true
        config.manual.fajr = 5 * 60 + 12      // 5:12 AM
        config.manual.sunrise = 6 * 60 + 34
        config.manual.dhuhr = 13 * 60 + 5      // 1:05 PM
        config.manual.asr = 16 * 60 + 45
        config.manual.maghrib = 19 * 60 + 58
        config.manual.isha = 21 * 60 + 30      // 9:30 PM

        let tz = "America/New_York"
        let t = PrayerEngine.times(latitude: 40.7128, longitude: -74.0060,
                                   date: date, config: config,
                                   timeZone: TimeZone(identifier: tz)!)!

        XCTAssertEqual(clock(t.fajr, tz), "05:12 AM")
        XCTAssertEqual(clock(t.sunrise, tz), "06:34 AM")
        XCTAssertEqual(clock(t.dhuhr, tz), "01:05 PM")
        XCTAssertEqual(clock(t.asr, tz), "04:45 PM")
        XCTAssertEqual(clock(t.maghrib, tz), "07:58 PM")
        XCTAssertEqual(clock(t.isha, tz), "09:30 PM")
    }

    /// Manual times ignore the calculation method — same input, different method,
    /// identical result.
    func testManualTimesIgnoreCalculationMethod() {
        var a = PrayerConfig(); a.manual.enabled = true; a.method = .ummAlQura
        var b = PrayerConfig(); b.manual.enabled = true; b.method = .karachi
        b.manual = a.manual   // same timetable, different method

        let tz = TimeZone(identifier: "Asia/Riyadh")!
        let ta = PrayerEngine.times(latitude: 21.4225, longitude: 39.8262, date: date, config: a, timeZone: tz)!
        let tb = PrayerEngine.times(latitude: 21.4225, longitude: 39.8262, date: date, config: b, timeZone: tz)!
        XCTAssertEqual(ta.fajr, tb.fajr)
        XCTAssertEqual(ta.isha, tb.isha)
    }

    /// Islamic midnight sits between Maghrib and the next day's Fajr, derived the
    /// same way as the calculated path, so the night cards stay coherent.
    func testManualIslamicMidnightDerivesFromMaghribAndNextFajr() {
        var config = PrayerConfig()
        config.manual.enabled = true
        config.manual.maghrib = 19 * 60       // 7:00 PM
        config.manual.fajr = 5 * 60           // 5:00 AM → night = 10h, midnight at 12:00 AM

        let tz = TimeZone(identifier: "America/New_York")!
        let t = PrayerEngine.times(latitude: 40.7128, longitude: -74.0060, date: date, config: config, timeZone: tz)!

        XCTAssertGreaterThan(t.islamicMidnight, t.maghrib)
        XCTAssertEqual(clock(t.islamicMidnight, "America/New_York"), "12:00 AM")
        XCTAssertEqual(clock(t.tahajjud, "America/New_York"), "01:40 AM")  // Maghrib + 2/3 night
    }

    /// A bare config calculates as before — manual mode is off by default, so the
    /// existing oracle numbers (and the verify harness) are untouched.
    func testManualDefaultsOffSoCalculationIsUnchanged() {
        XCTAssertFalse(PrayerConfig().manual.enabled)
    }

    // MARK: Helper

    private func assertCity(_ name: String, _ lat: Double, _ lng: Double, _ tz: String,
                            fajr: String, sunrise: String, dhuhr: String, asr: String,
                            maghrib: String, isha: String, islamicMidnight: String, tahajjud: String,
                            file: StaticString = #filePath, line: UInt = #line) {
        guard let t = PrayerEngine.times(latitude: lat, longitude: lng, date: date) else {
            return XCTFail("\(name): engine returned nil", file: file, line: line)
        }
        XCTAssertEqual(clock(t.fajr, tz), fajr, "\(name) Fajr", file: file, line: line)
        XCTAssertEqual(clock(t.sunrise, tz), sunrise, "\(name) Sunrise", file: file, line: line)
        XCTAssertEqual(clock(t.dhuhr, tz), dhuhr, "\(name) Dhuhr", file: file, line: line)
        XCTAssertEqual(clock(t.asr, tz), asr, "\(name) Asr", file: file, line: line)
        XCTAssertEqual(clock(t.maghrib, tz), maghrib, "\(name) Maghrib", file: file, line: line)
        XCTAssertEqual(clock(t.isha, tz), isha, "\(name) Isha", file: file, line: line)
        XCTAssertEqual(clock(t.islamicMidnight, tz), islamicMidnight, "\(name) Islamic midnight", file: file, line: line)
        XCTAssertEqual(clock(t.tahajjud, tz), tahajjud, "\(name) Tahajjud", file: file, line: line)
    }
}
