import XCTest
@testable import Duhaa

final class QuranPageIndexTests: XCTestCase {
    func testLoadsAllMadaniMushafPageStarts() {
        let index = QuranPageIndex.shared

        XCTAssertEqual(index.pages.count, 604)
        XCTAssertEqual(index.pages.first, QuranPageStart(page: 1, surah: 1, ayah: 1))
        XCTAssertEqual(index.pages.last, QuranPageStart(page: 604, surah: 112, ayah: 1))
    }

    func testFindsPageStartsAndContinuationVerses() {
        let index = QuranPageIndex.shared

        XCTAssertEqual(index.pageStartNumber(surah: 2, ayah: 1), 2)
        XCTAssertEqual(index.pageStartNumber(surah: 2, ayah: 6), 3)
        XCTAssertNil(index.pageStartNumber(surah: 2, ayah: 2))
        XCTAssertEqual(index.pageNumber(surah: 2, ayah: 5), 2)
        XCTAssertEqual(index.pageNumber(surah: 2, ayah: 6), 3)
    }

    func testSurahCanBeginMidPage() {
        let index = QuranPageIndex.shared

        XCTAssertNil(index.pageStartNumber(surah: 11, ayah: 1))
        XCTAssertEqual(index.pageNumber(surah: 11, ayah: 1), 221)
        XCTAssertEqual(index.pageStartNumber(surah: 11, ayah: 6), 222)
    }
}
