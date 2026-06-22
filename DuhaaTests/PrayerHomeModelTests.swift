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

    private func display(at now: Date, masjid: MasjidTimetable = MasjidTimetable()) -> HomeDisplay {
        let model = PrayerHomeModel()
        model.now = now
        return model.display(for: nyc, config: config,
                             hijriOffsetDays: 0, hijriIsPrimary: false, masjid: masjid)
    }

    private func row(_ prayer: Prayer, at now: Date) -> PrayerRowData {
        display(at: now).rows.first { $0.prayer == prayer }!
    }

    private func dayKey(_ date: Date) -> String { PrayerTracker.dayKey(date, tz) }

    private func expectedCountdown(from start: Date, to end: Date) -> String {
        let seconds = max(0, Int(ceil(end.timeIntervalSince(start))))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m) minute\(m == 1 ? "" : "s")" }
        return "\(s) second\(s == 1 ? "" : "s")"
    }

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

    // MARK: Next prayer countdown

    func testCountdownUsesNextPrayerTime() {
        let t = engineTimes()
        let now = t.fajr.addingTimeInterval(90)
        let d = display(at: now)

        XCTAssertEqual(d.nextName, Prayer.dhuhr.rawValue)
        XCTAssertEqual(d.countdown, expectedCountdown(from: now, to: t.dhuhr))
    }

    func testCountdownShowsSecondsInFinalMinute() {
        let t = engineTimes()
        let now = t.dhuhr.addingTimeInterval(-30)
        let d = display(at: now)

        XCTAssertEqual(d.nextName, Prayer.dhuhr.rawValue)
        XCTAssertEqual(d.countdown, "30 seconds")
    }

    func testNextPrayerRollsForwardAtExactPrayerTime() {
        let t = engineTimes()
        let d = display(at: t.dhuhr)

        XCTAssertEqual(d.nextName, Prayer.asr.rawValue)
    }

    func testNextPrayerAfterIshaUsesTomorrowFajr() {
        let t = engineTimes()
        let d = display(at: t.isha.addingTimeInterval(60))

        XCTAssertEqual(d.nextName, Prayer.fajr.rawValue)
    }

    // MARK: Time remaining mode deadlines

    func testTimeRemainingDuringFajrCountsToSunrise() {
        let t = engineTimes()
        let now = t.sunrise.addingTimeInterval(-5 * 60)
        let d = display(at: now)

        XCTAssertEqual(d.nextName, Prayer.dhuhr.rawValue)
        XCTAssertEqual(d.timeRemainingTarget, "sunrise")
        XCTAssertEqual(d.timeRemainingCountdown, "5 minutes")
    }

    func testTimeRemainingDuringIshaCountsToIslamicMidnight() {
        let t = engineTimes()
        let now = t.islamicMidnight.addingTimeInterval(-5 * 60)
        let d = display(at: now)

        XCTAssertEqual(d.nextName, Prayer.fajr.rawValue)
        XCTAssertEqual(d.timeRemainingTarget, "Islamic midnight")
        XCTAssertEqual(d.timeRemainingCountdown, "5 minutes")
    }

    // MARK: Local masjid jamāʿah times

    func testNoMasjidTimesMeansNoIqama() {
        let d = display(at: engineTimes().dhuhr.addingTimeInterval(60))
        XCTAssertTrue(d.rows.allSatisfy { $0.iqama == nil })
        XCTAssertEqual(d.masjidName, "")
    }

    func testMasjidIqamaShowsOnItsRowOnly() {
        var masjid = MasjidTimetable(name: "Test Masjid")
        masjid.asr = 17 * 60 + 15   // 5:15 PM
        let d = display(at: engineTimes().dhuhr.addingTimeInterval(60), masjid: masjid)

        let asr = d.rows.first { $0.prayer == .asr }
        XCTAssertEqual(asr?.iqama, "5:15 PM")
        XCTAssertEqual(asr?.iqamaIsJumuah, false)
        XCTAssertNil(d.rows.first { $0.prayer == .fajr }?.iqama)
        XCTAssertEqual(d.masjidName, "Test Masjid")
    }

    func testJumuahReplacesDhuhrIqamaOnFriday() {
        // 2026-06-12 is a Friday; assert that, then check the swap.
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 12; comps.hour = 12
        comps.timeZone = tz
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let friday = cal.date(from: comps)!
        XCTAssertEqual(cal.component(.weekday, from: friday), 6, "fixture must be a Friday")

        var masjid = MasjidTimetable()
        masjid.dhuhr = 13 * 60          // 1:00 PM on weekdays
        masjid.jumuah = 13 * 60 + 30    // 1:30 PM Jumuʿah
        let dhuhr = display(at: friday, masjid: masjid).rows.first { $0.prayer == .dhuhr }
        XCTAssertEqual(dhuhr?.iqamaIsJumuah, true)
        XCTAssertEqual(dhuhr?.iqama, "1:30 PM")
    }

    func testJumuahNotUsedOnNonFriday() {
        var masjid = MasjidTimetable()
        masjid.dhuhr = 13 * 60
        masjid.jumuah = 13 * 60 + 30
        // June 9 2026 is a Tuesday.
        let dhuhr = display(at: engineTimes().dhuhr.addingTimeInterval(60), masjid: masjid)
            .rows.first { $0.prayer == .dhuhr }
        XCTAssertEqual(dhuhr?.iqamaIsJumuah, false)
        XCTAssertEqual(dhuhr?.iqama, "1:00 PM")
    }
}
