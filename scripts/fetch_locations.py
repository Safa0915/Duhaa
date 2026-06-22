#!/usr/bin/env python3
"""Build Duhaa's bundled, offline country→city dataset from GeoNames (public domain,
CC BY 4.0). Manual location selection then works with no network — pick a country,
then a city, each carrying coordinates + an IANA time zone for prayer-time accuracy.

Sources (downloaded fresh each run):
  - countryInfo.txt        ISO code → country name
  - admin1CodesASCII.txt   admin1 code → region/state name (for disambiguation)
  - cities15000.zip        every city with population ≥ 15,000

Output: Duhaa/Location/locations.json
  {"countries":[{"code":"US","name":"United States",
                 "cities":[{"n":"New York","r":"New York","lat":40.71,"lon":-74.0,
                            "tz":"America/New_York"}, ...]}, ...]}
Cities are sorted by population (most relevant first); population itself is dropped.

⚠️  GeoNames is CC BY 4.0 — keep the attribution in AboutView.
"""
import json
import os
import subprocess
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "Duhaa", "Location", "locations.json")
TMP = "/tmp/duhaa_geonames"
BASE = "https://download.geonames.org/export/dump"


def curl(url: str, dest: str):
    subprocess.run(["curl", "-fsSL", "--max-time", "120", url, "-o", dest], check=True)


def main():
    os.makedirs(TMP, exist_ok=True)

    # Country code → name
    curl(f"{BASE}/countryInfo.txt", f"{TMP}/countryInfo.txt")
    country_name = {}
    with open(f"{TMP}/countryInfo.txt", encoding="utf-8") as f:
        for line in f:
            if line.startswith("#"):
                continue
            cols = line.rstrip("\n").split("\t")
            if len(cols) > 4 and cols[0]:
                country_name[cols[0]] = cols[4]

    # admin1 code ("US.NY") → region name ("New York")
    curl(f"{BASE}/admin1CodesASCII.txt", f"{TMP}/admin1CodesASCII.txt")
    admin1 = {}
    with open(f"{TMP}/admin1CodesASCII.txt", encoding="utf-8") as f:
        for line in f:
            cols = line.rstrip("\n").split("\t")
            if len(cols) >= 2:
                admin1[cols[0]] = cols[1]

    # Cities (population ≥ 15,000)
    curl(f"{BASE}/cities15000.zip", f"{TMP}/cities15000.zip")
    with zipfile.ZipFile(f"{TMP}/cities15000.zip") as z:
        z.extractall(TMP)

    by_country = {}  # code -> list of (population, city dict)
    with open(f"{TMP}/cities15000.txt", encoding="utf-8") as f:
        for line in f:
            c = line.rstrip("\n").split("\t")
            if len(c) < 18:
                continue
            name, lat, lon, cc, a1, pop, tz = c[1], c[4], c[5], c[8], c[10], c[14], c[17]
            if not (name and cc and lat and lon and tz):
                continue
            try:
                latf, lonf, popi = round(float(lat), 4), round(float(lon), 4), int(pop or 0)
            except ValueError:
                continue
            region = admin1.get(f"{cc}.{a1}")
            entry = {"n": name, "lat": latf, "lon": lonf, "tz": tz}
            if region and region != name:
                entry["r"] = region
            by_country.setdefault(cc, []).append((popi, entry))

    countries = []
    total_cities = 0
    for cc, rows in by_country.items():
        rows.sort(key=lambda r: r[0], reverse=True)  # biggest cities first
        cities = [r[1] for r in rows]
        total_cities += len(cities)
        countries.append({"code": cc, "name": country_name.get(cc, cc), "cities": cities})
    countries.sort(key=lambda c: c["name"])

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump({"countries": countries}, f, ensure_ascii=False, separators=(",", ":"))

    size = os.path.getsize(OUT)
    print(f"Wrote {OUT}")
    print(f"  countries: {len(countries)}")
    print(f"  cities:    {total_cities}")
    print(f"  size:      {size/1024/1024:.2f} MB")


if __name__ == "__main__":
    main()
