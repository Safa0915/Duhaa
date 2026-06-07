# Duha (ﺿﺤﻰ) — project context for Claude Code

> An iOS prayer app built on **hope, not guilt** — to gently bring people who don't pray, or barely pray, back to all five daily prayers. Named after Surah Ad-Duha ("the morning brightness" / "your Lord has not forsaken you").

**If you are a fresh Claude session: read `DUHA_SPEC.md` first — it is the full, authoritative spec.** The `context/` folder holds the original locked decision docs from the design session.

## Current status
- **Design: complete & locked.** Every decision is in `DUHA_SPEC.md`.
- **Engine: not yet built.** The prayer-time logic (adhan + Tahajjud/Islamic-midnight + offsets + Hijri) is the next thing to build — pure TypeScript, fully unit-testable, the riskiest/most important piece.
- **App shell: not started.** React Native, to be built/run on macOS + Xcode.

## How to work on this project
- **Build target:** iOS first (Android-ready later). Needs macOS + Xcode for the app shell, widgets, Core Haptics, simulator, signing.
- **Stack:** React Native (recommend **Expo prebuild** — config plugins + dev client, for native access to widgets/haptics/notifications), `adhan` library, Zustand, MMKV, bundled SQLite (offline).
- **Verification harness:** `prayer-verify/` — Node scripts that compute times with `adhan` and were validated against East London Mosque. Run `cd prayer-verify && npm install && node verify.js`.

## 🚨 Read before touching prayer-time logic
High-latitude (UK/N.Europe) **Fajr & Isha are a KNOWN EMERGENCY / unsolved debt** — see the banner at the top of `context/project_prayer_app.md` and §13 of `DUHA_SPEC.md`. No calculation reproduces a real local mosque (proven with numbers). v1 ships a stopgap (manual offsets + seasonal re-check); it must be properly fixed later. Do NOT present any high-lat number as authoritative.

## The "Duha moment" (first-launch cinematic)
The emotional heart of the app, to be built in its own focused session. Full storyboard in `context/project_duha_first_launch.md` and §2 of `DUHA_SPEC.md`. Handle with care; do not cheapen it.

## Design / palette (LOCKED — do not change)
Dark celestial. bg `#0D1628`, gold `#F0C040`, blue `#8ECFE8`, card `rgba(255,255,255,0.07)`. Reference mockup: `design/design-1-celestial.html`.
