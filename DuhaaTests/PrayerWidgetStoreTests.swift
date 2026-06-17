import XCTest
import WidgetKit
@testable import Duhaa

/// Covers the widget's shared storage, the snapshot builder's "what's next / done"
/// logic, the App Intents, and app↔widget sync. All against isolated suites so
/// nothing touches real user data or WidgetKit.
final class PrayerWidgetStoreTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: SharedPrayerStore!
    private let nyTZ = TimeZone(identifier: "America/New_York")!

    override func setUp() {
        super.setUp()
        suiteName = "test.widget.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = SharedPrayerStore(defaults: defaults)
        WidgetReloader.handler = {}   // never poke WidgetKit in tests
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        WidgetReloader.handler = { WidgetCenter.shared.reloadAllTimelines() }
        super.tearDown()
    }

    // MARK: - Shared store completion

    func testSaveAndReadCompletion() {
        store.setCompleted(true, .fajr, on: "2026-06-17")
        XCTAssertTrue(store.isCompleted(.fajr, on: "2026-06-17"))
        XCTAssertEqual(store.completedIDs(on: "2026-06-17"), [.fajr])
    }

    func testToggleOff() {
        store.setCompleted(true, .fajr, on: "2026-06-17")
        store.setCompleted(false, .fajr, on: "2026-06-17")
        XCTAssertFalse(store.isCompleted(.fajr, on: "2026-06-17"))
        XCTAssertEqual(store.completionCount(on: "2026-06-17"), 0)
    }

    func testTogglingOnePrayerDoesNotAffectOthers() {
        store.setCompleted(true, .fajr, on: "2026-06-17")
        store.setCompleted(true, .asr, on: "2026-06-17")
        store.setCompleted(false, .fajr, on: "2026-06-17")
        XCTAssertFalse(store.isCompleted(.fajr, on: "2026-06-17"))
        XCTAssertTrue(store.isCompleted(.asr, on: "2026-06-17"))
        XCTAssertEqual(store.completedIDs(on: "2026-06-17"), [.asr])
    }

    func testDifferentDatesDoNotCollide() {
        store.setCompleted(true, .fajr, on: "2026-06-17")
        store.setCompleted(true, .dhuhr, on: "2026-06-18")
        XCTAssertEqual(store.completedIDs(on: "2026-06-17"), [.fajr])
        XCTAssertEqual(store.completedIDs(on: "2026-06-18"), [.dhuhr])
        XCTAssertTrue(store.completedIDs(on: "2026-06-19").isEmpty)
    }

    func testToggleConvenienceReturnsNewState() {
        XCTAssertTrue(store.toggleCompleted(.maghrib, on: "2026-06-17"))
        XCTAssertFalse(store.toggleCompleted(.maghrib, on: "2026-06-17"))
    }

    func testInvalidPrayerIDFailsSafely() {
        // The stable IDs are lowercase; a display name is not a valid id.
        XCTAssertNil(PrayerID(rawValue: "Fajr"))
        XCTAssertNil(PrayerID(rawValue: "nonsense"))
        XCTAssertEqual(PrayerID(trackerKey: "Fajr"), .fajr)
        XCTAssertNil(PrayerID(trackerKey: "fajr"))   // trackerKey is capitalized
    }

    // MARK: - PrayerTracker compatibility (same keys / same shape)

    func testStoreWriteIsVisibleToPrayerTracker() {
        store.setCompleted(true, .asr, on: "2026-06-17")
        // A tracker pointed at the same suite must see it (cross-process contract).
        let tracker = PrayerTracker(defaults: defaults)
        XCTAssertTrue(tracker.isMarked(.asr, dayKey: "2026-06-17"))
    }

    func testTrackerWriteIsVisibleToStore() {
        let tracker = PrayerTracker(defaults: defaults)
        tracker.toggle(.isha, dayKey: "2026-06-17")
        XCTAssertTrue(store.isCompleted(.isha, on: "2026-06-17"))
    }

    func testTrackerReloadFromStorePicksUpWidgetChange() {
        let tracker = PrayerTracker(defaults: defaults)
        XCTAssertFalse(tracker.isMarked(.dhuhr, dayKey: "2026-06-17"))
        // Simulate a widget check-off, then the app foregrounding.
        store.setCompleted(true, .dhuhr, on: "2026-06-17")
        tracker.reloadFromStore()
        XCTAssertTrue(tracker.isMarked(.dhuhr, dayKey: "2026-06-17"))
    }

    func testWidgetMarkKeepsOnTimeNuance() {
        // Marking from the widget should count as on time: the prayer must NOT be
        // in lateMarks, so the app's insights stay correct.
        store.setCompleted(true, .fajr, on: "2026-06-17")
        let lateData = defaults.data(forKey: SharedPrayerStore.Key.lateMarks)
        let late = lateData.flatMap { try? JSONDecoder().decode([String: [String]].self, from: $0) } ?? [:]
        XCTAssertNil(late["2026-06-17"])
    }

    // MARK: - Migration

    func testMigrationCopiesLegacyDataOnce() {
        let legacy = UserDefaults(suiteName: "test.legacy.\(UUID().uuidString)")!
        defer { legacy.removePersistentDomain(forName: legacy.dictionaryRepresentation().isEmpty ? "" : "") }
        // Seed legacy (".standard"-style) tracker data.
        let marks = ["2026-06-17": ["Fajr", "Dhuhr"]]
        legacy.set(try! JSONEncoder().encode(marks), forKey: SharedPrayerStore.Key.marks)
        legacy.set("dark", forKey: SharedPrayerStore.Key.theme)

        let dest = UserDefaults(suiteName: "test.dest.\(UUID().uuidString)")!
        SharedPrayerStore.migrateLegacyData(into: dest, from: legacy)

        let migrated = SharedPrayerStore(defaults: dest)
        XCTAssertEqual(migrated.completedIDs(on: "2026-06-17"), [.fajr, .dhuhr])
        XCTAssertTrue(dest.bool(forKey: SharedPrayerStore.Key.migratedV1))

        // Idempotent: a second run with different legacy data must NOT re-copy.
        legacy.set(try! JSONEncoder().encode(["2026-06-18": ["Asr"]]), forKey: SharedPrayerStore.Key.marks)
        SharedPrayerStore.migrateLegacyData(into: dest, from: legacy)
        XCTAssertTrue(migrated.completedIDs(on: "2026-06-18").isEmpty)
    }

    func testMigrationDoesNotOverwriteExistingSuiteData() {
        let legacy = UserDefaults(suiteName: "test.legacy2.\(UUID().uuidString)")!
        legacy.set(try! JSONEncoder().encode(["2026-06-17": ["Fajr"]]), forKey: SharedPrayerStore.Key.marks)
        let dest = UserDefaults(suiteName: "test.dest2.\(UUID().uuidString)")!
        // Suite already has the user's (widget-era) data.
        let destStore = SharedPrayerStore(defaults: dest)
        destStore.setCompleted(true, .isha, on: "2026-06-17")

        SharedPrayerStore.migrateLegacyData(into: dest, from: legacy)
        // Existing data preserved; legacy not merged over it.
        XCTAssertEqual(destStore.completedIDs(on: "2026-06-17"), [.isha])
    }

    // MARK: - Times payload round-trip

    func testTimesPayloadRoundTrip() {
        let payload = Self.payload(themeID: "lightPink", tz: nyTZ)
        store.saveTimes(payload)
        let loaded = store.loadTimes()
        XCTAssertEqual(loaded, payload)
        XCTAssertEqual(store.themeID(), "lightPink")
    }

    // MARK: - Snapshot builder

    func testProgressAcrossZeroToFive() {
        for n in 0...5 {
            XCTAssertEqual(PrayerWidgetSnapshot.progress(n), Double(n) / 5.0, accuracy: 0.0001)
        }
        XCTAssertEqual(PrayerWidgetSnapshot.progress(7), 1.0)   // clamped
    }

    func testNextPrayerSelectionMidAfternoon() {
        let payload = Self.payload(tz: nyTZ)
        let now = Self.at(14, 5, tz: nyTZ)   // between Dhuhr (12:58) and Asr (16:47)
        let snap = PrayerWidgetSnapshot.make(payload: payload, completed: [.fajr], now: now)
        XCTAssertEqual(snap.status, .ok)
        XCTAssertEqual(snap.nextPrayerID, .asr)
        XCTAssertEqual(snap.currentPrayerID, .dhuhr)
        XCTAssertFalse(snap.nextPrayerIsTomorrow)
    }

    func testPrayerOrderingIsAlwaysFajrToIsha() {
        let snap = PrayerWidgetSnapshot.make(payload: Self.payload(tz: nyTZ),
                                             completed: [], now: Self.at(9, 0, tz: nyTZ))
        XCTAssertEqual(snap.prayers.map(\.id), PrayerID.ordered)
    }

    func testAfterIshaRollsToTomorrowFajr() {
        let payload = Self.payload(tz: nyTZ)
        let now = Self.at(23, 30, tz: nyTZ)   // after Isha (21:54)
        let snap = PrayerWidgetSnapshot.make(payload: payload, completed: [], now: now)
        XCTAssertEqual(snap.nextPrayerID, .fajr)
        XCTAssertTrue(snap.nextPrayerIsTomorrow)
        // No item flagged isNext when next is tomorrow's Fajr.
        XCTAssertFalse(snap.prayers.contains { $0.isNext })
    }

    func testBeforeFajrHasNoCurrentPrayer() {
        let snap = PrayerWidgetSnapshot.make(payload: Self.payload(tz: nyTZ),
                                             completed: [], now: Self.at(3, 0, tz: nyTZ))
        XCTAssertEqual(snap.nextPrayerID, .fajr)
        XCTAssertNil(snap.currentPrayerID)
    }

    func testCompletionCountAndProgressFromSet() {
        let snap = PrayerWidgetSnapshot.make(payload: Self.payload(tz: nyTZ),
                                             completed: [.fajr, .dhuhr, .asr],
                                             now: Self.at(18, 0, tz: nyTZ))
        XCTAssertEqual(snap.dailyCompletionCount, 3)
        XCTAssertEqual(snap.completionProgress, 0.6, accuracy: 0.0001)
        XCTAssertEqual(snap.completedPrayerIDs, [.fajr, .dhuhr, .asr])
    }

    func testFallbackWhenNoPayload() {
        let snap = PrayerWidgetSnapshot.make(payload: nil, completed: [.fajr], now: Date())
        XCTAssertEqual(snap.status, .unavailable)
        XCTAssertNotNil(snap.message)
        XCTAssertEqual(snap.prayers.count, 5)            // still lists the five names
        XCTAssertEqual(snap.dailyCompletionCount, 1)     // and the day's progress
        XCTAssertNil(snap.prayers.first?.time)
    }

    func testStaleWhenPayloadDoesNotCoverToday() {
        // A payload whose only day is far in the past.
        let old = Self.payload(tz: nyTZ, reference: Date(timeIntervalSince1970: 1_600_000_000))
        let snap = PrayerWidgetSnapshot.make(payload: old, completed: [], now: Date())
        XCTAssertEqual(snap.status, .stale)
    }

    func testSnapshotIsCodable() throws {
        let snap = PrayerWidgetSnapshot.make(payload: Self.payload(tz: nyTZ),
                                             completed: [.fajr], now: Self.at(14, 0, tz: nyTZ))
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(PrayerWidgetSnapshot.self, from: data)
        XCTAssertEqual(decoded, snap)
    }

    func testMissingLocationIsSafe() {
        var payload = Self.payload(tz: nyTZ)
        payload.locationDisplayName = nil
        let snap = PrayerWidgetSnapshot.make(payload: payload, completed: [], now: Self.at(14, 0, tz: nyTZ))
        XCTAssertNil(snap.locationDisplayName)
        XCTAssertEqual(snap.status, .ok)
    }

    // MARK: - Timeline provider

    func testTimelineFallsBackToNowWhenNoPayload() {
        let dates = PrayerTimelinePlanner.refreshDates(from: nil, now: Self.at(14, 0, tz: nyTZ))
        XCTAssertEqual(dates.count, 1)
    }

    func testTimelineIncludesUpcomingPrayerInstants() {
        let now = Self.at(9, 0, tz: nyTZ)   // before Dhuhr/Asr/Maghrib/Isha
        let dates = PrayerTimelinePlanner.refreshDates(from: Self.payload(tz: nyTZ), now: now)
        XCTAssertTrue(dates.contains(now))
        // Dhuhr, Asr, Maghrib, Isha (today) are all still ahead.
        let payload = Self.payload(tz: nyTZ)
        let today = payload.day(containing: now)!
        XCTAssertTrue(dates.contains(today.asr))
        XCTAssertTrue(dates.contains(today.isha))
        XCTAssertEqual(dates, dates.sorted())
    }

    func testTimelineIncludesNextMidnight() {
        let now = Self.at(23, 0, tz: nyTZ)
        let midnight = PrayerTimelinePlanner.nextMidnight(payload: Self.payload(tz: nyTZ), now: now)
        XCTAssertTrue(midnight > now)
        var cal = Calendar(identifier: .gregorian); cal.timeZone = nyTZ
        XCTAssertEqual(cal.component(.hour, from: midnight), 0)
    }

    // MARK: - App Intents

    func testSetIntentTogglesCorrectPrayerAndPersists() async throws {
        SharedPrayerStore.current = store
        defer { SharedPrayerStore.current = SharedPrayerStore(defaults: .duhaaShared) }
        var reloaded = false
        WidgetReloader.handler = { reloaded = true }

        let intent = SetPrayerCompletionIntent(prayer: .asr, dayKey: "2026-06-17")
        intent.value = true
        _ = try await intent.perform()

        XCTAssertTrue(store.isCompleted(.asr, on: "2026-06-17"))
        XCTAssertFalse(store.isCompleted(.fajr, on: "2026-06-17"))  // only Asr
        XCTAssertTrue(reloaded)                                     // reload requested
    }

    /// Regression: a tap must MARK even when WidgetKit doesn't inject a fresh
    /// `value` (so `value` stays at its `false` default). Previously this silently
    /// no-oped and the widget's check appeared then reverted. `perform()` now flips
    /// the stored state, so the mark sticks regardless of `value`.
    func testSetIntentMarksEvenWhenValueLeftAtDefault() async throws {
        SharedPrayerStore.current = store
        defer { SharedPrayerStore.current = SharedPrayerStore(defaults: .duhaaShared) }
        let intent = SetPrayerCompletionIntent(prayer: .fajr, dayKey: "2026-06-17")
        // Note: value is NOT set — it stays at the init default of false.
        _ = try await intent.perform()
        XCTAssertTrue(store.isCompleted(.fajr, on: "2026-06-17"))   // marked anyway
        _ = try await intent.perform()                              // tap again
        XCTAssertFalse(store.isCompleted(.fajr, on: "2026-06-17"))  // flips back off
    }

    func testSetIntentUnmarks() async throws {
        SharedPrayerStore.current = store
        defer { SharedPrayerStore.current = SharedPrayerStore(defaults: .duhaaShared) }
        store.setCompleted(true, .maghrib, on: "2026-06-17")

        let intent = SetPrayerCompletionIntent(prayer: .maghrib, dayKey: "2026-06-17")
        intent.value = false
        _ = try await intent.perform()
        XCTAssertFalse(store.isCompleted(.maghrib, on: "2026-06-17"))
    }

    func testToggleIntentFlipsState() async throws {
        SharedPrayerStore.current = store
        defer { SharedPrayerStore.current = SharedPrayerStore(defaults: .duhaaShared) }
        let intent = TogglePrayerCompletionIntent(prayer: .isha, dayKey: "2026-06-17")
        _ = try await intent.perform()
        XCTAssertTrue(store.isCompleted(.isha, on: "2026-06-17"))
        _ = try await intent.perform()
        XCTAssertFalse(store.isCompleted(.isha, on: "2026-06-17"))
    }

    func testIntentHandlesInvalidIDSafely() async throws {
        SharedPrayerStore.current = store
        defer { SharedPrayerStore.current = SharedPrayerStore(defaults: .duhaaShared) }
        let intent = SetPrayerCompletionIntent()
        intent.prayerID = "garbage"
        intent.dayKey = "2026-06-17"
        intent.value = true
        // Must not throw or persist anything.
        _ = try await intent.perform()
        XCTAssertEqual(store.completionCount(on: "2026-06-17"), 0)
    }

    func testIntentRejectsInvalidDayKeySafely() async throws {
        SharedPrayerStore.current = store
        defer { SharedPrayerStore.current = SharedPrayerStore(defaults: .duhaaShared) }
        let intent = TogglePrayerCompletionIntent(prayer: .fajr, dayKey: "2026-06-17-malformed-extra-data")

        _ = try await intent.perform()

        XCTAssertEqual(store.completionCount(on: "2026-06-17-malformed-extra-data"), 0)
        XCTAssertEqual(store.completionCount(on: "2026-06-17"), 0)
    }

    // MARK: - Five-state model

    func testPrayerStateDeriveTruthTable() {
        XCTAssertEqual(PrayerState.derive(prayed: true, late: false, windowPassed: false), .onTime)
        XCTAssertEqual(PrayerState.derive(prayed: true, late: true, windowPassed: true), .late)
        XCTAssertEqual(PrayerState.derive(prayed: false, late: false, windowPassed: false), .upcoming)
        XCTAssertEqual(PrayerState.derive(prayed: false, late: false, windowPassed: true), .missed)
        // Excused only when the whole day is excused (dormant hook).
        XCTAssertEqual(PrayerState.derive(prayed: false, late: false, windowPassed: true, dayExcused: true), .excused)
    }

    func testDeriveNeverFabricatesMadeUpOrExcusedFromRealData() {
        // Sweep every real input combination; the only producible states are the four.
        var produced = Set<PrayerState>()
        for prayed in [true, false] {
            for late in [true, false] {
                for passed in [true, false] {
                    produced.insert(PrayerState.derive(prayed: prayed, late: late, windowPassed: passed))
                }
            }
        }
        XCTAssertFalse(produced.contains(.madeUp))
        XCTAssertFalse(produced.contains(.excused))   // never, without dayExcused
        XCTAssertEqual(produced, [.onTime, .late, .upcoming, .missed])
    }

    func testSnapshotItemsCarryState() {
        let payload = Self.payload(tz: nyTZ)
        // Fajr on time, Dhuhr late; mid-afternoon so Asr/Maghrib/Isha not yet missed.
        let snap = PrayerWidgetSnapshot.make(payload: payload, completed: [.fajr, .dhuhr],
                                             late: [.dhuhr], now: Self.at(14, 5, tz: nyTZ))
        XCTAssertEqual(snap.item(.fajr)?.state, .onTime)
        XCTAssertEqual(snap.item(.dhuhr)?.state, .late)
        XCTAssertEqual(snap.item(.asr)?.state, .upcoming)
        XCTAssertEqual(snap.item(.isha)?.state, .upcoming)
    }

    func testUnprayedBecomesMissedOnlyAfterWindowCloses() {
        let payload = Self.payload(tz: nyTZ)
        // Just after Fajr's window closes (Sunrise is mid-window; Dhuhr 12:58 closes Fajr).
        let afterDhuhr = Self.at(13, 30, tz: nyTZ)
        let snap = PrayerWidgetSnapshot.make(payload: payload, completed: [], now: afterDhuhr)
        XCTAssertEqual(snap.item(.fajr)?.state, .missed)   // window (→Dhuhr) closed, unprayed
        XCTAssertEqual(snap.item(.dhuhr)?.state, .upcoming) // still in Dhuhr's window
    }

    // MARK: - Weekly grid

    func testWeeklyStatesShapeAndOrder() {
        store.saveTimes(Self.payload(tz: nyTZ))
        let now = Self.at(23, 0, tz: nyTZ)
        let week = store.weeklyStates(now: now)
        XCTAssertEqual(week.count, 7)
        XCTAssertTrue(week.allSatisfy { $0.states.count == 5 })
        XCTAssertTrue(week.last?.isToday ?? false)         // last entry is today
        XCTAssertFalse(week.first?.isToday ?? true)
    }

    func testWeeklyPastDayUnprayedIsMissed() {
        store.saveTimes(Self.payload(tz: nyTZ))
        let now = Self.at(12, 0, tz: nyTZ)
        // Mark Fajr on a day 3 days ago; leave the rest unprayed.
        var cal = Calendar(identifier: .gregorian); cal.timeZone = nyTZ
        let pastDay = cal.date(byAdding: .day, value: -3, to: now)!
        let pastKey = SharedDayKey.make(pastDay, nyTZ)
        store.setCompleted(true, .fajr, on: pastKey)

        let week = store.weeklyStates(now: now)
        let past = week.first { $0.dayKey == pastKey }
        XCTAssertEqual(past?.states[PrayerID.fajr.order], .onTime)
        XCTAssertEqual(past?.states[PrayerID.isha.order], .missed)   // past day, unprayed → missed
    }

    // MARK: - New payload / snapshot fields round-trip

    func testPayloadSunriseHijriDuaRoundTrip() {
        let payload = Self.payload(tz: nyTZ)
        store.saveTimes(payload)
        let loaded = store.loadTimes()
        XCTAssertEqual(loaded?.days.first?.sunrise, payload.days.first?.sunrise)
        XCTAssertEqual(loaded?.hijri, HijriStamp(day: 2, monthName: "Muharram", year: 1448))
        XCTAssertEqual(loaded?.dailyDua?.index, 3)
        XCTAssertEqual(loaded?.hijri?.formatted, "2 Muharram 1448")
    }

    func testSnapshotPassesThroughHijriDuaSunriseAndWindow() {
        let snap = PrayerWidgetSnapshot.make(payload: Self.payload(tz: nyTZ),
                                             completed: [], now: Self.at(14, 5, tz: nyTZ))
        XCTAssertEqual(snap.hijri?.formatted, "2 Muharram 1448")
        XCTAssertEqual(snap.dailyDua?.title, "Sample")
        XCTAssertNotEqual(snap.sunriseString, "—")
        // Mid-afternoon window is Dhuhr→Asr; progress is strictly between 0 and 1.
        XCTAssertNotNil(snap.currentWindowStart)
        XCTAssertNotNil(snap.currentWindowEnd)
        XCTAssertGreaterThan(snap.windowProgress, 0)
        XCTAssertLessThan(snap.windowProgress, 1)
    }

    func testEnrichedSnapshotIsCodable() throws {
        let snap = PrayerWidgetSnapshot.make(payload: Self.payload(tz: nyTZ),
                                             completed: [.fajr], late: [.fajr],
                                             now: Self.at(14, 5, tz: nyTZ),
                                             weekly: store.weeklyStates(now: Self.at(14, 5, tz: nyTZ)))
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(PrayerWidgetSnapshot.self, from: data)
        XCTAssertEqual(decoded, snap)
    }

    // MARK: - Ring-step timeline entries

    func testRingStepsStayInWindowAndCapped() {
        let now = Self.at(13, 0, tz: nyTZ)   // window Dhuhr(12:58)→Asr(16:47)
        let steps = PrayerTimelinePlanner.ringStepDates(payload: Self.payload(tz: nyTZ), now: now)
        let asr = Self.at(16, 47, tz: nyTZ)
        XCTAssertLessThanOrEqual(steps.count, 12)
        XCTAssertTrue(steps.allSatisfy { $0 > now && $0 < asr })
        XCTAssertEqual(steps, steps.sorted())
    }

    // MARK: - Fixtures

    /// A two-day payload (reference day + the next) in `tz`.
    static func payload(themeID: String = "dark",
                        tz: TimeZone,
                        reference: Date = Date(timeIntervalSince1970: 1_718_000_000)) -> PrayerTimesPayload {
        func day(_ d: Date) -> PrayerTimesPayload.Day {
            PrayerTimesPayload.Day(
                dayKey: SharedDayKey.make(d, tz),
                fajr: at(4, 21, on: d, tz: tz),
                dhuhr: at(12, 58, on: d, tz: tz),
                asr: at(16, 47, on: d, tz: tz),
                maghrib: at(20, 26, on: d, tz: tz),
                isha: at(21, 54, on: d, tz: tz),
                sunrise: at(5, 56, on: d, tz: tz))
        }
        return PrayerTimesPayload(
            days: [day(reference), day(reference.addingTimeInterval(86_400))],
            locationDisplayName: "New York, USA",
            timeZoneID: tz.identifier, themeID: themeID, lastUpdated: reference,
            hijri: HijriStamp(day: 2, monthName: "Muharram", year: 1448),
            dailyDua: DuaStamp(index: 3, title: "Sample", arabic: "س", latin: "s",
                               en: "Sample du'a", source: "Bukhari 1", status: nil))
    }

    /// `h:m` on the reference day used by `payload`, in `tz`.
    static func at(_ h: Int, _ m: Int, tz: TimeZone,
                   reference: Date = Date(timeIntervalSince1970: 1_718_000_000)) -> Date {
        at(h, m, on: reference, tz: tz)
    }

    private static func at(_ h: Int, _ m: Int, on day: Date, tz: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let start = cal.startOfDay(for: day)
        return cal.date(bySettingHour: h, minute: m, second: 0, of: start) ?? start
    }
}
