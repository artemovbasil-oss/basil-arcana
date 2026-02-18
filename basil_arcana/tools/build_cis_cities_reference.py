#!/usr/bin/env python3
"""
Build a CIS cities reference dataset from public GeoNames country dumps.

Outputs:
  - places CSV (canonical city records)
  - aliases CSV (search aliases for autocomplete)
  - metadata JSON (counts and source info)
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import re
import sys
import unicodedata
import urllib.request
import zipfile
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Set, Tuple

GEONAMES_BASE = "https://download.geonames.org/export/dump"

# Default scope requested: Russia, Kazakhstan and other CIS countries.
DEFAULT_COUNTRIES = [
    "RU",
    "KZ",
    "BY",
    "KG",
    "UZ",
    "TJ",
    "TM",
    "AM",
    "AZ",
    "MD",
]

PREFERRED_FEATURE_CODES = {
    "PPLC",  # capital of a political entity
    "PPLA",  # seat of a first-order admin division
    "PPLA2",
    "PPLA3",
    "PPLA4",
    "PPL",  # populated place
    "PPLF",
    "PPLG",
    "PPLL",
    "PPLQ",
    "PPLR",
    "PPLS",
    "PPLW",
    "PPLX",
}

ALIAS_MIN_LEN = 2
ALIAS_MAX_LEN = 120
MAX_ALIASES_PER_PLACE = 60


@dataclass(frozen=True)
class PlaceRow:
    place_id: str
    geoname_id: int
    country_code: str
    country_name: str
    admin1_code: str
    admin1_name: str
    admin2_code: str
    city_name: str
    city_name_ascii: str
    latitude: float
    longitude: float
    timezone: str
    population: int
    feature_code: str
    modification_date: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build CIS cities reference dataset from GeoNames."
    )
    parser.add_argument(
        "--output-dir",
        default="basil_arcana/server/data/geo",
        help="Where to write output CSV/JSON files.",
    )
    parser.add_argument(
        "--download-dir",
        default="basil_arcana/tools/.cache/geonames",
        help="Where to cache downloaded GeoNames files.",
    )
    parser.add_argument(
        "--countries",
        default=",".join(DEFAULT_COUNTRIES),
        help="Comma-separated ISO country codes to include.",
    )
    parser.add_argument(
        "--min-population",
        type=int,
        default=0,
        help="Skip places below this population.",
    )
    parser.add_argument(
        "--max-places-per-country",
        type=int,
        default=0,
        help="Optional cap for quick tests (0 = no cap).",
    )
    parser.add_argument(
        "--max-aliases-per-place",
        type=int,
        default=MAX_ALIASES_PER_PLACE,
        help="Max aliases stored per place after normalization/dedup.",
    )
    return parser.parse_args()


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def download_file(url: str, target: Path) -> None:
    if target.exists():
        return
    print(f"[download] {url}", file=sys.stderr)
    ensure_dir(target.parent)
    with urllib.request.urlopen(url) as response:
        data = response.read()
    target.write_bytes(data)


def load_country_names(download_dir: Path) -> Dict[str, str]:
    txt_path = download_dir / "countryInfo.txt"
    download_file(f"{GEONAMES_BASE}/countryInfo.txt", txt_path)
    country_names: Dict[str, str] = {}
    for line in txt_path.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 5:
            continue
        iso = parts[0].strip().upper()
        name = parts[4].strip()
        if iso and name:
            country_names[iso] = name
    return country_names


def load_admin1_names(download_dir: Path) -> Dict[str, str]:
    txt_path = download_dir / "admin1CodesASCII.txt"
    download_file(f"{GEONAMES_BASE}/admin1CodesASCII.txt", txt_path)
    mapping: Dict[str, str] = {}
    for line in txt_path.read_text(encoding="utf-8").splitlines():
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        key = parts[0].strip()
        name = parts[1].strip()
        if key and name:
            mapping[key] = name
    return mapping


def normalize_alias(value: str) -> str:
    text = value.strip().lower()
    if not text:
        return ""
    text = unicodedata.normalize("NFKC", text)
    text = text.replace("ё", "е")
    text = re.sub(r"[^\w\s\-']", " ", text, flags=re.UNICODE)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def is_alias_usable(value: str) -> bool:
    v = value.strip()
    if not v:
        return False
    if len(v) < ALIAS_MIN_LEN or len(v) > ALIAS_MAX_LEN:
        return False
    if re.fullmatch(r"[\d\W_]+", v, flags=re.UNICODE):
        return False
    return True


def build_aliases(
    name: str,
    asciiname: str,
    alternates_raw: str,
    max_aliases: int,
) -> List[Tuple[str, str, int]]:
    values: List[str] = []
    if name:
        values.append(name)
    if asciiname and asciiname != name:
        values.append(asciiname)
    if alternates_raw:
        values.extend([x.strip() for x in alternates_raw.split(",") if x.strip()])

    seen_norm: Set[str] = set()
    output: List[Tuple[str, str, int]] = []
    for i, raw in enumerate(values):
        if not is_alias_usable(raw):
            continue
        norm = normalize_alias(raw)
        if not norm or norm in seen_norm:
            continue
        seen_norm.add(norm)
        is_primary = 1 if i == 0 else 0
        output.append((raw, norm, is_primary))
        if len(output) >= max_aliases:
            break
    return output


def parse_country_dump(
    country_code: str,
    country_name: str,
    admin1_names: Dict[str, str],
    zip_path: Path,
    min_population: int,
    max_places: int,
    max_aliases: int,
) -> Tuple[List[PlaceRow], Dict[str, List[Tuple[str, str, int]]]]:
    places: List[PlaceRow] = []
    aliases_by_place: Dict[str, List[Tuple[str, str, int]]] = {}
    expected_txt = f"{country_code}.txt"
    with zipfile.ZipFile(zip_path, "r") as zf:
        txt_name = expected_txt if expected_txt in zf.namelist() else zf.namelist()[0]
        with zf.open(txt_name, "r") as fp:
            reader = io.TextIOWrapper(fp, encoding="utf-8", newline="")
            for raw_line in reader:
                line = raw_line.rstrip("\n")
                if not line:
                    continue
                parts = line.split("\t")
                if len(parts) < 19:
                    continue
                feature_class = parts[6].strip()
                feature_code = parts[7].strip().upper()
                if feature_class != "P":
                    continue
                if feature_code not in PREFERRED_FEATURE_CODES:
                    continue
                try:
                    population = int(parts[14].strip() or "0")
                except ValueError:
                    population = 0
                if population < min_population:
                    continue

                geoname_id_raw = parts[0].strip()
                if not geoname_id_raw.isdigit():
                    continue
                geoname_id = int(geoname_id_raw)
                place_id = str(geoname_id)
                name = parts[1].strip()
                asciiname = parts[2].strip()
                alternates = parts[3].strip()
                admin1_code = parts[10].strip()
                admin2_code = parts[11].strip()
                lat_raw = parts[4].strip()
                lon_raw = parts[5].strip()
                timezone_name = parts[17].strip()
                modification_date = parts[18].strip()
                if not name:
                    continue
                try:
                    lat = float(lat_raw)
                    lon = float(lon_raw)
                except ValueError:
                    continue
                admin1_key = f"{country_code}.{admin1_code}" if admin1_code else ""
                admin1_name = admin1_names.get(admin1_key, "")

                row = PlaceRow(
                    place_id=place_id,
                    geoname_id=geoname_id,
                    country_code=country_code,
                    country_name=country_name,
                    admin1_code=admin1_code,
                    admin1_name=admin1_name,
                    admin2_code=admin2_code,
                    city_name=name,
                    city_name_ascii=asciiname,
                    latitude=lat,
                    longitude=lon,
                    timezone=timezone_name,
                    population=population,
                    feature_code=feature_code,
                    modification_date=modification_date,
                )
                places.append(row)
                aliases_by_place[place_id] = build_aliases(
                    name=name,
                    asciiname=asciiname,
                    alternates_raw=alternates,
                    max_aliases=max_aliases,
                )
                if max_places > 0 and len(places) >= max_places:
                    break
    return places, aliases_by_place


def write_places_csv(path: Path, rows: Iterable[PlaceRow]) -> int:
    ensure_dir(path.parent)
    count = 0
    with path.open("w", encoding="utf-8", newline="") as fp:
        writer = csv.writer(fp)
        writer.writerow(
            [
                "place_id",
                "geoname_id",
                "country_code",
                "country_name",
                "admin1_code",
                "admin1_name",
                "admin2_code",
                "city_name",
                "city_name_ascii",
                "latitude",
                "longitude",
                "timezone",
                "population",
                "feature_code",
                "modification_date",
            ]
        )
        for row in rows:
            count += 1
            writer.writerow(
                [
                    row.place_id,
                    row.geoname_id,
                    row.country_code,
                    row.country_name,
                    row.admin1_code,
                    row.admin1_name,
                    row.admin2_code,
                    row.city_name,
                    row.city_name_ascii,
                    row.latitude,
                    row.longitude,
                    row.timezone,
                    row.population,
                    row.feature_code,
                    row.modification_date,
                ]
            )
    return count


def write_aliases_csv(
    path: Path,
    aliases_by_place: Dict[str, List[Tuple[str, str, int]]],
) -> int:
    ensure_dir(path.parent)
    count = 0
    with path.open("w", encoding="utf-8", newline="") as fp:
        writer = csv.writer(fp)
        writer.writerow(
            [
                "place_id",
                "alias",
                "alias_normalized",
                "is_primary",
            ]
        )
        for place_id, aliases in aliases_by_place.items():
            for alias, normalized, is_primary in aliases:
                count += 1
                writer.writerow([place_id, alias, normalized, is_primary])
    return count


def main() -> int:
    args = parse_args()
    output_dir = Path(args.output_dir)
    download_dir = Path(args.download_dir)
    ensure_dir(output_dir)
    ensure_dir(download_dir)

    countries = [x.strip().upper() for x in args.countries.split(",") if x.strip()]
    if not countries:
        print("No countries provided.", file=sys.stderr)
        return 2

    country_names = load_country_names(download_dir)
    admin1_names = load_admin1_names(download_dir)

    all_places: List[PlaceRow] = []
    all_aliases: Dict[str, List[Tuple[str, str, int]]] = {}
    by_country_counts: Dict[str, int] = defaultdict(int)

    for country in countries:
        zip_path = download_dir / f"{country}.zip"
        download_file(f"{GEONAMES_BASE}/{country}.zip", zip_path)
        resolved_country_name = country_names.get(country, country)
        print(f"[parse] {country} ({resolved_country_name})", file=sys.stderr)
        places, aliases = parse_country_dump(
            country_code=country,
            country_name=resolved_country_name,
            admin1_names=admin1_names,
            zip_path=zip_path,
            min_population=max(0, args.min_population),
            max_places=max(0, args.max_places_per_country),
            max_aliases=max(5, args.max_aliases_per_place),
        )
        all_places.extend(places)
        all_aliases.update(aliases)
        by_country_counts[country] += len(places)

    # Prefer larger/popular places first when duplicates on same place_id are impossible.
    all_places.sort(
        key=lambda r: (r.country_code, -r.population, r.city_name.lower(), r.geoname_id)
    )

    places_path = output_dir / "cis_places.csv"
    aliases_path = output_dir / "cis_place_aliases.csv"
    meta_path = output_dir / "cis_places_meta.json"

    places_count = write_places_csv(places_path, all_places)
    aliases_count = write_aliases_csv(aliases_path, all_aliases)

    metadata = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "source": "GeoNames dump (country files)",
        "source_base_url": GEONAMES_BASE,
        "countries": countries,
        "min_population": max(0, args.min_population),
        "max_places_per_country": max(0, args.max_places_per_country),
        "places_count": places_count,
        "aliases_count": aliases_count,
        "places_by_country": dict(sorted(by_country_counts.items())),
        "outputs": {
            "places_csv": str(places_path),
            "aliases_csv": str(aliases_path),
        },
    }
    meta_path.write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print(
        json.dumps(
            {
                "ok": True,
                "places_count": places_count,
                "aliases_count": aliases_count,
                "places_csv": str(places_path),
                "aliases_csv": str(aliases_path),
                "meta_json": str(meta_path),
            },
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

