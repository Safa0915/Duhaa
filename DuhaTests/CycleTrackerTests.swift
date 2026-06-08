import XCTest
@testable import Duha

/// Covers the private cycle logging + the excused-day math it feeds to the streak.
final class CycleTrackerTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var cycle: CycleTracker!

    override func setUp() {
        super.setUp()
        suiteName = "test.cycle.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        cycle = CycleTracker(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func dayNum(_ s: String) -> Int { CycleTracker.dayNumber(s)! }

    // MARK: Logging

    func testStartBeginsAnOngoingPeriod() {
        cycle.startPeriod(today: "2026-06-04")
        XCTAssertTrue(cycle.isOnPeriod)
        XCTAssertEqual(cycle.ongoing?.start, "2026-06-04")
        XCTAssertEqual(cycle.entries.count, 1)
    }

    func testStartIsNoOpWhileOngoing() {
        cycle.startPeriod(today: "2026-06-04")
        cycle.startPeriod(today: "2026-06-05")   // already ongoing → ignored
        XCTAssertEqual(cycle.entries.count, 1)
        XCTAssertEqual(cycle.ongoing?.start, "2026-06-04")
    }

    func testStartGuardsAgainstDuplicateDay() {
        cycle.startPeriod(today: "2026-06-04")
        cycle.endPeriod(today: "2026-06-04")
        cycle.startPeriod(today: "2026-06-04")   // same day already logged → ignored
        XCTAssertEqual(cycle.entries.count, 1)
    }

    func testEndClosesTheOngoingPeriod() {
        cycle.startPeriod(today: "2026-06-04")
        cycle.endPeriod(today: "2026-06-07")
        XCTAssertFalse(cycle.isOnPeriod)
        XCTAssertEqual(cycle.entries.first?.end, "2026-06-07")
    }

    func testEndCannotPredateStart() {
        cycle.startPeriod(today: "2026-06-04")
        cycle.endPeriod(today: "2026-06-02")     // before start → clamped to start
        XCTAssertEqual(cycle.entries.first?.end, "2026-06-04")
    }

    func testDeleteRemovesEntry() {
        cycle.startPeriod(today: "2026-06-04")
        cycle.endPeriod(today: "2026-06-06")
        cycle.delete(cycle.entries[0])
        XCTAssertTrue(cycle.entries.isEmpty)
    }

    // MARK: Excused days (feeds the streak bridge)

    func testExcusedDaysCoverClosedSpan() {
        cycle.startPeriod(today: "2026-06-04")
        cycle.endPeriod(today: "2026-06-07")
        let excused = cycle.excusedDayNumbers(today: "2026-06-10")
        XCTAssertEqual(excused, Set((4...7).map { dayNum("2026-06-0\($0)") }))
    }

    func testOngoingSpanExtendsThroughToday() {
        cycle.startPeriod(today: "2026-06-04")   // no end → ongoing
        let excused = cycle.excusedDayNumbers(today: "2026-06-06")
        XCTAssertEqual(excused, Set([dayNum("2026-06-04"), dayNum("2026-06-05"), dayNum("2026-06-06")]))
    }

    // MARK: Prediction

    func testPredictionFromHistory() {
        // Two starts 28 days apart → average 28, next ≈ last + 28.
        cycle.startPeriod(today: "2026-05-01"); cycle.endPeriod(today: "2026-05-05")
        cycle.startPeriod(today: "2026-05-29")
        XCTAssertEqual(cycle.averageCycleLength, 28)
        XCTAssertEqual(cycle.predictedNextStart(), "2026-06-26")
    }

    func testNoPredictionWithoutEnoughHistory() {
        cycle.startPeriod(today: "2026-05-01")
        XCTAssertNil(cycle.averageCycleLength)
        XCTAssertNil(cycle.predictedNextStart())
    }

    // MARK: Persistence

    func testEntriesPersistAcrossInstances() {
        cycle.startPeriod(today: "2026-06-04")
        cycle.endPeriod(today: "2026-06-07")
        let reloaded = CycleTracker(defaults: defaults)
        XCTAssertEqual(reloaded.entries.count, 1)
        XCTAssertEqual(reloaded.entries.first?.start, "2026-06-04")
    }
}
