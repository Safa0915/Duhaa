import WidgetKit
import Foundation

/// One timeline entry: an instant + the snapshot to render at that instant.
struct PrayerEntry: TimelineEntry {
    let date: Date
    let snapshot: PrayerWidgetSnapshot
}

/// Builds lightweight, predictable timelines from the shared store. It never runs
/// prayer-time math — it reads the app-written payload and re-evaluates the
/// snapshot at each meaningful instant (now, each upcoming prayer, midnight), so
/// "next" and "current" flip on their own and the day rolls over without the app.
struct PrayerTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: Date(), snapshot: .placeholder())
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        let store = SharedPrayerStore.current
        // In the gallery before any real data exists, show a polished sample.
        if context.isPreview && store.loadTimes() == nil {
            completion(PrayerEntry(date: Date(), snapshot: .sample()))
            return
        }
        completion(PrayerEntry(date: Date(), snapshot: store.snapshot(now: Date())))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let store = SharedPrayerStore.current
        let now = Date()
        let payload = store.loadTimes()

        // All the date math lives in the shared, unit-tested `PrayerTimelinePlanner`.
        let refreshPoints = PrayerTimelinePlanner.refreshDates(from: payload, now: now)
        let entries = refreshPoints.map { date in
            PrayerEntry(date: date, snapshot: store.snapshot(now: date))
        }

        // Re-pull at the next local midnight so the day rolls over and (if the app
        // was opened) fresher times are picked up. Until then the system advances
        // between our precomputed entries; explicit reloads handle check-offs.
        let reload = PrayerTimelinePlanner.nextMidnight(payload: payload, now: now)
        completion(Timeline(entries: entries, policy: .after(reload)))
    }
}
