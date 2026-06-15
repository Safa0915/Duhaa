# Duhaa — Project Handoff (for a fresh Claude Code session)

_Last updated: 2026-06-15. Read this first, then `CLAUDE.md`._

## 1. Vision
Duhaa (ﺿﺤﻰ, "the morning brightness") is a native iOS 17+ SwiftUI prayer app built on **hope, not guilt** — to gently bring people who don't pray (or barely do) back to all five daily prayers. Calm, premium, Islamic. It celebrates only what's prayed, never shames a miss. Named after Surah Ad-Duhaa ("your Lord has not forsaken you").

## 2. Current state
- **Feature-complete v1**, builds clean, **103 tests pass** (1 StoreKit test skips unless the full Xcode toolchain is the system default).
- On GitHub `Safa0915/Duhaa`, branch `main` (a stale `codex` branch exists; ignore/refresh before reuse).
- **Not submitted.** Dev has NOT paid the $99 Apple Developer fee — deliberately staying in device-testing mode. Free provisioning means the app on the dev's iPhone expires ~weekly and needs reinstalling (normal, not a bug).
- Dev's main computer is **Windows**; this Mac is for builds. Editing/commits happen from Windows via Claude Code; builds/Simulator/signing need the Mac. (CI/Mac mini is the eventual plan; see memory `quran-foundation-api-plan` / pre-launch notes.)

## 3. Implemented features (by folder under `Duhaa/`)
- **Home / Prayer** (`Home/`): live clock, next-prayer countdown, today's 5 prayers with check circles, Verse of the Day, Night card (Tahajjud/Islamic midnight), Ramadan card (seasonal), a **Nearby Mosques** entry card. Fajr row shows "ends at sunrise H:MM"; Isha shows "ends at Islamic midnight H:MM".
- **Tracking** (`Tracking/`): `PrayerTracker` (`@Observable`) — marks, streaks (with grace), insights (on-time/late/missed, opt-in), Journey view (heatmap, milestones). Marking a prayer plays a gold swell + "winning" CoreHaptic; 5/5 has an extra flourish.
- **Engine** (`Engine/`): Adhan Swift wrapper + Tahajjud/Islamic-midnight, method/madhab/high-lat config, manual offsets, Hijri.
- **Quran** (`Quran/`): full offline Quran (Uthmani Arabic + **ClearQuran / Talal Itani "Allah" edition** English — CC-licensed, replaced Saheeh Intl); searchable list, reader with per-ayah bookmarks, audio streaming from **Quran Foundation CDN** (9 reciters, `reciters.json`), reciter picker, Arabic size, tajweed toggle, audio cache. Verse of the Day.
- **Du'as** (`Duas/`): two curated categories only — **Wudu & Purification** (4) and **After Prayer Adhkar** (8). Cards: Arabic (Uthmani) + transliteration + English + source. The Hisnul-Muslim bulk set was removed pending curation (in git history).
- **Learn** (`Learn/`): offline education — 9 guides (Wudu/Ghusl/Tayammum/How to Pray/Differences per Prayer/Dhikr after Prayer/Sujud al-Sahw/Tawbah/Coming Back to Prayer). Each step: instruction + Arabic/translit/translation + a collapsible **Evidence** disclosure (source · grade · grader). Content in `learn_guides.json`. **See `docs/learn-content-review.md`** for the full text to verify.
- **Membership** (`Membership/`): Duhaa+ StoreKit 2 paywall — 3 tiers (Hilal/Fajr/Duhaa) × monthly/annual, benefits screen, restore/manage/redeem. Local `Duhaa.storekit` config drives testing without the paid account. **Perks are not all real yet — must be true before charging.**
- **Nearby Mosques** (`Mosques/`): MapKit-only finder (see §8).
- **Others**: Qibla compass, Tasbih counter, Notifications (per-prayer adhan/silent/off, Friday Jumu'ah, soft `duhaa-chime.wav`), Onboarding (4 steps), customizable tab bar (`Tabs/`), Settings (`Settings/` — sectioned, profile/appearance/prayer/quran/privacy/help/about), Support (hidden for v1), Acknowledgements/About, privacy + scholar-review docs.

## 4. Recent work (newest first, see `git log`)
- **Nearby Mosques** + shimmer loading skeletons (`3b21cc6`).
- **`.gitattributes`** for LF line endings (Windows editing safety) (`b6bc649`).
- **Removed women's cycle / Sisters section** — parked, restore via `git revert cdb726e`; everything preserved in checkpoint `c6506e7`.
- Before that: new app icon, ClearQuran translation swap, App Store readiness (privacy manifest, iPhone-only/portrait, export-compliance), curated du'as, Du'a Arabic comma fix.

## 5. Learn section — status & direction
Built and shipping. 9 guides, evidence-first (source chips + expandable grade/grader). Salafi methodology: Quran + sahih/hasan only; the only non-sahih are **two hasan** narrations (Tirmidhi 3474/3534; Ibn Majah 4252). **Unverified-but-sourced** — needs an imam to confirm references/grades before any "verified" claim. Future "Learn" could also host Sahw deep-dive, Wudu Q&A for everyone, and Hajj/Umrah (memory notes exist).

## 6. Du'a / Adhkar content — status
Two curated, source-cited categories live (Wudu, After Prayer Adhkar). Sources named (Bukhari/Muslim/Tirmidhi/Abu Dawud/Nasa'i numbers). NOT marked "Verified." The bulk Hisnul Muslim import was pulled until each category gets the same curation + review.

## 7. Source verification & madhhab strategy
- **Verification:** all religious content is "source-provided," never "Verified," until a qualified scholar signs off. `docs/scholar-review.md` is the single checkbox doc covering every religious claim (prayer-window rules, Sisters Q&A [parked], adhkar citations, Learn guides, notification copy). Hand this to an imam before launch.
- **Madhhab-sensitive content:** present the dalil-grounded position, then a neutral **"Madhhab note"** where schools differ (e.g., sujud al-sahw before/after salam, witr forms). The app declares a school only for Asr timing (Standard vs Hanafi). Don't assert one madhhab as "the" ruling.

## 8. Nearby Mosques — status (DONE)
MapKit-only (`MKLocalSearch` × `mosque`/`masjid`/`islamic center`, merged/deduped/sorted/capped 15). Reuses the existing `LocationProvider` (no second location manager). Cards: name, distance, address, Directions (Apple Maps), Call/Website (only if data exists). Testable seams: `LocationProviding` / `MosqueSearching` / `MapsOpening` with fakes (~31 tests). Loading = shimmer skeletons. **Rules: no food places ever, no third-party API/key, no analytics, no background tracking.** Manual QA: `docs/nearby-mosques-qa.md`.

## 9. Light Pink theme (FUTURE idea, not built)
A soft **light pink** theme: gentle pink palette, a subtle **flowing-hearts background** (calm, slow, Reduce-Motion-aware — not flashy), cozy/feminine/calm feel. Optional, user-selectable in Settings → Appearance alongside dark/light/sisters. Keep it premium and understated (no particle spam). The existing `sisters` (Rose) theme is a starting point but this is a distinct, softer direction. (Note: the women's cycle/Sisters *section* is removed/parked — this is purely a color theme, unrelated.)

## 10. Interactive prayer widget — PLAN (next likely feature, NOT built)
Goal: mark prayers as prayed directly from a Home/Lock-Screen widget.
- **Architecture:** iOS 17 WidgetKit + `AppIntent` (prefer **Toggle** for optimistic UI, **Button** fallback). `perform()` loads shared store → validates prayer+date → updates → **persists before returning** → `WidgetCenter.shared.reloadTimelines`. No UI/haptics in the intent.
- **Shared storage (the key prerequisite):** today `PrayerTracker` writes to **`UserDefaults.standard`** (keys `duhaa.tracker.marks` = `[dayKey: Set<prayerRaw>]`, `duhaa.tracker.lateMarks`, `duhaa.tracker.lastOpened`; `dayKey` = `PrayerTracker.dayKey(date, tz)` "yyyy-MM-dd"). For a widget to share state, migrate this to an **App Group** suite (`UserDefaults(suiteName:)`) read/written by both targets. `PrayerTracker(defaults:)` already takes an injectable suite — point app + widget at the same group.
- **Status model:** marks are boolean prayed/unprayed per `Prayer` (fajr/dhuhr/asr/maghrib/isha) per dayKey, plus a parallel `lateMarks` set (on-time vs late). Widget MVP = toggle unmarked↔prayed; **don't wipe the late/on-time nuance** — when marking prayed from the widget, mirror the app's `toggle(_:dayKey:onTime:)` default. Don't mark future prayers if the app wouldn't.
- **Haptics:** **main app only** (`DuhaaHaptics`, CoreHaptics). Widget gives feedback via checkmark state + subtle tint + reload. Never promise widget vibration.
- ⚠️ **Manual Xcode setup required (cannot be safely automated via pbxproj):**
  1. Add a **Widget Extension** target (e.g. `DuhaaWidgets`).
  2. Enable **App Groups** capability on BOTH the app target and the widget target; create group id **`group.com.duhaa.app`** (constant in code; do NOT hardcode a Team ID).
  3. Add the shared files (the App-Group store + `Prayer` enum + intent) to **both** targets' membership.
  4. Verify bundle ids (`com.duhaa.app`, widget `com.duhaa.app.<widget>`).
  5. Build the widget target.
  Synchronized folder groups only auto-add files to the **app** target — widget files must be added manually.

## 11. Next-priority options (pick one)
1. **Interactive prayer widget** (§10) — high impact, but needs the manual Xcode target + App Group setup, and realistically the $99 account for App Group entitlements on device.
2. **Light Pink theme** (§9) — pure SwiftUI, no account needed, ships from Windows-edit + CI.
3. **The Duhaa cinematic** (first-launch moment) — code-ready; blocked only on the dev recording Surah Ad-Duhaa.
4. **Imam review** of `docs/scholar-review.md` (human task, gates "verified" content).
5. **GitHub Actions CI** (build+test on macOS runner) — was requested; not yet added. Would give a green-check safety net for Windows editing.

## 12. Known risks / do-NOT list
- Don't mark religious content "Verified" pre-review. Don't assert one madhhab as the ruling.
- Don't add a halal-food finder, third-party packages (besides Adhan), or analytics.
- Don't break existing features when refactoring shared types (`PrayerTracker`, `Prayer`, themes).
- Don't add flashy/game animations. Respect Reduce Motion everywhere.
- High-latitude Fajr/Isha is unsolved — never present as authoritative.
- Membership perks must be REAL before charging; ClearQuran license is non-commercial (revisit before monetizing); Quran Foundation API is registered under a placeholder "Cekilis" account (re-register as Duhaa before launch). See memory notes.

## 13. Manual setup notes
- **Widget:** the §10 manual Xcode steps (target + App Group).
- **Toolchain for StoreKit tests:** `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` makes the 1 skipped StoreKit test run.
- **Privacy policy** is live at `https://safa0915.github.io/duhaa/privacy.html` (canonical copy `docs/privacy.html`).
- Memory dir (cross-session facts): `~/.claude/projects/-Users-safagokdemir-Desktop-Duhaa/memory/` — start at `MEMORY.md`.
