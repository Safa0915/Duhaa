# Tafsir (Qur'an commentary) — setup & how to add editions

Duhaa bundles tafsir **offline** (no backend, per the app's hard rules). A per-ayah
**book** button in the surah reader opens a sheet with the commentary; the active
tafsir is chosen from a picker in that sheet's toolbar.

## What ships today
- **Ibn Kathir (Abridged), English** — bundled as `Duhaa/Quran/tafsir_ibnkathir.json`
  (~11 MB, full 6,236 ayahs, range-deduped to ~1,900 blocks).
- Source: the open **spa5k/tafsir_api** dataset (itself sourced from Quran.com).

## ⚠️ Pre-launch
- **Verify redistribution rights** for the bundled tafsir before App Store submission
  — the same check already noted for the ClearQuran translation and the KFGQPC font.
- **As-Saadi** is **not** freely available in English. Quran.com / spa5k carry only
  Arabic and Russian As-Saadi. The published English As-Saadi (IIPH) is copyrighted —
  do **not** bundle it without a license. If/when licensed, drop the JSON in and add an
  edition (below); the picker will surface it with no further UI work.

## How the data is built
`scripts/fetch_tafsir.py` downloads an edition from the spa5k CDN, strips any HTML,
collapses consecutive ayahs that share identical commentary into `{s, a, b, t}` ranges
(Ibn Kathir groups verses), and writes a compact JSON into `Duhaa/Quran/`.

```bash
python3 scripts/fetch_tafsir.py <slug> "<Display Name>" "<Author>" <outfile.json>
# e.g. (what shipped):
python3 scripts/fetch_tafsir.py en-tafisr-ibn-kathir "Ibn Kathir (Abridged)" "Hafiz Ibn Kathir" tafsir_ibnkathir.json
```
Browse available editions: `https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir/editions.json`
(English Salafi-aligned option is Ibn Kathir; Al-Jalalayn `en-al-jalalayn` is a concise
classical alternative but carries occasional Ash'ari glosses — add a neutral note if used.)

## Adding another edition (picker-ready)
1. Fetch it with the script → new JSON in `Duhaa/Quran/` (auto-joins the app target via
   the synchronized folder group).
2. Append a `TafsirEdition` to `Tafsir.editions` in `Duhaa/Quran/TafsirData.swift`
   (`id` = slug, `file` = resource name without `.json`).
3. Add an attribution line in `Duhaa/Settings/AboutView.swift`.

That's it — the toolbar picker in `TafsirView` renders every registered edition.
