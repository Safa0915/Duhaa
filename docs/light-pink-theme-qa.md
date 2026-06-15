# Light Pink Theme — QA & design notes

_Last updated: 2026-06-15. The free "premium preview" theme + its ambient floating
hearts._

## Floating-hearts design decision
The hearts are **ambient background decoration**, never a focal point.

- **Sparse:** 16 deterministic (seeded) hearts — no reflow between launches.
- **Low opacity:** 0.05–0.12 (soft accent / accent pink).
- **Small–medium:** 12–30pt, light weight, no glow/shadow.
- **Edge-biased:** hearts only live in the side gutters (x ≤ 0.18 or ≥ 0.82); the
  central reading column stays clear. Opaque white cards further occlude anything
  behind them, so hearts only peek through background margins.
- **Slow upward drift** with a faint wobble/tilt; **capped at 20fps** for battery.
- **Light Pink only.** Every other theme has `showsFloatingHearts = false`.

### Where hearts appear (opt-in)
- Prayer home (`CelestialBackground(allowsThemeDecorations: true)`)
- More tab, Settings, and Settings detail screens (incl. the Appearance picker),
  via `ThemeDecorativeBackground`.

### Where hearts never appear
- Quran list & reader, Du'a detail, Learn list & detail/evidence, Nearby Mosques —
  these use a plain `Palette.appBg` and don't apply the decorative background at all.
- Tasbih, Qibla, Onboarding — use `CelestialBackground()` with decorations off.
- Any screen can also opt out explicitly: `ThemeDecorativeBackground(allowsHearts: false)`.

### Reduce Motion
When Reduce Motion is on, hearts are **faint and static** — the drift/wobble/tilt
animation is skipped entirely (no `TimelineView`), positions are computed at time 0.

## Manual checklist
- [ ] Launch with Classic Duhaa selected → **no hearts** anywhere.
- [ ] Settings → Appearance → choose **Light Pink** → colors update immediately.
- [ ] Restart app → Light Pink persists.
- [ ] Prayer home: hearts subtle, drift slowly in the gutters, text stays readable.
- [ ] More / Settings: hearts visible in open background, feel premium (not busy).
- [ ] Appearance picker screen shows the Light Pink swatches + "Free preview" badge.
- [ ] Quran reader: **no moving hearts** behind Arabic; Arabic crisp.
- [ ] Du'a detail: Arabic remains highly readable, no hearts.
- [ ] Learn detail: long text remains readable, no hearts.
- [ ] Reduce Motion ON: hearts do not drift (faint static or none); nothing janky.
- [ ] Larger Dynamic Type: text scales; hearts stay in the gutters.
- [ ] Small iPhone (SE/13 mini): not cluttered.
- [ ] Overall: soft, premium, calm — not Valentine's, not childish.

## Verified 2026-06-15 (iPhone 17 simulator)
- Light Pink home: hearts subtle & edge-biased, clock/cards/verse readable. ✓
- More: soft pink hearts in the open background, premium feel. ✓
- Quran list + Al-Fatihah reader: no hearts, Arabic fully readable. ✓
- Classic theme: no hearts. ✓ (unit test enforces it)
- Still needs a human pass: Reduce Motion on a real device, Du'a/Learn detail eyeball,
  small-screen + large-Dynamic-Type check.
