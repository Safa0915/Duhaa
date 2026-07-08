import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity

/// Shared constants + storage for **Salah Lock**, usable by BOTH the main app and
/// the `DeviceActivityMonitor` extension.
///
/// ⚠️ Keep this file free of any app-only types (no `Prayer`, no `PrayerEngine`,
/// no `PrayerTimesPayload`) so it can be a member of the monitor extension target
/// too — exactly like `Palette.swift` is shared with the widget target. It talks
/// only to system frameworks (FamilyControls / ManagedSettings / DeviceActivity)
/// and to the App-Group `UserDefaults`.
///
/// The whole feature lights up only once the **Family Controls** capability +
/// entitlement are added in Xcode (paid account + Apple approval). Until then the
/// frameworks still compile, authorization simply reports `.notDetermined`/denied,
/// and the app keeps working — see `docs/salah-lock-setup.md`.
enum SalahLock {

    // MARK: App Group

    /// The App-Group suite the app and the monitor extension both read/write. Same
    /// id the widgets already use, so no new capability id is introduced.
    static let suiteName = "group.com.duhaa.app"

    static var defaults: UserDefaults { UserDefaults(suiteName: suiteName) ?? .standard }

    // MARK: Managed settings store

    /// The named `ManagedSettingsStore` both processes share (over the App Group).
    /// Sharing the name lets the extension *apply* the shield when a prayer window
    /// begins, and the app *lift* it the moment that prayer is logged.
    static let storeName = ManagedSettingsStore.Name("DuhaaSalahLock")

    static var store: ManagedSettingsStore { ManagedSettingsStore(named: storeName) }

    // MARK: Prayers ↔ activities

    /// The five prayers, keyed by the app's `Prayer.rawValue` *display* names, so
    /// the app and extension agree on identity without sharing the `Prayer` enum.
    static let prayerKeys = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]

    static func activityName(for prayerKey: String) -> DeviceActivityName {
        DeviceActivityName("salahlock.\(prayerKey)")
    }

    static func prayerKey(from activity: DeviceActivityName) -> String? {
        let prefix = "salahlock."
        guard activity.rawValue.hasPrefix(prefix) else { return nil }
        return String(activity.rawValue.dropFirst(prefix.count))
    }

    static var allActivityNames: [DeviceActivityName] { prayerKeys.map(activityName(for:)) }

    // MARK: Tuning

    static let defaultCapMinutes = 40
    static let minCapMinutes = 10
    static let maxCapMinutes = 90

    private enum Key {
        static let enabled = "duhaa.salahlock.enabled"
        static let capMinutes = "duhaa.salahlock.capMinutes"
        static let selection = "duhaa.salahlock.selection"
        static let activePrayer = "duhaa.salahlock.activePrayer"
        static let timeZoneID = "duhaa.salahlock.tzid"
        // The app's prayer marks — same cross-process key PrayerTracker writes.
        static let marks = "duhaa.tracker.marks"
    }

    // MARK: Persisted settings

    static var isEnabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    /// Safety cap: the longest a window can ever stay locked, so it can never trap
    /// the user even if they never log the prayer. The lock normally lifts earlier,
    /// the instant the prayer is marked prayed.
    static var capMinutes: Int {
        get {
            let v = defaults.integer(forKey: Key.capMinutes)
            return v == 0 ? defaultCapMinutes : clampCap(v)
        }
        set { defaults.set(clampCap(newValue), forKey: Key.capMinutes) }
    }

    static func clampCap(_ v: Int) -> Int { min(max(v, minCapMinutes), maxCapMinutes) }

    static func loadSelection() -> FamilyActivitySelection {
        guard let data = defaults.data(forKey: Key.selection),
              let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return FamilyActivitySelection() }
        return sel
    }

    static func saveSelection(_ selection: FamilyActivitySelection) {
        if let data = try? JSONEncoder().encode(selection) {
            defaults.set(data, forKey: Key.selection)
        }
    }

    /// True when the user has chosen at least one app or category to block.
    static func hasSelection() -> Bool {
        let s = loadSelection()
        return !s.applicationTokens.isEmpty || !s.categoryTokens.isEmpty || !s.webDomainTokens.isEmpty
    }

    /// Which prayer's window is currently shielding (set by the monitor on start,
    /// cleared on end / when the app lifts it early). `nil` = no active shield.
    static var activePrayer: String? {
        get { defaults.string(forKey: Key.activePrayer) }
        set {
            if let newValue { defaults.set(newValue, forKey: Key.activePrayer) }
            else { defaults.removeObject(forKey: Key.activePrayer) }
        }
    }

    /// The location time zone the app last scheduled in — used by the monitor to
    /// resolve "today" the same way the app does when reading marks.
    static var timeZoneID: String? {
        get { defaults.string(forKey: Key.timeZoneID) }
        set { defaults.set(newValue, forKey: Key.timeZoneID) }
    }

    // MARK: Already-prayed check (honoured by the monitor)

    /// True if this prayer is already marked prayed for "today" — so praying early
    /// (before the adhan) means the window never locks. Reads the same
    /// `[dayKey: [prayerKey]]` map PrayerTracker persists to the App Group.
    static func didPrayToday(_ prayerKey: String, now: Date = Date()) -> Bool {
        let tz = TimeZone(identifier: timeZoneID ?? "") ?? .current
        let key = dayKey(now, tz)
        guard let data = defaults.data(forKey: Key.marks),
              let marks = try? JSONDecoder().decode([String: [String]].self, from: data)
        else { return false }
        return marks[key]?.contains(prayerKey) ?? false
    }

    /// Matches `PrayerTracker.dayKey` exactly (POSIX "yyyy-MM-dd" in the given tz).
    static func dayKey(_ date: Date, _ tz: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = tz
        return f.string(from: date)
    }

    // MARK: Shield control (shared by app + monitor)

    /// Apply the user's chosen apps/categories to the shared shield.
    static func applyShield() {
        let selection = loadSelection()
        let store = store
        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty
            ? nil : selection.webDomainTokens
    }

    /// Lift the shield entirely.
    static func clearShield() {
        let store = store
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }
}
