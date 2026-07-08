import XCTest
@testable import Duhaa

/// Verifies the bundled offline transliteration loads and looks up correctly.
final class QuranTransliterationTests: XCTestCase {

    func testBundleIsAvailableAndComplete() {
        let translit = QuranTransliteration.shared
        XCTAssertTrue(translit.isAvailable, "quran_transliteration.json must be bundled")
        XCTAssertEqual(translit.bySurah.count, 114)

        let total = translit.bySurah.values.reduce(0) { $0 + $1.count }
        XCTAssertEqual(total, 6236, "Every ayah should have a transliteration")
    }

    func testKnownLookups() {
        let translit = QuranTransliteration.shared
        // Al-Fatihah 1 — the Basmala.
        XCTAssertEqual(translit.text(surah: 1, ayah: 1), "Bismillaahir Rahmaanir Raheem")
        // Ayat al-Kursi begins with "Allahu".
        XCTAssertTrue(translit.text(surah: 2, ayah: 255)?.hasPrefix("Allahu") == true)
    }

    func testOutOfRangeLookupsAreNil() {
        let translit = QuranTransliteration.shared
        XCTAssertNil(translit.text(surah: 1, ayah: 0))
        XCTAssertNil(translit.text(surah: 1, ayah: 99))
        XCTAssertNil(translit.text(surah: 999, ayah: 1))
    }

    /// Counts line up with the main Quran text, surah by surah.
    func testMatchesQuranAyahCounts() {
        let translit = QuranTransliteration.shared
        for surah in Quran.shared.surahs {
            XCTAssertEqual(translit.bySurah[surah.number]?.count, surah.ayahs.count,
                           "Surah \(surah.number) ayah count should match")
        }
    }
}
