import XCTest
@testable import Duhaa

/// Guards the bundled "Hadith of the Day" content + its daily rotation. Per the
/// project's religious-content rules every hadith must be fully populated (Arabic,
/// transliteration, English, narrator, source) and carry an authenticity grade
/// plus the grader whose grading it is — and only sahih/hasan grades are allowed.
final class HadithDataTests: XCTestCase {

    func testLibraryDecodesAndIsNonEmpty() {
        XCTAssertFalse(Hadiths.all.isEmpty, "hadith_of_day.json failed to decode or is empty")
    }

    func testEveryHadithIsFullyPopulated() {
        for h in Hadiths.all {
            XCTAssertFalse(h.arabic.isEmpty, "empty arabic: \(h.en)")
            XCTAssertFalse(h.latin.isEmpty, "empty transliteration: \(h.en)")
            XCTAssertFalse(h.en.isEmpty, "empty translation")
            XCTAssertFalse(h.narrator.isEmpty, "empty narrator: \(h.en)")
            XCTAssertFalse(h.source.isEmpty, "empty source: \(h.en)")
            XCTAssertFalse(h.grade.isEmpty, "empty grade: \(h.en)")
            XCTAssertFalse(h.grader.isEmpty, "empty grader: \(h.en)")
        }
    }

    /// Only authentic narrations ship — weak/fabricated are omitted by policy.
    func testOnlySahihOrHasanGradesShip() {
        let allowed: Set<String> = ["Sahih", "Hasan"]
        for h in Hadiths.all {
            XCTAssertTrue(allowed.contains(h.grade), "disallowed grade \(h.grade): \(h.en)")
        }
    }

    /// Content must never be labeled "Verified" until a scholar reviews it.
    func testNoVerifiedLabel() {
        for h in Hadiths.all {
            XCTAssertFalse(h.grade.localizedCaseInsensitiveContains("verified"), "remove 'Verified' label")
            XCTAssertFalse(h.grader.localizedCaseInsensitiveContains("verified"), "remove 'Verified' label")
        }
    }

    func testGradeLineCombinesGradeAndGrader() {
        guard let h = Hadiths.all.first else { return XCTFail("no hadith") }
        XCTAssertEqual(h.gradeLine, "\(h.grade) · \(h.grader)")
    }

    // MARK: Daily rotation

    func testTodayIsInRange() {
        let pick = Hadiths.today()
        XCTAssertNotNil(pick)
        if let pick {
            XCTAssertTrue((0..<Hadiths.all.count).contains(pick.index))
            XCTAssertEqual(pick.hadith.en, Hadiths.all[pick.index].en)
        }
    }

    func testRotationIsStableForTheSameDay() {
        let date = Date(timeIntervalSince1970: 1_718_000_000)
        let a = Hadiths.today(date)
        let b = Hadiths.today(date)
        XCTAssertEqual(a?.index, b?.index)
    }

    func testRotationAdvancesAcrossConsecutiveDays() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        // Two days within the same year advance by exactly one slot (mod count).
        let day1 = Date(timeIntervalSince1970: 1_718_000_000)            // some day
        let day2 = day1.addingTimeInterval(86_400)
        let i1 = Hadiths.today(day1, calendar: cal)!.index
        let i2 = Hadiths.today(day2, calendar: cal)!.index
        XCTAssertEqual(i2, (i1 + 1) % Hadiths.all.count)
    }

    // MARK: Stamp round-trip (app → widget contract)

    func testHadithStampRoundTripsInPayload() throws {
        let stamp = HadithStamp(index: 3, arabic: "ع", latin: "ʿayn", en: "test",
                                narrator: "X (RA)", source: "Bukhari 1",
                                grade: "Sahih", grader: "al-Bukhari")
        let payload = PrayerTimesPayload(days: [], locationDisplayName: nil,
                                         timeZoneID: "UTC", themeID: "dark",
                                         lastUpdated: Date(), dailyHadith: stamp)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(PrayerTimesPayload.self, from: data)
        XCTAssertEqual(decoded.dailyHadith, stamp)
        XCTAssertEqual(decoded.dailyHadith?.gradeLine, "Sahih · al-Bukhari")
    }

    /// Old payloads written before the field still decode (dailyHadith is optional).
    func testPayloadWithoutHadithStillDecodes() throws {
        let json = """
        {"days":[],"timeZoneID":"UTC","themeID":"dark","lastUpdated":0}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(PrayerTimesPayload.self, from: json)
        XCTAssertNil(decoded.dailyHadith)
    }
}
