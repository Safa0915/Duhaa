import XCTest
@testable import Duhaa

/// Covers the "hope, not guilt" tracking math: totals, streaks, the grace for a
/// not-yet-started today, and the crucial menses-excused bridging (spec §5 + the
/// Sisters integration). Uses an isolated UserDefaults suite per test.
final class PrayerTrackerTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var tracker: PrayerTracker!
    private let utc = TimeZone(identifier: "UTC")!

    override func setUp() {
        super.setUp()
        suiteName = "test.tracker.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        tracker = PrayerTracker(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: Helpers

    /// Noon-UTC date for a "yyyy-MM-dd" string.
    private func date(_ s: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = utc
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: "\(s) 12:00")!
    }

    /// The day-index (matches PrayerTracker/CycleTracker) for a key.
    private func dayNum(_ s: String) -> Int { CycleTracker.dayNumber(s)! }

    /// Mark `n` prayers on a day (Fajr first).
    private func mark(_ n: Int, on key: String) {
        for p in Array(Prayer.allCases.prefix(n)) { tracker.toggle(p, dayKey: key) }
    }

    // MARK: Totals

    func testEmptyHasNoStats() {
        XCTAssertEqual(tracker.totalPrayed(), 0)
        XCTAssertEqual(tracker.daysShownUp(), 0)
        XCTAssertEqual(tracker.perfectDays(), 0)
        XCTAssertEqual(tracker.currentStreak(asOf: date("2026-06-08"), timeZone: utc), 0)
        XCTAssertEqual(tracker.bestStreak(), 0)
    }

    func testTotalsAndPerfectDay() {
        mark(3, on: "2026-06-01")          // 3 prayers
        mark(5, on: "2026-06-02")          // a full day
        XCTAssertEqual(tracker.totalPrayed(), 8)
        XCTAssertEqual(tracker.daysShownUp(), 2)
        XCTAssertEqual(tracker.perfectDays(), 1)
    }

    func testTogglingOffDecrements() {
        tracker.toggle(.fajr, dayKey: "2026-06-01")
        tracker.toggle(.fajr, dayKey: "2026-06-01")   // unmark
        XCTAssertEqual(tracker.totalPrayed(), 0)
        XCTAssertEqual(tracker.daysShownUp(), 0)
    }

    // MARK: Streaks

    func testCurrentStreakCountsConsecutiveDays() {
        mark(1, on: "2026-06-06")
        mark(1, on: "2026-06-07")
        mark(2, on: "2026-06-08")
        XCTAssertEqual(tracker.currentStreak(asOf: date("2026-06-08"), timeZone: utc), 3)
    }

    func testTodayNotStartedKeepsStreakViaGrace() {
        // Prayed through yesterday; today not yet logged should NOT break the streak.
        mark(2, on: "2026-06-06")
        mark(2, on: "2026-06-07")
        XCTAssertEqual(tracker.currentStreak(asOf: date("2026-06-08"), timeZone: utc), 2)
    }

    func testGapBreaksStreak() {
        mark(1, on: "2026-06-04")
        // 06-05 missed (not excused)
        mark(1, on: "2026-06-06")
        mark(1, on: "2026-06-07")
        XCTAssertEqual(tracker.currentStreak(asOf: date("2026-06-07"), timeZone: utc), 2)
    }

    func testBestStreakIsLongestRunEver() {
        // A 3-run, a gap, then a 2-run.
        mark(1, on: "2026-05-01"); mark(1, on: "2026-05-02"); mark(1, on: "2026-05-03")
        mark(1, on: "2026-05-10"); mark(1, on: "2026-05-11")
        XCTAssertEqual(tracker.bestStreak(), 3)
    }

    // MARK: The menses-excused bridge (the Sisters integration)

    func testExcusedDaysBridgeTheStreak() {
        // Prayed 01-03, then excused 04-08 (incl. today). Streak must stay 3, not reset.
        mark(2, on: "2026-06-01")
        mark(2, on: "2026-06-02")
        mark(2, on: "2026-06-03")
        let excused = Set((4...8).map { dayNum("2026-06-0\($0)") })
        let streak = tracker.currentStreak(asOf: date("2026-06-08"), timeZone: utc, excused: excused)
        XCTAssertEqual(streak, 3, "Excused (menses) days must not break the streak")
    }

    func testExcusedDaysDoNotInflateTheStreak() {
        // Only excused days, no prayers → streak is 0 (excused days never count as prayed).
        let excused = Set((1...8).map { dayNum("2026-06-0\($0)") })
        XCTAssertEqual(tracker.currentStreak(asOf: date("2026-06-08"), timeZone: utc, excused: excused), 0)
    }

    func testBestStreakBridgesExcused() {
        // 01-02 prayed, 03-05 excused, 06-07 prayed → one continuous best run of 4 prayed days.
        mark(1, on: "2026-06-01"); mark(1, on: "2026-06-02")
        mark(1, on: "2026-06-06"); mark(1, on: "2026-06-07")
        let excused = Set((3...5).map { dayNum("2026-06-0\($0)") })
        XCTAssertEqual(tracker.bestStreak(excused: excused), 4)
    }

    // MARK: Persistence

    func testMarksPersistAcrossInstances() {
        mark(3, on: "2026-06-01")
        let reloaded = PrayerTracker(defaults: defaults)
        XCTAssertEqual(reloaded.count(dayKey: "2026-06-01"), 3)
    }
}
