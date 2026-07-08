#!/usr/bin/env python3
"""Fetch a bundled, offline English transliteration of the Quran for Duhaa.

The app ships backend-free, so the transliteration is downloaded once at build
time into a compact JSON that the app bundles next to quran.json. We key it by
surah number → ordered list of per-ayah transliteration strings (index = ayah-1),
which the reader looks up lazily.

Source: alquran.cloud `en.transliteration` edition (the standard Latin
transliteration used widely in Quran apps).

Usage:
    python3 scripts/fetch_transliteration.py

Output is written to Duhaa/Quran/quran_transliteration.json.

⚠️  Licensing: verify the rights to redistribute this transliteration before App
    Store submission (the same pre-launch check applied to the translation,
    tafsir, and Arabic font).
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Duhaa", "Quran", "quran_transliteration.json")
URL = "https://api.alquran.cloud/v1/quran/en.transliteration"


def main() -> int:
    print(f"Fetching {URL} …")
    # Shell out to curl — matches the repo's other fetch scripts and avoids the
    # macOS system-Python SSL trust issues.
    raw = subprocess.run(
        ["curl", "-fsSL", "--max-time", "120", URL],
        capture_output=True, check=True,
    ).stdout
    payload = json.loads(raw)

    if payload.get("code") != 200:
        print(f"Unexpected response code: {payload.get('code')}", file=sys.stderr)
        return 1

    surahs = {}
    total = 0
    for surah in payload["data"]["surahs"]:
        number = surah["number"]
        # Keep ayahs in order; numberInSurah is 1-based and contiguous.
        ayahs = [a["text"].strip() for a in sorted(surah["ayahs"], key=lambda a: a["numberInSurah"])]
        surahs[str(number)] = ayahs
        total += len(ayahs)

    if total != 6236:
        print(f"WARNING: expected 6236 ayahs, got {total}", file=sys.stderr)

    out = {
        "source": "alquran.cloud en.transliteration",
        "surahs": surahs,
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))

    size_kb = os.path.getsize(OUT) / 1024
    print(f"Wrote {total} ayahs across {len(surahs)} surahs → {OUT} ({size_kb:.0f} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
