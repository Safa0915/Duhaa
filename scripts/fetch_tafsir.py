#!/usr/bin/env python3
"""Fetch a bundled, offline tafsir for Duhaa from the open spa5k/tafsir_api dataset.

The app ships backend-free, so the tafsir is downloaded once at build time into a
compact JSON that the app bundles. Ibn Kathir groups several ayahs under one block
of commentary; we collapse consecutive ayahs that share identical text into a single
{s, a, b, t} range so the file stays as small as possible.

Usage:
    python3 scripts/fetch_tafsir.py en-tafisr-ibn-kathir "Ibn Kathir (Abridged)" "Hafiz Ibn Kathir" tafsir_ibnkathir.json

Output is written to Duhaa/Quran/<outfile>.

⚠️  Licensing: verify the rights to redistribute the chosen tafsir before App Store
    submission (the same pre-launch check applied to the translation + Arabic font).
"""
import html
import json
import os
import re
import subprocess
import sys
import time

CDN = "https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir"
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "..", "Duhaa", "Quran")

TAG_RE = re.compile(r"<[^>]+>")
MULTI_NL_RE = re.compile(r"\n{3,}")
TRAIL_WS_RE = re.compile(r"[ \t]+\n")


def clean(text: str) -> str:
    """Strip any HTML, unescape entities, normalize whitespace."""
    if not text:
        return ""
    text = TAG_RE.sub("", text)
    text = html.unescape(text)
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = TRAIL_WS_RE.sub("\n", text)
    text = MULTI_NL_RE.sub("\n\n", text)
    return text.strip()


def fetch(url: str, attempts: int = 4):
    """Fetch JSON via curl (system Python on macOS often lacks CA roots)."""
    last = None
    for i in range(attempts):
        try:
            out = subprocess.run(
                ["curl", "-fsSL", "--max-time", "60", "-A", "Duhaa-build/1.0", url],
                capture_output=True, check=True,
            )
            return json.loads(out.stdout.decode("utf-8"))
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(1.5 * (i + 1))
    raise RuntimeError(f"failed to fetch {url}: {last}")


def main():
    if len(sys.argv) < 5:
        print(__doc__)
        sys.exit(1)
    slug, name, author, outfile = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

    blocks = []
    total_ayahs = 0
    for surah in range(1, 115):
        data = fetch(f"{CDN}/{slug}/{surah}.json")
        entries = data if isinstance(data, list) else data.get("ayahs", [])
        entries = sorted(entries, key=lambda e: e.get("ayah", 0))
        prev = None  # (a, b, text) currently being extended
        for e in entries:
            ayah = int(e.get("ayah", 0))
            if ayah <= 0:
                continue
            total_ayahs += 1
            text = clean(e.get("text", ""))
            if prev and prev[2] == text and ayah == prev[1] + 1:
                prev = (prev[0], ayah, text)  # extend the range
            else:
                if prev:
                    blocks.append({"s": surah, "a": prev[0], "b": prev[1], "t": prev[2]})
                prev = (ayah, ayah, text)
        if prev:
            blocks.append({"s": surah, "a": prev[0], "b": prev[1], "t": prev[2]})
        print(f"  surah {surah:3d}: {len(entries):3d} ayahs", flush=True)

    out = {
        "slug": slug,
        "name": name,
        "author": author,
        "source": "spa5k/tafsir_api (quran.com)",
        "blocks": blocks,
    }
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, outfile)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))

    size = os.path.getsize(path)
    print(f"\nWrote {path}")
    print(f"  ayahs covered: {total_ayahs}")
    print(f"  blocks (after range-dedupe): {len(blocks)}")
    print(f"  file size: {size/1024/1024:.2f} MB")


if __name__ == "__main__":
    main()
