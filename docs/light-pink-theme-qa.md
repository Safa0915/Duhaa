# Light Pink Theme — QA & design notes

_Last updated: 2026-06-15. The free "premium preview" theme + its ambient floating
hearts._

## Floating-hearts design decision
The hearts are **ambient background decoration**, never a focal point. The Light
Pink preview uses the original cute-heart field from the first pass:

- **34 deterministic (seeded) floating hearts** so the layout feels consistent
  between launches.
- **Classic-star-style routes:** each heart follows the same kind of slow upward
  drift used by the Classic Duhaa star field, with subtle wobble and twinkle.
- **Spaced columns + staggered routes:** hearts keep separation while drifting,
  so they do not visually merge into each other.
- **Top coverage:** the staggered phases keep several hearts visible in the upper
  portion throughout the loop, instead of leaving the top empty.
- **Launch-frame top coverage:** the live animation uses elapsed time from when
  the heart field appears, so opening or switching to Light Pink starts from the
  seeded top-populated frame instead of a random absolute-clock position.
- **Feature hearts** every few items are larger (28–40pt) and more visible.
- **Sparkly feature hearts:** 5 of the larger feature hearts use the `💖` emoji
  style, inspired by the reference image without recreating the image itself.
  The rest remain simple baby-pink hearts so the background stays calm.
- **Opacity:** regular hearts 0.09–0.20, feature hearts 0.18–0.26.
- **Soft pink glow:** a gentle `Palette.glow` shadow makes the hearts feel sweet
  and premium rather than flat.
- **No parked hearts:** there is no fixed Prayer-only layer; every visible heart
  drifts on a route.
- **Hidden loop reset:** hearts fade at the top and fade back in after wrapping
  so the restart does not look robotic.
- **Baby-pink hearts:** alternating baby pink + blush pink, filled and outline
  SF Symbol hearts.
- **Pink-aligned preview swatch:** the fourth Light Pink swatch uses a rose-pink
  secondary accent, not the old brownish muted text color.
- **Light Pink only.** Every other theme has `showsFloatingHearts = false`.

### Where hearts appear (opt-in)
- Prayer home (`CelestialBackground(allowsThemeDecorations: true)`)
- More tab, Settings, and Settings detail screens (incl. the Appearance picker),
  via `ThemeDecorativeBackground`.

### Where hearts never appear
- Quran list & reader, Du'a detail, Learn list & detail/evidence, Nearby Mosques —
  these use a plain `Palette.appBg` and don't apply the decorative background at all.
- Tasbih, Qibla, Onboarding — use `CelestialBackground()` with decorations off.

### Reduce Motion
When Reduce Motion is on, the same heart field renders as a still frame. The
`TimelineView` is skipped, so nothing drifts; the Light Pink theme still feels
finished.

## Manual checklist
- [ ] Launch with Classic Duhaa selected → **no hearts** anywhere.
- [ ] Settings → Appearance → choose **Light Pink** → colors update immediately.
- [ ] Restart app → Light Pink persists.
- [ ] Prayer home: route-based hearts are visible above the main content immediately after launch; text stays readable.
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
- Light Pink home: 34-heart field visible behind the clock/cards/verse. ✓
- Prayer home: the same route-based heart field is unit-tested for top visibility and spacing. ✓
- More: floating pink hearts feel cute, visible, and soft. ✓
- Unit tests sample a full loop to check motion, separation, top coverage, launch-frame top hearts, sparkly-heart count, and fade-at-wrap. ✓
- Quran list: no hearts, list fully readable (reader unchanged → also clean). ✓
- Classic theme: no hearts. ✓ (unit test enforces it)
- Still needs a human pass: Reduce Motion on a real device, Du'a/Learn detail eyeball,
  small-screen + large-Dynamic-Type check.
