# Duhaa — Build Plan (execute in order)

> Read alongside `CLAUDE.md` and `DUHAA_SPEC.md`. Build **engine-first, in thin vertical slices.** Do ONE slice at a time. Each slice: build → review → test/verify → **commit + push** before starting the next. The cinematic is LAST. Ship to TestFlight as soon as Slice 5 works.

## Working rules
- **The dev reviews and understands every slice.** Claude writes the code; the dev makes the decisions and must be able to debug it. No 1,000-line dumps.
- **The Node `prayer-verify/` harness is the test oracle.** The Swift engine's unit tests must reproduce its numbers (e.g. London Fajr 1:00 AM, Mecca Maghrib 7:01 PM, Mecca Islamic midnight 11:37 PM, Mecca Tahajjud 1:09 AM).
- **Commit after every working slice** (`git add -A && git commit && git push`).
- **Scope is law:** only the v1.0 slices below. Everything else → v1.1 backlog in the spec.
- **Test on a real iPhone early** — notifications, location, and widgets behave differently than the Simulator.

---

## Slice 0 — Project setup
**Goal:** A running "Hello world" SwiftUI app inside the repo, with Adhan Swift added.
**Done when:** `Duhaa.xcodeproj` exists under `~/Desktop/Duhaa`, Adhan Swift package resolves, app runs in the Simulator, no nested git repo.
**Prompt:** *"Guide me through creating the Duhaa Xcode project (SwiftUI, iOS 17+, Include Tests, save in ~/Desktop/Duhaa, DON'T create a git repo). Then walk me through adding the Adhan Swift package (github.com/batoulapps/adhan-swift). Confirm it builds and runs."*

## Slice 1 — Prayer engine (the foundation) ⭐
**Goal:** A tested Swift engine: 5 prayers + Tahajjud + Islamic midnight + per-prayer manual offsets + method/madhab/high-lat config.
**Done when:** Unit tests pass and reproduce the `prayer-verify` numbers for Mecca, London, New York, Jakarta, Karachi. High-lat Isha>midnight edge case handled gracefully (see spec §13).
**Prompt:** *"Build the prayer engine as a Swift module in the Duhaa target with unit tests, using Adhan Swift. Include 5 daily prayers, SunnahTimes (Tahajjud = lastThirdOfTheNight, Islamic midnight = middleOfTheNight), method + madhab + high-latitude config, and manual per-prayer offsets. Write XCTest cases asserting the exact times from prayer-verify. Mind the high-latitude emergency note in the spec."*

## Slice 2 — Prayer home screen
**Goal:** The celestial main screen showing today's times, next-prayer highlight, Isha "ends at Islamic midnight", and the Night Prayer card.
**Done when:** It matches the locked palette/design (`design/design-1-celestial.html`) and shows live engine data for the device's location (hardcode a location for now if needed).
**Prompt:** *"Build the Prayer home screen in SwiftUI matching design/design-1-celestial.html and the locked palette in the spec. Wire it to the Slice 1 engine. Include the next-prayer highlight, Isha end-time + countdown, and the Night Prayer card (Tahajjud + Islamic midnight)."*

## Slice 3 — Location
**Goal:** Real location drives the times.
**Done when:** CoreLocation "While Using" permission, GPS auto-detect, cached last coordinates (works offline), and a manual city override.
**Prompt:** *"Add CoreLocation: While-Using permission, GPS auto-detect, cache last coordinates for offline, and a manual city search override. Feed coordinates into the engine."*

## Slice 4 — Settings that drive the engine
**Goal:** User can change method, madhab ("Shafi'i, Hanbali, Maliki" vs "Hanafi"), Hijri primary/offset, and per-prayer time offsets — and the screen updates.
**Done when:** Settings persist (@AppStorage) and changing them re-computes times live. High-lat users see the gentle disclaimer + offset UI from the spec.
**Prompt:** *"Build the Settings screen: calculation method, Asr madhab toggle, Hijri primary/adjustment, and per-prayer manual offsets with the high-latitude disclaimer + seasonal re-check reminder from the spec. Persist with @AppStorage and re-compute live."*

## Slice 5 — Notifications  → 🚀 ship to TestFlight after this
**Goal:** Reliable prayer-time notifications.
**Done when:** Rolling ~10–12 day window, re-filled on app open, per-prayer audio/silent/off (bundled Makkah + Madinah), optional pre-prayer reminders (off by default). Tested on a real device.
**Prompt:** *"Implement local notifications with the rolling-window scheduler from the spec (≤64 pending, refill on app open, BGAppRefreshTask as backup). Per-prayer audio/silent/off with bundled adhan sounds; optional pre-prayer reminders off by default."*

## Slice 6 — Prayer tracking (the mission)
**Goal:** Gentle "mark as prayed" + quiet progress + encouragement. ZERO guilt mechanics.
**Done when:** Tap to mark each prayer, a calm progress view, reassurance on return after misses ("welcome back", never a scold).
**Prompt:** *"Build gentle prayer tracking per the spec's motivation loop: mark-as-prayed per prayer, a quiet beautiful progress view, encouragement after marking, and a warm 'welcome back' when returning after missed prayers. No streaks-shaming."*

## Slice 7 — Qibla
**Prompt:** *"Build the Qibla compass tab (device heading + great-circle bearing to Makkah) with a clean celestial-themed UI."*

## Slice 8 — Widgets
**Prompt:** *"Add a WidgetKit extension: small (next prayer + countdown), medium (next + all 5), and lock-screen widget. Celestial theme. Share the engine via an App Group."*

## Slice 9 — Onboarding
**Prompt:** *"Build the 3-screen onboarding (welcome → location → method+madhab), no account, under 60s, leading into the app."*

## Slice 10 — The Duhaa cinematic (LAST, its own track) 🌅
**Goal:** The first-launch chills moment. **The app already works without it.**
**Done when:** Matches the storyboard in `context/project_duhaa_first_launch.md` (tap ×3 → pitch black → basmala → light-switch sound → recitation → light hits on "Wad-Duhā"), skippable, plays once, replayable from Settings.
**Note:** Do this in a dedicated Claude session. Needs the dev's own recitation recorded first.

## Slice 11 — Polish & ship
Accessibility (VoiceOver, Dynamic Type, RTL), DST regression tests (late-Mar / late-Oct), empty/edge states, App Store assets → submit.

---

## The finish line
**Done = on real iPhones via TestFlight, used daily for actual prayers — not flawless.** Get there by Slice 5, then iterate. Hold scope, commit every slice, keep the engine matching the harness, and you'll actually ship it. 🌅
