# Nearby Mosques — Manual QA Checklist

Automated tests cover the logic (permissions, dedupe, sort, distance, filtering,
refresh, map-action construction). These checks need a human + a real network /
device because they exercise live MapKit and the system permission dialogs.

## Locations (Simulator → Features → Location → Custom Location…)
- [ ] **Dense city** (e.g. 42.3314, −83.0458 Detroit): list fills with real
      masjids, sorted nearest-first, no obvious food places.
- [ ] **Rural area** (a remote coordinate): shows the **empty state**
      ("No nearby mosques found") without crashing.
- [ ] **Different country** (e.g. London, Istanbul): names/addresses look right.

## Permission flows
- [ ] **Not determined** (fresh install): opening the feature shows the gentle
      permission screen with the exact copy; "Allow Location" triggers the
      system prompt; allowing then loads results.
- [ ] **Denied:** Settings → Duhaa → Location → Never. Feature shows the denied
      state with **Open Settings**, which opens the app's system settings.
- [ ] **Restricted:** (Screen Time / MDM if available) shows the denied/restricted state.
- [ ] **Approximate Location ON** (Settings → Privacy → Location → Duhaa →
      Precise Location OFF): still returns nearby mosques, no crash.

## Network
- [ ] **Airplane mode / no network:** shows the **error state** with "Try Again"
      (not a blank screen, not a crash).
- [ ] **Poor / slow network:** shows "Finding nearby mosques…" then resolves.

## Actions (per card)
- [ ] **Directions** opens **Apple Maps** with a route to the mosque (never Google).
- [ ] **Call** appears only when a phone number exists; tapping dials it.
- [ ] **Website** appears only when a URL exists; tapping opens Safari.
- [ ] A card with no phone shows no Call button; no website shows no Website button.
- [ ] A card with no address shows "Address unavailable".

## Refresh & lifecycle
- [ ] Refresh (↻) starts a new search; mashing it doesn't duplicate the list.
- [ ] Reopening the sheet quickly reuses results (no flicker / re-search storm).
- [ ] Leaving the screen mid-load doesn't crash.

## Content / safety
- [ ] **No halal restaurants or food places** appear intentionally. If MapKit
      surfaces a clear eatery, confirm it's filtered (category + name backstop).
- [ ] Names like "Islamic Center", "Masjid", "Mosque", "Muslim Community Center"
      are kept.

## Real device
- [ ] On a physical iPhone near your real location, the nearest masjids you know
      appear with sensible distances, and Directions routes correctly.
