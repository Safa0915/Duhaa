import XCTest
@testable import Duhaa

final class RecitersTests: XCTestCase {
    func testDefaultReciterKeepsAyahAudioURL() throws {
        let reciter = try XCTUnwrap(Reciters.byID(Reciters.defaultID))

        XCTAssertTrue(reciter.supportsAyahAudio)
        XCTAssertFalse(reciter.supportsChapterAudio)
        XCTAssertEqual(reciter.ayahURL(surah: 8, ayah: 1)?.absoluteString,
                       "https://verses.quran.com/Alafasy/mp3/008001.mp3")
    }

    func testFullSurahReciterBuildsZeroPaddedChapterURL() throws {
        let reciter = try XCTUnwrap(Reciters.byID(173))

        XCTAssertEqual(reciter.name, "Mishary Rashid Alafasy (Classic Recording)")
        XCTAssertFalse(reciter.supportsAyahAudio)
        XCTAssertTrue(reciter.supportsChapterAudio)
        // QuranicAudio files are zero-padded to 3 digits (008.mp3, not 8.mp3).
        XCTAssertEqual(reciter.chapterURL(surah: 8)?.absoluteString,
                       "https://download.quranicaudio.com/quran/mishaari_raashid_al_3afaasee/008.mp3")
    }

    func testCatalogHasManyReciters() {
        // A per-ayah default plus the expanded full-surah roster.
        XCTAssertGreaterThan(Reciters.all.count, 20)
        XCTAssertTrue(Reciters.all.contains { $0.name.contains("Maher al-Muaiqly") })
        XCTAssertTrue(Reciters.all.contains { $0.name.contains("Yasser") })
    }

    func testProfilePhotosWhenPresentAreHTTPS() throws {
        XCTAssertFalse(Reciters.all.isEmpty)
        // Photos are optional (the gallery falls back to a monogram), but any that
        // ARE provided must be HTTPS so they load under App Transport Security.
        for reciter in Reciters.all {
            if let url = reciter.imageURL {
                XCTAssertEqual(url.scheme, "https", "\(reciter.name) photo must be HTTPS")
            }
        }
        // The default reciter should always have a photo.
        XCTAssertNotNil(Reciters.byID(Reciters.defaultID)?.imageURL)
    }

    func testMonogramInitialsStripParentheticalsAndUseFirstAndLastWord() throws {
        XCTAssertEqual(Reciters.byID(2)?.initials, "AA")  // AbdulBaset AbdulSamad (Murattal)
        XCTAssertEqual(Reciters.byID(5)?.initials, "HR")  // Hani ar-Rifai
        XCTAssertEqual(Reciters.byID(10)?.initials, "SS") // Sa`ud ash-Shuraym
    }
}
