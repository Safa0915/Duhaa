import Foundation
import WidgetKit

/// Bridges the app's prayer engine to the shared widget store.
///
/// The app calls `update(...)` whenever the inputs that affect the widget change
/// (foreground, location resolves, settings/theme change). It computes a small
/// rolling window of prayer times via `PrayerEngine`, writes it to the shared
/// App-Group store, and reloads the widget timelines. The widget then reads only
/// this lightweight payload — it never imports Adhan or recomputes anything.
///
/// ⚠️ App-target only. Do NOT add this file to the widget extension target — it
/// depends on `PrayerEngine` (Adhan), which the widget must stay free of.
enum WidgetSnapshotWriter {

    /// How many days of times to write ahead of today. A 3-day window means the
    /// widget keeps working — and rolls into tomorrow at midnight — even if the
    /// app isn't opened for a couple of days.
    private static let windowDays = 3

    /// Recompute and persist the widget times payload, then reload timelines.
    /// Safe to call often; it's cheap and idempotent.
    static func update(location: ActiveLocation,
                       config: PrayerConfig,
                       themeID: String,
                       hijriOffsetDays: Int = 0,
                       now: Date = Date()) {
        let tz = location.timeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz

        var days: [PrayerTimesPayload.Day] = []
        for offset in 0..<windowDays {
            guard let date = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            let comps = calendar.dateComponents([.year, .month, .day], from: date)
            guard let t = PrayerEngine.times(latitude: location.latitude,
                                             longitude: location.longitude,
                                             date: comps,
                                             config: config,
                                             timeZone: tz) else { continue }
            days.append(PrayerTimesPayload.Day(
                dayKey: SharedDayKey.make(date, tz),
                fajr: t.fajr, dhuhr: t.dhuhr, asr: t.asr,
                maghrib: t.maghrib, isha: t.isha, sunrise: t.sunrise))
        }

        // Nothing solvable (extreme latitude) → leave any previous payload in
        // place rather than overwriting good data with an empty one.
        guard !days.isEmpty else {
            WidgetReloader.reload()
            return
        }

        let payload = PrayerTimesPayload(
            days: days,
            locationDisplayName: location.name,
            timeZoneID: tz.identifier,
            themeID: themeID,
            lastUpdated: now,
            hijri: hijriStamp(now: now, tz: tz, offsetDays: hijriOffsetDays),
            dailyDua: todaysDua(now: now, tz: tz))
        SharedPrayerStore.current.saveTimes(payload)
        WidgetReloader.reload()
    }

    /// Today's Hijri date, offset-adjusted to match the app's home screen.
    private static func hijriStamp(now: Date, tz: TimeZone, offsetDays: Int) -> HijriStamp {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.timeZone = tz
        let adjusted = cal.date(byAdding: .day, value: offsetDays, to: now) ?? now
        let comps = cal.dateComponents([.year, .month, .day], from: adjusted)
        let f = DateFormatter()
        f.calendar = cal
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = tz
        f.dateFormat = "MMMM"
        return HijriStamp(day: comps.day ?? 0,
                          monthName: f.string(from: adjusted),
                          year: comps.year ?? 0)
    }

    /// Today's du'a — a stable daily rotation over the bundled library (currently
    /// the two curated categories, not the old 97-item set). `index` is the stable
    /// position used by the `duhaa://dua/<index>` deep link.
    private static func todaysDua(now: Date, tz: TimeZone) -> DuaStamp? {
        let all = Duas.categories.flatMap { $0.duas }
        guard !all.isEmpty else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let dayOfYear = cal.ordinality(of: .day, in: .year, for: now) ?? 1
        let idx = (dayOfYear - 1) % all.count
        let d = all[idx]
        return DuaStamp(index: idx, title: d.title, arabic: d.arabic,
                        latin: d.latin, en: d.en, source: d.source, status: d.status)
    }
}
