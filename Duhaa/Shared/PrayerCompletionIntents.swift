import AppIntents
import WidgetKit

/// Toggle a single prayer's completion for a given day, driven by a widget
/// **Toggle**. Conforming to `SetValueIntent` gives WidgetKit the optimistic UI
/// (it flips the switch immediately, then runs `perform()` and reloads).
///
/// We deliberately **flip the stored state** rather than write the framework's
/// injected `value`: the Toggle's optimistic flip already shows `!current`, and
/// toggling the persisted state always lands on that same result — so a tap marks
/// reliably even in setups where WidgetKit doesn't hand us a fresh `value` (which
/// otherwise leaves `value` at its default and silently no-ops the mark, so the
/// check appears then reverts). The intent stays tiny: no UI, haptics, network,
/// or prayer-time recalculation — it persists and asks for a reload.
struct SetPrayerCompletionIntent: AppIntent, SetValueIntent {
    static var title: LocalizedStringResource = "Mark Prayer"
    static var description = IntentDescription("Mark a prayer as prayed for the day.")
    /// Never launches the app — the whole point is to act in place.
    static var openAppWhenRun = false
    /// Widget-only plumbing; keep it out of the Shortcuts app / Spotlight.
    static var isDiscoverable = false

    @Parameter(title: "Prayer") var prayerID: String
    @Parameter(title: "Day") var dayKey: String
    /// Required by `SetValueIntent` (and carries the Toggle's optimistic state).
    /// `perform()` flips the stored state rather than reading this, for the
    /// reliability reasons above.
    @Parameter(title: "Prayed") var value: Bool

    init() {}

    init(prayer: PrayerID, dayKey: String) {
        self.prayerID = prayer.rawValue
        self.dayKey = dayKey
        self.value = false
    }

    func perform() async throws -> some IntentResult {
        guard let id = PrayerID(rawValue: prayerID), SharedDayKey.isValid(dayKey) else {
            // Unknown id/day → no-op, never crash. (Belt-and-braces: invalid input.)
            return .result()
        }
        // Flip + persist FIRST so any reload reads fresh state; the coalesced
        // reload then fires once per tap burst (the Toggle's optimistic flip
        // already shows the result, so the debounce is invisible).
        SharedPrayerStore.current.toggleCompleted(id, on: dayKey)
        await WidgetReloader.reloadPrayerWidgetsCoalesced()
        return .result()
    }
}

/// Flip a prayer's completion (no externally-supplied target state), driven by a
/// widget **Button** — used where a Toggle doesn't fit (e.g. the small/large
/// widget's "mark the next prayer" affordance). Reads the current state from the
/// shared store and inverts it.
struct TogglePrayerCompletionIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Prayer"
    static var description = IntentDescription("Toggle whether a prayer is marked as prayed.")
    static var openAppWhenRun = false
    /// Widget-only plumbing; keep it out of the Shortcuts app / Spotlight.
    static var isDiscoverable = false

    @Parameter(title: "Prayer") var prayerID: String
    @Parameter(title: "Day") var dayKey: String

    init() {}

    init(prayer: PrayerID, dayKey: String) {
        self.prayerID = prayer.rawValue
        self.dayKey = dayKey
    }

    func perform() async throws -> some IntentResult {
        guard let id = PrayerID(rawValue: prayerID), SharedDayKey.isValid(dayKey) else { return .result() }
        SharedPrayerStore.current.toggleCompleted(id, on: dayKey)
        await WidgetReloader.reloadPrayerWidgetsCoalesced()
        return .result()
    }
}
