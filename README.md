# Duhaa (ﺿﺤﻰ)

An iOS prayer app built on **hope, not guilt** — to gently bring people who don't pray, or barely pray, back to all five daily prayers. Named after Surah Ad-Duhaa.

## What's here
- **`DUHAA_SPEC.md`** — the full product specification (start here)
- **`CLAUDE.md`** — context for Claude Code sessions
- **`context/`** — original locked decision docs from the design session
- **`design/`** — UI mockups (`design-1-celestial.html` is the approved direction)
- **`prayer-verify/`** — Node verification harness for prayer-time math (validated vs East London Mosque)

## Status
Design complete & locked. Engine + app build not yet started.

## Getting started (engine verification)
```bash
cd prayer-verify
npm install
node verify.js            # prayer times for several cities
node test-london-angles.js # 18° vs 15° vs East London Mosque
```

## Build
Native **SwiftUI** app (iOS-only for now), min target iOS 17+. Built and run in **Xcode** on macOS. Prayer math via **Adhan Swift** (Swift Package Manager). Widgets = WidgetKit, haptics = Core Haptics, notifications = UserNotifications.

---
*Hope, not guilt. 🌅*
