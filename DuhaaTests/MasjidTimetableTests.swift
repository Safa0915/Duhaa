import XCTest
@testable import Duhaa

/// Covers the local-masjid jamāʿah times: clock formatting, per-prayer lookup, and
/// that they persist through SettingsStore.
final class MasjidTimetableTests: XCTestCase {

    func testClockFormatting() {
        XCTAssertEqual(MasjidTimetable.clock(0), "12:00 AM")
        XCTAssertEqual(MasjidTimetable.clock(5), "12:05 AM")
        XCTAssertEqual(MasjidTimetable.clock(12 * 60), "12:00 PM")
        XCTAssertEqual(MasjidTimetable.clock(13 * 60 + 30), "1:30 PM")
        XCTAssertEqual(MasjidTimetable.clock(20 * 60 + 5), "8:05 PM")
        XCTAssertEqual(MasjidTimetable.clock(23 * 60 + 59), "11:59 PM")
    }

    func testClockWrapsOutOfRangeValues() {
        XCTAssertEqual(MasjidTimetable.clock(1440), "12:00 AM")  // 24:00 → midnight
        XCTAssertEqual(MasjidTimetable.clock(-60), "11:00 PM")   // negative wraps back
    }

    func testMinutesForPrayer() {
        var t = MasjidTimetable()
        t.fajr = 330; t.dhuhr = 810; t.asr = 1020; t.maghrib = 1140; t.isha = 1230
        XCTAssertEqual(t.minutes(for: .fajr), 330)
        XCTAssertEqual(t.minutes(for: .dhuhr), 810)
        XCTAssertEqual(t.minutes(for: .isha), 1230)
    }

    func testHasAnyTime() {
        XCTAssertFalse(MasjidTimetable().hasAnyTime)
        XCTAssertFalse(MasjidTimetable(name: "Named but empty").hasAnyTime)
        var t = MasjidTimetable()
        t.jumuah = 13 * 60 + 30
        XCTAssertTrue(t.hasAnyTime)
    }

    func testPersistsThroughSettingsStore() {
        let suite = UserDefaults(suiteName: "masjid.test.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: suite)

        var t = MasjidTimetable(name: "Masjid An-Noor")
        t.fajr = 5 * 60 + 45
        t.jumuah = 13 * 60 + 30
        store.masjid = t

        let reloaded = SettingsStore(defaults: suite)
        XCTAssertEqual(reloaded.masjid.name, "Masjid An-Noor")
        XCTAssertEqual(reloaded.masjid.fajr, 5 * 60 + 45)
        XCTAssertEqual(reloaded.masjid.jumuah, 13 * 60 + 30)
        XCTAssertNil(reloaded.masjid.asr)
    }

    func testDefaultStoreHasEmptyMasjid() {
        let suite = UserDefaults(suiteName: "masjid.test.\(UUID().uuidString)")!
        XCTAssertFalse(SettingsStore(defaults: suite).masjid.hasAnyTime)
    }
}
