import XCTest
@testable import Duhaa

/// Guards the bundled du'a content: the JSON keeps decoding (incl. the optional
/// fields), and the curated categories keep their exact card count and order.
final class DuaDataTests: XCTestCase {

    private var afterPrayer: DuaCategory! {
        Duas.categories.first { $0.name == "After Prayer Adhkar" }
    }

    func testAllCategoriesDecode() {
        let names = Duas.categories.map(\.name)
        XCTAssertEqual(names, ["Wudu & Purification", "After Prayer Adhkar",
                               "Morning", "Evening", "Daily Du'as", "Selected"])
    }

    func testWuduCategoryIntact() {
        let wudu = Duas.categories.first { $0.name == "Wudu & Purification" }
        XCTAssertEqual(wudu?.duas.count, 4)
        XCTAssertEqual(wudu?.duas.first?.title, "Before Entering the Bathroom")
    }

    /// The spec's exact order — 8 cards, no splits, Fajr/Maghrib tawhid BEFORE tasbih.
    func testAfterPrayerAdhkarOrder() {
        XCTAssertEqual(afterPrayer.duas.map(\.title), [
            "Istighfar & Allahumma Antas-Salam",
            "Tawhid & Allahumma la mani‘a",
            "Sincere Tawhid Dhikr",
            "Fajr and Maghrib Tawhid Dhikr",
            "Tasbih, Tahmid, and Takbir",
            "Ayat al-Kursi",
            "Al-Ikhlas, Al-Falaq, and An-Nas",
            "Optional Post-Prayer Du‘as",
        ])
    }

    func testEveryCardHasContentAndSource() {
        for dua in afterPrayer.duas {
            XCTAssertFalse(dua.arabic.isEmpty, "\(dua.title): empty arabic")
            XCTAssertFalse(dua.latin.isEmpty, "\(dua.title): empty transliteration")
            XCTAssertFalse(dua.en.isEmpty, "\(dua.title): empty translation")
            XCTAssertFalse(dua.source.isEmpty, "\(dua.title): empty source")
            XCTAssertNil(dua.status, "\(dua.title): no status label per spec")
        }
    }

    func testFajrMaghribDhikrFields() {
        let dhikr = afterPrayer.duas[3]
        XCTAssertEqual(dhikr.count, 10)
        XCTAssertEqual(dhikr.prayerScope, "Fajr & Maghrib")
        XCTAssertNotNil(dhikr.fiqhNote)
    }

    func testTasbihVariationsCollapsedNotSplit() {
        let tasbih = afterPrayer.duas[4]
        XCTAssertEqual(tasbih.variations?.count, 6)
        XCTAssertNotNil(tasbih.countNote)
    }

    /// One card with conditional counts — never split into "once" + "extra" cards.
    func testSurahsAreOneCardWithConditionalCounts() {
        let surahs = afterPrayer.duas[6]
        XCTAssertTrue(surahs.countNote?.contains("3×") == true)
        XCTAssertEqual(afterPrayer.duas.filter { $0.title.contains("Ikhlas") }.count, 1)
    }
}
