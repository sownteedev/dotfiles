import html
import math
import re
import xml.etree.ElementTree as ElementTree

def strip_translation(value):
    return str(value or "").split("^", 1)[0].rstrip()


def milliseconds(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError("invalid timestamp")
    if not math.isfinite(value) or value < 0:
        raise ValueError("invalid timestamp")
    return value / 1000


def normalize_lines(lines, duration):
    if not isinstance(lines, list) or len(lines) > 1500:
        return []
    result = []
    has_words = False
    for line in lines:
        if not isinstance(line, dict) or not isinstance(line.get("text"), str):
            continue
        try:
            start = milliseconds(line.get("start_ms"))
            end = milliseconds(line.get("end_ms")) if line.get("end_ms") is not None else None
        except ValueError:
            continue
        if duration and start > duration + 3:
            continue
        original_text = line["text"]
        text = strip_translation(original_text)
        if not text.strip() or len(text) > 2000:
            continue
        raw_words = line.get("words", [])
        if "^" in original_text or any("^" in str(word.get("text", "")) for word in raw_words if isinstance(word, dict)):
            raw_words = []
        words = []
        try:
            if not isinstance(raw_words, list) or len(raw_words) > 400:
                raise ValueError("invalid words")
            for index, word in enumerate(raw_words):
                if not isinstance(word, dict) or not isinstance(word.get("text"), str):
                    raise ValueError("invalid word")
                word_start = milliseconds(word.get("start_ms"))
                boundary = word.get("end_ms")
                if boundary is None and index + 1 < len(raw_words):
                    boundary = raw_words[index + 1].get("start_ms")
                word_end = milliseconds(boundary) if boundary is not None else end
                if word_end is None:
                    word_end = word_start
                if word_end < word_start or word_start < start:
                    raise ValueError("invalid word range")
                if words and word_start < words[-1]["start"]:
                    raise ValueError("unordered words")
                if (end is not None and word_end > end + 0.001) or (duration and word_end > duration + 3):
                    raise ValueError("word outside track")
                words.append({"text": word["text"], "start": word_start, "end": word_end})
            if "".join(word["text"] for word in words) != text:
                raise ValueError("word text mismatch")
            if len([word for word in words if word["text"].strip()]) < 2:
                words = []
        except (ValueError, TypeError, AttributeError):
            words = []
        if end is not None and end < start:
            words = []
        has_words = has_words or bool(words)
        result.append({"time": start, "end": end, "text": text, "words": words})
    result.sort(key=lambda line: line["time"])
    return result if has_words else []


def lyricsfile_lines(value, duration):
    if not isinstance(value, str) or len(value) > 1024 * 1024:
        return []
    try:
        import yaml

        for token in yaml.scan(value):
            if isinstance(token, (yaml.tokens.AliasToken, yaml.tokens.AnchorToken, yaml.tokens.TagToken)):
                return []
        document = yaml.safe_load(value)
        if not isinstance(document, dict):
            return []
        return normalize_lines(document.get("lines"), duration)
    except (ImportError, ValueError, RecursionError):
        return []
    except Exception:
        return []


def timed_format_lines(value, duration, yrc=False):
    if not isinstance(value, str) or len(value) > 1024 * 1024:
        return []
    if value.lstrip().startswith("<"):
        if "<!DOCTYPE" in value.upper() or "<!ENTITY" in value.upper():
            return []
        try:
            document = ElementTree.fromstring(value)
            value = next((node.attrib["LyricContent"] for node in document.iter() if "LyricContent" in node.attrib), "")
        except (ElementTree.ParseError, RecursionError):
            return []
    result = []
    for row in value.splitlines()[:1500]:
        header = re.match(r"^\[(\d+),(\d+)\]", row.strip())
        if not header:
            continue
        content = row.strip()[header.end():]
        words = []
        if yrc:
            pattern = r"\((\d+),(\d+),\d+\)(.*?)(?=\(\d+,\d+,\d+\)|$)"
            for match in re.finditer(pattern, content):
                start, length, text = match.groups()
                words.append({"text": html.unescape(text), "start_ms": int(start), "end_ms": int(start) + int(length)})
        else:
            for match in re.finditer(r"(.*?)\((\d+),(\d+)\)", content):
                text, start, length = match.groups()
                words.append({"text": html.unescape(text), "start_ms": int(start), "end_ms": int(start) + int(length)})
        result.append({
            "text": "".join(word["text"] for word in words),
            "start_ms": int(header[1]), "end_ms": int(header[1]) + int(header[2]), "words": words,
        })
    return normalize_lines(result, duration)


def word_lines(record, duration):
    return (lyricsfile_lines(record.get("lyricsfile"), duration)
            or timed_format_lines(record.get("yrc"), duration, yrc=True)
            or timed_format_lines(record.get("qrc"), duration))


def line_lrc(lines):
    rows = []
    for line in lines:
        position = round(line["time"] * 100)
        rows.append(f"[{position // 6000:02d}:{position // 100 % 60:02d}.{position % 100:02d}]{line['text']}")
    return "\n".join(rows)
