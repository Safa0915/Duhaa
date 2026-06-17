# Duhaa Widgets — Xcode setup

_Last updated: 2026-06-17._

> ✅ **STATUS: DONE — the widget target is wired and builds.** The `DuhaaWidgets`
> app-extension target, App Groups on both targets, and shared-file membership are
> now committed in `Duhaa.xcodeproj/project.pbxproj`. Verified: app + widget build
> for the Simulator, the `.appex` embeds into `Duhaa.app/PlugIns/`, both
> `*-Simulated.xcent` carry `com.apple.security.application-groups → group.com.duhaa.app`,
> the runtime App Group container resolves, and all 230 unit tests pass. The steps
> below are retained as **reference** (how it was set up / how to recreate it) and
> for the **remaining device step** (§ Device note).
>
> **Device note:** App Groups on a **physical iPhone** needs a provisioning profile
> that includes the group. With "Automatically manage signing" + the personal team
> (`3HYBHNTCV7`), Xcode usually generates this on first device build; if it
> complains, open the target's *Signing & Capabilities* once so Xcode registers the
> App Group with the profile. Simulator needs nothing extra.
>
> **Cosmetic note:** the 7 shared files are referenced into the widget target via an
> explicit "Widget Shared (membership)" group, so they appear twice in Xcode's
> navigator (once under `Duhaa/`, once under that group). This is harmless and
> builds correctly; if you prefer, you can reconcile membership via the GUI later.

The widget **code is written and the app compiles and ships the shared store + App
Intents.** What previously had to be done in Xcode — creating the **Widget
Extension target**, enabling **App Groups**, and setting **target membership** —
has now been applied to the project file.

Group identifier used everywhere in code: **`group.com.duhaa.app`**
(constant: `DuhaaAppGroup.identifier`). Never hardcode a Team ID.

---

## What already exists in the repo

| Location | Target it belongs to | Notes |
|---|---|---|
| `Duhaa/Shared/*.swift` | **App + Widget** | Store, snapshot, payload, intents, planner. Auto-joins the **app** (synchronized folder); you must add it to the **widget** target too. |
| `Duhaa/Theme/Palette.swift` | **App + Widget** | Reused for exact theme colors. Add widget membership. |
| `Duhaa/Support/WidgetSnapshotWriter.swift` | **App only** | Uses Adhan via `PrayerEngine`; do **not** add to the widget. |
| `DuhaaWidgets/*.swift` | **Widget only** | Bundle, widgets, views, provider. Do **not** add to the app. |
| `Duhaa/Duhaa.entitlements` | App | App-Groups entitlement template. |
| `DuhaaWidgets/DuhaaWidgets.entitlements` | Widget | App-Groups entitlement template. |

---

## Step 1 — Add the Widget Extension target

1. **File ▸ New ▸ Target… ▸ Widget Extension.**
2. Product name: **`DuhaaWidgets`**. Uncheck *Include Live Activity* and
   *Include Configuration App Intent* (we provide our own files). Finish.
3. When asked to **activate the new scheme**, you can say *Activate*.
4. Xcode generates a starter `DuhaaWidgets.swift` + `Info.plist` + an
   `Assets.xcassets`. **Delete the generated `DuhaaWidgets.swift`** (the bundle,
   widget, and provider Swift files) — we replace them with the files in the
   `DuhaaWidgets/` folder. Keep the generated **Info.plist** and asset catalog.
5. Confirm the new target's bundle id is **`com.duhaa.app.DuhaaWidgets`** and its
   deployment target is **iOS 17.0**.

## Step 2 — Add our widget files to the widget target

In the Project navigator, add the files under `DuhaaWidgets/` to the **DuhaaWidgets
target** (drag them in, or *Add Files…*, ensuring **only** the DuhaaWidgets target
checkbox is checked):

- `DuhaaWidgetBundle.swift` (has the `@main`)
- `PrayerWidgets.swift`, `PrayerWidgetViews.swift`, `WidgetComponents.swift`
- `WidgetTheme.swift`, `PrayerTimelineProvider.swift`, `LockScreenWidgets.swift`

> The starter target may already have a `@main` in the generated file — make sure
> only **one** `@main` remains (`DuhaaWidgetBundle`).

## Step 3 — Share the shared code with the widget target

Select each of these files and, in the **File inspector ▸ Target Membership**, tick
**DuhaaWidgets** (leave **Duhaa** ticked too):

- `Duhaa/Shared/PrayerWidgetShared.swift`
- `Duhaa/Shared/PrayerTimesPayload.swift`
- `Duhaa/Shared/PrayerWidgetSnapshot.swift`
- `Duhaa/Shared/SharedPrayerStore.swift`
- `Duhaa/Shared/PrayerCompletionIntents.swift`
- `Duhaa/Shared/PrayerTimelinePlanner.swift`
- `Duhaa/Theme/Palette.swift`

Do **not** add `WidgetSnapshotWriter.swift` or anything that imports `Adhan` to the
widget target.

> Because `Duhaa/` is an Xcode 16 synchronized folder group, files there join the
> **app** target automatically. Adding widget membership is a manual checkbox per
> file — there's no `project.pbxproj` surgery to do.

## Step 4 — Enable App Groups on BOTH targets

For the **Duhaa** app target and the **DuhaaWidgets** target, in
**Signing & Capabilities**:

1. **+ Capability ▸ App Groups.**
2. Add (or tick) the group **`group.com.duhaa.app`** on **both** targets — it must
   be the *same* string on each.
3. Xcode writes/updates each target's `.entitlements` file. If it created new ones,
   you can point `CODE_SIGN_ENTITLEMENTS` at the templates already in the repo
   (`Duhaa/Duhaa.entitlements`, `DuhaaWidgets/DuhaaWidgets.entitlements`) or just
   let Xcode manage its generated ones — either is fine as long as both list the
   same group.

## Step 5 — Embed & verify

1. The app target's **Frameworks, Libraries, and Embedded Content** should list
   *DuhaaWidgets.appex* as **Embed Without Signing** (Xcode adds this when you
   create the extension). Verify it's there.
2. **Build the `DuhaaWidgets` scheme** (and the `Duhaa` scheme). Both should
   compile. Run the app once so it writes the first times payload.
3. Add a widget from the Home Screen and confirm it shows real times.

## Step 6 — Confirm the shared data path

- Mark a prayer **in the app** → the widget updates within a moment (the app calls
  `WidgetCenter.reloadAllTimelines()` after every completion change).
- Mark a prayer **in the widget** → reopen the app; the check is reflected (the app
  calls `tracker.reloadFromStore()` on foreground).
- If the widget shows "Open Duhaa to set up prayer times", the App Group isn't
  wired yet (the widget can't see the app's payload) — re-check Step 4 on **both**
  targets, and that the group string matches exactly.

---

## Migration behaviour (existing users keep their prayers)

`PrayerTracker` now persists to the App-Group suite (`UserDefaults.duhaaShared`)
instead of `.standard`. The first time anything touches that suite,
`SharedPrayerStore.migrateLegacyData(into:)` runs **once** (guarded by the
`duhaa.shared.migratedTrackerV1` flag) and copies the legacy `.standard` keys
(`duhaa.tracker.marks` / `lateMarks` / `lastOpened` / `theme`) into the suite if
the suite has no marks yet. It never deletes anything and never overwrites suite
data.

⚠️ **One caveat at entitlement-activation time:** before App Groups is enabled,
`UserDefaults(suiteName: "group.com.duhaa.app")` works but writes to an
*app-private* plist. After you enable the capability (Step 4), the same suite name
maps to the real shared container, which starts empty, and the migration flag is
already set — so on that one transition the app may appear to reset today's marks.
This only matters on the device the app already ran on pre-capability. Because the
app is still in device-testing (not submitted), the simplest fix is to delete the
app once after enabling App Groups, or clear the `duhaa.shared.migratedTrackerV1`
key so migration re-pulls from `.standard`. New installs are unaffected.

---

## Known limitations / notes

- **No Adhan in the widget.** The widget only reads the app-written times payload
  (`PrayerTimesPayload`, a 3-day rolling window). If the app isn't opened for 3+
  days the widget shows a graceful "Open Duhaa to refresh times" fallback rather
  than stale times.
- **Two-writer race:** if a prayer is toggled in the widget while the app is in the
  foreground holding stale in-memory marks, the next app write could clobber it.
  The app re-reads on foreground; in practice users don't toggle the widget while
  the app is open. Acceptable for v1.
- **Haptics stay in the app.** Widgets give feedback via the optimistic Toggle +
  reload only — never custom vibration.
- **Lock Screen privacy:** accessory widgets show the next prayer + progress only,
  never a detailed location/address.
