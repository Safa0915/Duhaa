import XCTest
import DeviceActivity
@testable import Duhaa

/// Unit tests for the pure, entitlement-free parts of Salah Lock — the cross-process
/// contract the app and the `DeviceActivityMonitor` extension rely on. The
/// authorization/shielding paths need the Family Controls entitlement + a real
/// device, so they aren't exercised here.
final class SalahLockTests: XCTestCase {

    func testCapMinutesClampsToBounds() {
        XCTAssertEqual(SalahLock.clampCap(0), SalahLock.minCapMinutes)
        XCTAssertEqual(SalahLock.clampCap(5), SalahLock.minCapMinutes)
        XCTAssertEqual(SalahLock.clampCap(1000), SalahLock.maxCapMinutes)
        XCTAssertEqual(SalahLock.clampCap(40), 40)
        XCTAssertGreaterThanOrEqual(SalahLock.defaultCapMinutes, SalahLock.minCapMinutes)
        XCTAssertLessThanOrEqual(SalahLock.defaultCapMinutes, SalahLock.maxCapMinutes)
    }

    func testActivityNameAndPrayerKeyRoundTrip() {
        for key in SalahLock.prayerKeys {
            let name = SalahLock.activityName(for: key)
            XCTAssertEqual(SalahLock.prayerKey(from: name), key,
                           "activity name must map back to its prayer key")
        }
        XCTAssertEqual(SalahLock.allActivityNames.count, 5)
    }

    func testPrayerKeyRejectsForeignActivityNames() {
        XCTAssertNil(SalahLock.prayerKey(from: DeviceActivityName("something.else")))
        XCTAssertNil(SalahLock.prayerKey(from: DeviceActivityName("")))
    }

    func testPrayerKeysMatchTheAppsPrayerRawValues() {
        // The monitor identifies prayers by Prayer.rawValue without importing the
        // enum — keep them in lockstep.
        XCTAssertEqual(SalahLock.prayerKeys, Prayer.allCases.map(\.rawValue))
    }

    func testDayKeyMatchesPrayerTrackerFormat() {
        let tz = TimeZone(identifier: "America/New_York")!
        let date = Date(timeIntervalSince1970: 1_718_000_000)  // fixed instant
        XCTAssertEqual(SalahLock.dayKey(date, tz), PrayerTracker.dayKey(date, tz))
    }
}
