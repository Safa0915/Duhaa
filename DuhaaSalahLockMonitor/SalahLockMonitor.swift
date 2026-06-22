import DeviceActivity
import ManagedSettings

/// The `DeviceActivityMonitor` for **Salah Lock**. iOS launches this extension at
/// the start and end of each scheduled prayer window — even when the Duhaa app is
/// closed — so it is the piece that actually applies and removes the app shield.
///
/// It is deliberately tiny and depends only on `SalahLock` (the shared App-Group
/// layer): on a window's start it shields the user's chosen apps; on its end (the
/// safety cap) it lifts them. The Duhaa app lifts the shield earlier, the instant
/// the prayer is marked prayed.
///
/// ⚠️ This file (and `SalahLockShared.swift`) belong to the **monitor extension
/// target**, not the app target. See `docs/salah-lock-setup.md` for the one-time
/// Xcode setup.
final class SalahLockMonitor: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard SalahLock.isEnabled,
              let prayer = SalahLock.prayerKey(from: activity) else { return }

        // Prayed early (before the adhan)? Then never lock this window.
        guard !SalahLock.didPrayToday(prayer) else { return }

        SalahLock.applyShield()
        SalahLock.activePrayer = prayer
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Cap reached — lift the shield. (The app lifts it sooner when the prayer
        // is logged; this is the backstop so it can never get stuck on.)
        SalahLock.clearShield()
        if let prayer = SalahLock.prayerKey(from: activity), SalahLock.activePrayer == prayer {
            SalahLock.activePrayer = nil
        }
    }
}
