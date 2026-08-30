#!/usr/bin/env python3

"""Search, download, and manage wallpapers through the Wallhaven API."""

from __future__ import annotations

import json
import os
import re
import signal
import struct
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


API_ROOT = "https://wallhaven.cc/api/v1"
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
ID_PATTERN = re.compile(r"^[a-zA-Z0-9]{2,16}$")
ACTIVE_PART: Path | None = None
LOCAL_NAME_PATTERN = re.compile(r"^wallhaven-([a-zA-Z0-9]{2,16})\.(?:jpe?g|png|webp)$", re.IGNORECASE)
COLOR_PATTERN = re.compile(r"^[0-9a-fA-F]{6}$")
SORTING_OPTIONS = {"date_added", "relevance", "random", "views", "favorites", "toplist"}
TOP_RANGE_OPTIONS = {"1d", "3d", "1w", "1M", "3M", "6M", "1y"}


def emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False), flush=True)


def read_payload() -> dict[str, Any]:
    try:
        payload = json.loads(sys.stdin.readline() or "{}")
    except json.JSONDecodeError:
        return {}
    return payload if isinstance(payload, dict) else {}


def api_get(endpoint: str, parameters: dict[str, Any], api_key: str = "") -> dict[str, Any]:
    values = {key: value for key, value in parameters.items() if value not in (None, "")}
    url = API_ROOT + endpoint
    if values:
        url += "?" + urllib.parse.urlencode(values)
    headers = {
        "Accept": "application/json",
        "User-Agent": "Quickshell-Wallhaven/1.0",
    }
    if api_key:
        headers["X-API-Key"] = api_key
    request = urllib.request.Request(url, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(request, timeout=25) as response:
            value = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        messages = {
            401: ("authentication_required", "Wallhaven rejected the API key"),
            403: ("authentication_required", "This Wallhaven content needs account access"),
            404: ("not_found", "Wallhaven could not find this resource"),
            429: ("rate_limited", "Wallhaven rate limit reached; wait a moment and try again"),
        }
        code, message = messages.get(error.code, ("http_error", f"Wallhaven request failed ({error.code})"))
        return {"ok": False, "code": code, "message": message}
    except (urllib.error.URLError, TimeoutError):
        return {"ok": False, "code": "network_error", "message": "Could not reach Wallhaven"}
    except (UnicodeDecodeError, json.JSONDecodeError):
        return {"ok": False, "code": "invalid_response", "message": "Wallhaven returned unreadable data"}
    return value if isinstance(value, dict) else {"ok": False, "message": "Wallhaven returned invalid data"}


def local_wallpaper(wallpaper_dir: Path, wallpaper_id: str) -> Path | None:
    if not wallpaper_dir.is_dir() or not ID_PATTERN.fullmatch(wallpaper_id):
        return None
    try:
        root = wallpaper_dir.resolve()
    except OSError:
        return None
    for candidate in wallpaper_dir.glob(f"wallhaven-{wallpaper_id}.*"):
        if candidate.is_symlink() or not candidate.is_file() or candidate.suffix.lower() not in ALLOWED_EXTENSIONS:
            continue
        try:
            resolved = candidate.resolve()
        except OSError:
            continue
        if resolved.parent == root:
            return resolved
    return None

def resolved_input_path(value: str) -> Path:
    parsed = urllib.parse.urlparse(value)
    if parsed.scheme == "file":
        return Path(urllib.parse.unquote(parsed.path)).expanduser()
    return Path(value).expanduser()

def image_dimensions(path: Path) -> tuple[int, int]:
    try:
        with path.open("rb") as source:
            data = source.read(131072)
    except OSError:
        return 0, 0
    if data.startswith(b"\x89PNG\r\n\x1a\n") and len(data) >= 24:
        return struct.unpack(">II", data[16:24])
    if data.startswith(b"\xff\xd8"):
        offset = 2
        sof_markers = {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}
        while offset + 9 < len(data):
            if data[offset] != 0xFF:
                offset += 1
                continue
            marker = data[offset + 1]
            offset += 2
            if marker in {0xD8, 0xD9} or 0xD0 <= marker <= 0xD7:
                continue
            if offset + 2 > len(data):
                break
            segment_length = int.from_bytes(data[offset:offset + 2], "big")
            if marker in sof_markers and offset + 7 <= len(data):
                return int.from_bytes(data[offset + 5:offset + 7], "big"), int.from_bytes(data[offset + 3:offset + 5], "big")
            if segment_length < 2:
                break
            offset += segment_length
    if len(data) >= 30 and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        chunk = data[12:16]
        if chunk == b"VP8X":
            return 1 + int.from_bytes(data[24:27], "little"), 1 + int.from_bytes(data[27:30], "little")
        if chunk == b"VP8L" and data[20] == 0x2F:
            width = 1 + data[21] + ((data[22] & 0x3F) << 8)
            height = 1 + (data[22] >> 6) + (data[23] << 2) + ((data[24] & 0x0F) << 10)
            return width, height
        if chunk == b"VP8 " and data[23:26] == b"\x9d\x01\x2a":
            return int.from_bytes(data[26:28], "little") & 0x3FFF, int.from_bytes(data[28:30], "little") & 0x3FFF
    return 0, 0

def local_item(path: Path, wallpaper_dir: Path) -> dict[str, Any] | None:
    match = LOCAL_NAME_PATTERN.fullmatch(path.name)
    if match is None or path.is_symlink() or not path.is_file():
        return None
    try:
        root = wallpaper_dir.resolve()
        resolved = path.resolve(strict=True)
        stat = resolved.stat()
    except OSError:
        return None
    if resolved.parent != root or resolved.suffix.lower() not in ALLOWED_EXTENSIONS:
        return None
    wallpaper_id = match.group(1)
    width, height = image_dimensions(resolved)
    return {
        "id": wallpaper_id,
        "url": f"https://wallhaven.cc/w/{wallpaper_id}",
        "full": "",
        "preview": str(resolved),
        "thumb": str(resolved),
        "category": "local",
        "purity": "",
        "nsfw": False,
        "resolution": f"{width}x{height}" if width > 0 and height > 0 else "",
        "width": width,
        "height": height,
        "ratio": "",
        "file_size": stat.st_size,
        "file_type": resolved.suffix.lower().lstrip("."),
        "views": 0,
        "favorites": 0,
        "source": "",
        "created_at": "",
        "downloaded": True,
        "path": str(resolved),
        "modified": int(stat.st_mtime_ns // 1_000_000),
    }

def list_installed(payload: dict[str, Any]) -> dict[str, Any]:
    wallpaper_dir = Path(str(payload.get("wallpaper_dir") or "~/Pictures/Wallpapers")).expanduser()
    if not wallpaper_dir.is_dir():
        return {"ok": True, "items": []}
    items = []
    try:
        candidates = list(wallpaper_dir.iterdir())
    except OSError:
        return {"ok": False, "code": "list_failed", "message": "Could not read the wallpaper folder"}
    for candidate in candidates:
        item = local_item(candidate, wallpaper_dir)
        if item is not None:
            items.append(item)
    items.sort(key=lambda item: int(item.get("modified") or 0), reverse=True)
    return {"ok": True, "items": items}

def remove(payload: dict[str, Any]) -> dict[str, Any]:
    wallpaper_id = str(payload.get("id") or "").strip()
    target_text = str(payload.get("path") or "").strip()
    if not ID_PATTERN.fullmatch(wallpaper_id) or not target_text:
        return {"ok": False, "code": "invalid_file", "message": "Invalid installed Wallhaven wallpaper"}

    wallpaper_dir = Path(str(payload.get("wallpaper_dir") or "~/Pictures/Wallpapers")).expanduser()
    target = resolved_input_path(target_text)
    if target.is_symlink():
        return {"ok": False, "code": "unsafe_path", "message": "Refusing to remove a symbolic link"}
    try:
        root = wallpaper_dir.resolve()
        resolved = target.resolve(strict=True)
    except OSError:
        return {"ok": False, "code": "not_found", "message": "Installed wallpaper was not found"}
    match = LOCAL_NAME_PATTERN.fullmatch(resolved.name)
    if match is None or match.group(1) != wallpaper_id or resolved.parent != root or not resolved.is_file():
        return {"ok": False, "code": "unsafe_path", "message": "Refusing to remove a file outside the Wallhaven wallpaper folder"}

    current_text = str(payload.get("current_path") or "").strip()
    if current_text:
        try:
            if resolved_input_path(current_text).resolve() == resolved:
                return {"ok": False, "code": "in_use", "message": "Choose another wallpaper before deleting this one"}
        except OSError:
            pass
    try:
        removed_size = resolved.stat().st_size
        resolved.unlink()
    except OSError:
        return {"ok": False, "code": "remove_failed", "message": "Could not delete the wallpaper permanently"}
    return {
        "ok": True,
        "id": wallpaper_id,
        "path": str(resolved),
        "title": f"wallhaven-{wallpaper_id}",
        "bytes_removed": removed_size,
    }


def normalize_wallpaper(item: dict[str, Any], wallpaper_dir: Path) -> dict[str, Any]:
    wallpaper_id = str(item.get("id") or "")
    local_path = local_wallpaper(wallpaper_dir, wallpaper_id)
    thumbs = item.get("thumbs") if isinstance(item.get("thumbs"), dict) else {}
    resolution = str(item.get("resolution") or "")
    return {
        "id": wallpaper_id,
        "url": str(item.get("url") or ""),
        "full": str(item.get("path") or ""),
        "preview": str(thumbs.get("large") or thumbs.get("original") or thumbs.get("small") or ""),
        "thumb": str(thumbs.get("small") or thumbs.get("original") or ""),
        "category": str(item.get("category") or "general"),
        "purity": str(item.get("purity") or "sfw"),
        "nsfw": str(item.get("purity") or "").lower() == "nsfw",
        "resolution": resolution,
        "width": int(item.get("dimension_x") or 0),
        "height": int(item.get("dimension_y") or 0),
        "ratio": str(item.get("ratio") or ""),
        "file_size": int(item.get("file_size") or 0),
        "file_type": str(item.get("file_type") or ""),
        "views": int(item.get("views") or 0),
        "favorites": int(item.get("favorites") or 0),
        "source": str(item.get("source") or ""),
        "created_at": str(item.get("created_at") or ""),
        "downloaded": local_path is not None,
        "path": str(local_path) if local_path else "",
        "modified": int(local_path.stat().st_mtime_ns // 1_000_000) if local_path else 0,
    }


def normalize_page(response: dict[str, Any], wallpaper_dir: Path) -> dict[str, Any]:
    if response.get("ok") is False:
        return response
    raw_items = response.get("data")
    meta = response.get("meta") if isinstance(response.get("meta"), dict) else {}
    items = [normalize_wallpaper(item, wallpaper_dir) for item in raw_items or [] if isinstance(item, dict)]
    return {
        "ok": True,
        "items": items,
        "current_page": int(meta.get("current_page") or 1),
        "last_page": int(meta.get("last_page") or 1),
        "total": int(meta.get("total") or len(items)),
        "seed": str(meta.get("seed") or ""),
    }


def bit_filter(value: Any, fallback: str) -> str:
    text = str(value or "")
    return text if re.fullmatch(r"[01]{3}", text) and text != "000" else fallback


def search(payload: dict[str, Any]) -> dict[str, Any]:
    api_key = str(payload.get("api_key") or "").strip()
    try:
        page = max(1, int(payload.get("page") or 1))
    except (TypeError, ValueError):
        page = 1
    sorting = str(payload.get("sorting") or "toplist")
    if sorting not in SORTING_OPTIONS:
        sorting = "toplist"
    categories = bit_filter(payload.get("categories"), "111")
    purity = bit_filter(payload.get("purity"), "110")
    if not api_key:
        purity = purity[:2] + "0"
        if purity == "000":
            purity = "100"
    order = str(payload.get("order") or "desc")
    if order not in {"asc", "desc"}:
        order = "desc"
    top_range = str(payload.get("top_range") or "1M")
    if top_range not in TOP_RANGE_OPTIONS:
        top_range = "1M"
    color = str(payload.get("colors") or "").lstrip("#")
    if color and not COLOR_PATTERN.fullmatch(color):
        color = ""
    seed = str(payload.get("seed") or "")
    if not re.fullmatch(r"[a-zA-Z0-9]{1,32}", seed):
        seed = ""
    parameters = {
        "q": str(payload.get("query") or "").strip(),
        "categories": categories,
        "purity": purity,
        "sorting": sorting,
        "order": order,
        "topRange": top_range if sorting == "toplist" else "",
        "atleast": str(payload.get("atleast") or ""),
        "resolutions": str(payload.get("resolutions") or ""),
        "ratios": str(payload.get("ratios") or ""),
        "colors": color,
        "seed": seed if sorting == "random" else "",
        "page": page,
    }
    response = api_get("/search", parameters, api_key)
    wallpaper_dir = Path(str(payload.get("wallpaper_dir") or "~/Pictures/Wallpapers")).expanduser()
    return normalize_page(response, wallpaper_dir)


def collections(payload: dict[str, Any]) -> dict[str, Any]:
    api_key = str(payload.get("api_key") or "").strip()
    if not api_key:
        return {"ok": False, "code": "authentication_required", "message": "Add a Wallhaven API key to load collections"}
    response = api_get("/collections", {}, api_key)
    if response.get("ok") is False:
        return response
    data = response.get("data")
    items = []
    for item in data or []:
        if not isinstance(item, dict):
            continue
        items.append({
            "id": int(item.get("id") or 0),
            "label": str(item.get("label") or "Collection"),
            "views": int(item.get("views") or 0),
            "public": int(item.get("public") or 0) == 1,
            "count": int(item.get("count") or 0),
        })
    return {"ok": True, "items": items}


def collection_items(payload: dict[str, Any]) -> dict[str, Any]:
    username = str(payload.get("username") or "").strip()
    collection_id = str(payload.get("collection_id") or "").strip()
    if not username or not collection_id.isdigit():
        return {"ok": False, "code": "invalid_collection", "message": "Wallhaven username and collection are required"}
    try:
        page = max(1, int(payload.get("page") or 1))
    except (TypeError, ValueError):
        page = 1
    endpoint = "/collections/{}/{}".format(
        urllib.parse.quote(username, safe=""),
        urllib.parse.quote(collection_id, safe=""),
    )
    response = api_get(endpoint, {"page": page}, str(payload.get("api_key") or "").strip())
    wallpaper_dir = Path(str(payload.get("wallpaper_dir") or "~/Pictures/Wallpapers")).expanduser()
    return normalize_page(response, wallpaper_dir)


def cleanup_part() -> None:
    global ACTIVE_PART
    if ACTIVE_PART is not None:
        try:
            ACTIVE_PART.unlink(missing_ok=True)
        except OSError:
            pass
        ACTIVE_PART = None


def terminate(_signum: int, _frame: Any) -> None:
    cleanup_part()
    raise SystemExit(130)


def download(payload: dict[str, Any]) -> dict[str, Any]:
    global ACTIVE_PART

    wallpaper_id = str(payload.get("id") or "").strip()
    source = str(payload.get("url") or "").strip()
    if not ID_PATTERN.fullmatch(wallpaper_id):
        return {"ok": False, "code": "invalid_id", "message": "Invalid Wallhaven wallpaper ID"}
    parsed = urllib.parse.urlparse(source)
    if parsed.scheme != "https" or parsed.hostname != "w.wallhaven.cc":
        return {"ok": False, "code": "invalid_url", "message": "Wallhaven returned an unsafe download URL"}
    extension = Path(parsed.path).suffix.lower()
    if extension not in ALLOWED_EXTENSIONS:
        return {"ok": False, "code": "unsupported_file", "message": "Unsupported Wallhaven image format"}

    wallpaper_dir = Path(str(payload.get("wallpaper_dir") or "~/Pictures/Wallpapers")).expanduser()
    wallpaper_dir.mkdir(parents=True, exist_ok=True)
    existing = local_wallpaper(wallpaper_dir, wallpaper_id)
    if existing:
        stat = existing.stat()
        return {
            "ok": True,
            "id": wallpaper_id,
            "path": str(existing),
            "modified": int(stat.st_mtime_ns // 1_000_000),
            "file_size": stat.st_size,
            "existing": True,
        }

    target = wallpaper_dir / f"wallhaven-{wallpaper_id}{extension}"
    ACTIVE_PART = wallpaper_dir / f".{target.name}.{os.getpid()}.part"
    request = urllib.request.Request(source, headers={"User-Agent": "Quickshell-Wallhaven/1.0"}, method="GET")
    try:
        with urllib.request.urlopen(request, timeout=35) as response, ACTIVE_PART.open("wb") as output:
            while True:
                chunk = response.read(262144)
                if not chunk:
                    break
                output.write(chunk)
        if ACTIVE_PART.stat().st_size <= 0:
            raise OSError("empty download")
        os.replace(ACTIVE_PART, target)
        ACTIVE_PART = None
    except urllib.error.HTTPError as error:
        cleanup_part()
        return {"ok": False, "code": "download_failed", "message": f"Wallhaven download failed ({error.code})"}
    except (urllib.error.URLError, TimeoutError, OSError):
        cleanup_part()
        return {"ok": False, "code": "download_failed", "message": "Could not download the Wallhaven image"}

    stat = target.stat()
    return {
        "ok": True,
        "id": wallpaper_id,
        "path": str(target.resolve()),
        "modified": int(stat.st_mtime_ns // 1_000_000),
        "file_size": stat.st_size,
        "existing": False,
    }


def main() -> int:
    signal.signal(signal.SIGTERM, terminate)
    signal.signal(signal.SIGINT, terminate)
    commands = {
        "search": search,
        "collections": collections,
        "collection": collection_items,
        "download": download,
        "list": list_installed,
        "remove": remove,
    }
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    handler = commands.get(command)
    if handler is None:
        emit({"ok": False, "message": "Unknown Wallhaven command"})
        return 2
    result = handler(read_payload())
    emit(result)
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
