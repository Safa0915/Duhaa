import XCTest
@testable import Duhaa

/// Verse of the Day → reader navigation. The card/sheet must hand the reader a
/// concrete surah *and* ayah (never surah-only), and every curated verse must
/// resolve to a real ayah so the jump-to-verse + highlight has a valid target.
final class VerseOfDayTests: XCTestCase {

    // 1. The tap carries both surah and ayah (structured data, not a display string).
    func testVerseRefCarriesSurahAndAyah() {
        let ref = VerseRef(surah: 2, ayah: 255)
        XCTAssertEqual(ref.surah, 2)
        XCTAssertEqual(ref.ayah, 255)
        XCTAssertEqual(ref.id, "2:255")
    }

    // 2. Today's verse is a real, locatable ayah — i.e. the reader can identify the
    //    exact target verse by its (surah, ayah) id.
    func testTodayResolvesToARealAyah() throws {
        let ref = VerseOfDay.today()
        let surah = try XCTUnwrap(Quran.surah(ref.surah), "Verse-of-day surah \(ref.surah) missing")
        let ayah = surah.ayahs.first { $0.number == ref.ayah }
        XCTAssertNotNil(ayah, "Verse-of-day \(ref.id) has no matching ayah")
        XCTAssertFalse(ayah?.arabic.isEmpty ?? true)
    }

    // 3. EVERY curated verse must exist — guards against a typo'd surah/ayah that
    //    would otherwise silently fail to jump.
    func testAllCuratedVersesExist() {
        for ref in VerseOfDay.verses {
            let surah = Quran.surah(ref.surah)
            XCTAssertNotNil(surah, "Curated verse references missing surah \(ref.surah)")
            let ayah = surah?.ayahs.first { $0.number == ref.ayah }
            XCTAssertNotNil(ayah, "Curated verse \(ref.id) references a non-existent ayah")
        }
    }

    // 4. Invalid ayah fails gracefully at the data layer (the reader shows a quiet
    //    "Couldn't jump" message rather than crashing).
    func testInvalidAyahIsSimplyNotFound() throws {
        let surah = try XCTUnwrap(Quran.surah(1)) // Al-Fatihah, 7 ayahs
        XCTAssertNil(surah.ayahs.first { $0.number == 999 })
    }

    // 5. today() is deterministic per calendar day and always in range.
    func testTodayIsDeterministicAndInRange() {
        let date = Date(timeIntervalSince1970: 1_750_000_000)
        XCTAssertEqual(VerseOfDay.today(date), VerseOfDay.today(date))
        let ref = VerseOfDay.today(date)
        XCTAssertTrue(VerseOfDay.verses.contains(ref))
    }

    // 6. The Daily Reflection widget snapshot carries a renderable verse stamp.
    func testSnapshotSampleCarriesVerseStamp() throws {
        let verse = try XCTUnwrap(PrayerWidgetSnapshot.sample().dailyVerse)
        XCTAssertFalse(verse.arabic.isEmpty)
        XCTAssertFalse(verse.en.isEmpty)
        XCTAssertEqual(verse.reference, "\(verse.surah):\(verse.ayah)")
        XCTAssertEqual(verse.citation, "\(verse.surahName) · \(verse.reference)")
    }
}
