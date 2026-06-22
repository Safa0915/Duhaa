import XCTest
@testable import Duhaa

final class QuranWordTraceTests: XCTestCase {
    func testWordsSkipStandalonePauseMarks() {
        let words = QuranWordTrace.words(in: "فَٱكْتُبُوهُ ۚ وَلْيَكْتُب")

        XCTAssertEqual(words, ["فَٱكْتُبُوهُ", "وَلْيَكْتُب"])
    }

    func testWordsHideDisplayOnlyZeroMarks() {
        let words = QuranWordTrace.words(in: "وَمَا \u{06DF}يَخْدَعُونَ")

        XCTAssertEqual(words, ["وَمَا", "يَخْدَعُونَ"])
    }

    func testActiveWordIndexTracksProgressAndClamps() {
        XCTAssertNil(QuranWordTrace.activeWordIndex(progress: 0.4, wordCount: 0))
        XCTAssertEqual(QuranWordTrace.activeWordIndex(progress: -1, wordCount: 4), 0)
        XCTAssertEqual(QuranWordTrace.activeWordIndex(progress: 0, wordCount: 4), 0)
        XCTAssertEqual(QuranWordTrace.activeWordIndex(progress: 0.26, wordCount: 4), 1)
        XCTAssertEqual(QuranWordTrace.activeWordIndex(progress: 0.99, wordCount: 4), 3)
        XCTAssertEqual(QuranWordTrace.activeWordIndex(progress: 1.5, wordCount: 4), 3)
    }
}
