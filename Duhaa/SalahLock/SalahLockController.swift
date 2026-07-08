import Foundation
import Observation
import FamilyControls
import ManagedSettings
import DeviceActivity

/// App-side brain for **Salah Lock**. Owns the user's settings (enabled, chosen
/// apps, safety cap), requests Screen Time authorization, registers a
/// `DeviceActivity` window per prayer, and lifts the shield the moment a prayer is
/// logged.
///
/// The actual blocking is applied/removed by the `DeviceActivityMonitor` extension
/// (it runs even when the app is closed). The app and the extension coordinate
/// through `SalahLock` (shared App-Group storage + a shared named
/// `ManagedSettingsStore`). See `docs/salah-lock-setup.md`.
///
/// Until the Family Controls capability + entitlement are wired up,
/// `authorizationStatus` stays `.notDetermined`/denied, every call here is a safe
/// no-op, and the app is unaffected — the UI simply shows the "not allowed" state.
///
/// Created once by `DuhaaApp` and injected into the environment (the settings UI
/// and the home's mark handler both read it from there) — mirroring `PrayerTracker`.
@Observable
final class SalahLockController {

    private(set) var isEnabled: Bool
    private(set) var selection: FamilyActivitySelection
    private(set) var authorizationStatus: AuthorizationStatus

    /// Safety cap (minutes). The lock lifts earlier when the prayer is marked.
    var capMinutes: Int {
        didSet {
            guard capMinutes != oldValue else { return }
            SalahLock.capMinutes = capMinutes
            reschedule()
        }
    }

    private let center = DeviceActivityCenter()

    init() {
        isEnabled = SalahLock.isEnabled
        capMinutes = SalahLock.capMinutes
        selection = SalahLock.loadSelection()
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    // MARK: Derived state

    var isAuthorized: Bool { authorizationStatus == .approved }
    var selectedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }
    var hasSelection: Bool { selectedCount > 0 }

    /// True once everything needed for the lock to actually fire is in place.
    var isArmed: Bool { isEnabled && isAuthorized && hasSelection }

    // MARK: Authorization

    func refreshAuthorization() {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    }

    /// Ask iOS for Screen Time access. Throws (silently handled) when the user
    /// declines or the entitlement isn't present yet — we just re-read the status.
    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            // Declined, or Family Controls entitlement not yet provisioned.
        }
        refreshAuthorization()
    }

    // MARK: Settings mutations

    func setEnabled(_ on: Bool) {
        isEnabled = on
        SalahLock.isEnabled = on
        if on { reschedule() } else { stopEverything() }
    }

    func updateSelection(_ newValue: FamilyActivitySelection) {
        selection = newValue
        SalahLock.saveSelection(newValue)
        reschedule()
    }

    // MARK: Scheduling

    /// Re-register today's prayer windows from the shared times payload. Cheap and
    /// idempotent — call it on launch, on foreground, and whenever times change.
    func refreshSchedule() { reschedule() }

    private func reschedule(now: Date = Date()) {
        // Not ready → make sure nothing stale lingers.
        guard isArmed else { stopEverything(); return }
        guard let payload = SharedPrayerStore.current.loadTimes(),
              let today = payload.day(containing: now) else { return }

        let tz = payload.timeZone
        SalahLock.timeZoneID = tz.identifier
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz

        let currentWindow = SalahLockWindow.activePrayerKey(in: today,
                                                            capMinutes: capMinutes,
                                                            now: now)

        // If the app missed the monitor's end callback, or the user prayed from
        // another surface, clear the stale shield as soon as Duhaa wakes up.
        if let liveWindow = SalahLock.activePrayer,
           liveWindow != currentWindow || SalahLock.didPrayToday(liveWindow, now: now) {
            SalahLock.clearShield()
            SalahLock.activePrayer = nil
        }

        let liveWindow = SalahLock.activePrayer   // never tear down a lock that's on

        for (id, time) in today.ordered {
            let key = id.trackerKey
            let name = SalahLock.activityName(for: key)

            // Leave a currently-active window exactly as the monitor set it.
            if liveWindow == key { continue }

            let start = cal.dateComponents([.hour, .minute], from: time)
            let endDate = time.addingTimeInterval(Double(capMinutes) * 60)
            let end = cal.dateComponents([.hour, .minute], from: endDate)

            // A daily-repeating window at this time-of-day. Re-registering on each
            // foreground keeps it tracking the (slowly drifting) prayer times.
            let schedule = DeviceActivitySchedule(intervalStart: start,
                                                  intervalEnd: end,
                                                  repeats: true)
            do {
                center.stopMonitoring([name])
                try center.startMonitoring(name, during: schedule)
            } catch {
                // Most often: entitlement not provisioned yet. Safe to ignore.
            }
        }

        // If Salah Lock is enabled after the adhan, or Duhaa foregrounds during
        // the window, don't wait until tomorrow's repeated schedule to shield.
        if let currentWindow,
           liveWindow != currentWindow,
           !SalahLock.didPrayToday(currentWindow, now: now) {
            SalahLock.applyShield()
            SalahLock.activePrayer = currentWindow
        }
    }

    /// Stop every window and clear any active shield. Used when disabling, or when
    /// the lock can't run (no auth / no apps chosen).
    private func stopEverything() {
        center.stopMonitoring(SalahLock.allActivityNames)
        SalahLock.clearShield()
        SalahLock.activePrayer = nil
    }

    // MARK: Lift-on-pray

    /// Called when a prayer is marked prayed. If that prayer's window is the one
    /// currently shielding, lift it immediately — the reward for praying, not for
    /// waiting out the cap. The daily monitor stays registered for tomorrow.
    func markPrayed(_ prayerRawValue: String) {
        guard isEnabled else { return }
        guard SalahLock.activePrayer == prayerRawValue else { return }
        SalahLock.clearShield()
        SalahLock.activePrayer = nil
    }
}

enum SalahLockWindow {
    static func activePrayerKey(in day: PrayerTimesPayload.Day,
                                capMinutes: Int,
                                now: Date) -> String? {
        day.ordered.last { item in
            let end = item.time.addingTimeInterval(Double(SalahLock.clampCap(capMinutes)) * 60)
            return now >= item.time && now < end
        }?.id.trackerKey
    }
}
