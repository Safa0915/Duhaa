# Duhaa Widgets — manual QA checklist

_Run after completing `docs/widgets-setup.md`. Test on a **real iPhone**, not only
the Simulator (App Groups + interactive intents behave most truthfully on device)._

## Add & families
- [ ] Add the **Small** widget ("Next Prayer").
- [ ] Add the **Medium** widget ("Today's Prayers").
- [ ] Add the **Large** widget ("Prayer Day").
- [ ] Add a **Lock Screen** accessory (rectangular / circular / inline).

### Expanded suite (2026-06-17)
- [ ] **Next Prayer Countdown** (Lock Screen circular + rectangular): rectangular countdown ticks live every second; the circular ring fills as the window elapses (steps every few min).
- [ ] **Prayer Tracker** (Lock Screen circular + rectangular): circular shows X/5; on the rectangular, **tap each of F D A M I** — the symbol flips and it sticks; open the app to confirm it synced.
- [ ] **Morning Times** + **Evening Times** (Lock Screen rect + circular): Morning = Fajr/Sunrise/Dhuhr, Evening = Asr/Maghrib/Isha; circular shows the group's next prayer.
- [ ] **Hijri Date** (Lock Screen circular + inline): inline reads "D Month YYYY"; matches the app's home Hijri (incl. the user's offset).
- [ ] **7-Day Grid**: Lock Screen accessory (monochrome 7×5) + Home **systemSmall** (color 7×5). Confirm it's gentle consistency, **no streak counter**.
- [ ] **Daily Du'a** (Home medium): shows today's du'a (Arabic + English + source); tapping opens the Du'as tab.
- [ ] **Verse & Hadith** (Home medium + large): shows today's Quran verse and sourced hadith together; large includes the Quran Arabic; tapping opens the Prayer tab.
- [ ] Confirm state is legible **monochrome** on the Lock Screen (fill/symbol, not color) and **color** on Home.

## Theme parity
- [ ] In the app set **Classic Duhaa** — widgets show deep navy + warm gold, calm
      crescent watermark, readable text.
- [ ] Switch to **Light Pink** — widgets re-skin to soft pink/rose with very faint
      static hearts; text stays readable; hearts are not overdone on small.
- [ ] (Optional) Sky / Rose themes also render sensibly.

## Interactivity (Medium & Large)
- [ ] Tap **Fajr**'s toggle → only Fajr flips; the others don't move.
- [ ] The completion ring / "n of 5" updates.
- [ ] Tap to **un-mark** a prayer → it clears; count decrements.
- [ ] Toggling a prayer does **not** reset the rest of the day.

## App ⇆ widget sync
- [ ] Mark a prayer **in the app** → the widget reflects it shortly after.
- [ ] Mark a prayer **in the widget** → open the app → the app shows it checked.
- [ ] Force-quit and relaunch the app → completed prayers persist.
- [ ] Remove and re-add the widget → completed prayers persist.

## Time / day behaviour
- [ ] Before a prayer time: that prayer is highlighted as **NEXT**; countdown reads
      sensibly ("in 2 hr").
- [ ] After a prayer time passes: **NEXT** advances to the following prayer.
- [ ] After **Isha**: small/medium/large show tomorrow's **Fajr** as next
      ("NEXT · TOMORROW").
- [ ] Cross **midnight** (or change device date): the day rolls over, progress
      resets to 0/5, times update.

## Graceful fallback
- [ ] Fresh install / no location yet → widget shows **"Open Duhaa to set up prayer
      times"** (never blank, never crashes).
- [ ] Don't open the app for 3+ days (or clear the payload) → widget shows **"Open
      Duhaa to refresh times"** but still shows the day's completion.

## Accessibility & rendering
- [ ] **VoiceOver**: each prayer toggle reads "Mark Asr as prayed, 4:47 PM" /
      "Asr prayed, 4:47 PM"; the ring reads "n of 5 prayers prayed today".
- [ ] **Reduce Motion** on: widgets are static (no motion to disable, but verify
      nothing animates jarringly).
- [ ] **Larger text / Dynamic Type**: prayer names + times stay legible (they scale
      / truncate gracefully, not clipped).
- [ ] **Tinted / dark Home Screen** widget mode: text and accents stay readable;
      completion isn't conveyed by color alone (check glyph + count present).
- [ ] **Lock Screen tint**: accessory widgets are legible when system-tinted.

## Privacy
- [ ] Lock Screen accessory shows next prayer + progress only — **no** street
      address / detailed location.

## Regression
- [ ] App's own Prayer tab still marks/unmarks correctly (haptics + swell intact).
- [ ] Journey / streaks / insights unaffected by the storage move.
- [ ] Full unit suite still green (`xcodebuild test -scheme Duhaa …`).
