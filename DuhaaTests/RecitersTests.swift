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

    func testQuranComMediaReciter173IsFullSurahAudio() throws {
        let reciter = try XCTUnwrap(Reciters.byID(173))

        XCTAssertEqual(reciter.name, "Mishary Rashid Alafasy (Classic Recording)")
        XCTAssertFalse(reciter.supportsAyahAudio)
        XCTAssertTrue(reciter.supportsChapterAudio)
        XCTAssertEqual(reciter.chapterURL(surah: 8)?.absoluteString,
                       "https://download.quranicaudio.com/qdc/mishari_al_afasy/streaming/mp3/8.mp3")
    }
}
