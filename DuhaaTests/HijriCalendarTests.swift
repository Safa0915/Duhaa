import XCTest
@testable import Duhaa

/// Covers the shared Umm al-Qura Hijri helpers: components, formatting, the
/// moon-sighting offset, and the white-day (Ayyām al-Bīḍ) detection used by the
/// voluntary-fasting feature.
final class HijriCalendarTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!

    private func date(_ s: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = utc
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)!
    }

    /// 2026-05-29 is 12 Dhuʼl-Hijjah 1447 in Foundation's Umm al-Qura calendar.
    func testComponentsAreUmmAlQura() {
        let comps = HijriCalendar.components(date("2026-05-29"), timeZone: utc, offsetDays: 0)
        XCTAssertEqual(comps.day, 12)
        XCTAssertEqual(comps.month, 12)      // Dhuʼl-Hijjah
        XCTAssertEqual(comps.year, 1447)
    }

    func testOffsetShiftsTheDay() {
        let plus = HijriCalendar.components(date("2026-05-29"), timeZone: utc, offsetDays: 1)
        XCTAssertEqual(plus.day, 13)
        let minus = HijriCalendar.components(date("2026-05-29"), timeZone: utc, offsetDays: -1)
        XCTAssertEqual(minus.day, 11)
    }

    func testWhiteDays() {
        // The 13th/14th/15th are white days; the 12th and 16th are not.
        XCTAssertFalse(HijriCalendar.isWhiteDay(date("2026-05-29"), timeZone: utc, offsetDays: 0)) // 12th
        XCTAssertTrue(HijriCalendar.isWhiteDay(date("2026-05-30"), timeZone: utc, offsetDays: 0))  // 13th
        XCTAssertTrue(HijriCalendar.isWhiteDay(date("2026-05-31"), timeZone: utc, offsetDays: 0))  // 14th
        XCTAssertTrue(HijriCalendar.isWhiteDay(date("2026-06-01"), timeZone: utc, offsetDays: 0))  // 15th
        XCTAssertFalse(HijriCalendar.isWhiteDay(date("2026-06-02"), timeZone: utc, offsetDays: 0)) // 16th
    }

    func testStringContainsDayAndYear() {
        let s = HijriCalendar.string(date("2026-05-29"), timeZone: utc, offsetDays: 0)
        XCTAssertTrue(s.contains("12"))
        XCTAssertTrue(s.contains("1447"))
    }
}
