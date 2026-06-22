import XCTest
@testable import Duhaa

@MainActor
final class QuranOfflineLibraryTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "QuranOfflineLibraryTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testNewLibraryReportsNothingDownloaded() {
        let library = QuranOfflineLibrary(defaults: defaults)
        XCTAssertEqual(library.state(surah: 1, reciterID: 7), .notDownloaded)
        XCTAssertFalse(library.isDownloaded(surah: 1, reciterID: 7))
    }

    func testLibraryLoadsDownloadedSetFromDefaults() {
        defaults.set(["7:1", "7:2"], forKey: "duhaa.quran.offline.surahs")
        let library = QuranOfflineLibrary(defaults: defaults)

        XCTAssertTrue(library.isDownloaded(surah: 1, reciterID: 7))
        XCTAssertTrue(library.isDownloaded(surah: 2, reciterID: 7))
        XCTAssertFalse(library.isDownloaded(surah: 3, reciterID: 7))
    }

    func testRemoveClearsDownloadedStateAndPersistence() throws {
        defaults.set(["7:1"], forKey: "duhaa.quran.offline.surahs")
        let library = QuranOfflineLibrary(defaults: defaults)
        let reciter = try XCTUnwrap(Reciters.byID(7)) // Mishary — per-ayah

        library.remove(surah: testSurah, reciter: reciter)

        XCTAssertEqual(library.state(surah: 1, reciterID: 7), .notDownloaded)
        XCTAssertFalse((defaults.stringArray(forKey: "duhaa.quran.offline.surahs") ?? []).contains("7:1"))
    }

    func testChapterReciterCannotBeDownloaded() throws {
        let library = QuranOfflineLibrary(defaults: defaults)
        let chapterReciter = try XCTUnwrap(Reciters.all.first { $0.supportsChapterAudio })

        library.download(surah: testSurah, reciter: chapterReciter)

        XCTAssertEqual(library.state(surah: testSurah.number, reciterID: chapterReciter.id), .notDownloaded)
    }

    func testOfflineStoreReturnsNilForUndownloadedURL() throws {
        let url = try XCTUnwrap(URL(string: "https://verses.quran.com/Alafasy/mp3/114001.mp3"))
        XCTAssertNil(QuranOfflineStore.localURLIfDownloaded(for: url))
    }

    func testOfflineStoreFileNameIsStableAndMP3() throws {
        let url = try XCTUnwrap(URL(string: "https://verses.quran.com/Alafasy/mp3/001001.mp3"))
        let a = QuranOfflineStore.fileName(for: url)
        let b = QuranOfflineStore.fileName(for: url)
        XCTAssertEqual(a, b)
        XCTAssertTrue(a.hasSuffix(".mp3"))
    }

    private var testSurah: Surah {
        Surah(number: 1, arabicName: "الفاتحة", englishName: "Al-Fatihah",
              translation: "The Opening", revelation: "Meccan",
              ayahs: [
                Ayah(number: 1, arabic: "a", english: "one"),
                Ayah(number: 2, arabic: "b", english: "two")
              ])
    }
}
