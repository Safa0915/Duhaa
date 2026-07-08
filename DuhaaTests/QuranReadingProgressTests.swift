import XCTest
@testable import Duhaa

/// Covers the Quran reading-progress / khatmah store: forward-only recording,
/// per-surah and overall roll-up, completion crediting, reset, and persistence.
/// Uses a tiny synthetic 3-surah mushaf (10 verses total) and an isolated suite.
final class QuranReadingProgressTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var progress: QuranReadingProgress!

    /// 3 surahs of 2 / 3 / 5 ayahs = 10 verses total.
    private let lengths: [Int: Int] = [1: 2, 2: 3, 3: 5]

    override func setUp() {
        super.setUp()
        suiteName = "test.quranprogress.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        progress = QuranReadingProgress(defaults: defaults, surahLengths: lengths)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testEmpty() {
        XCTAssertEqual(progress.versesRead, 0)
        XCTAssertEqual(progress.totalVerses, 10)
        XCTAssertEqual(progress.overallProgress, 0)
        XCTAssertFalse(progress.hasProgress)
        XCTAssertEqual(progress.completedKhatmahs, 0)
    }

    func testRecordAdvancesAndRollsUp() {
        progress.recordRead(surah: 2, ayah: 2)   // 2 of surah 2's 3
        XCTAssertEqual(progress.furthestAyah(surah: 2), 2)
        XCTAssertEqual(progress.versesRead, 2)
        XCTAssertEqual(progress.progress(surah: 2), 2.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(progress.overallProgress, 0.2, accuracy: 0.0001)
        XCTAssertTrue(progress.hasProgress)
    }

    func testRecordIsForwardOnly() {
        progress.recordRead(surah: 3, ayah: 4)
        progress.recordRead(surah: 3, ayah: 2)   // ignored — already past it
        XCTAssertEqual(progress.furthestAyah(surah: 3), 4)
    }

    func testRecordClampsToSurahLength() {
        progress.recordRead(surah: 1, ayah: 99)   // surah 1 only has 2
        XCTAssertEqual(progress.furthestAyah(surah: 1), 2)
        XCTAssertTrue(progress.isComplete(surah: 1))
    }

    func testCompletingWholeMushafCreditsOneKhatmah() {
        progress.recordRead(surah: 1, ayah: 2)
        progress.recordRead(surah: 2, ayah: 3)
        XCTAssertEqual(progress.completedKhatmahs, 0)
        progress.recordRead(surah: 3, ayah: 5)   // now all 10 read
        XCTAssertEqual(progress.overallProgress, 1.0, accuracy: 0.0001)
        XCTAssertEqual(progress.completedKhatmahs, 1)
    }

    func testResetClearsProgressButKeepsKhatmahs() {
        progress.recordRead(surah: 1, ayah: 2)
        progress.recordRead(surah: 2, ayah: 3)
        progress.recordRead(surah: 3, ayah: 5)
        XCTAssertEqual(progress.completedKhatmahs, 1)
        progress.reset()
        XCTAssertEqual(progress.versesRead, 0)
        XCTAssertFalse(progress.hasProgress)
        XCTAssertEqual(progress.completedKhatmahs, 1)   // lifetime count kept
    }

    func testSecondKhatmahCreditsAgainAfterReset() {
        for (s, a) in lengths { progress.recordRead(surah: s, ayah: a) }
        XCTAssertEqual(progress.completedKhatmahs, 1)
        progress.reset()
        for (s, a) in lengths { progress.recordRead(surah: s, ayah: a) }
        XCTAssertEqual(progress.completedKhatmahs, 2)
    }

    func testPersistsAcrossInstances() {
        progress.recordRead(surah: 2, ayah: 2)
        let reloaded = QuranReadingProgress(defaults: defaults, surahLengths: lengths)
        XCTAssertEqual(reloaded.furthestAyah(surah: 2), 2)
        XCTAssertEqual(reloaded.versesRead, 2)
    }
}
