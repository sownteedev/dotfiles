#!/usr/bin/env python3
"""Query KLIPY and copy selected media through a bounded runtime cache."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

API_BASE = "https://api.klipy.com/api/v1"
ALLOWED_KINDS = {"gif": "gifs", "sticker": "stickers"}
ALLOWED_MIME_TYPES = {"image/gif", "image/webp", "image/png"}
CACHE_MAX_BYTES = 256 * 1024 * 1024
CACHE_MAX_FILES = 40
MAX_COPY_BYTES = 64 * 1024 * 1024
MIME_EXTENSIONS = {
    "image/gif": ".gif",
    "image/png": ".png",
    "image/webp": ".webp",
}
USER_AGENT = "SownteeShell/1.0 KLIPY launcher"


def read_payload(path: str) -> dict[str, Any]:
    if path == "-":
        payload = ""
        while True:
            character = sys.stdin.read(1)
            if character == "":
                if not payload.strip():
                    raise ValueError("Request payload was empty")
                decoded = json.loads(payload)
                break
            payload += character
            if character not in "}]":
                continue
            try:
                decoded = json.loads(payload)
                break
            except json.JSONDecodeError:
                continue
    else:
        decoded = json.loads(Path(path).read_text(encoding="utf-8"))
    if not isinstance(decoded, dict):
        raise ValueError("Request payload must be a JSON object")
    return decoded


def emit(payload: dict[str, Any]) -> int:
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
    return 0 if payload.get("ok") else 1


def safe_integer(value: Any, fallback: int) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return fallback


def media_variant(
    files: dict[str, Any],
    qualities: tuple[str, ...],
    formats: tuple[str, ...],
) -> dict[str, Any]:
    for quality in qualities:
        tier = files.get(quality)
        if not isinstance(tier, dict):
            continue
        for media_format in formats:
            variant = tier.get(media_format)
            if not isinstance(variant, dict):
                continue
            url = str(variant.get("url") or "").strip()
            if url.startswith("https://"):
                return {
                    "url": url,
                    "width": safe_integer(variant.get("width"), 0),
                    "height": safe_integer(variant.get("height"), 0),
                    "size": safe_integer(variant.get("size"), 0),
                    "format": media_format,
                }
    return {}


def normalize_item(item: Any, kind: str) -> dict[str, Any] | None:
    if not isinstance(item, dict):
        return None
    files = item.get("file")
    if not isinstance(files, dict):
        return None

    static_preview = media_variant(
        files,
        ("sm", "xs", "md", "hd"),
        ("jpg", "png", "webp", "gif"),
    )
    animated_preview = media_variant(
        files,
        ("sm", "xs", "md", "hd"),
        ("gif", "webp"),
    )
    gif_variant = media_variant(files, ("md", "hd", "sm", "xs"), ("gif",))
    webp_variant = media_variant(files, ("md", "hd", "sm", "xs"), ("webp",))
    png_variant = media_variant(files, ("md", "hd", "sm", "xs"), ("png",))

    if not static_preview:
        static_preview = animated_preview or gif_variant or webp_variant or png_variant
    if not static_preview or not (gif_variant or webp_variant or png_variant):
        return None

    preferred = gif_variant if kind == "gif" else webp_variant
    if not preferred:
        preferred = gif_variant or webp_variant or png_variant

    title = str(item.get("title") or ("GIF" if kind == "gif" else "Sticker")).strip()
    return {
        "id": str(item.get("id") or ""),
        "title": title or ("GIF" if kind == "gif" else "Sticker"),
        "previewUrl": static_preview.get("url", ""),
        "animatedUrl": animated_preview.get("url", ""),
        "gifUrl": gif_variant.get("url", ""),
        "webpUrl": webp_variant.get("url", ""),
        "pngUrl": png_variant.get("url", ""),
        "preferredUrl": preferred.get("url", ""),
        "preferredFormat": preferred.get("format", ""),
        "width": safe_integer(static_preview.get("width"), 0),
        "height": safe_integer(static_preview.get("height"), 0),
    }


def response_items(response: Any) -> list[Any]:
    if not isinstance(response, dict):
        return []
    data = response.get("data")
    if isinstance(data, dict):
        nested = data.get("data")
        if isinstance(nested, list):
            return nested
    return data if isinstance(data, list) else []


def query(payload: dict[str, Any]) -> dict[str, Any]:
    request_id = safe_integer(payload.get("requestId"), 0)
    kind = str(payload.get("kind") or "").strip().lower()
    api_key = str(payload.get("apiKey") or "").strip()
    search_query = str(payload.get("query") or "").strip()
    if kind not in ALLOWED_KINDS:
        return {"ok": False, "requestId": request_id, "error": "invalid_kind"}
    if not api_key:
        return {"ok": False, "requestId": request_id, "error": "missing_api_key"}

    per_page = max(8, min(24, safe_integer(payload.get("perPage"), 24)))
    endpoint = "search" if search_query else "trending"
    parameters = {
        "customer_id": "sownteeshell",
        "per_page": str(per_page),
        "content_filter": "medium",
    }
    if search_query:
        parameters["q"] = search_query
    url = (
        f"{API_BASE}/{urllib.parse.quote(api_key, safe='')}/"
        f"{ALLOWED_KINDS[kind]}/{endpoint}?{urllib.parse.urlencode(parameters)}"
    )
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})

    try:
        with urllib.request.urlopen(request, timeout=12) as response:
            decoded = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        if error.code in (401, 403, 404):
            code = "invalid_api_key"
        elif error.code == 429:
            code = "rate_limited"
        else:
            code = "http_error"
        return {
            "ok": False,
            "requestId": request_id,
            "error": code,
            "status": error.code,
        }
    except (urllib.error.URLError, TimeoutError, OSError):
        return {"ok": False, "requestId": request_id, "error": "offline"}
    except (UnicodeDecodeError, json.JSONDecodeError):
        return {"ok": False, "requestId": request_id, "error": "invalid_response"}

    items: list[dict[str, Any]] = []
    for raw_item in response_items(decoded):
        normalized = normalize_item(raw_item, kind)
        if normalized:
            items.append(normalized)
    return {
        "ok": True,
        "requestId": request_id,
        "items": items,
        "trending": not bool(search_query),
    }


def validate_media_url(url: str) -> None:
    parsed = urllib.parse.urlparse(url)
    hostname = (parsed.hostname or "").lower()
    if parsed.scheme != "https" or not (hostname == "klipy.com" or hostname.endswith(".klipy.com")):
        raise ValueError("Unsupported media URL")


def media_cache_dir() -> Path:
    directory = Path(tempfile.gettempdir()) / f"sownteeshell-{os.getuid()}" / "launcher-media"
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    directory.chmod(0o700)
    return directory


def media_signature_matches(header: bytes, mime_type: str) -> bool:
    if mime_type == "image/gif":
        return header.startswith((b"GIF87a", b"GIF89a"))
    if mime_type == "image/png":
        return header.startswith(b"\x89PNG\r\n\x1a\n")
    if mime_type == "image/webp":
        return len(header) >= 12 and header.startswith(b"RIFF") and header[8:12] == b"WEBP"
    return False


def prune_media_cache(directory: Path, keep: Path) -> None:
    cached_files: list[tuple[float, int, Path]] = []
    for path in directory.iterdir():
        if not path.is_file() or path == keep or path.suffix.lower() not in MIME_EXTENSIONS.values():
            continue
        try:
            status = path.stat()
            cached_files.append((status.st_mtime, status.st_size, path))
        except OSError:
            continue

    cached_files.sort(key=lambda entry: entry[0], reverse=True)
    total_bytes = keep.stat().st_size if keep.exists() else 0
    retained = 1 if keep.exists() else 0
    for _, size, path in cached_files:
        try:
            if retained < CACHE_MAX_FILES and total_bytes + size <= CACHE_MAX_BYTES:
                total_bytes += size
                retained += 1
                continue
            path.unlink()
        except OSError:
            continue


def download_media_file(url: str, mime_type: str) -> Path:
    directory = media_cache_dir()
    extension = MIME_EXTENSIONS[mime_type]
    digest = hashlib.sha256(url.encode("utf-8")).hexdigest()[:24]
    target = directory / f"klipy-{digest}{extension}"
    try:
        target_size = target.stat().st_size
        with target.open("rb") as cached_media:
            target_header = cached_media.read(16)
        if 0 < target_size <= MAX_COPY_BYTES and media_signature_matches(target_header, mime_type):
            target.touch()
            prune_media_cache(directory, target)
            return target
        target.unlink(missing_ok=True)
    except OSError:
        target.unlink(missing_ok=True)

    temporary = directory / f".{target.name}.{os.getpid()}.part"
    copied = 0
    header = b""
    try:
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=20) as response:
            validate_media_url(response.geturl())
            content_length = safe_integer(response.headers.get("Content-Length"), 0)
            if content_length > MAX_COPY_BYTES:
                raise ValueError("Media is too large to copy")

            with temporary.open("wb") as output:
                while chunk := response.read(128 * 1024):
                    copied += len(chunk)
                    if copied > MAX_COPY_BYTES:
                        raise ValueError("Media is too large to copy")
                    if len(header) < 16:
                        header += chunk[: 16 - len(header)]
                    output.write(chunk)

        if copied == 0 or not media_signature_matches(header, mime_type):
            raise ValueError("Downloaded media format did not match its MIME type")
        temporary.chmod(0o600)
        temporary.replace(target)
    finally:
        temporary.unlink(missing_ok=True)

    prune_media_cache(directory, target)
    return target


def copy_media(url: str, mime_type: str, paste: bool) -> int:
    validate_media_url(url)
    if mime_type not in ALLOWED_MIME_TYPES:
        raise ValueError("Unsupported media type")
    if not shutil.which("wl-copy"):
        raise RuntimeError("wl-copy is not installed")

    media_path = download_media_file(url, mime_type)
    clipboard_data = (media_path.resolve().as_uri() + "\r\n").encode("utf-8")
    clipboard = subprocess.run(
        ["wl-copy", "--type", "text/uri-list"],
        input=clipboard_data,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return_code = clipboard.returncode
    if return_code != 0:
        raise RuntimeError("Could not update the clipboard")

    if paste and shutil.which("wtype"):
        # Keep this helper alive until the shortcut has been delivered. A
        # detached child can be reaped with the launcher copy process before
        # Niri has returned keyboard focus to the previous window.
        time.sleep(0.4)
        subprocess.run(
            ["wtype", "-M", "ctrl", "-k", "v", "-m", "ctrl"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    query_parser = subparsers.add_parser("query")
    query_parser.add_argument("payload")

    copy_parser = subparsers.add_parser("copy")
    copy_parser.add_argument("--url", required=True)
    copy_parser.add_argument("--mime", required=True)
    copy_parser.add_argument("--paste", action="store_true")

    args = parser.parse_args()
    try:
        if args.command == "query":
            return emit(query(read_payload(args.payload)))
        return copy_media(args.url, args.mime, args.paste)
    except (ValueError, RuntimeError, urllib.error.URLError, urllib.error.HTTPError, TimeoutError, OSError) as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
