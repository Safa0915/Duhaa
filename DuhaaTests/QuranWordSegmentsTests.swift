import XCTest
@testable import Duhaa

@MainActor
final class QuranWordSegmentsTests: XCTestCase {
    // Al-Fatihah 1:1 (Bismillah), Mishary — verbatim from Quran.com.
    private let bismillahJSON = """
    {"verse":{"audio":{"url":"Alafasy/mp3/001001.mp3","segments":[[0,1,60,610],[1,2,620,1310],[2,3,1320,2450],[3,4,2460,5970]]}}}
    """.data(using: .utf8)!

    func testParseFourElementSegments() {
        let segments = QuranWordSegments.parse(bismillahJSON)
        XCTAssertEqual(segments.count, 4)
        XCTAssertEqual(segments.first, QuranWordSegment(word: 1, startMs: 60, endMs: 610))
        XCTAssertEqual(segments.last, QuranWordSegment(word: 4, startMs: 2460, endMs: 5970))
    }

    func testParseThreeElementSegments() {
        let json = #"{"verse":{"audio":{"segments":[[1,0,500],[2,500,900]]}}}"#.data(using: .utf8)!
        let segments = QuranWordSegments.parse(json)
        XCTAssertEqual(segments, [QuranWordSegment(word: 1, startMs: 0, endMs: 500),
                                  QuranWordSegment(word: 2, startMs: 500, endMs: 900)])
    }

    func testParseMissingAudioReturnsEmpty() {
        let json = #"{"verse":{}}"#.data(using: .utf8)!
        XCTAssertTrue(QuranWordSegments.parse(json).isEmpty)
    }

    func testActiveWordIndexTracksRealTiming() {
        let segments = QuranWordSegments.parse(bismillahJSON)
        // Before the first word starts → no highlight.
        XCTAssertNil(QuranWordSegments.activeWordIndex(atMs: 0, segments: segments, wordCount: 4))
        // Inside each word's window → that word (0-based).
        XCTAssertEqual(QuranWordSegments.activeWordIndex(atMs: 100, segments: segments, wordCount: 4), 0)
        XCTAssertEqual(QuranWordSegments.activeWordIndex(atMs: 700, segments: segments, wordCount: 4), 1)
        XCTAssertEqual(QuranWordSegments.activeWordIndex(atMs: 2000, segments: segments, wordCount: 4), 2)
        XCTAssertEqual(QuranWordSegments.activeWordIndex(atMs: 3000, segments: segments, wordCount: 4), 3)
        // Past the end → stays on the final word.
        XCTAssertEqual(QuranWordSegments.activeWordIndex(atMs: 99999, segments: segments, wordCount: 4), 3)
    }

    func testActiveWordIndexClampsToDisplayedWordCount() {
        let segments = QuranWordSegments.parse(bismillahJSON) // max word position 4
        XCTAssertEqual(QuranWordSegments.activeWordIndex(atMs: 3000, segments: segments, wordCount: 2), 1)
    }

    func testActiveWordIndexEmptyInputsAreNil() {
        XCTAssertNil(QuranWordSegments.activeWordIndex(atMs: 500, segments: [], wordCount: 4))
        let segments = QuranWordSegments.parse(bismillahJSON)
        XCTAssertNil(QuranWordSegments.activeWordIndex(atMs: 500, segments: segments, wordCount: 0))
    }

    func testDownloadedTracePersistsToDiskAndHydratesOffline() {
        let reciterID = 999001, surah = 999001, ayah = 1
        let trace = QuranAyahTrace(
            words: [QuranAyahWord(arabic: "بِسْمِ", translation: "In (the) name")],
            segments: [QuranWordSegment(word: 1, startMs: 0, endMs: 500)]
        )
        defer {
            QuranOfflineStore.removeTraces(reciterID: reciterID, surah: surah)
            QuranWordSegments.forget(reciterID: reciterID, surah: surah)
        }

        QuranOfflineStore.saveTraces(["\(ayah)": trace], reciterID: reciterID, surah: surah)

        // Disk round-trip.
        XCTAssertEqual(QuranOfflineStore.savedTraces(reciterID: reciterID, surah: surah)?["\(ayah)"], trace)
        // Offline read path: cachedTrace hydrates from disk with no network.
        XCTAssertEqual(QuranWordSegments.cachedTrace(reciterID: reciterID, surah: surah, ayah: ayah), trace)
    }

    func testParseTraceExtractsWordsTranslationsAndDropsEndMarker() {
        // Two words + a verse-end marker (which must be dropped) + segments.
        let json = #"""
        {"verse":{"words":[
          {"char_type_name":"word","text_uthmani":"بِسْمِ","translation":{"text":"In (the) name"}},
          {"char_type_name":"word","text_uthmani":"ٱللَّهِ","translation":{"text":"(of) Allah"}},
          {"char_type_name":"end","text_uthmani":"١","translation":{"text":null}}
        ],"audio":{"segments":[[0,1,0,500],[1,2,500,900]]}}}
        """#.data(using: .utf8)!

        let trace = QuranWordSegments.parseTrace(json)
        XCTAssertEqual(trace.words.count, 2) // end marker dropped
        XCTAssertEqual(trace.words.first, QuranAyahWord(arabic: "بِسْمِ", translation: "In (the) name"))
        XCTAssertEqual(trace.words.last?.translation, "(of) Allah")
        XCTAssertEqual(trace.segments.count, 2)
    }
}
