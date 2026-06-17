import XCTest
@testable import Duhaa

final class SettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test.settings.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testFreshDefaultsToTimeRemainingHomeDisplay() {
        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.nextPrayerDisplayMode, .timeRemaining)
        XCTAssertEqual(store.nextPrayerDisplayMode.label, "Time Remaining")
    }

    func testNextPrayerDisplayModePersists() {
        let store = SettingsStore(defaults: defaults)

        store.nextPrayerDisplayMode = .nextPrayer

        XCTAssertEqual(defaults.string(forKey: "duhaa.settings.nextPrayerDisplayMode"),
                       NextPrayerDisplayMode.nextPrayer.rawValue)
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.nextPrayerDisplayMode, .nextPrayer)
    }

    func testDataExporterIncludesStandardAndAppGroupSuites() throws {
        let appGroupSuiteName = "test.settings.appGroup.\(UUID().uuidString)"
        let appGroup = try XCTUnwrap(UserDefaults(suiteName: appGroupSuiteName))
        defer { appGroup.removePersistentDomain(forName: appGroupSuiteName) }
        defaults.set("standard-value", forKey: "duhaa.profile.name")
        appGroup.set("shared-value", forKey: "duhaa.tracker.lastOpened")

        let payload = DuhaaDataExporter.exportPayload(appVersion: "test", standard: defaults, appGroup: appGroup)
        let settings = payload["settings"] as? [String: Any]
        let standard = settings?["standard"] as? [String: Any]
        let shared = settings?["appGroup"] as? [String: Any]

        XCTAssertEqual(payload["format"] as? String, "duhaa.local.userdefaults.v2")
        XCTAssertEqual(standard?["duhaa.profile.name"] as? String, "standard-value")
        XCTAssertEqual(shared?["duhaa.tracker.lastOpened"] as? String, "shared-value")
    }

    func testDataExporterDeletesStandardAndAppGroupSuites() throws {
        let appGroupSuiteName = "test.settings.delete.appGroup.\(UUID().uuidString)"
        let appGroup = try XCTUnwrap(UserDefaults(suiteName: appGroupSuiteName))
        defer { appGroup.removePersistentDomain(forName: appGroupSuiteName) }
        defaults.set("standard-value", forKey: "duhaa.profile.name")
        appGroup.set("shared-value", forKey: "duhaa.tracker.lastOpened")
        defaults.set("keep", forKey: "notDuhaa")
        appGroup.set("keep", forKey: "notDuhaa")

        let removed = DuhaaDataExporter.deleteLocalData(standard: defaults, appGroup: appGroup)

        XCTAssertEqual(removed, 2)
        XCTAssertNil(defaults.object(forKey: "duhaa.profile.name"))
        XCTAssertNil(appGroup.object(forKey: "duhaa.tracker.lastOpened"))
        XCTAssertEqual(defaults.string(forKey: "notDuhaa"), "keep")
        XCTAssertEqual(appGroup.string(forKey: "notDuhaa"), "keep")
    }
}
