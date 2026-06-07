import XCTest
import Foundation
@testable import Duha

/// DST regression tests (spec §8): prayer times must always format in the
/// location's IANA time zone, never a fixed offset — so the displayed times
/// shift by an hour across the spring-forward and fall-back transitions.
final class DSTTests: XCTestCase {
    private let lat = 51.5074, lng = -0.1278   // London (~0° longitude)
    private let timeZone = "Europe/London"

    /// The displayed hour of Dhuhr (solar noon) in London local time.
    private func dhuhrHour(_ date: DateComponents) -> Int {
        let times = PrayerEngine.times(latitude: lat, longitude: lng, date: date)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        return calendar.component(.hour, from: times.dhuhr)
    }

    func testLondonDhuhrIsGMTInWinter() {
        // Solar noon ≈ 12:00 UTC; in January (GMT) it displays at ~12:xx.
        XCTAssertEqual(dhuhrHour(DateComponents(year: 2026, month: 1, day: 15)), 12)
    }

    func testLondonDhuhrIsBSTInSummer() {
        // In June (BST = UTC+1) the same solar noon displays at ~13:xx.
        XCTAssertEqual(dhuhrHour(DateComponents(year: 2026, month: 6, day: 7)), 13)
    }

    func testSpringForwardShiftsDisplayedTimeUpAnHour() {
        // UK clocks go forward on 29 Mar 2026 (GMT → BST).
        let before = dhuhrHour(DateComponents(year: 2026, month: 3, day: 28))
        let after  = dhuhrHour(DateComponents(year: 2026, month: 3, day: 30))
        XCTAssertEqual(after - before, 1, "Displayed Dhuhr should jump +1h across spring-forward")
    }

    func testFallBackShiftsDisplayedTimeDownAnHour() {
        // UK clocks go back on 25 Oct 2026 (BST → GMT).
        let before = dhuhrHour(DateComponents(year: 2026, month: 10, day: 24))
        let after  = dhuhrHour(DateComponents(year: 2026, month: 10, day: 26))
        XCTAssertEqual(after - before, -1, "Displayed Dhuhr should drop 1h across fall-back")
    }

    func testTransitionDaysStillProduceTimes() {
        for day in [DateComponents(year: 2026, month: 3, day: 29),
                    DateComponents(year: 2026, month: 10, day: 25)] {
            XCTAssertNotNil(PrayerEngine.times(latitude: lat, longitude: lng, date: day),
                            "Engine should produce times on the DST transition day itself")
        }
    }
}
