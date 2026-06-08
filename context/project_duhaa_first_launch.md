---
name: project_duhaa_first_launch
description: "The first-launch cinematic \"Duhaa moment\" — the emotional heart of the prayer app"
metadata: 
  node_type: memory
  type: project
  originSessionId: d5d52f45-e26e-4383-865b-8a2510acbb62
---

The app is named **Duhaa (ﺿﺤﻰ)** — "the morning brightness." Named after Surah Ad-Duhaa, the surah of hope ("your Lord has not forsaken you"). The mission: gently call people who don't pray / barely pray back to praying all 5 daily prayers — hope, not guilt.

**The first-launch cinematic ("the Duhaa moment")** — plays on very first launch only. This is the emotional centerpiece. User wants it to give people CHILLS.

**FINAL storyboard (REVISED & LOCKED by user — supersedes the earlier draft below):**
- **Beat 1 — Tap three times, in the black.** App opens pitch black with a minimal "tap three times" prompt. User taps 3× to begin (active participation — they *choose* the dawn).
- **Beat 2 — Pitch black holds.** Darkness sustains briefly (the "held breath"; where they are spiritually).
- **Beat 3 — Basmala (~1.5s after the taps).** "Bismillāhi-r-Raḥmāni-r-Raḥīm" in the dark.
- **Beat 4 — Light switch sound.** An audio cue marking the light turning on. ⚠️ User EXPLICITLY wants a "light switch" sound — this OVERRIDES my earlier push for an organic-swell-only / no-click. Honor the user's call.
- **Beat 5 — The recitation begins** — user's OWN recitation of Surah Ad-Duhaa.
- **Beat 6 — Lights hit on Surah Ad-Duhaa.** The light visually floods in as the surah (the word Duhaa) is recited — light still lands on the recitation of Duhaa.

**Cut in this revision (were in the earlier draft):** the "breathe in/out" centering beat, and the elaborate "When you're ready…" framing — user wants a tighter flow. (Translation-in-sync and the name resolving out of the light were NOT re-specified by the user; treat as optional/retained-if-desired, confirm in the build session.)

**Locked craft decisions:**
- ⚠️ Light switch SOUND cue is IN, per user's explicit instruction (reverses my earlier "no mechanical click" note — do not re-argue it).
- Light still VISUALLY lands on the recitation of Surah Ad-Duhaa ("lights hitting surah duhaa").
- Pitch black + silence up front retained — it's what creates chills (tension → release).
- Haptics (Core Haptics) retained as an enhancement on the taps and the light moment (turns visual into physical chills).
- Skippable: "Skip" fades in after ~4–5s. Plays before the practical setup screens. Never auto-plays again, but add a way to replay it (dawn icon / Settings → About Duhaa).

**Reciter:** The creator (user) will record their OWN recitation of Surah Ad-Duhaa for the cinematic. Solves licensing entirely (owned outright) and makes the app deeply personal — the creator's own voice is the first thing every user hears as the dawn breaks. Recording on a **Blue Yeti** (set to cardioid, side-address into front grille, ~6–8in, pop filter, low gain, treated/soft room to kill echo). Needs a clean, well-recorded take since this recitation carries the whole emotional moment.

**Audio licensing (IMPORTANT):** Only ship audio the user has rights to. User's OWN recitation = default, fully owned. User also has a famous Indonesian reciter's recording — this is COPYRIGHTED; use ONLY as a private dev reference/scratch track for pacing & melody, do NOT ship it. Shippable fallback must be an explicitly open-licensed recitation (e.g. Alafasy/Husary from EveryAyah/Quran.com, confirmed free-to-distribute). Keep written proof of license terms.

**Why:** This moment IS the app's thesis — the dark celestial theme is the "night," the whole app is the invitation to the "dawn." Name + aesthetic + mission + opening all collapse into one idea. Handle with extreme care; do not cheapen it. See [[project_prayer_app]].
