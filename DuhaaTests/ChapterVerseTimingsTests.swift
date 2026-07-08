import XCTest
@testable import Duhaa

/// Covers parsing of Quran.com's gapless verse-timing JSON into per-ayah start
/// times, which is what lets a full-surah recording begin at a chosen ayah.
final class ChapterVerseTimingsTests: XCTestCase {

    func testParsesAyahStartMillisecondsFromQuranComJSON() {
        let json = Data("""
        {"audio_file":{"audio_url":"https://x/8.mp3","timestamps":[
          {"verse_key":"8:1","timestamp_from":80,"timestamp_to":23203,"duration":23123},
          {"verse_key":"8:2","timestamp_from":23203,"timestamp_to":40000},
          {"verse_key":"8:10","timestamp_from":95000,"timestamp_to":99000}
        ]}}
        """.utf8)

        let map = ChapterVerseTimings.parse(json)

        XCTAssertEqual(map[1], 80)
        XCTAssertEqual(map[2], 23203)
        XCTAssertEqual(map[10], 95000)
        XCTAssertNil(map[3])
    }

    func testGarbageOrEmptyYieldsNoTimings() {
        XCTAssertTrue(ChapterVerseTimings.parse(Data("not json".utf8)).isEmpty)
        XCTAssertTrue(ChapterVerseTimings.parse(Data("{}".utf8)).isEmpty)
        XCTAssertTrue(ChapterVerseTimings.parse(Data(#"{"audio_file":{}}"#.utf8)).isEmpty)
    }

    func testParsesAyahStartMillisecondsFromMP3QuranJSON() {
        let json = Data("""
        [{"ayah":1,"start_time":300,"end_time":3240,"page":"https://x/001.svg"},
         {"ayah":2,"start_time":3240,"end_time":9280},
         {"ayah":7,"start_time":24000,"end_time":30000}]
        """.utf8)

        let map = ChapterVerseTimings.parseMP3Quran(json)

        XCTAssertEqual(map[1], 300)
        XCTAssertEqual(map[2], 3240)
        XCTAssertEqual(map[7], 24000)
        XCTAssertNil(map[3])
    }

    func testMP3QuranGarbageOrEmptyYieldsNoTimings() {
        XCTAssertTrue(ChapterVerseTimings.parseMP3Quran(Data("not json".utf8)).isEmpty)
        XCTAssertTrue(ChapterVerseTimings.parseMP3Quran(Data("[]".utf8)).isEmpty)
        XCTAssertTrue(ChapterVerseTimings.parseMP3Quran(Data(#"[{"ayah":1}]"#.utf8)).isEmpty)
    }
}
