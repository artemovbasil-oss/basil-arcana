#!/usr/bin/env python3
import json
import os
import sys
from typing import Any
from urllib.request import Request, urlopen

BASE_URL = os.environ.get("ASSETS_BASE_URL", "https://cdn.basilarcana.com").rstrip("/")
CARD_FILES = ["cards_ru.json", "cards_en.json", "cards_kz.json"]
SPREAD_FILES = ["spreads_ru.json", "spreads_en.json", "spreads_kz.json"]

CARD_KEYS = {"title", "keywords", "meaning", "fact", "stats"}
MEANING_KEYS = {"general", "detailed"}
STAT_KEYS = {"luck", "power", "love", "clarity"}
SPREAD_KEYS = {"id", "name", "title", "description", "cardsCount", "positions"}
POSITION_KEYS = {"id", "title", "meaning"}


def fetch_json(path: str) -> Any:
    url = f"{BASE_URL}/data/{path}"
    request = Request(url, headers={"Accept": "application/json"})
    with urlopen(request, timeout=30) as response:
        payload = response.read().decode("utf-8")
    return json.loads(payload)


def assert_no_fun_fact(payload: Any, path: str = "$") -> None:
    if isinstance(payload, dict):
        if "funFact" in payload:
            raise ValueError(f"funFact found at {path}")
        for key, value in payload.items():
            assert_no_fun_fact(value, f"{path}.{key}")
    elif isinstance(payload, list):
        for idx, item in enumerate(payload):
            assert_no_fun_fact(item, f"{path}[{idx}]")


def validate_cards(payload: Any, filename: str) -> None:
    if not isinstance(payload, dict) or not payload:
        raise ValueError(f"{filename} must be a non-empty JSON object")
    for card_id, card in payload.items():
        if not isinstance(card, dict):
            raise ValueError(f"{filename}:{card_id} must be an object")
        if set(card.keys()) != CARD_KEYS:
            raise ValueError(
                f"{filename}:{card_id} keys must be {sorted(CARD_KEYS)}"
            )
        keywords = card["keywords"]
        if not isinstance(keywords, list) or not (3 <= len(keywords) <= 6):
            raise ValueError(
                f"{filename}:{card_id} keywords must have 3-6 items"
            )
        meaning = card["meaning"]
        if not isinstance(meaning, dict) or set(meaning.keys()) != MEANING_KEYS:
            raise ValueError(
                f"{filename}:{card_id} meaning must have {sorted(MEANING_KEYS)}"
            )
        stats = card["stats"]
        if not isinstance(stats, dict) or set(stats.keys()) != STAT_KEYS:
            raise ValueError(
                f"{filename}:{card_id} stats must have {sorted(STAT_KEYS)}"
            )
        for stat_key in STAT_KEYS:
            stat_value = stats[stat_key]
            if not isinstance(stat_value, int) or not (0 <= stat_value <= 100):
                raise ValueError(
                    f"{filename}:{card_id} stat {stat_key} must be 0-100 int"
                )


def validate_spreads(payload: Any, filename: str) -> None:
    if not isinstance(payload, list) or not payload:
        raise ValueError(f"{filename} must be a non-empty JSON array")
    for spread in payload:
        if not isinstance(spread, dict):
            raise ValueError(f"{filename} entries must be objects")
        if set(spread.keys()) != SPREAD_KEYS:
            raise ValueError(
                f"{filename}:{spread.get('id')} keys must be {sorted(SPREAD_KEYS)}"
            )
        positions = spread["positions"]
        if not isinstance(positions, list):
            raise ValueError(f"{filename}:{spread.get('id')} positions must be list")
        if len(positions) != spread["cardsCount"]:
            raise ValueError(
                f"{filename}:{spread.get('id')} positions length must match cardsCount"
            )
        for position in positions:
            if not isinstance(position, dict):
                raise ValueError(
                    f"{filename}:{spread.get('id')} positions must be objects"
                )
            if set(position.keys()) != POSITION_KEYS:
                raise ValueError(
                    f"{filename}:{spread.get('id')} position keys must be {sorted(POSITION_KEYS)}"
                )


def main() -> int:
    for filename in CARD_FILES:
        payload = fetch_json(filename)
        assert_no_fun_fact(payload)
        validate_cards(payload, filename)
    for filename in SPREAD_FILES:
        payload = fetch_json(filename)
        assert_no_fun_fact(payload)
        validate_spreads(payload, filename)
    print("OK")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover - CLI error handling
        print(f"Validation failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
