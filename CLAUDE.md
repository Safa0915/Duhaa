# Duhaa (ﺿﺤﻰ) — Claude Code project context

> Native **iOS 17+ SwiftUI** prayer app, built on **hope, not guilt** — gently bringing people back to the five daily prayers. Named after Surah Ad-Duhaa.

**New session? Read `docs/DUHAA_HANDOFF.md` first** — it's the up-to-date state of the app. (`DUHAA_SPEC.md` + `context/` hold original design rationale, but parts are now historical — trust the handoff + the code for current truth.)

## Status (2026-06-15)
Feature-complete v1 app, **not yet submitted** (dev hasn't paid the $99 Apple Developer fee — staying in device-testing mode). Builds clean, **103 tests pass**. Pushed to GitHub `Safa0915/Duhaa` (branch `main`).

## Design — LOCKED, do not change
- **Calm, premium, Islamic.** Dark celestial: bg `#0D1628`, gold `#F0C040`, blue `#8ECFE8`, card `rgba(255,255,255,0.07)`. Rounded cards, generous spacing.
- Themes: `dark` (Celestial, default), `light` (Dawn), `sisters` (Rose) — `AppTheme` in `Duhaa/Theme/Palette.swift`.
- **No flashy / game-like animation** — no confetti, particles, mascots. Motion is subtle and purposeful (gold swells, shimmer skeletons). Always respect Reduce Motion.
- Fonts: `.duhaaFont(size, weight)` (Dynamic Type). Arabic: bundled KFGQPC Uthmani font via `QuranFont`.

## Religious-content rules (non-negotiable)
- **Source-backed.** Every claim cites a source; **never label content "Verified"** until a scholar reviews it (see `docs/scholar-review.md`). Prefer "Source provided" or a grade + grader.
- **Arabic + transliteration + English** for du'as/adhkar/guide steps.
- **Learn / Du'a UI:** source chips + an expandable "Evidence" disclosure (source · grade · grader). Pattern lives in `Duhaa/Learn/` and `Duhaa/Duas/`.
- **Madhhab differences:** where schools differ, add a neutral "Madhhab note" rather than asserting one ruling. The app only declares a school for Asr timing (Standard/Hanafi).
- Salafi methodology for Learn (Quran + sahih/hasan, weak narrations omitted). High-latitude Fajr/Isha = known unsolved debt — never present as authoritative.

## Hard product rules
- **No halal-food / restaurant finder.** Ever.
- **Nearby Mosques is MapKit-only** (`MKLocalSearch`/CoreLocation) — no Google/Yelp/OSM, no API key, no analytics, no background tracking.
- **Interactive prayer widget** (planned, not built): WidgetKit + `AppIntent` (Toggle/Button) + **App Group shared storage**. Persist in `perform()` before returning, then `WidgetCenter.reloadTimelines`. **Custom haptics stay in the main app only** — never required from the widget.
- **No third-party packages** unless explicitly asked. Only dependency is Adhan Swift (SPM). No analytics, ever.
- Don't break existing features: Prayer, Qibla, Quran, Du'as, Learn, Tasbih, Nearby Mosques, Membership, Notifications, Ramadan, Journey/tracking.

## Architecture / conventions
- State: `@Observable` + `@AppStorage`; persistence: `UserDefaults` (keys prefixed `duhaa.*`) + bundled JSON (Quran/du'as/learn/reciters).
- **Xcode 16 synchronized folder groups (`objectVersion 71`):** new `.swift` files dropped into `Duhaa/…` auto-join the app target — no `project.pbxproj` surgery. ⚠️ A **widget extension is a separate target**; its files do NOT auto-join and need manual Xcode setup.
- Bundle id `com.duhaa.app`. Tracking store: `Duhaa/Tracking/PrayerTracker.swift` (`@Observable`, `init(defaults:)` for tests). Haptics: `Duhaa/Theme/DuhaaHaptics.swift` (CoreHaptics, main app only).
- Memory lives in `~/.claude/projects/-Users-safagokdemir-Desktop-Duhaa/memory/` (read `MEMORY.md`).

## Build / test
```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
# Full suite (iPhone 17 sim — adjust the id via `xcrun simctl list devices available`)
xcodebuild test -scheme Duhaa -destination 'id=77A5968F-1D12-4B45-B6E9-CA5F4DA115B9' -derivedDataPath build/DerivedData
# Device install (dev's iPhone; needs the phone unlocked)
xcodebuild -scheme Duhaa -destination 'id=<device-id>' -derivedDataPath build/DeviceDD -allowProvisioningUpdates build
xcrun devicectl device install app --device <device-id> build/DeviceDD/Build/Products/Debug-iphoneos/Duhaa.app
```
Commit only when asked; end commit messages with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
