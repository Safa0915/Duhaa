# Duha (ﺿﺤﻰ) — Product Specification

> An iOS prayer app built on hope, not guilt — to gently bring people who don't pray, or barely pray, back to all five daily prayers.

*Last updated: 2026-06-06 · Status: design locked, ready to build v1.0*

---

## 1. Vision & Mission

**Duha** means *"the morning brightness."* Named after Surah Ad-Duha — the surah of hope, revealed when the Prophet ﷺ felt abandoned, with Allah reassuring him *"your Lord has not forsaken you."*

The app's thesis: the dark celestial theme is the **night**; the whole app is the invitation to the **dawn**. The name, the aesthetic, the mission, and the opening moment all collapse into one idea. Every design choice serves **hope, not guilt** — a struggling person should feel welcomed back, never scolded.

---

## 2. The Duha Moment (first-launch cinematic) — the emotional heart

> Built in its own dedicated session. This is the soul of the app — handle with extreme care, do not cheapen.

Plays on **very first launch only**. Skippable ("Skip" fades in after ~4–5s). Never auto-plays again, but replayable later (dawn icon / Settings → About Duha).

**Storyboard (revised & locked by user):**
1. **Tap three times, in the black** — app opens pitch black with a minimal "tap three times" prompt. The user *chooses* the dawn (active participation).
2. **Pitch black holds** — darkness sustains briefly (the "held breath").
3. **Basmala (~1.5s after the taps)** — *"Bismillāhi-r-Raḥmāni-r-Raḥīm"* in the dark.
4. **Light switch sound** — an audio cue marking the light turning on. *(User explicitly wants a "light switch" sound — this overrides the earlier "organic swell only" note.)*
5. **The recitation begins** — the creator's own recitation of Surah Ad-Duha.
6. **Lights hit on Surah Ad-Duha** — the light visually floods in as the surah (the word *Duha*) is recited.

*Cut for a tighter flow:* the "breathe in/out" beat and the elaborate "When you're ready…" text. (Translation-in-sync and the name resolving out of the light are optional/retained — confirm in the build session.)

**Locked craft rules:**
- **Light switch sound cue is IN** (user's explicit call — do not re-argue).
- Light still **visually lands on the recitation of Surah Ad-Duha**.
- **Pitch black + silence up front** retained (tension → release = chills).
- **Haptics** retained as enhancement — on the taps and the light moment.

**Reciter & audio licensing:**
- The **creator records their own recitation** (Blue Yeti: cardioid, side-address into front grille, ~6–8in, pop filter, low gain, soft/treated room). Owns it outright — solves licensing, makes the app personal.
- The famous Indonesian recording the user has is **copyrighted** → private dev reference/scratch only, **do not ship**.
- Shippable fallback must be an **openly-licensed** recitation (e.g. Alafasy/Husary, EveryAyah/Quran.com, confirmed free). Keep written proof.

---

## 3. Tech Stack

| Area | Choice |
|---|---|
| Framework | **React Native** (iOS-first, Android-ready later) |
| Prayer calc | **`adhan`** library (Batoul Apps) |
| State | **Zustand** |
| Storage | **MMKV** (fast, synchronous) |
| Content data | **Bundled SQLite**, fully offline (Quran ~3–4MB, Duas ~200KB) |
| Target size | Well under 30MB |

---

## 4. Prayer Time Engine (core)

**Settings the user controls:**
- **Calculation method** — user-selectable on first launch (MWL default). Reference angles: MWL 18°/17°, ISNA 15°/15°, Umm al-Qura 18.5° + fixed 90-min Isha, Tehran 17.7°, Karachi, Egyptian, etc.
- **Asr madhab** — toggle labeled **"Shafi'i, Hanbali, Maliki"** vs **"Hanafi"** (default: Shafi'i/standard).
- **Location** — GPS auto-detect with manual city override; cache last coordinates (works offline); **"While Using"** permission only.

**Night-prayer math** (the differentiators). Night = Maghrib → next day's Fajr:
- **Islamic midnight** = Maghrib + (night ÷ 2). **This is when Isha ends.** Shown on the Isha card with a countdown in the last 30 min.
- **Tahajjud** (last third begins) = Maghrib + (night × 2/3).
- Verified: `adhan`'s `SunnahTimes` (`middleOfTheNight`, `lastThirdOfTheNight`) computes exactly this.

**Display:**
- Main list: Fajr, Dhuhr, Asr, Maghrib, Isha. Current/next prayer highlighted.
- Isha card shows "ends at [Islamic midnight]" + countdown.
- Separate **Night Prayer** card: Tahajjud + Islamic Midnight.

### ⚠️ High-latitude handling (see Known Issues §13)
- Auto-detect above ~48°N → apply "Middle of Night" silently; advanced toggle hidden in Settings.
- **Gentle precaution copy (high-lat only):**
  - Fajr: *"Dawn is hard to pin down exactly here. To be safe, finish suhoor a little early — and don't rush to pray the moment Fajr begins."*
  - Isha: *"Isha's start is approximate here. Give it a few minutes before you pray."*
- **Universal mission line (all users):** *"Pray each one on time — that's the heart of it."*
- **Manual per-prayer offsets** + seasonal re-check reminder (v1 stopgap — see §13).

---

## 5. Features

**v1.0 (MVP):** Prayer Times · Duha cinematic · Notifications · Qibla compass · Gentle prayer tracking · Widgets · Settings · Onboarding

**v1.1:** Quran reader · Duas · Light mode · Sisters (pink) theme · Apple Watch complication · (later) monthly-point interpolation, mosque timetables, Jummah custom time

**Quran reader (v1.1):** Arabic + Sahih International English, bundled offline (SQLite), bookmarks, surah/ayah nav. **No audio in v1.**

**Duas (v1.1):** occasion-based categories + dedicated "After Prayer" section, ~50–80 duas, Arabic + transliteration + English.

**Prayer tracking (v1.0, core to mission):** soft "mark as prayed" tap per prayer + a quiet, beautiful progress view. Encouragement layer (short reassuring verse/hadith after marking). **ZERO guilt mechanics** — no broken-streak shaming. Returning after missed prayers is met with *"your Lord has not forsaken you" / "welcome back"*, never a scold.

---

## 6. UI / Design — LOCKED celestial palette

Dark/celestial, brightened & approved. **Do not change these:**

| Token | Value | Use |
|---|---|---|
| App background | `#0D1628` | main bg (dark navy, not pitch black) |
| Page bg | `#08111F` | outermost |
| Gold accent | `#F0C040` | highlights, active prayer, progress, moon |
| Blue accent | `#8ECFE8` | location, date, labels, night card |
| Card bg | `rgba(255,255,255,0.07)` | cards (border `rgba(255,255,255,0.13)`) |
| Prayer time text | `rgba(255,255,255,0.8)` | times |

Active prayer = gold left bar + gold time + gold "Next" badge + subtle gold glow. Reference mockup: `design-1-celestial.html`.

**Themes:** v1 dark only. v1.1 adds light mode + Sisters (all-pink celestial) theme.

---

## 7. Navigation & Onboarding

**Bottom tab bar:** Prayer · Qibla · Quran · Duas · Settings (Prayer is home).

**Onboarding** (after the cinematic): 3 screens — Welcome → Location → Calculation method + madhab. No account, no email, under 60 seconds.

---

## 8. Notifications

- **Per-prayer control:** audio adhan vs silent vs off. Bundled Makkah + Madinah recordings. Offline only (no streaming).
- **iOS scheduling pattern (critical):** iOS caps pending local notifications at ~64 and times change daily. Pre-schedule a **rolling ~10–12 day window** (each with that day's exact time) and **re-fill on every app open**. Use `BGAppRefreshTask` to top up opportunistically but **never depend on it**.
- **Pre-prayer reminders:** optional, **off by default** (protects the 64-slot budget).
- **DST:** always format from the device's IANA timezone (e.g. `Europe/London`), never a fixed offset. Add regression tests around late-March & late-October transitions.

---

## 9. Monetization

Free. Voluntary **"Support the App" IAP (~$2.99)**. **No paywalled features** — locking Islamic content behind money is off-limits.

---

## 10. Accessibility (Enhanced)

VoiceOver labels on all elements · Dynamic Type (iOS text scaling) · RTL layout support (Arabic) · large tap targets.

---

## 11. Testing & Verification

- **Unit tests for ALL calculations** — prayer times vs known-good across cities/methods/madhabs; Tahajjud; Islamic midnight; Hijri conversion.
- **Manual QA** for UI.
- **Verification harness:** `prayer-verify/verify.js` (Node + `adhan`) computes 5 prayers + SunnahTimes for several cities. Diff against IslamicFinder / local mosque.
  - **RULE:** match method + madhab + high-lat rule *exactly* on both sides before comparing — a mismatch there is config, not a bug.
  - Validated vs East London Mosque (Jun 6): Asr **exact**, Sunrise/Dhuhr/Maghrib within 3–4 min — engine core is correct.

---

## 12. Hijri Date

Umm al-Qura calendar. User chooses which date (Hijri/Gregorian) is **primary/larger** — both always shown. **±1–2 day manual adjustment** in Settings for local moon-sighting differences.

---

## 13. 🚨 Known Issues / Emergency Debt

**HIGH-LATITUDE FAJR/ISHA — MUST FIX POST-v1.**

The v1 high-latitude solution is a **stopgap, not a real fix.** Proven with numbers:
- UK/N.Europe Fajr & Isha are *genuinely disputed* among scholars (researched: MuftiSays, Islam21c, SeekersGuidance). All agree on 18° where a sign exists + calculate-don't-observe in persistent twilight; they **disagree** on the fallback (½-night vs aqrab al-ayyām). Mosques in the *same city* differ by **1–2.5 hours**.
- Even tuned to ELM's claimed **15°**, calculation landed ~55 min (Fajr) / ~1h37m (Isha) off — **no angle reproduces a real mosque**, and the gap is **seasonal**.
- Fajr = suhoor/fast cutoff → high stakes. App must **never** present one high-lat number as authoritative.

**v1 ships:** neutral mainstream default + gentle disclaimer + **manual per-prayer offset** + **seasonal re-check reminder**. Absolute-time typing rejected (drifts within weeks).

**Must revisit:** monthly-reference-point interpolation (Option B) and/or a reliable mosque-timetable source. *Mawaqit was rejected (gated/unofficial APIs, too shaky).* Find or own an alternative. **Do not treat as "done."**

---

## 14. Roadmap

**v1.0** — Prayer engine, Duha cinematic, notifications, Qibla, prayer tracking, widgets (small/medium/lock), onboarding, settings, dark theme. *Solo dev.*

**v1.1** — Quran reader, Duas, light mode, Sisters theme, Watch complication.

**Backlog / debt** — proper high-latitude fix (§13), monthly-point interpolation, mosque-timetable directory, Jummah custom time, region presets.

---

## Appendix — files
- `design-1-celestial.html` — approved UI mockup (locked palette)
- `prayer-verify/verify.js` — multi-city verification harness
- `prayer-verify/test-london-angles.js` — 18° vs 15° vs ELM empirical test
