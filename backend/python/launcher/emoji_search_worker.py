#!/usr/bin/env python3
"""Serve bounded Emoji and Unicode launcher searches over JSON lines."""

from __future__ import annotations

import json
import re
import sys
from itertools import chain
from pathlib import Path
from typing import Any

EMOJI_CATALOG_PATH = Path(__file__).with_name("emoji_catalog.jsonl")
UNICODE_CATALOG_PATH = Path(__file__).with_name("unicode_catalog.jsonl")
MAX_RESULTS = 100
MAX_QUERY_LENGTH = 160


def load_entries(path: Path) -> list[dict[str, str]]:
    entries: list[dict[str, str]] = []
    with path.open(encoding="utf-8") as catalog:
        for line in catalog:
            raw = line.strip()
            if not raw:
                continue
            entry = json.loads(raw)
            if isinstance(entry, dict) and entry.get("glyph"):
                entries.append(entry)
    return entries


def words(value: str, pattern: str) -> frozenset[str]:
    return frozenset(token for token in re.split(pattern, value) if token)


def prepare_entry(
    entry: dict[str, str],
    kind: str,
    order: int,
) -> tuple[dict[str, str], str, str, str, str, frozenset[str], frozenset[str], str, int]:
    glyph = str(entry.get("glyph") or "").lower()
    name = str(entry.get("name") or "").lower()
    keywords = str(entry.get("keywords") or "").lower()
    category = str(entry.get("category") or "").lower()
    return (
        entry,
        glyph,
        name,
        keywords,
        category,
        words(name, r"[^a-z0-9+]+"),
        words(keywords, r"\s+"),
        kind,
        order,
    )


def score_entry(
    prepared: tuple[dict[str, str], str, str, str, str, frozenset[str], frozenset[str], str, int],
    term: str,
    tokens: list[str],
) -> int | None:
    _, glyph, name, keywords, category, name_words, keyword_words, _, _ = prepared
    if glyph == term:
        return 0
    if name == term:
        return 1
    if category == term:
        return 2
    if term in keyword_words:
        return 3
    if len(term) > 1 and name.startswith(term):
        return 4
    if len(term) > 1 and (term in name or term in keywords or term in category):
        return 8

    score = 20
    for token in tokens:
        if glyph == token:
            continue
        if token in name_words:
            score += 1
        elif token in keyword_words:
            score += 2
        elif category == token:
            score += 2
        elif len(token) > 1 and token in name:
            score += 4
        elif len(token) > 1 and (token in keywords or token in category):
            score += 5
        else:
            return None
    return score


def result_for(
    prepared: tuple[dict[str, str], str, str, str, str, frozenset[str], frozenset[str], str, int],
    score: int | None = None,
) -> dict[str, Any]:
    entry, _, _, _, _, _, _, kind, order = prepared
    result: dict[str, Any] = {
        "type": "emoji",
        "characterKind": kind,
        "data": entry,
    }
    if score is not None:
        result["score"] = score
        result["order"] = order
    return result


def build_catalog() -> tuple[list[Any], list[Any]]:
    emoji_entries = load_entries(EMOJI_CATALOG_PATH)
    emoji_glyphs = {str(entry.get("glyph") or "") for entry in emoji_entries}
    emoji_catalog = [prepare_entry(entry, "emoji", index) for index, entry in enumerate(emoji_entries)]
    unicode_catalog = []
    next_order = len(emoji_catalog)
    for entry in load_entries(UNICODE_CATALOG_PATH):
        if str(entry.get("glyph") or "") in emoji_glyphs:
            continue
        unicode_catalog.append(prepare_entry(entry, "unicode", next_order))
        next_order += 1
    return emoji_catalog, unicode_catalog


def search(emoji_catalog: list[Any], unicode_catalog: list[Any], query: str, limit: int) -> list[dict[str, Any]]:
    term = query.strip().lower()[:MAX_QUERY_LENGTH]
    if not term:
        return [result_for(entry) for entry in emoji_catalog[:limit]]

    tokens = [token for token in re.split(r"\s+", term) if token]
    matches: list[tuple[int, int, Any]] = []
    for prepared in chain(emoji_catalog, unicode_catalog):
        score = score_entry(prepared, term, tokens)
        if score is not None:
            matches.append((score, prepared[-1], prepared))
    matches.sort(key=lambda match: (match[0], match[1]))
    return [result_for(prepared, score) for score, _, prepared in matches[:limit]]


def emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), flush=True)


def main() -> int:
    emoji_catalog, unicode_catalog = build_catalog()
    emit({"ready": True, "emojiCount": len(emoji_catalog), "unicodeCount": len(unicode_catalog)})
    for line in sys.stdin:
        request_id = -1
        try:
            request = json.loads(line)
            request_id = int(request.get("requestId", -1))
            limit = max(1, min(MAX_RESULTS, int(request.get("limit", 24))))
            results = search(emoji_catalog, unicode_catalog, str(request.get("query") or ""), limit)
            emit({"requestId": request_id, "results": results})
        except (OSError, TypeError, ValueError, json.JSONDecodeError) as error:
            emit({"requestId": request_id, "results": [], "error": str(error)})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
