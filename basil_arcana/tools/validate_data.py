#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List
from urllib.request import urlopen

REPO_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = REPO_ROOT / "cdn" / "data"

CARD_KEYS = {"title", "keywords", "meaning", "fact", "stats"}
OPTIONAL_CARD_KEYS = {"detailedDescription"}
MEANING_KEYS = {"general", "light", "shadow", "advice"}
STATS_KEYS = {"luck", "power", "love", "clarity"}


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def load_json_url(url: str) -> Any:
    with urlopen(url) as response:
        payload = response.read().decode("utf-8")
    return json.loads(payload)


def validate_card(card_id: str, card: Dict[str, Any], errors: List[str]) -> None:
    extra = set(card.keys()) - CARD_KEYS - OPTIONAL_CARD_KEYS
    missing = CARD_KEYS - set(card.keys())
    if extra or missing:
        if extra:
            errors.append(f"{card_id}: unexpected keys {sorted(extra)}")
        if missing:
            errors.append(f"{card_id}: missing keys {sorted(missing)}")
        return

    if not isinstance(card["title"], str):
        errors.append(f"{card_id}: title must be string")

    keywords = card["keywords"]
    if not isinstance(keywords, list) or not keywords or not all(isinstance(k, str) for k in keywords):
        errors.append(f"{card_id}: keywords must be non-empty list of strings")

    meaning = card["meaning"]
    if not isinstance(meaning, dict) or set(meaning.keys()) != MEANING_KEYS:
        errors.append(f"{card_id}: meaning must have keys {sorted(MEANING_KEYS)}")
    else:
        if not isinstance(meaning["general"], str):
            errors.append(f"{card_id}: meaning.general must be string")
        if not isinstance(meaning["light"], str):
            errors.append(f"{card_id}: meaning.light must be string")
        if not isinstance(meaning["shadow"], str):
            errors.append(f"{card_id}: meaning.shadow must be string")
        if not isinstance(meaning["advice"], str):
            errors.append(f"{card_id}: meaning.advice must be string")

    if not isinstance(card["fact"], str):
        errors.append(f"{card_id}: fact must be string")

    stats = card["stats"]
    if not isinstance(stats, dict) or set(stats.keys()) != STATS_KEYS:
        errors.append(f"{card_id}: stats must have keys {sorted(STATS_KEYS)}")
    else:
        for key in STATS_KEYS:
            value = stats[key]
            if not isinstance(value, int):
                errors.append(f"{card_id}: stats.{key} must be int")
            elif not (0 <= value <= 100):
                errors.append(f"{card_id}: stats.{key} must be 0..100")


def validate_spread(spread: Dict[str, Any], errors: List[str]) -> None:
    expected_keys = {"id", "name", "title", "description", "cardsCount", "positions"}
    if set(spread.keys()) != expected_keys:
        extra = set(spread.keys()) - expected_keys
        missing = expected_keys - set(spread.keys())
        if extra:
            errors.append(f"spread {spread.get('id', '<unknown>')}: unexpected keys {sorted(extra)}")
        if missing:
            errors.append(f"spread {spread.get('id', '<unknown>')}: missing keys {sorted(missing)}")
        return

    if not isinstance(spread["id"], str):
        errors.append("spread id must be string")
    if not isinstance(spread["name"], str):
        errors.append(f"spread {spread.get('id')}: name must be string")
    if not isinstance(spread["title"], str):
        errors.append(f"spread {spread.get('id')}: title must be string")
    if not isinstance(spread["description"], str):
        errors.append(f"spread {spread.get('id')}: description must be string")
    if not isinstance(spread["cardsCount"], int):
        errors.append(f"spread {spread.get('id')}: cardsCount must be int")

    positions = spread["positions"]
    if not isinstance(positions, list):
        errors.append(f"spread {spread.get('id')}: positions must be list")
        return

    if isinstance(spread.get("cardsCount"), int) and len(positions) != spread["cardsCount"]:
        errors.append(
            f"spread {spread.get('id')}: positions length {len(positions)} != cardsCount {spread['cardsCount']}"
        )

    for pos in positions:
        if not isinstance(pos, dict):
            errors.append(f"spread {spread.get('id')}: position must be object")
            continue
        if set(pos.keys()) != {"id", "title", "meaning"}:
            errors.append(
                f"spread {spread.get('id')}: position keys must be ['id', 'title', 'meaning']"
            )
            continue
        if not isinstance(pos["id"], str):
            errors.append(f"spread {spread.get('id')}: position id must be string")
        if not isinstance(pos["title"], str):
            errors.append(f"spread {spread.get('id')}: position title must be string")
        if not isinstance(pos["meaning"], str):
            errors.append(f"spread {spread.get('id')}: position meaning must be string")


def validate_cards(data: Any, errors: List[str]) -> None:
    if not isinstance(data, dict):
        errors.append("cards root must be object")
        return
    for card_id, card in data.items():
        if not isinstance(card_id, str):
            errors.append("card id must be string")
            continue
        if not isinstance(card, dict):
            errors.append(f"{card_id}: card must be object")
            continue
        validate_card(card_id, card, errors)


def validate_spreads(data: Any, errors: List[str]) -> None:
    if not isinstance(data, list):
        errors.append("spreads root must be list")
        return
    for spread in data:
        if not isinstance(spread, dict):
            errors.append("spread must be object")
            continue
        validate_spread(spread, errors)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate basil-arcana JSON data packs.")
    parser.add_argument(
        "--base-url",
        default=None,
        help="Optional base URL to fetch JSON (e.g. https://cdn.basilarcana.com/data).",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    errors: List[str] = []

    for locale in ("en", "ru", "kz"):
        cards_name = f"cards_{locale}.json"
        spreads_name = f"spreads_{locale}.json"
        if args.base_url:
            cards = load_json_url(f"{args.base_url}/{cards_name}")
            spreads = load_json_url(f"{args.base_url}/{spreads_name}")
        else:
            cards = load_json(DATA_DIR / cards_name)
            spreads = load_json(DATA_DIR / spreads_name)

        validate_cards(cards, errors)
        validate_spreads(spreads, errors)

    if errors:
        for err in errors:
            print(f"ERROR: {err}")
        sys.exit(1)

    print("OK")


if __name__ == "__main__":
    main()
