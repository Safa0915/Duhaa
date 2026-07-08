import XCTest
@testable import Duhaa

/// Covers the recommended voluntary-fast detection: Mondays, Thursdays, and the
/// Hijri white days (Ayyām al-Bīḍ), plus the upcoming-days roll-up.
final class VoluntaryFastTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!

    private func date(_ s: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = utc
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)!
    }

    func testMonday() {
        // 2026-06-29 is a Monday.
        let kinds = VoluntaryFast.kinds(for: date("2026-06-29"), timeZone: utc, hijriOffsetDays: 0)
        XCTAssertTrue(kinds.contains(.monday))
        XCTAssertTrue(VoluntaryFast.isRecommended(date("2026-06-29"), timeZone: utc, hijriOffsetDays: 0))
    }

    func testThursday() {
        // 2026-07-02 is a Thursday.
        let kinds = VoluntaryFast.kinds(for: date("2026-07-02"), timeZone: utc, hijriOffsetDays: 0)
        XCTAssertTrue(kinds.contains(.thursday))
    }

    func testOrdinaryDayIsNotRecommended() {
        // 2026-06-10 is a Wednesday and 24 Dhuʼl-Hijjah — neither Mon/Thu nor a white day.
        XCTAssertFalse(VoluntaryFast.isRecommended(date("2026-06-10"), timeZone: utc, hijriOffsetDays: 0))
    }

    func testWhiteDay() {
        // 2026-05-30 is 13 Dhuʼl-Hijjah 1447 — a white day.
        let kinds = VoluntaryFast.kinds(for: date("2026-05-30"), timeZone: utc, hijriOffsetDays: 0)
        XCTAssertTrue(kinds.contains(.whiteDay))
    }

    func testUpcomingFindsRecommendedDays() {
        // Two weeks from a Tuesday should include the coming Thursday & Monday.
        let upcoming = VoluntaryFast.upcoming(from: date("2026-06-30"), days: 14,
                                              timeZone: utc, hijriOffsetDays: 0)
        XCTAssertFalse(upcoming.isEmpty)
        XCTAssertTrue(upcoming.allSatisfy { !$0.kinds.isEmpty })
        // Every returned day key parses and is unique.
        XCTAssertEqual(Set(upcoming.map(\.dayKey)).count, upcoming.count)
    }
}
