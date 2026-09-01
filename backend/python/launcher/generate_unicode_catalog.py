#!/usr/bin/env python3
"""Generate the offline Unicode catalog used by the unified launcher provider."""

from __future__ import annotations

import argparse
import json
import re
import unicodedata
from pathlib import Path


QUICKSHELL_DIR = Path(__file__).resolve().parents[3]
OUTPUT_PATH = QUICKSHELL_DIR / "widget" / "launcher" / "LauncherUnicodeCatalog.js"

BLOCKS = (
    ("Latin-1 Supplement", 0x00A1, 0x00FF, "Latin", ("latin", "accented")),
    ("Latin Extended-A", 0x0100, 0x017F, "Latin", ("latin", "accented")),
    ("Latin Extended-B", 0x0180, 0x024F, "Latin", ("latin", "accented")),
    ("Latin Extended Additional", 0x1E00, 0x1EFF, "Latin", ("latin", "accented")),
    ("Greek and Coptic", 0x0370, 0x03FF, "Greek", ("greek",)),
    ("Currency Symbols", 0x20A0, 0x20CF, "Currency", ("currency", "money")),
    ("Arrows", 0x2190, 0x21FF, "Arrows", ("arrow", "direction")),
    ("Supplemental Arrows-A", 0x27F0, 0x27FF, "Arrows", ("arrow", "direction")),
    ("Supplemental Arrows-B", 0x2900, 0x297F, "Arrows", ("arrow", "direction")),
    ("Mathematical Operators", 0x2200, 0x22FF, "Mathematics", ("math", "operator")),
    ("Miscellaneous Mathematical Symbols-A", 0x27C0, 0x27EF, "Mathematics", ("math", "operator")),
    ("Miscellaneous Mathematical Symbols-B", 0x2980, 0x29FF, "Mathematics", ("math", "operator")),
    ("Supplemental Mathematical Operators", 0x2A00, 0x2AFF, "Mathematics", ("math", "operator")),
    ("Superscripts and Subscripts", 0x2070, 0x209F, "Numbers", ("superscript", "subscript")),
    ("Letterlike Symbols", 0x2100, 0x214F, "Letterlike", ("letterlike",)),
    ("Number Forms", 0x2150, 0x218F, "Numbers", ("number", "fraction", "roman")),
    ("General Punctuation", 0x2000, 0x206F, "Punctuation", ("punctuation",)),
    ("Miscellaneous Technical", 0x2300, 0x23FF, "Technical", ("technical",)),
    ("Enclosed Alphanumerics", 0x2460, 0x24FF, "Enclosed", ("enclosed", "circle")),
    ("Box Drawing", 0x2500, 0x257F, "Box Drawing", ("box", "drawing", "line")),
    ("Block Elements", 0x2580, 0x259F, "Blocks", ("block", "shade")),
    ("Geometric Shapes", 0x25A0, 0x25FF, "Shapes", ("shape", "geometry")),
    ("Miscellaneous Symbols", 0x2600, 0x26FF, "Symbols", ("symbol",)),
    ("Dingbats", 0x2700, 0x27BF, "Dingbats", ("dingbat", "symbol")),
)

EXCLUDED_CATEGORIES = {"Cc", "Cf", "Cn", "Co", "Cs", "Mc", "Me", "Mn", "Zl", "Zp", "Zs"}
KEYWORD_STOPWORDS = {"a", "and", "of", "the", "with"}

LANGUAGE_CHARACTERS = {
    "spanish": set("áéíóúüñÁÉÍÓÚÜÑ¿¡"),
    "french": set("àâæçéèêëîïôœùûüÿÀÂÆÇÉÈÊËÎÏÔŒÙÛÜŸ"),
    "portuguese": set("áàâãçéêíóôõúüÁÀÂÃÇÉÊÍÓÔÕÚÜ"),
    "german": set("äöüßÄÖÜẞ"),
    "nordic": set("åæøäöÅÆØÄÖ"),
    "polish": set("ąćęłńóśźżĄĆĘŁŃÓŚŹŻ"),
    "czech slovak": set("áäčďéěíĺľňóôŕřšťúůýžÁÄČĎÉĚÍĹĽŇÓÔŔŘŠŤÚŮÝŽ"),
    "romanian": set("ăâîșşțţĂÂÎȘŞȚŢ"),
    "hungarian": set("áéíóöőúüűÁÉÍÓÖŐÚÜŰ"),
    "turkish": set("çğıİöşüÇĞIÖŞÜ"),
    "icelandic": set("áðéíóúýþæöÁÐÉÍÓÚÝÞÆÖ"),
    "vietnamese": set(
        "àáạảãăằắặẳẵâầấậẩẫèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡ"
        "ùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃĂẰẮẶẲẴÂẦẤẬẨẪÈÉẸẺẼÊỀẾỆỂỄ"
        "ÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ"
    ),
}

ALIASES = {
    "©": ("copyright",),
    "®": ("registered", "trademark"),
    "™": ("trademark",),
    "°": ("degree", "temperature"),
    "±": ("plus", "minus"),
    "×": ("multiply", "multiplication"),
    "÷": ("divide", "division"),
    "∞": ("infinity", "infinite"),
    "√": ("root", "square root"),
    "∑": ("sum", "summation"),
    "∏": ("product",),
    "∫": ("integral",),
    "≈": ("approximately", "approx"),
    "≠": ("not equal", "unequal"),
    "≤": ("less equal",),
    "≥": ("greater equal",),
    "←": ("left", "back"),
    "→": ("right", "next"),
    "↑": ("up",),
    "↓": ("down",),
    "↔": ("left right", "horizontal"),
    "↕": ("up down", "vertical"),
}


def keyword_tokens(value: str) -> list[str]:
    return [token for token in re.split(r"[^\w+]+", value.lower(), flags=re.UNICODE) if token]


def language_keywords(character: str) -> list[str]:
    keywords: list[str] = []
    for language, characters in LANGUAGE_CHARACTERS.items():
        if character in characters:
            keywords.extend(language.split())
    return keywords


def build_keywords(
    character: str,
    name: str,
    block_name: str,
    category_name: str,
    block_keywords: tuple[str, ...],
    codepoint: str,
) -> str:
    values = [name, block_name, category_name, *block_keywords, "unicode", "character", codepoint, codepoint[2:]]
    values.extend(language_keywords(character))
    values.extend(ALIASES.get(character, ()))

    decomposition = unicodedata.normalize("NFD", character)
    if decomposition and decomposition[0].isascii() and decomposition[0].isalnum():
        values.append(decomposition[0])

    seen: set[str] = set()
    tokens: list[str] = []
    for value in values:
        for token in keyword_tokens(value):
            if token in KEYWORD_STOPWORDS or token in seen:
                continue
            seen.add(token)
            tokens.append(token)
    return " ".join(tokens)


def display_name(name: str) -> str:
    return " ".join(part.capitalize() for part in name.split())


def catalog_entries() -> list[dict[str, str]]:
    entries: list[dict[str, str]] = []
    seen: set[str] = set()
    for block_name, start, end, category_name, block_keywords in BLOCKS:
        for value in range(start, end + 1):
            character = chr(value)
            if character in seen or character.isspace() or unicodedata.category(character) in EXCLUDED_CATEGORIES:
                continue
            try:
                name = unicodedata.name(character)
            except ValueError:
                continue
            if "VARIATION SELECTOR" in name:
                continue

            seen.add(character)
            codepoint = f"U+{value:04X}"
            entries.append(
                {
                    "glyph": character,
                    "name": display_name(name),
                    "keywords": build_keywords(
                        character,
                        name,
                        block_name,
                        category_name,
                        block_keywords,
                        codepoint.lower(),
                    ),
                    "category": category_name,
                    "codepoint": codepoint,
                }
            )
    return entries


def render_catalog(entries: list[dict[str, str]]) -> str:
    lines = [
        "// Auto-generated by backend/python/launcher/generate_unicode_catalog.py.",
        f"// Python Unicode database version: {unicodedata.unidata_version}.",
        "// Do not edit manually.",
        "",
        "var unicodeEntries = [",
    ]
    for entry in entries:
        lines.append("    " + json.dumps(entry, ensure_ascii=False, separators=(",", ":")) + ",")
    lines.extend(
        [
            "]",
            "",
            "function getEntries() {",
            "    return unicodeEntries;",
            "}",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="fail when the generated catalog is stale")
    args = parser.parse_args()

    entries = catalog_entries()
    rendered = render_catalog(entries)
    if args.check:
        if not OUTPUT_PATH.exists() or OUTPUT_PATH.read_text(encoding="utf-8") != rendered:
            print(f"Unicode catalog is stale: {OUTPUT_PATH}")
            return 1
        print(f"Unicode catalog is current: {OUTPUT_PATH}")
        return 0

    OUTPUT_PATH.write_text(rendered, encoding="utf-8")
    print(f"Generated {len(entries)} Unicode entries in {OUTPUT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
