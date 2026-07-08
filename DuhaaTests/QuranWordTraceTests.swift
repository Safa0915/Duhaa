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

    func testWordRangesSubstringsMatchWords() {
        let raw = "فَٱكْتُبُوهُ ۚ وَلْيَكْتُب"
        let layout = QuranWordTrace.wordRanges(in: raw)
        let fromRanges = layout.ranges.map { String(layout.display[$0]) }

        XCTAssertEqual(fromRanges, QuranWordTrace.words(in: raw))
        XCTAssertEqual(fromRanges, ["فَٱكْتُبُوهُ", "وَلْيَكْتُب"])
    }

    func testWordRangesSkipStandalonePauseMarks() {
        let layout = QuranWordTrace.wordRanges(in: "فَٱكْتُبُوهُ ۚ وَلْيَكْتُب")
        // The standalone pause mark is not a word, so only two ranges exist…
        XCTAssertEqual(layout.ranges.count, 2)
        // …and none of them is the lone pause mark.
        XCTAssertFalse(layout.ranges.contains { String(layout.display[$0]) == "ۚ" })
    }

    func testWordRangesAreValidAgainstReturnedDisplay() {
        let layout = QuranWordTrace.wordRanges(in: "وَمَا \u{06DF}يَخْدَعُونَ")
        // Display hides the zero mark; ranges must index that exact string.
        XCTAssertEqual(layout.display, QuranArabicText.display("وَمَا \u{06DF}يَخْدَعُونَ"))
        for range in layout.ranges {
            XCTAssertGreaterThanOrEqual(range.lowerBound, layout.display.startIndex)
            XCTAssertLessThanOrEqual(range.upperBound, layout.display.endIndex)
        }
        XCTAssertEqual(layout.ranges.map { String(layout.display[$0]) }, ["وَمَا", "يَخْدَعُونَ"])
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
