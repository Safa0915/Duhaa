import XCTest
@testable import Duhaa

final class QuranArabicTextTests: XCTestCase {
    func testDisplayHidesRoundedZeroButKeepsRealPauseMark() throws {
        let ayah = try XCTUnwrap(Quran.surah(2)?.ayahs.first { $0.number == 5 })

        XCTAssertTrue(ayah.arabic.unicodeScalars.contains(UnicodeScalar(0x06DF)!))
        XCTAssertTrue(ayah.arabic.unicodeScalars.contains(UnicodeScalar(0x06D6)!))

        let display = QuranArabicText.display(ayah.arabic)

        XCTAssertFalse(display.unicodeScalars.contains(UnicodeScalar(0x06DF)!))
        XCTAssertTrue(display.unicodeScalars.contains(UnicodeScalar(0x06D6)!))
    }

    func testDisplayDoesNotChangePlainArabic() {
        let text = "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ"

        XCTAssertEqual(QuranArabicText.display(text), text)
    }

    func testDisplayHidesRoundedZeroInAlBaqarahNine() throws {
        let ayah = try XCTUnwrap(Quran.surah(2)?.ayahs.first { $0.number == 9 })

        XCTAssertTrue(ayah.arabic.unicodeScalars.contains(UnicodeScalar(0x06DF)!))
        XCTAssertFalse(QuranArabicText.display(ayah.arabic).unicodeScalars.contains(UnicodeScalar(0x06DF)!))
    }
}
