import XCTest
@testable import Duhaa

/// Verifies the full-page Mushaf reconstruction: 604 pages, correct surah
/// headers / bismillah, cross-surah pages, and complete + non-duplicated
/// coverage of every ayah in the Quran.
final class MushafPageTests: XCTestCase {

    private let pages = Mushaf.pages

    func testHasAll604Pages() {
        XCTAssertEqual(pages.count, 604)
        XCTAssertEqual(pages.first?.page, 1)
        XCTAssertEqual(pages.last?.page, 604)
    }

    func testPageOneIsAlFatihahWithoutSeparateBismillah() throws {
        let page = try XCTUnwrap(Mushaf.page(1))
        // Header for surah 1, and Al-Fatihah's basmala IS ayah 1 (no extra line).
        guard case .surahHeader(let n, _, _, let showsBismillah)? = page.segments.first else {
            return XCTFail("Page 1 should open with a surah header")
        }
        XCTAssertEqual(n, 1)
        XCTAssertFalse(showsBismillah)

        let ayahs = ayahNumbers(in: page, surah: 1)
        XCTAssertEqual(ayahs, Array(1...7))
    }

    func testPageTwoIsAlBaqarahHeaderWithBismillahAndFirstFiveAyahs() throws {
        let page = try XCTUnwrap(Mushaf.page(2))
        guard case .surahHeader(let n, _, _, let showsBismillah)? = page.segments.first else {
            return XCTFail("Page 2 should open Al-Baqarah")
        }
        XCTAssertEqual(n, 2)
        XCTAssertTrue(showsBismillah)
        XCTAssertEqual(ayahNumbers(in: page, surah: 2), Array(1...5))
    }

    func testContinuationPageHasNoHeader() throws {
        // Page 3 continues Al-Baqarah (ayahs 6–16) — no surah begins here, so no
        // header, and the run does not start at ayah 1.
        let page3 = try XCTUnwrap(Mushaf.page(3))
        XCTAssertFalse(page3.segments.contains {
            if case .surahHeader = $0 { return true }
            return false
        })
        XCTAssertEqual(ayahNumbers(in: page3, surah: 2).first, 6)
    }

    func testSurahBeginningMidPageGetsHeaderWhereItStarts() throws {
        // Surah 11 (Hud) begins partway down page 221, right after Yunus ends —
        // so the mushaf shows Hud's title + bismillah there, mid-page.
        let page = try XCTUnwrap(Mushaf.page(221))
        XCTAssertTrue(ayahNumbers(in: page, surah: 10).contains(109), "Yunus should finish here")
        guard let header = page.segments.first(where: {
            if case .surahHeader(let n, _, _, _) = $0 { return n == 11 }
            return false
        }), case .surahHeader(_, _, _, let showsBismillah) = header else {
            return XCTFail("Hud's header should appear on page 221")
        }
        XCTAssertTrue(showsBismillah)
        XCTAssertEqual(ayahNumbers(in: page, surah: 11).first, 1)
    }

    func testLastPageHasThreeShortSurahsEachWithHeader() throws {
        let page = try XCTUnwrap(Mushaf.page(604))
        let headerSurahs = page.segments.compactMap { segment -> Int? in
            if case .surahHeader(let n, _, _, _) = segment { return n }
            return nil
        }
        XCTAssertEqual(headerSurahs, [112, 113, 114])
    }

    func testEveryAyahAppearsExactlyOnce() {
        var seen: [String: Int] = [:]
        for page in pages {
            for segment in page.segments {
                if case .ayahRun(let surah, let ayahs) = segment {
                    for ayah in ayahs { seen["\(surah):\(ayah.number)", default: 0] += 1 }
                }
            }
        }
        let totalAyahs = Quran.shared.surahs.reduce(0) { $0 + $1.ayahs.count }
        XCTAssertEqual(seen.count, totalAyahs, "Every ayah should be covered")
        XCTAssertEqual(seen.count, 6236)
        XCTAssertTrue(seen.values.allSatisfy { $0 == 1 }, "No ayah should be duplicated across pages")
    }

    func testArabicIndicNumerals() {
        XCTAssertEqual(MushafPage.arabicIndic(2), "٢")
        XCTAssertEqual(MushafPage.arabicIndic(255), "٢٥٥")
        XCTAssertEqual(MushafPage.verseMarker(7), "﴿٧﴾")
        XCTAssertEqual(MushafPage.rosetteVerseMarker(24), "\u{06DD}٢٤")
    }

    /// The Indo-Pak Nastaleeq font has blank glyphs for U+0660–0669, so ayah
    /// markers for that font must use the Extended Arabic-Indic (Urdu) digits.
    func testEasternArabicIndicNumeralsForIndoPak() {
        XCTAssertEqual(MushafPage.arabicIndic(2, eastern: true), "۲")
        XCTAssertEqual(MushafPage.arabicIndic(255, eastern: true), "۲۵۵")
        XCTAssertEqual(MushafPage.verseMarker(7, easternDigits: true), "﴿۷﴾")
        XCTAssertEqual(MushafPage.rosetteVerseMarker(24, easternDigits: true), "\u{06DD}۲۴")
        // Only the Indo-Pak font opts into the eastern digit set.
        XCTAssertTrue(QuranFontPreference.indopak.usesEasternArabicDigits)
        XCTAssertFalse(QuranFontPreference.kfgqpc.usesEasternArabicDigits)
    }

    func testPageRefsAndJuzNumbersSupportMushafChrome() throws {
        let page2 = try XCTUnwrap(Mushaf.page(2))

        XCTAssertEqual(page2.firstAyahRef, QuranVerseRef(surah: 2, ayah: 1))
        XCTAssertEqual(page2.lastAyahRef, QuranVerseRef(surah: 2, ayah: 5))
        XCTAssertEqual(page2.juzNumber, 1)
        XCTAssertEqual(MushafPage.juzNumber(forPage: 22), 2)
        XCTAssertEqual(MushafPage.juzNumber(forPage: 604), 30)
    }

    func testQuranComPageReportsFirstLineForEachSurah() {
        let page = QuranComMushafPage(
            page: 604,
            juzNumber: 30,
            lines: [
                QuranComMushafLine(number: 3, text: "surah 112 text", refs: [QuranVerseRef(surah: 112, ayah: 1)], words: []),
                QuranComMushafLine(number: 7, text: "surah 113 text", refs: [QuranVerseRef(surah: 113, ayah: 1)], words: []),
                QuranComMushafLine(number: 12, text: "surah 114 text", refs: [QuranVerseRef(surah: 114, ayah: 1)], words: [])
            ],
            firstRef: QuranVerseRef(surah: 112, ayah: 1),
            lastRef: QuranVerseRef(surah: 114, ayah: 6)
        )

        XCTAssertEqual(page.firstLineNumber(forSurah: 112), 3)
        XCTAssertEqual(page.firstLineNumber(forSurah: 113), 7)
        XCTAssertEqual(page.firstLineNumber(forSurah: 114), 12)
        XCTAssertNil(page.firstLineNumber(forSurah: 1))
    }

    func testMushafWordBuildsWordByWordAudioURL() {
        let word = MushafWord(
            id: 1, text: "بِسْمِ", surah: 1, ayah: 1, position: 1, isWord: true,
            translation: "In (the) name", transliteration: "bis'mi",
            audioPath: "wbw/001_001_001.mp3")
        XCTAssertEqual(word.audioURL?.absoluteString,
                       "https://audio.qurancdn.com/wbw/001_001_001.mp3")
    }

    func testMushafVerseMarkerHasNoAudioAndIsNotTappable() {
        let marker = MushafWord(
            id: 2, text: "﴿١﴾", surah: 1, ayah: 1, position: 0, isWord: false,
            translation: "", transliteration: "", audioPath: nil)
        XCTAssertFalse(marker.isWord)
        XCTAssertNil(marker.audioURL)
    }

    // MARK: - Helpers

    private func ayahNumbers(in page: MushafPage, surah: Int) -> [Int] {
        page.segments.flatMap { segment -> [Int] in
            if case .ayahRun(let s, let ayahs) = segment, s == surah {
                return ayahs.map(\.number)
            }
            return []
        }
    }
}
