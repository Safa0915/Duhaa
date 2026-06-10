import XCTest
@testable import Duhaa

/// Covers the home model's row plumbing for the insights tracker: the on-time
/// windows (Fajr ends at sunrise) and the midnight rule (before today's Fajr,
/// the Isha row belongs to yesterday).
final class PrayerHomeModelTests: XCTestCase {

    private let nyc = ActiveLocation(name: "New York, US",
                                     latitude: 40.7128, longitude: -74.0060,
                                     timeZoneID: "America/New_York", isManual: true)
    private let config = PrayerConfig()
    private var tz: TimeZone { nyc.timeZone }

    /// Engine times for a fixed day (2026-06-09) so anchors come from the engine,
    /// not hardcoded clock times.
    private func engineTimes() -> DuhaaPrayerTimes {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 9
        return PrayerEngine.times(latitude: nyc.latitude, longitude: nyc.longitude,
                                  date: comps, config: config)!
    }

    private func display(at now: Date) -> HomeDisplay {
        let model = PrayerHomeModel()
        model.now = now
        return model.display(for: nyc, config: config,
                             hijriOffsetDays: 0, hijriIsPrimary: false)
    }

    private func row(_ prayer: Prayer, at now: Date) -> PrayerRowData {
        display(at: now).rows.first { $0.prayer == prayer }!
    }

    private func dayKey(_ date: Date) -> String { PrayerTracker.dayKey(date, tz) }

    // MARK: Fajr on-time window (consensus: ends at sunrise)

    func testFajrOnTimeBeforeSunrise() {
        let t = engineTimes()
        let between = t.fajr.addingTimeInterval(60)
        XCTAssertTrue(row(.fajr, at: between).onTime)
    }

    func testFajrLateAfterSunrise() {
        let t = engineTimes()
        let after = t.sunrise.addingTimeInterval(60)
        XCTAssertFalse(row(.fajr, at: after).onTime)
    }

    // MARK: Isha on-time window (ends at Islamic midnight)

    func testIshaOnTimeBeforeIslamicMidnight() {
        let t = engineTimes()
        let evening = t.isha.addingTimeInterval(60)
        XCTAssertTrue(row(.isha, at: evening).onTime)
    }

    func testIshaLateAfterIslamicMidnight() {
        let t = engineTimes()
        // Just past June 9's Islamic midnight (early hours of June 10): the row
        // routes to yesterday (June 9) and is no longer on time.
        let lateNight = t.islamicMidnight.addingTimeInterval(300)
        XCTAssertFalse(row(.isha, at: lateNight).onTime)
    }

    // MARK: Midnight rule (pre-Fajr Isha is yesterday's)

    func testIshaBeforeFajrBelongsToYesterday() {
        let t = engineTimes()
        let night = t.fajr.addingTimeInterval(-3600)   // ~2:20am, before Fajr
        let isha = row(.isha, at: night)
        let yesterday = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: night)!
        XCTAssertEqual(isha.dayKey, dayKey(yesterday))
        XCTAssertFalse(isha.onTime)   // well past yesterday's Islamic midnight
    }

    func testOtherRowsKeepTodayKeyBeforeFajr() {
        let t = engineTimes()
        let night = t.fajr.addingTimeInterval(-3600)
        let d = display(at: night)
        for r in d.rows where r.prayer != .isha {
            XCTAssertEqual(r.dayKey, dayKey(night), "\(r.prayer) should stay on today")
        }
    }

    func testIshaAfterFajrBelongsToToday() {
        let t = engineTimes()
        let midday = t.dhuhr.addingTimeInterval(60)
        XCTAssertEqual(row(.isha, at: midday).dayKey, dayKey(midday))
    }
}
