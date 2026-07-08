import XCTest
@testable import Duhaa

/// Covers the private per-surah reflection store: save, blank-clears, persistence,
/// and the stable reflection-prompt selection.
final class QuranNotesTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var notes: QuranNotes!

    override func setUp() {
        super.setUp()
        suiteName = "test.qurannotes.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        notes = QuranNotes(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testEmpty() {
        XCTAssertEqual(notes.note(forSurah: 1), "")
        XCTAssertFalse(notes.hasNote(forSurah: 1))
        XCTAssertTrue(notes.surahsWithNotes.isEmpty)
    }

    func testSaveAndRead() {
        notes.setNote("Mercy throughout.", forSurah: 1)
        XCTAssertEqual(notes.note(forSurah: 1), "Mercy throughout.")
        XCTAssertTrue(notes.hasNote(forSurah: 1))
        XCTAssertEqual(notes.surahsWithNotes, [1])
    }

    func testBlankClearsNote() {
        notes.setNote("temp", forSurah: 2)
        XCTAssertTrue(notes.hasNote(forSurah: 2))
        notes.setNote("   \n ", forSurah: 2)
        XCTAssertFalse(notes.hasNote(forSurah: 2))
        XCTAssertTrue(notes.surahsWithNotes.isEmpty)
    }

    func testPersistsAcrossInstances() {
        notes.setNote("Reflection for 36.", forSurah: 36)
        let reloaded = QuranNotes(defaults: defaults)
        XCTAssertEqual(reloaded.note(forSurah: 36), "Reflection for 36.")
    }

    func testReflectionPromptIsStablePerSurah() {
        XCTAssertEqual(ReflectionPrompt.forSurah(1), ReflectionPrompt.forSurah(1))
        XCTAssertFalse(ReflectionPrompt.forSurah(1).isEmpty)
    }
}
