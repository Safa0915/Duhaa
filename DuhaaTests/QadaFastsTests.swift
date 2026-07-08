import XCTest
@testable import Duhaa

/// Covers the make-up (qaḍāʾ) fast tracker: setting/owed clamping, logging a
/// make-up, undo, and persistence. Uses an isolated suite per test.
final class QadaFastsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var qada: QadaFasts!

    override func setUp() {
        super.setUp()
        suiteName = "test.qada.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        qada = QadaFasts(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testEmpty() {
        XCTAssertEqual(qada.owed, 0)
        XCTAssertEqual(qada.completed, 0)
        XCTAssertFalse(qada.hasAny)
    }

    func testSetOwedClampsAtZero() {
        qada.setOwed(5)
        XCTAssertEqual(qada.owed, 5)
        qada.setOwed(-3)
        XCTAssertEqual(qada.owed, 0)
    }

    func testLogMakeUpMovesOwedToCompleted() {
        qada.setOwed(3)
        qada.logMakeUp()
        XCTAssertEqual(qada.owed, 2)
        XCTAssertEqual(qada.completed, 1)
    }

    func testLogMakeUpDoesNothingWhenNoneOwed() {
        qada.logMakeUp()
        XCTAssertEqual(qada.owed, 0)
        XCTAssertEqual(qada.completed, 0)
    }

    func testUndoReturnsCompletedToOwed() {
        qada.setOwed(2)
        qada.logMakeUp()
        qada.undoMakeUp()
        XCTAssertEqual(qada.owed, 2)
        XCTAssertEqual(qada.completed, 0)
    }

    func testPersistsAcrossInstances() {
        qada.setOwed(4)
        qada.logMakeUp()
        let reloaded = QadaFasts(defaults: defaults)
        XCTAssertEqual(reloaded.owed, 3)
        XCTAssertEqual(reloaded.completed, 1)
        XCTAssertTrue(reloaded.hasAny)
    }
}
