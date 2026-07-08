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

    func testSurahPageGroupsFollowPageStarts() {
        let index = QuranPageIndex(pages: [
            QuranPageStart(page: 1, surah: 1, ayah: 1),
            QuranPageStart(page: 2, surah: 1, ayah: 3),
            QuranPageStart(page: 3, surah: 2, ayah: 1)
        ])
        let surah = Surah(
            number: 1,
            arabicName: "الفاتحة",
            englishName: "Al-Fatihah",
            translation: "The Opening",
            revelation: "Meccan",
            ayahs: [
                Ayah(number: 1, arabic: "a", english: "one"),
                Ayah(number: 2, arabic: "b", english: "two"),
                Ayah(number: 3, arabic: "c", english: "three")
            ]
        )

        let groups = surah.pageGroups(using: index)

        XCTAssertEqual(groups.map(\.page), [1, 2])
        XCTAssertEqual(groups.map { $0.ayahs.map(\.number) }, [[1, 2], [3]])
        XCTAssertEqual(groups.map(\.isContinuation), [false, false])
    }

    func testSurahPageGroupsMarkOpeningContinuation() {
        let index = QuranPageIndex(pages: [
            QuranPageStart(page: 1, surah: 1, ayah: 1),
            QuranPageStart(page: 2, surah: 2, ayah: 3)
        ])
        let surah = Surah(
            number: 2,
            arabicName: "البقرة",
            englishName: "Al-Baqarah",
            translation: "The Cow",
            revelation: "Medinan",
            ayahs: [
                Ayah(number: 1, arabic: "a", english: "one"),
                Ayah(number: 2, arabic: "b", english: "two"),
                Ayah(number: 3, arabic: "c", english: "three")
            ]
        )

        let groups = surah.pageGroups(using: index)

        XCTAssertEqual(groups.map(\.page), [1, 2])
        XCTAssertEqual(groups.map(\.isContinuation), [true, false])
    }
}
