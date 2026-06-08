import XCTest
@testable import Duhaa

/// Covers the Ramadan fasting log: toggling, totals, the Hijri-month count, and
/// persistence. Uses an isolated UserDefaults suite per test.
final class FastingTrackerTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var fasting: FastingTracker!
    private let utc = TimeZone(identifier: "UTC")!

    override func setUp() {
        super.setUp()
        suiteName = "test.fasting.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        fasting = FastingTracker(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testEmpty() {
        XCTAssertEqual(fasting.total, 0)
        XCTAssertFalse(fasting.isFasted("2026-03-01"))
    }

    func testToggleOnAndOff() {
        XCTAssertTrue(fasting.toggle("2026-03-01"))     // now fasted
        XCTAssertTrue(fasting.isFasted("2026-03-01"))
        XCTAssertEqual(fasting.total, 1)
        XCTAssertFalse(fasting.toggle("2026-03-01"))    // unmarked
        XCTAssertEqual(fasting.total, 0)
    }

    func testHijriMonthCount() {
        // Log two days; count only those whose Hijri month/year matches that day's.
        let key = "2026-03-01"
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.timeZone = utc
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = utc; f.dateFormat = "yyyy-MM-dd"
        let comps = cal.dateComponents([.year, .month], from: f.date(from: key)!)

        fasting.toggle(key)
        XCTAssertEqual(fasting.count(hijriMonth: comps.month!, hijriYear: comps.year!,
                                     offsetDays: 0, timeZone: utc), 1)
        // A different Hijri month yields zero.
        let otherMonth = (comps.month! % 12) + 1
        XCTAssertEqual(fasting.count(hijriMonth: otherMonth, hijriYear: comps.year!,
                                     offsetDays: 0, timeZone: utc), 0)
    }

    func testPersistsAcrossInstances() {
        fasting.toggle("2026-03-01")
        fasting.toggle("2026-03-02")
        let reloaded = FastingTracker(defaults: defaults)
        XCTAssertEqual(reloaded.total, 2)
        XCTAssertTrue(reloaded.isFasted("2026-03-02"))
    }
}
