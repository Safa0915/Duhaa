# Duhaa (ﺿﺤﻰ) — project context for Claude Code

> An iOS prayer app built on **hope, not guilt** — to gently bring people who don't pray, or barely pray, back to all five daily prayers. Named after Surah Ad-Duhaa ("the morning brightness" / "your Lord has not forsaken you").

**If you are a fresh Claude session: read `DUHAA_SPEC.md` first — it is the full, authoritative spec.** The `context/` folder holds the original locked decision docs from the design session.

**Full design-session transcript** (the complete "why" behind every decision) is archived in `docs/design-session.md` (conversation + decisions) and `docs/design-session-full.md` (also includes tool outputs: the prayer-time verifications, the East London Mosque comparison, and the high-latitude fiqh research). Read these if you need the reasoning behind a decision — but `DUHAA_SPEC.md` + `BUILD_PLAN.md` are the day-to-day source of truth.

## Current status
- **Design: complete & locked.** Every decision is in `DUHAA_SPEC.md`.
- **Framework: NATIVE SwiftUI (Xcode).** Switched from React Native on 2026-06-07 — Duhaa is iOS-native-heavy (cinematic Core Haptics, WidgetKit, custom sounds) and the dev wants to work in Xcode. iOS-only for now; Android = future rewrite if ever.
- **Engine: not yet built.** The prayer-time logic (Adhan Swift + Tahajjud/Islamic-midnight + offsets + Hijri) is the next thing to build — as a Swift module with unit tests, the riskiest/most important piece.
- **App shell: not started.** SwiftUI app, built/run in Xcode on macOS.

## How to work on this project
- **Build target:** iOS-only (SwiftUI), min deployment iOS 17+. Built and run in Xcode.
- **Stack:** Native **SwiftUI**, **Adhan Swift** (`batoulapps/adhan-swift` via Swift Package Manager), state via `@Observable`/`@AppStorage`, persistence via UserDefaults (settings) and SwiftData/SQLite (Quran/Duas in v1.1). Widgets = WidgetKit; haptics = Core Haptics; notifications = UserNotifications; audio = AVFoundation.
- **Verification harness:** `prayer-verify/` — Node scripts (adhan-js) validated against East London Mosque. Keep as a cross-check reference for the Swift engine's output: `cd prayer-verify && npm install && node verify.js`. The Swift engine should reproduce these same numbers.

## 🚨 Read before touching prayer-time logic
High-latitude (UK/N.Europe) **Fajr & Isha are a KNOWN EMERGENCY / unsolved debt** — see the banner at the top of `context/project_prayer_app.md` and §13 of `DUHAA_SPEC.md`. No calculation reproduces a real local mosque (proven with numbers). v1 ships a stopgap (manual offsets + seasonal re-check); it must be properly fixed later. Do NOT present any high-lat number as authoritative.

## The "Duhaa moment" (first-launch cinematic)
The emotional heart of the app, to be built in its own focused session. Full storyboard in `context/project_duhaa_first_launch.md` and §2 of `DUHAA_SPEC.md`. Handle with care; do not cheapen it.

## Design / palette (LOCKED — do not change)
Dark celestial. bg `#0D1628`, gold `#F0C040`, blue `#8ECFE8`, card `rgba(255,255,255,0.07)`. Reference mockup: `design/design-1-celestial.html`.
