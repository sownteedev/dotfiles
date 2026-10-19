import argparse
import concurrent.futures
import hashlib
import html
import json
import math
import os
from pathlib import Path
import re
import tempfile
import time
import unicodedata
import urllib.parse
import urllib.request
from word_lyrics import line_lrc, word_lines


TIMESTAMP = re.compile(r"\[(\d+):([0-5]?\d(?:\.\d+)?)\]")
OFFSET = re.compile(r"\[offset:\s*([+-]?\d+)\]", re.I)
MAX_RESPONSE = 2 * 1024 * 1024
PROVIDER_SECONDS = 10


def normalized(value, keep_masks=False):
    value = unicodedata.normalize("NFKD", str(value or "").casefold())
    value = value.replace("\u0111", "d")
    return " ".join(re.sub(r"[^\w*]+" if keep_masks else r"[^\w]+", " ", "".join(
        char for char in value if not unicodedata.combining(char)
    )).split())


def number(value):
    try:
        result = float(value or 0)
        return result if math.isfinite(result) and result > 0 else 0
    except (TypeError, ValueError):
        return 0


def artist_names(value):
    return [normalized(part) for part in re.split(r",|;| & | feat\.? | ft\.? ", value, flags=re.I) if normalized(part)]

def strip_translation(value):
    return "\n".join(
        line.split("^", 1)[0].rstrip()
        for line in str(value or "").splitlines()
    ).strip()


def title_matches(track, record):
    wanted = normalized(track["title"], keep_masks=True)
    actual = normalized(record.get("trackName"), keep_masks=True)
    if not normalized(wanted) or not normalized(actual):
        return False
    if wanted == actual:
        return True
    if (not normalized(track["album"])
            or normalized(track["album"]) != normalized(record.get("albumName"))
            or not track["duration"] or not number(record.get("duration"))
            or abs(track["duration"] - number(record.get("duration"))) > 1):
        return False
    for masked, title in ((wanted, actual), (actual, wanted)):
        if "*" not in masked or "*" in title or len(re.sub(r"[\s*]", "", masked)) < 3:
            continue
        pattern = r"\w+".join(re.escape(part) for part in re.split(r"\*+", masked))
        if re.fullmatch(pattern, title):
            return True
    return False

def match_score(track, record):
    if not title_matches(track, record):
        return -1
    wanted = artist_names(track["artist"])
    actual = artist_names(record.get("artistName", ""))
    if not wanted or not actual or wanted[0] not in actual:
        return -1
    duration = number(record.get("duration"))
    difference = abs(duration - track["duration"])
    if track["duration"] and (not duration or difference > max(3, min(6, track["duration"] * 0.015))):
        return -1
    album_match = normalized(track["album"]) == normalized(record.get("albumName"))
    return 100 + (5 if album_match else 0) - difference


def clean_lyrics(value, duration):
    value = html.unescape(str(value or "")).strip()
    offset_match = OFFSET.search(value)
    offset = int(offset_match[1]) / 1000 if offset_match else 0
    lines = []
    plain = []
    for row in value.splitlines():
        stamps = TIMESTAMP.findall(row)
        text = strip_translation(TIMESTAMP.sub("", row))
        if not text or re.fullmatch(r"\[[a-z]+:.*\]", text, re.I):
            continue
        plain.append(text)
        for minutes, seconds in stamps:
            position = max(0, int(minutes) * 60 + float(seconds) + offset)
            if not duration or position <= duration + 3:
                lines.append((round(position * 100), text))
    lines = sorted(set(lines))
    if len({position for position, text in lines}) < 2:
        return "\n".join(plain), ""
    synced = "\n".join(
        f"[{position // 6000:02d}:{position // 100 % 60:02d}.{position % 100:02d}]{text}"
        for position, text in lines
    )
    return "\n".join(plain), synced


def prepare_record(track, record, source):
    score = match_score(track, record)
    if score < 0:
        return None
    plain, synced = clean_lyrics(record.get("syncedLyrics") or record.get("plainLyrics"), track["duration"])
    words = word_lines(record, track["duration"])
    if words:
        synced = line_lrc(words)
        plain = "\n".join(line["text"] for line in words)
    source_plain = strip_translation(record.get("plainLyrics"))
    if not plain and not synced and not record.get("instrumental"):
        return None
    return {
        "plainLyrics": source_plain or plain,
        "syncedLyrics": synced,
        "wordLines": words,
        "instrumental": bool(record.get("instrumental")) and not plain and not synced,
        "source": source,
        "score": score,
    }


def rank(record):
    return (bool(record.get("wordLines")), bool(record.get("syncedLyrics")), bool(record.get("plainLyrics")), record.get("score", 0))


def request_json(endpoint, params, deadline, referer=None):
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise TimeoutError("provider deadline")
    headers = {"User-Agent": "SownteeShell-Music/1.0", "Accept": "application/json"}
    if referer:
        headers["Referer"] = referer
    request = urllib.request.Request(endpoint + "?" + urllib.parse.urlencode(params), headers=headers)
    with urllib.request.urlopen(request, timeout=min(4, remaining)) as response:
        content = response.read(MAX_RESPONSE + 1)
    if len(content) > MAX_RESPONSE:
        raise ValueError("response too large")
    return json.loads(content)


def lrclib(track, deadline):
    best = None
    last_error = None
    searched = False
    queries = [{"track_name": track["title"], "artist_name": track["artist"]}]
    if track["album"] and track["duration"]:
        queries.append({"q": track["artist"] + " " + track["album"]})
    queries.append({"track_name": track["title"]})
    for params in queries:
        if best and params == {"track_name": track["title"]}:
            continue
        try:
            records = request_json("https://lrclib.net/api/search", params, deadline)
            searched = True
        except Exception as error:
            last_error = error
            continue
        for record in records:
            candidate = prepare_record(track, record, "LRCLIB")
            if candidate and (not best or rank(candidate) > rank(best)):
                best = candidate
        if best and best.get("wordLines"):
            return best
    if not searched and last_error:
        raise last_error
    return best


def netease(track, deadline):
    data = request_json("https://music.163.com/api/search/get", {
        "s": track["title"] + " " + track["artist"], "type": 1, "limit": 12, "offset": 0,
    }, deadline)
    if data.get("code") != 200:
        raise ValueError("search unavailable")
    candidates = []
    for song in data.get("result", {}).get("songs", []):
        record = {
            "trackName": song.get("name"),
            "artistName": ", ".join(artist.get("name", "") for artist in song.get("artists", [])),
            "albumName": song.get("album", {}).get("name"),
            "duration": number(song.get("duration")) / 1000,
        }
        score = match_score(track, record)
        if score >= 0:
            candidates.append((score, song["id"], record))
    best = None
    for score, song_id, record in sorted(candidates, key=lambda item: item[0], reverse=True)[:2]:
        try:
            lyrics = request_json("https://music.163.com/api/song/lyric/v1", {
                "id": song_id, "cp": "false", "lv": 0, "kv": 0, "yv": 0, "tv": 0, "rv": 0, "ytv": 0, "yrv": 0,
            }, deadline)
            if lyrics.get("code") != 200:
                raise ValueError("word lyrics unavailable")
        except Exception:
            try:
                lyrics = request_json("https://music.163.com/api/song/lyric", {"id": song_id, "lv": 1}, deadline)
            except Exception:
                if best:
                    break
                raise
        if lyrics.get("code") != 200:
            raise ValueError("lyrics unavailable")
        record["syncedLyrics"] = lyrics.get("lrc", {}).get("lyric", "")
        record["yrc"] = lyrics.get("yrc", {}).get("lyric", "")
        candidate = prepare_record(track, record, "NetEase")
        if candidate and (not best or rank(candidate) > rank(best)):
            best = candidate
        if best and best.get("wordLines"):
            break
    return best


def qqmusic(track, deadline):
    data = request_json("https://c.y.qq.com/soso/fcgi-bin/client_search_cp", {
        "w": track["title"] + " " + track["artist"], "format": "json", "p": 1, "n": 12,
    }, deadline, "https://y.qq.com/")
    if data.get("code") != 0:
        raise ValueError("search unavailable")
    candidates = []
    for song in data.get("data", {}).get("song", {}).get("list", []):
        record = {
            "trackName": html.unescape(song.get("songname", "")),
            "artistName": ", ".join(html.unescape(artist.get("name", "")) for artist in song.get("singer", [])),
            "albumName": song.get("albumname"),
            "duration": number(song.get("interval")),
        }
        score = match_score(track, record)
        if score >= 0:
            candidates.append((score, song["songmid"], record))
    best = None
    for score, song_id, record in sorted(candidates, key=lambda item: item[0], reverse=True)[:2]:
        try:
            lyrics = request_json("https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg", {
                "songmid": song_id, "format": "json", "nobase64": 1,
            }, deadline, "https://y.qq.com/")
        except Exception:
            if best:
                break
            raise
        if lyrics.get("code") != 0 or lyrics.get("retcode", 0) != 0:
            raise ValueError("lyrics unavailable")
        record["syncedLyrics"] = lyrics.get("lyric", "")
        try:
            karaoke = request_json("https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg", {
                "songmid": song_id, "format": "json", "nobase64": 1, "qrc": 1,
            }, deadline, "https://y.qq.com/")
            if karaoke.get("code") == 0:
                record["qrc"] = karaoke.get("lyric", "")
        except Exception:
            pass
        candidate = prepare_record(track, record, "QQ Music")
        if candidate and (not best or rank(candidate) > rank(best)):
            best = candidate
        if best and best.get("wordLines"):
            break
    return best


def cache_path():
    return Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "sownteeshell" / "lyrics-v4.json"


def read_cache():
    try:
        content = cache_path().read_text()
        if len(content) > 4 * MAX_RESPONSE:
            return {}
        data = json.loads(content)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def cached_record(key):
    entry = read_cache().get(key)
    if not isinstance(entry, dict) or not isinstance(entry.get("record"), dict):
        return None
    ttl = 7 * 86400 if entry["record"].get("syncedLyrics") else 3600
    age = time.time() - number(entry.get("time"))
    return entry["record"] if 0 <= age < ttl else None


def save_cache(key, record):
    path = cache_path()
    temporary = None
    try:
        entries = read_cache()
        entries[key] = {"time": time.time(), "record": record}
        entries = dict(sorted(
            ((entry_key, value) for entry_key, value in entries.items() if isinstance(value, dict)),
            key=lambda item: number(item[1].get("time")), reverse=True,
        )[:48])
        path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as output:
            temporary = output.name
            json.dump(entries, output, ensure_ascii=False)
        os.replace(temporary, path)
    except OSError:
        pass
    finally:
        if temporary and os.path.exists(temporary):
            os.unlink(temporary)


def emit(record, done=False, failed=False):
    print(json.dumps({"record": record, "done": done, "failed": failed}, ensure_ascii=False), flush=True)


def lookup(track):
    key = hashlib.sha256(json.dumps(track, sort_keys=True).encode()).hexdigest()
    cached = cached_record(key)
    if cached:
        emit(cached, done=True)
        return
    best = None
    failures = 0
    providers = (lrclib, netease, qqmusic)
    deadline = time.monotonic() + PROVIDER_SECONDS
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(providers)) as executor:
        futures = [executor.submit(provider, track, deadline) for provider in providers]
        for future in concurrent.futures.as_completed(futures):
            try:
                record = future.result()
            except Exception:
                failures += 1
                continue
            if record and record.get("wordLines"):
                save_cache(key, record)
                emit(record, done=True)
                for pending in futures:
                    pending.cancel()
                return
            if record and (not best or rank(record) > rank(best)):
                best = record
                emit(best)
    if best and (best["syncedLyrics"] or not failures):
        save_cache(key, best)
    emit(best, done=True, failed=failures == len(providers))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--title", required=True)
    parser.add_argument("--artist", required=True)
    parser.add_argument("--album", default="")
    parser.add_argument("--duration", type=float, default=0)
    args = parser.parse_args()
    lookup({"title": args.title, "artist": args.artist, "album": args.album, "duration": number(args.duration)})


if __name__ == "__main__":
    main()
