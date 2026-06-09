import XCTest
@testable import Duhaa

/// Covers the opt-in prayer-insights tally: on-time vs late, missed days, the
/// today-excluded and excused-excluded rules, and percentage math.
final class InsightsTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var tracker: PrayerTracker!

    override func setUp() {
        super.setUp()
        suiteName = "test.insights.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        tracker = PrayerTracker(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// Day index matching PrayerTracker's internal UTC-based scheme.
    private func dayNum(_ key: String) -> Int {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return Int((f.date(from: key)!.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    /// Builds a representative 3-day window: a perfect day, a partial day with one
    /// late prayer, and a fully-missed day.
    private func seedThreeDays() {
        // Day 1 — all five, on time.
        for p in Prayer.allCases { tracker.toggle(p, dayKey: "2026-01-01", onTime: true) }
        // Day 2 — Fajr/Dhuhr on time, Asr late, Maghrib & Isha missed.
        tracker.toggle(.fajr, dayKey: "2026-01-02", onTime: true)
        tracker.toggle(.dhuhr, dayKey: "2026-01-02", onTime: true)
        tracker.toggle(.asr, dayKey: "2026-01-02", onTime: false)
        // Day 3 — nothing.
    }

    func testOnTimeLateMissedTally() {
        seedThreeDays()
        let d = tracker.insights(startDay: "2026-01-01", todayKey: "2026-01-04")
        XCTAssertEqual(d.onTime, 7)   // 5 + 2
        XCTAssertEqual(d.late, 1)     // Asr on day 2
        XCTAssertEqual(d.missed, 7)   // 2 (day 2) + 5 (day 3)
        XCTAssertEqual(d.total, 15)   // 3 completed days × 5
    }

    func testTodayIsNeverJudged() {
        seedThreeDays()
        // Mark some prayers "today" — they must not enter the tally.
        tracker.toggle(.fajr, dayKey: "2026-01-04", onTime: true)
        let d = tracker.insights(startDay: "2026-01-01", todayKey: "2026-01-04")
        XCTAssertEqual(d.total, 15)   // still only the three completed days
        XCTAssertEqual(d.onTime, 7)
    }

    func testExcusedDaysSkipped() {
        seedThreeDays()
        let d = tracker.insights(startDay: "2026-01-01", todayKey: "2026-01-04",
                                 excused: [dayNum("2026-01-02")])
        // Day 2 dropped entirely: 2 completed days remain (day 1 perfect, day 3 missed).
        XCTAssertEqual(d.total, 10)
        XCTAssertEqual(d.onTime, 5)
        XCTAssertEqual(d.late, 0)
        XCTAssertEqual(d.missed, 5)
    }

    func testNoCompletedDaysHasNoData() {
        seedThreeDays()
        // Window starts today → nothing completed yet.
        let d = tracker.insights(startDay: "2026-01-04", todayKey: "2026-01-04")
        XCTAssertFalse(d.hasData)
        XCTAssertEqual(d.total, 0)
    }

    func testUnmarkClearsLateness() {
        tracker.toggle(.asr, dayKey: "2026-01-02", onTime: false)   // late
        tracker.toggle(.asr, dayKey: "2026-01-02", onTime: false)   // unmark
        let d = tracker.insights(startDay: "2026-01-01", todayKey: "2026-01-04")
        XCTAssertEqual(d.late, 0)
        XCTAssertEqual(d.onTime, 0)
        XCTAssertEqual(d.missed, 15)   // all completed slots now missed
    }

    func testPercentagesSumTo100() {
        seedThreeDays()
        let d = tracker.insights(startDay: "2026-01-01", todayKey: "2026-01-04")
        XCTAssertEqual(d.onTimePct + d.latePct + d.missedPct, 100)
    }

    func testLatenessPersistsAcrossInstances() {
        tracker.toggle(.asr, dayKey: "2026-01-02", onTime: false)
        let reloaded = PrayerTracker(defaults: defaults)
        let d = reloaded.insights(startDay: "2026-01-01", todayKey: "2026-01-04")
        XCTAssertEqual(d.late, 1)
    }
}
