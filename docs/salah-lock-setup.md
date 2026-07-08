# Salah Lock — Xcode & entitlement setup

_Last updated: 2026-07-02._

> ✅ **STATUS (2026-07-02): LIVE on the dev's iPhone (development signing).** The
> monitor `.appex` is re-embedded (the 2026-06-19 temporary de-embed is reverted),
> the app + monitor both carry the **Family Controls (development)** capability via
> `-allowProvisioningUpdates`, and the signed extension carries
> `com.apple.developer.family-controls` + `group.com.duhaa.app` (verified with
> `codesign -d --entitlements`). Device build + install succeeded on the
> iPhone 17 Pro Max. Next: on-device smoke test (grant Screen Time access, pick
> apps, confirm the shield at the next prayer window).
>
> ⚠️ **Before TestFlight / App Store:** the **distribution** Family Controls
> entitlement is granted only **on request** —
> <https://developer.apple.com/contact/request/family-controls-distribution>.
> Until Apple approves it, **archive/TestFlight signing will fail with the monitor
> embedded** — if a TestFlight build must ship first, temporarily de-embed again
> (remove build file `DA000000000000000000020C` from the Embed Foundation
> Extensions phase and dependency `DA000000000000000000020B` from the app
> target's `dependencies` in `project.pbxproj`).
>
> The app target also carries the Family Controls entitlement because it requests
> Screen Time authorization and presents the Family Activity picker. Without it,
> the settings UI can look enabled while authorization never truly completes.

App Group used everywhere (already enabled for widgets): **`group.com.duhaa.app`**.

---

## What already exists in the repo

| Location | Target it belongs to | Notes |
|---|---|---|
| `Duhaa/Shared/SalahLockShared.swift` | **App + Monitor** | Shared constants, App-Group storage, shield apply/clear, already-prayed check. System frameworks only. Auto-joins the app; **add it to the Monitor target too.** |
| `Duhaa/SalahLock/SalahLockController.swift` | **App** | `@Observable` store: authorization, scheduling, lift-on-pray. |
| `Duhaa/SalahLock/SalahLockView.swift` | **App** | Settings screen (Settings → Prayer → Salah Lock). |
| `DuhaaSalahLockMonitor/SalahLockMonitor.swift` | **Monitor** | The `DeviceActivityMonitor` that applies/removes the shield. **Does not auto-join** (it's outside `Duhaa/`). |
| `DuhaaSalahLockMonitor/Info.plist` | **Monitor** | `NSExtensionPointIdentifier = com.apple.deviceactivity.monitor-extension`. |
| `DuhaaSalahLockMonitor/DuhaaSalahLockMonitor.entitlements` | **Monitor** | Family Controls + App Group. |

Already wired in code (no Xcode work needed): the controller is created and injected
in `DuhaaApp`, re-armed alongside the widget snapshot, and the home's mark handler
calls `markPrayed(_:)` to lift the lock the instant a prayer is logged.

---

## One-time Xcode steps (when you enrol)

1. **Request the entitlement** from Apple (link above). Wait for approval before
   shipping; development testing can begin once the capability is added.

2. **Create the monitor target:** File → New → Target → **Device Activity Monitor
   Extension**. Name it **DuhaaSalahLockMonitor**, bundle id
   `com.duhaa.app.SalahLockMonitor`. Delete the stub files Xcode generates and add
   the three `DuhaaSalahLockMonitor/*` files from this repo instead. Set its
   *Info.plist* and *Code Signing Entitlements* to the ones in that folder.

3. **Add target membership** for `Duhaa/Shared/SalahLockShared.swift` to the
   **DuhaaSalahLockMonitor** target (File inspector → Target Membership). It must
   compile into both the app and the monitor — same pattern as the widget's shared
   files.

4. **Add capabilities to BOTH the app target and the monitor target:**
   - **Family Controls** (Signing & Capabilities → + Capability).
   - **App Groups** → `group.com.duhaa.app` (the app already has it; add it to the
     monitor).

5. **Build & embed:** the `.appex` should embed into `Duhaa.app/PlugIns/`. Run on a
   real device, open Settings → Prayer → **Salah Lock**, grant Screen Time access,
   pick a few apps, and confirm they shield at the next prayer time and unlock when
   you mark the prayer prayed.

---

## How it works (behaviour summary)

- **Window:** for each of the five prayers, a daily `DeviceActivitySchedule` runs
  from the prayer time to prayer time + the **safety cap** (default 40 min, 10–90).
  Re-registered every foreground from the shared times payload, so it tracks the
  drifting prayer times. (Schedules use time-of-day components; if the app isn't
  opened for a long stretch the windows drift slightly until the next foreground.)
- **Lock:** the monitor's `intervalDidStart` shields the chosen apps, categories,
  and sites — *unless* that prayer is already marked prayed today (praying early
  means it never locks). iOS still requires user-selected Screen Time tokens; do
  **not** switch this to `.all(except:)` unless Duhaa can be safely excluded, or
  the user may be unable to reopen Duhaa to mark the prayer.
- **Lift:** marking the prayer prayed in Duhaa clears the shield immediately
  (`SalahLockController.markPrayed`). The cap (`intervalDidEnd`) is only a backstop
  so a window can never get stuck on.
- **Privacy:** app choices are opaque `FamilyActivitySelection` tokens stored in the
  App Group. Nothing leaves the device — no servers, no analytics (consistent with
  Duhaa's rules).
