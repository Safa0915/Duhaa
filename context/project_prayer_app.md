---
name: project_prayer_app
description: "Islamic prayer app for iOS (Native SwiftUI), decisions made so far"
metadata: 
  node_type: memory
  type: project
  originSessionId: d5d52f45-e26e-4383-865b-8a2510acbb62
---

> 🚨 **EMERGENCY / KNOWN DEBT — HIGH-LATITUDE PRAYER TIMES (MUST FIX LATER):** The v1 solution for high-latitude (UK/N.Europe) Fajr/Isha is a STOPGAP, not a real fix. Proven with numbers that NO calculation/angle reproduces a real local mosque (even ELM's claimed 15° lands ~1hr off; the gap is seasonal). v1 ships: manual per-prayer OFFSET + a seasonal re-check reminder for high-lat users (absolute-time typing deliberately avoided — it drifts within weeks). This shifts setup burden onto the user and can still drift between seasonal rechecks. MUST revisit post-v1 with a proper fix: monthly-reference-point interpolation (Option B) and/or a reliable mosque-timetable source (Mawaqit was rejected as too shaky/gated — find/own an alternative). Treat as a real outstanding problem, not "done."

User is building an Islamic prayer iOS app named **Duhaa (ﺿﺤﻰ)** — see [[project_duhaa_first_launch]] for the first-launch cinematic, the emotional heart of the app. Decisions locked in so far:

- **App name:** Duhaa (Arabic for "morning brightness"; mission = hope/motivation to bring people back to all 5 daily prayers)
- **Framework:** **Native SwiftUI (Xcode)** — iOS-only for now; Android = future rewrite if ever. ⚠️ REVERSED the earlier React Native choice on 2026-06-07. Reasons: Duhaa is iOS-native-heavy (the cinematic's Core Haptics + animations, WidgetKit widgets, custom adhan notification sounds are all native work even in RN, eroding RN's cross-platform benefit), and the user wants to work IN Xcode with Claude. Tooling: Xcode 26 with Claude added as an Intelligence provider, and/or Claude Code in the repo. Min deployment target iOS 17+ (for @Observable / modern SwiftUI).
- **v1 features:** Prayer Times (home), Qibla compass, Quran reader, Duas, Settings — bottom tab bar in that order
- **Quran reader:** Arabic + Sahih International English, bundled offline (SQLite), bookmarks, surah/ayah nav, NO audio in v1
- **Duas:** occasion-based categories + dedicated "After Prayer" section, ~50–80 duas, Arabic + transliteration + English
- **Hijri date:** Umm al-Qura calendar, user chooses which date (Hijri/Gregorian) is primary/larger — both always shown, ±1–2 day manual adjustment in Settings for moon sighting
- **Onboarding:** 3 screens (welcome → location → calc method+madhab), no account, <60s — but the Duhaa cinematic plays first
- **Monetization:** free, voluntary "Support the App" IAP (~$2.99), NO paywalled features
- **State/storage:** Native SwiftUI — `@Observable`/`@State` for state, `@AppStorage`/UserDefaults for settings, SwiftData (or bundled SQLite/GRDB) for Quran/Duas content in v1.1. (Was Zustand + MMKV under the old React Native plan — no longer applies.)
- **Widgets:** small + medium + lock screen (all celestial theme)
- **Themes:** v1 = dark celestial only. v1.1 = light mode + "Sisters theme" (all pink celestial variant)
- **Apple Watch:** none in v1, complication in v1.1
- **Accessibility:** Enhanced — VoiceOver labels, dynamic type, RTL support, large tap targets
- **Testing:** unit tests for ALL calculations (prayer times vs known-good across cities/methods/madhabs, Tahajjud, Islamic midnight, Hijri); manual QA for UI
- **Motivation/habit loop (CORE to mission, in v1.0):** Gentle prayer tracking — soft "mark as prayed" tap per prayer + a quiet, beautiful progress view. Plus an encouragement layer (short reassuring verse/hadith after marking). ZERO guilt mechanics — NO broken-streak shaming, no "you failed". When a user returns after missing prayers, the app meets them like Surah Ad-Duhaa: "your Lord has not forsaken you" / "welcome back", never a scold. Hope, not guilt — the habit loop must embody the same thesis as the cinematic.
- **Team:** SOLO developer
- **Scope split (to actually ship):**
  - **v1.0 MVP:** Prayer times engine + Duhaa cinematic + notifications + Qibla + widgets + Settings + onboarding + gentle prayer tracking. Complete & special on its own.
  - **v1.1:** Quran reader + Duas + light mode + Sisters (pink) theme + Watch complication
  - Rationale: Quran/Duas are the heaviest content + least differentiated; shipping prayer-first gets to App Store sooner, protects momentum, gets real feedback.
- **Prayer time library:** **Adhan Swift** (`batoulapps/adhan-swift` via Swift Package Manager) — same algorithms as the adhan-js we validated with, incl. `SunnahTimes` (middleOfTheNight = Islamic midnight, lastThirdOfTheNight = Tahajjud). The Node `prayer-verify` harness stays as a cross-check reference.
- **Calculation method:** User-selectable on first launch
- **Asr madhab toggle:** "Shafi'i, Hanbali, Maliki" vs "Hanafi" (user picks)
- **Location:** GPS auto-detect with manual city override, cache last coords, "While Using" permission only
- **High latitude:** Auto-detect above ~48°N, apply "Middle of Night" silently, advanced toggle hidden in Settings
  - ⚠️ FIQH REALITY (researched via 3 scholarly sources — MuftiSays, Islam21c, SeekersGuidance): UK/high-lat Fajr & Isha are GENUINELY DISPUTED. All agree Fajr/Isha = 18° depression where a true sign exists, and that you must CALCULATE (not observe) in persistent summer twilight. They DISAGREE on the fallback: half/middle-of-night (tanṣīf al-layl) vs nearest-valid-day (aqrab al-ayyām); SeekersGuidance accepts both. Islam21c explicitly rejects the Hizbul Ulama observational timetable that East London Mosque & Regents Park use. Mosques in the SAME city differ by 1–2.5 HOURS. There is NO single correct number to compute.
  - HIGH STAKES: Fajr = suhoor/fast cutoff, so wrong Fajr can invalidate a fast. App must NOT present one high-lat number as authoritative.
  - DESIGN CONCLUSION: at high latitude, be humble + configurable. Offer multiple high-lat conventions (angle/18°, middle-of-night, 1/7th, ideally aqrab al-ayyām), MANUAL PER-PRAYER OFFSETS (universal escape hatch — match any mosque), a "follow your local mosque" framing + gentle "times estimated, consult local scholars" disclaimer.
  - TECH GOTCHA: `adhan` lib only ships 3 high-lat rules (MiddleOfTheNight, SeventhOfTheNight, TwilightAngle). It does NOT implement aqrab al-ayyām — that's custom code if needed. Manual offsets cover the gap in v1.
- **"SAFE ROUTE" — locked guiding principle (user chose this when overwhelmed by the fiqh dispute):** Duhaa NEVER claims to be the timing authority. (1) Normal latitudes: user-selected mainstream method → accurate times automatically. (2) High latitudes: NEUTRAL mainstream default + one gentle disclaimer ("Fajr & Isha estimated at your location, scholars differ — follow your local mosque"); do NOT silently pick a side. (3) Manual offsets are the universal safety net for any mismatch. (4) Do NOT hardcode any single UK timetable (e.g. ELM) — that takes a contested side; stay neutral & defer to the user's mosque. Default high-lat method stays "Middle of Night" (neutral), NOT a specific UK convention.
- **Manual per-prayer time offsets (v1 high-lat solution — LOCKED but flagged EMERGENCY, see top of file):** lets user nudge each prayer (esp. Fajr/Isha) ±minutes to match their mosque. Rides on top of daily calc so it auto-tracks day-to-day drift. Paired with a gentle SEASONAL re-check reminder ("times may have shifted with the season — recheck against your timetable") to handle seasonal drift. Absolute-time typing explicitly REJECTED (drifts within weeks). Monthly-reference-point interpolation (Option B, more accurate) deferred to v1.1+. Mawaqit/mosque-directory rejected (gated/unofficial APIs, too shaky to depend on).
- **Gentle precaution copy (LOCKED, warmer than a dry disclaimer):** Only the *fuzzy* boundaries get a caution, and only for high-latitude users. Note: Fajr's *start* (dawn/suhoor) is uncertain — its END (sunrise) is precise; Isha's *start* is uncertain. Copy:
  - Fajr card (high-lat): "Dawn is hard to pin down exactly here. To be safe, finish suhoor a little early — and don't rush to pray the moment Fajr begins."
  - Isha card (high-lat): "Isha's start is approximate here. Give it a few minutes before you pray."
  - Universal mission line (ALL users): "Pray each one on time — that's the heart of it."
  - Scope the "may not be exact" wording to high-latitude ONLY — never tell normal-latitude users their (accurate) times might be wrong.
  - Validated against East London Mosque (June 6): astronomical prayers matched great (Asr EXACT at 5:21, Sunrise/Dhuhr/Maghrib within 3–4 min mosque caution margins) — engine core is correct. Only Fajr (−106 min) & Isha (+145 min) diverged, purely due to high-lat convention, confirming the offsets need.
  - EMPIRICAL PROOF (test-london-angles.js): tried the claim that ELM uses 15° (not 18°). 15° moved Fajr 1:00→1:51 AM and Isha 12:59→12:11 AM — closer to ELM (2:46 / 10:34) but STILL ~55 min (Fajr) & ~1h37m (Isha) off. CONCLUSION: even with the "right" angle, pure calculation CANNOT reproduce a real London mosque (ELM layers seasonal/observational Hizbul Ulama adjustments). The safe route (manual offsets / bundled mosque timetable) is the ONLY way to be exact — proven with numbers, not opinion.
- **Angle reference (from research, for the method picker):** MWL 18°/17°, ISNA 15°/15°, Umm al-Qura 18.5° + FIXED 90-min Isha interval (not an angle — use adhan ishaInterval), Tehran 17.7°, ELM ~15° + own seasonal adj, Regents Park/London Central strict 18° + aqrab-al-ayyam in extreme season + Hanafi Asr.
- **DST gotcha (real engineering trap):** apps that hardcode UTC offsets show Maghrib ±1hr wrong twice a year. MUST always format times from the device's IANA timezone (e.g. Europe/London), NEVER a fixed +0/+1. adhan returns absolute UTC Date objects → formatting with IANA tz handles DST automatically. ADD regression tests around late-March & late-October DST transitions.
- **Jummah:** no fixed time — tied to Dhuhr but each mosque picks its own khutbah slot (12:30/1:00/1:20…). Consider a small "set your Jummah time" field. v1.1 nice-to-have.
- **Mosque-directory endgame (v1.1+):** real-world apps/sites (e.g. londonprayertime.co.uk, Prayers Connect) gave up on calculation and just let users pick their mosque & follow its published timetable. Natural evolution of "follow your mosque" — bundle/sync major-mosque timetables so user taps their mosque → exact times. Heavier (data upkeep) → post-v1.
- **Tahajjud:** Last third of the night (Maghrib → Fajr interval)
- **Islamic midnight:** Shown as end time of Isha directly on Isha card, with countdown ("Isha ends in X min") in last 30 minutes
  - ⚠️ EDGE CASE (found via verify.js): at high latitudes in summer (e.g. London June), calculated Isha can fall AFTER the Islamic midnight (night midpoint), making "Isha ends at Islamic midnight" contradictory (would end before it starts). Engine must handle this gracefully — e.g. clamp/hide the "ends" countdown when Isha > Islamic midnight, or fall back to a high-lat night rule. Verify per-city before trusting.
- **Verification harness:** `Desktop/claudeTesting/prayer-verify/verify.js` — Node + `adhan` lib, computes 5 prayers + SunnahTimes (middleOfTheNight = Islamic midnight, lastThirdOfTheNight = Tahajjud) for several cities. Use to diff against IslamicFinder/local mosque. RULE: match method + madhab + high-lat rule exactly on both sides before comparing; a mismatch there is config, not a bug.
- **Adhan notifications:** Per-prayer control (audio vs silent vs off), bundled Makkah + Madinah recordings, offline only
- **Notification scheduling (iOS gotcha):** iOS caps pending local notifications at ~64 and prayer times change daily. Pattern: pre-schedule a ROLLING WINDOW of ~10–12 days (stay under 64), each with that day's exact computed time, and RE-FILL the window every time the app opens (the reliable trigger). Use BGAppRefreshTask to top up opportunistically but NEVER depend on it. Works offline (times computed locally).
- **Pre-prayer reminders:** Supported but OPTIONAL and OFF by default (e.g. "Maghrib in 15 min") — keeps the 64-slot budget healthy for users who don't enable them.
- **UI aesthetic:** Dark/celestial — APPROVED FINAL COLORS (do not change these):
  - App background: `#0D1628` (dark navy, not pitch black)
  - Page bg: `#08111F`
  - Gold accent: `#F0C040` / `rgba(240, 192, 64, ...)` — vivid warm gold, used for highlights, active prayer, progress bar, moon
  - Blue accent: `#8ECFE8` / `rgba(142, 207, 232, ...)` — electric sky blue, used for location, date, labels, night card
  - Card bg: `rgba(255, 255, 255, 0.07)` with `rgba(255,255,255,0.13)` border
  - Prayer time text: `rgba(255,255,255,0.8)`
  - Active prayer: gold left bar + gold time + gold "Next" badge + subtle gold glow background
  - Night card: blue-tinted with `rgba(142, 207, 232, 0.22)` border
  - Phone frame border: `rgba(142, 207, 232, 0.2)`
  - Reference file: `design-1-celestial.html` on Desktop/claudeTesting

**Why:** User wants smooth, lightweight, visually appealing app. Not heavy or bloated.
