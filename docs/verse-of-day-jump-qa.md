# Verse of the Day → exact-ayah jump + highlight — Manual QA Checklist

Automated tests cover the data layer (Verse of the Day carries surah **and** ayah,
every curated verse resolves to a real ayah, invalid ayah is simply not found).
The scroll + highlight are SwiftUI runtime behavior and need a human on a device
or Simulator.

The same jump-to-verse + highlight runs from three entry points:
**Verse of the Day** (home), **Bookmarks**, and **search → Verses**.
"Continue Reading" deliberately resumes position **without** a highlight.

## Core behavior
- [ ] Tap **Verse of the Day** for a verse in a **short** surah (e.g. Ad-Duhaa 93):
      reader opens, lands on the exact ayah, glow appears, fades after ~3–5s.
- [ ] Tap a Verse of the Day in a **long** surah (force one to 2:255 if needed):
      reader scrolls all the way to ayah 255, not near the top; verse is glowed.
- [ ] Target ayah sits **slightly above vertical center** with context visible above.
- [ ] Highlight is the soft theme accent (fill + border) — noticeable, not harsh.
- [ ] After the glow fades, scrolling/reading is completely normal.

## One-time-only
- [ ] After the jump, scroll away and back within the same surah — it does **not**
      re-jump or re-glow.
- [ ] Open the same surah **manually** from the surah list afterwards — no jump, no glow.

## Themes (Settings → Appearance)
- [ ] **Celestial (dark):** gold glow.
- [ ] **Rose (sisters):** glow is rose/pink (auto — uses `Palette.gold` accent).
- [ ] **Dawn (light):** glow is the deep honey-gold accent, still readable.
- [ ] (Future Light Pink theme will inherit automatically — no code change.)

## Accessibility / robustness
- [ ] **Reduce Motion** ON (Settings → Accessibility → Motion): verse still appears
      and highlights, but with no dramatic animation (simple show/clear).
- [ ] **Cold start:** force-quit, relaunch, tap Verse of the Day → still jumps + glows.
- [ ] **Bookmarks** and **search → Verses** jump + glow the saved/found ayah.
- [ ] **Continue Reading** resumes position with **no** glow.
- [ ] Small iPhone (e.g. iPhone SE): target still lands above center, readable.
- [ ] Fallback: a verse whose ayah doesn't exist shows a quiet "Couldn't jump to
      verse." capsule and opens the surah normally (no crash). (Can't trigger from
      the UI today since all entry points use real data — verify via a temp edit if needed.)
