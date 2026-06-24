import XCTest
@testable import Duhaa

/// Covers the user's manual timetable: it persists through SettingsStore, flows into
/// the engine config, and stays off by default.
final class ManualPrayerTimesTests: XCTestCase {

    func testDefaultsOffAndUnconfigured() {
        let suite = UserDefaults(suiteName: "manual.test.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: suite)
        XCTAssertFalse(store.manualTimes.enabled)
        XCTAssertFalse(store.manualTimes.configured)
        XCTAssertFalse(store.prayerConfig.manual.enabled)
    }

    func testPersistsThroughSettingsStore() {
        let suite = UserDefaults(suiteName: "manual.test.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: suite)

        var m = ManualPrayerTimes()
        m.enabled = true
        m.configured = true
        m.fajr = 5 * 60 + 12
        m.isha = 21 * 60 + 30
        store.manualTimes = m

        let reloaded = SettingsStore(defaults: suite)
        XCTAssertTrue(reloaded.manualTimes.enabled)
        XCTAssertTrue(reloaded.manualTimes.configured)
        XCTAssertEqual(reloaded.manualTimes.fajr, 5 * 60 + 12)
        XCTAssertEqual(reloaded.manualTimes.isha, 21 * 60 + 30)
    }

    func testEnablingFlowsIntoPrayerConfig() {
        let suite = UserDefaults(suiteName: "manual.test.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: suite)
        store.manualTimes.enabled = true
        store.manualTimes.dhuhr = 13 * 60 + 5

        XCTAssertTrue(store.prayerConfig.manual.enabled)
        XCTAssertEqual(store.prayerConfig.manual.dhuhr, 13 * 60 + 5)
    }
}
