#!/usr/bin/env python3
"""Search, download and manage Wallpaper Engine Steam Workshop projects."""

from __future__ import annotations

import json
import mmap
import os
import re
import shutil
import signal
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

APP_ID = "431960"
QUERY_ENDPOINT = "https://api.steampowered.com/IPublishedFileService/QueryFiles/v1/"
QUERY_TYPES = {
    "popular": 0,
    "recent": 1,
    "trending": 3,
}
ACTIVE_PROCESS: subprocess.Popen[str] | None = None
ACTIVE_DOWNLOAD_CLEANUP_PATHS: list[Path] = []
NSFW_CONTENT_DESCRIPTOR_IDS = {1, 3, 4}
RESOLUTION_PATTERN = re.compile(r"(?<!\d)(\d{3,5})\s*[x×]\s*(\d{3,5})(?!\d)", re.IGNORECASE)
SCENE_HEIGHT_WIDTH_PATTERN = re.compile(
    rb'"height"\s*:\s*(\d{2,5})\s*,\s*"width"\s*:\s*(\d{2,5})'
)
SCENE_WIDTH_HEIGHT_PATTERN = re.compile(
    rb'"width"\s*:\s*(\d{2,5})\s*,\s*"height"\s*:\s*(\d{2,5})'
)
SIZE_CACHE: dict[str, dict[str, Any]] = {}
SIZE_CACHE_DIRTY = False
SIZE_CACHE_LOADED = False


def emit(payload: dict[str, Any]) -> int:
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
    return 0 if payload.get("ok") else 1


def read_payload() -> dict[str, Any]:
    try:
        payload = json.loads(sys.stdin.readline())
    except (json.JSONDecodeError, OSError):
        return {}
    return payload if isinstance(payload, dict) else {}

def prepare_steamcmd_session() -> tuple[str, dict[str, str]]:
    data_home_text = os.environ.get("XDG_DATA_HOME", "").strip()
    data_home = Path(data_home_text).expanduser() if data_home_text else Path.home() / ".local" / "share"
    session_home = data_home / "quickshell" / "steamcmd-home"
    steam_state = session_home / ".steam"

    session_home.mkdir(parents=True, exist_ok=True, mode=0o700)
    steam_state.mkdir(parents=True, exist_ok=True, mode=0o700)
    session_home.chmod(0o700)
    steam_state.chmod(0o700)
    for relative_path in ("appcache", "config", "logs", "SteamApps/common"):
        (steam_state / relative_path).mkdir(parents=True, exist_ok=True)
    for link_name in ("root", "steam"):
        link_path = steam_state / link_name
        if not os.path.lexists(link_path):
            link_path.symlink_to(steam_state, target_is_directory=True)

    shared_launcher = Path.home() / ".steam" / "steamcmd" / "steamcmd.sh"
    launcher = str(shared_launcher) if shared_launcher.is_file() else str(shutil.which("steamcmd") or "")
    if not launcher:
        raise FileNotFoundError("steamcmd")

    environment = os.environ.copy()
    environment["HOME"] = str(session_home)
    return launcher, environment


def installed_path(published_file_id: str, roots: list[str]) -> Path | None:
    for root_text in roots:
        if not root_text:
            continue
        candidate = Path(root_text).expanduser() / published_file_id
        if (candidate / "project.json").is_file():
            return candidate
    return None


def directory_size(directory: Path) -> int:
    total = 0
    try:
        for root, _directories, filenames in os.walk(directory, followlinks=False):
            for filename in filenames:
                try:
                    total += (Path(root) / filename).stat(follow_symlinks=False).st_size
                except OSError:
                    continue
    except OSError:
        return 0
    return total

def size_cache_path() -> Path:
    cache_home_text = os.environ.get("XDG_CACHE_HOME", "").strip()
    cache_home = Path(cache_home_text).expanduser() if cache_home_text else Path.home() / ".cache"
    return cache_home / "quickshell" / "wallpaper-workshop" / "sizes.json"

def load_size_cache() -> None:
    global SIZE_CACHE, SIZE_CACHE_LOADED
    if SIZE_CACHE_LOADED:
        return
    SIZE_CACHE_LOADED = True
    try:
        payload = json.loads(size_cache_path().read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        payload = {}
    SIZE_CACHE = payload if isinstance(payload, dict) else {}

def save_size_cache() -> None:
    global SIZE_CACHE, SIZE_CACHE_DIRTY
    if not SIZE_CACHE_DIRTY:
        return
    SIZE_CACHE = {
        path: entry
        for path, entry in SIZE_CACHE.items()
        if Path(path).is_dir() and isinstance(entry, dict)
    }
    target = size_cache_path()
    temporary = target.with_suffix(".tmp")
    try:
        target.parent.mkdir(parents=True, exist_ok=True)
        temporary.write_text(json.dumps(SIZE_CACHE, separators=(",", ":")), encoding="utf-8")
        temporary.replace(target)
        SIZE_CACHE_DIRTY = False
    except OSError:
        try:
            temporary.unlink(missing_ok=True)
        except OSError:
            pass

def cached_directory_size(directory: Path) -> int:
    global SIZE_CACHE_DIRTY
    load_size_cache()
    try:
        resolved = directory.resolve()
        project_stat = (resolved / "project.json").stat()
        directory_stat = resolved.stat()
    except OSError:
        return 0
    signature = project_stat.st_mtime_ns ^ directory_stat.st_mtime_ns
    key = str(resolved)
    cached = SIZE_CACHE.get(key)
    if isinstance(cached, dict) and int(cached.get("signature", -1)) == signature:
        return max(0, int(cached.get("size", 0)))
    size = directory_size(resolved)
    next_entry = dict(cached) if isinstance(cached, dict) else {}
    next_entry.update({"signature": signature, "size": size})
    SIZE_CACHE[key] = next_entry
    SIZE_CACHE_DIRTY = True
    return size

def wallpaper_type(tags: list[str]) -> str:
    lowered = {tag.casefold() for tag in tags}
    for candidate in ("scene", "video", "web", "application"):
        if candidate in lowered:
            return candidate
    return "unknown"

def normalized_words(value: str) -> str:
    return " ".join(re.sub(r"[^\w+]+", " ", value.casefold()).split())

def wallpaper_resolution(raw_item: dict[str, Any], tags: list[str]) -> str:
    candidates = list(tags)
    for key in ("metadata", "short_description", "description"):
        value = raw_item.get(key)
        if isinstance(value, str) and value:
            candidates.append(value)

    for value in candidates:
        match = RESOLUTION_PATTERN.search(value)
        if not match:
            continue
        width = int(match.group(1))
        height = int(match.group(2))
        if width > 0 and height > 0:
            return f"{width}×{height}"
    return ""

def content_signature(content_path: Path, project_file: Path) -> str:
    try:
        project_stat = project_file.stat()
        content_stat = content_path.stat()
    except OSError:
        return ""
    return (
        f"{project_stat.st_mtime_ns}:{project_stat.st_size}:"
        f"{content_stat.st_mtime_ns}:{content_stat.st_size}"
    )

def video_resolution(video_path: Path) -> str:
    ffprobe = shutil.which("ffprobe")
    if not ffprobe or not video_path.is_file():
        return ""
    try:
        result = subprocess.run(
            [
                ffprobe,
                "-v",
                "error",
                "-select_streams",
                "v:0",
                "-show_entries",
                "stream=width,height",
                "-of",
                "csv=s=x:p=0",
                str(video_path),
            ],
            check=True,
            capture_output=True,
            text=True,
            timeout=4,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    match = RESOLUTION_PATTERN.search(result.stdout.strip())
    return f"{match.group(1)}×{match.group(2)}" if match else ""

def scene_resolution(scene_path: Path) -> str:
    if not scene_path.is_file():
        return ""
    try:
        with scene_path.open("rb") as scene_file:
            with mmap.mmap(scene_file.fileno(), 0, access=mmap.ACCESS_READ) as scene_data:
                match = SCENE_HEIGHT_WIDTH_PATTERN.search(scene_data)
                if match:
                    return f"{int(match.group(2))}×{int(match.group(1))}"
                match = SCENE_WIDTH_HEIGHT_PATTERN.search(scene_data)
                if match:
                    return f"{int(match.group(1))}×{int(match.group(2))}"
    except (OSError, ValueError):
        return ""
    return ""

def cached_local_resolution(
    project_dir: Path, metadata: dict[str, Any], tags: list[str]
) -> str:
    global SIZE_CACHE_DIRTY
    item_type = str(metadata.get("type") or "unknown").casefold()
    project_file = project_dir / "project.json"
    media_name = str(metadata.get("file") or "")
    content_path = project_dir / (media_name if media_name else "scene.pkg")
    if item_type == "scene" and not content_path.is_file():
        content_path = project_dir / "scene.pkg"

    signature = content_signature(content_path, project_file)
    load_size_cache()
    key = str(project_dir.resolve())
    cached = SIZE_CACHE.get(key)
    if (
        signature
        and isinstance(cached, dict)
        and str(cached.get("resolution_signature") or "") == signature
    ):
        return str(cached.get("resolution") or "")

    if item_type == "video":
        resolution = video_resolution(content_path)
    elif item_type == "scene":
        resolution = scene_resolution(content_path)
    else:
        resolution = ""
    if not resolution:
        resolution = wallpaper_resolution(metadata, tags)

    if signature:
        next_entry = dict(cached) if isinstance(cached, dict) else {}
        next_entry.update(
            {"resolution_signature": signature, "resolution": resolution}
        )
        SIZE_CACHE[key] = next_entry
        SIZE_CACHE_DIRTY = True
    return resolution

def content_descriptor_ids(raw_item: dict[str, Any]) -> set[int]:
    raw_descriptors: Any = raw_item.get("content_descriptorids")
    if raw_descriptors is None:
        raw_descriptors = raw_item.get("content_descriptor_ids", [])
    if isinstance(raw_descriptors, dict):
        raw_descriptors = raw_descriptors.get("ids", raw_descriptors.get("content_descriptorids", []))
    if not isinstance(raw_descriptors, (list, tuple, set)):
        raw_descriptors = [raw_descriptors]

    descriptors: set[int] = set()
    for descriptor in raw_descriptors:
        if isinstance(descriptor, dict):
            descriptor = descriptor.get("id", descriptor.get("content_descriptorid"))
        try:
            descriptors.add(int(descriptor))
        except (TypeError, ValueError):
            continue
    return descriptors

def is_nsfw_item(raw_item: dict[str, Any], tags: list[str]) -> bool:
    inappropriate_sex = raw_item.get("maybe_inappropriate_sex", False)
    if inappropriate_sex is True or str(inappropriate_sex).casefold() in {"1", "true", "yes"}:
        return True
    if content_descriptor_ids(raw_item) & NSFW_CONTENT_DESCRIPTOR_IDS:
        return True

    if "nsfw" in {normalized_words(tag) for tag in tags}:
        return True

    title = normalized_words(str(raw_item.get("title") or ""))
    return " nsfw " in f" {title} "


def subscribed_ids(steam_root: Path) -> set[str]:
    manifest = steam_root / "steamapps" / "workshop" / f"appworkshop_{APP_ID}.acf"
    try:
        manifest_text = manifest.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return set()

    section_start = manifest_text.find('"WorkshopItemDetails"')
    if section_start < 0:
        return set()
    details = manifest_text[section_start:]
    return {
        match.group(1)
        for match in re.finditer(r'"(\d+)"\s*\{([^{}]*)\}', details, re.DOTALL)
        if re.search(r'"subscribedby"\s*"[^"]+"', match.group(2))
    }


def local_project_item(project_dir: Path, subscribed: set[str]) -> dict[str, Any] | None:
    project_file = project_dir / "project.json"
    if not project_file.is_file() or not project_dir.name.isdigit():
        return None
    try:
        metadata = json.loads(project_file.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        return None
    if not isinstance(metadata, dict):
        return None

    item_type = str(metadata.get("type") or "unknown").casefold()
    raw_tags = metadata.get("tags")
    tags = [str(tag) for tag in raw_tags if tag] if isinstance(raw_tags, list) else []
    preview = str(metadata.get("preview") or "")
    preview_path = project_dir / preview if preview else Path()
    return {
        "id": project_dir.name,
        "title": str(metadata.get("title") or project_dir.name),
        "preview": str(preview_path) if preview and preview_path.is_file() else "",
        "type": item_type,
        "resolution": cached_local_resolution(project_dir, metadata, tags),
        "tags": tags[:8],
        "subscriptions": 0,
        "updated": int(project_file.stat().st_mtime),
        "supported": item_type not in {"web", "application"},
        "downloaded": True,
        "subscribed": project_dir.name in subscribed,
        "path": str(project_dir),
        "file_size": cached_directory_size(project_dir),
        "modified": project_file.stat().st_mtime_ns // 1_000_000,
    }


def normalize_search_response(
    payload: dict[str, Any], roots: list[str], subscribed: set[str]
) -> dict[str, Any]:
    response = payload.get("response") if isinstance(payload, dict) else None
    if not isinstance(response, dict):
        return {"ok": False, "message": "Steam returned an invalid response"}

    raw_items = response.get("publishedfiledetails")
    if not isinstance(raw_items, list):
        raw_items = []

    items: list[dict[str, Any]] = []
    for raw_item in raw_items:
        if not isinstance(raw_item, dict) or int(raw_item.get("result", 1) or 1) != 1:
            continue
        published_file_id = str(raw_item.get("publishedfileid") or "").strip()
        if not published_file_id.isdigit():
            continue
        tags = [
            str(tag.get("tag") or "")
            for tag in raw_item.get("tags", [])
            if isinstance(tag, dict) and tag.get("tag")
        ]
        nsfw = is_nsfw_item(raw_item, tags)
        item_type = wallpaper_type(tags)
        resolution = wallpaper_resolution(raw_item, tags)
        local_path = installed_path(published_file_id, roots)
        try:
            remote_file_size = int(raw_item.get("file_size", 0) or 0)
        except (TypeError, ValueError):
            remote_file_size = 0
        preview_url = str(raw_item.get("preview_url") or "")
        previews = raw_item.get("previews")
        if not preview_url and isinstance(previews, list) and previews:
            first_preview = previews[0]
            if isinstance(first_preview, dict):
                preview_url = str(first_preview.get("url") or first_preview.get("preview_url") or "")
        items.append(
            {
                "id": published_file_id,
                "title": str(raw_item.get("title") or published_file_id),
                "preview": preview_url,
                "type": item_type,
                "resolution": resolution,
                "tags": tags[:8],
                "subscriptions": int(raw_item.get("subscriptions", 0) or 0),
                "updated": int(raw_item.get("time_updated", 0) or 0),
                "supported": item_type not in {"web", "application"},
                "downloaded": local_path is not None,
                "subscribed": published_file_id in subscribed,
                "path": str(local_path) if local_path else "",
                "file_size": cached_directory_size(local_path) if local_path else remote_file_size,
                "modified": int((local_path / "project.json").stat().st_mtime_ns // 1_000_000) if local_path else 0,
                "nsfw": nsfw,
            }
        )
    return {
        "ok": True,
        "items": items,
        "total": int(response.get("total", len(items)) or len(items)),
    }


def search(payload: dict[str, Any]) -> dict[str, Any]:
    api_key = str(payload.get("api_key") or "").strip()
    if not api_key:
        return {"ok": False, "message": "Steam Web API key is missing"}

    query = str(payload.get("query") or "").strip()
    sort_mode = str(payload.get("sort") or "trending").strip()
    try:
        page = max(1, int(payload.get("page", 1)))
    except (TypeError, ValueError):
        page = 1
    query_parameters = {
        "query_type": QUERY_TYPES.get(sort_mode, QUERY_TYPES["trending"]),
        "page": page,
        "numperpage": 30,
        "appid": APP_ID,
        "search_text": query,
        "return_metadata": True,
        "return_tags": True,
        "return_previews": True,
        "return_vote_data": True,
        "return_short_description": True,
        "strip_description_bbcode": True,
    }
    query_string = urllib.parse.urlencode(
        {
            "key": api_key,
            "input_json": json.dumps(query_parameters, separators=(",", ":")),
        }
    )
    request = urllib.request.Request(
        f"{QUERY_ENDPOINT}?{query_string}",
        headers={"User-Agent": "Quickshell-Wallpaper-Workshop/1.0"},
        method="GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=25) as response:
            response_payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        if error.code in (401, 403):
            return {"ok": False, "message": "Steam rejected the Web API key"}
        return {"ok": False, "message": f"Steam Workshop request failed ({error.code})"}
    except (urllib.error.URLError, TimeoutError):
        return {"ok": False, "message": "Could not reach Steam Workshop"}
    except (UnicodeDecodeError, json.JSONDecodeError):
        return {"ok": False, "message": "Steam returned unreadable search data"}

    roots = [
        str(payload.get("workshop_root") or ""),
        str(payload.get("legacy_workshop_root") or ""),
    ]
    steam_root = Path(str(payload.get("steam_root") or "~/.local/share/Steam")).expanduser()
    return normalize_search_response(response_payload, roots, subscribed_ids(steam_root))


def list_installed(payload: dict[str, Any]) -> dict[str, Any]:
    roots = [
        str(payload.get("workshop_root") or ""),
        str(payload.get("legacy_workshop_root") or ""),
    ]
    steam_root = Path(str(payload.get("steam_root") or "~/.local/share/Steam")).expanduser()
    subscribed = subscribed_ids(steam_root)
    seen: set[Path] = set()
    items: list[dict[str, Any]] = []
    for root_text in roots:
        if not root_text:
            continue
        root = Path(root_text).expanduser()
        if not root.is_dir():
            continue
        for project_dir in root.iterdir():
            try:
                resolved = project_dir.resolve()
            except OSError:
                continue
            if resolved in seen:
                continue
            seen.add(resolved)
            item = local_project_item(project_dir, subscribed)
            if item is not None:
                items.append(item)
    items.sort(key=lambda item: (int(item["modified"]), str(item["title"]).casefold()), reverse=True)
    return {"ok": True, "items": items, "total": len(items)}

def subscriptions(payload: dict[str, Any]) -> dict[str, Any]:
    steam_root = Path(str(payload.get("steam_root") or "~/.local/share/Steam")).expanduser()
    return {"ok": True, "ids": sorted(subscribed_ids(steam_root), key=int)}


def cleanup_interrupted_download() -> None:
    global ACTIVE_DOWNLOAD_CLEANUP_PATHS

    for cleanup_path in reversed(ACTIVE_DOWNLOAD_CLEANUP_PATHS):
        try:
            if cleanup_path.is_dir() and not cleanup_path.is_symlink():
                shutil.rmtree(cleanup_path)
            elif cleanup_path.exists() or cleanup_path.is_symlink():
                cleanup_path.unlink()
        except OSError:
            continue
    ACTIVE_DOWNLOAD_CLEANUP_PATHS = []

def terminate_active_process(_signum: int, _frame: Any) -> None:
    if ACTIVE_PROCESS is not None and ACTIVE_PROCESS.poll() is None:
        try:
            os.killpg(ACTIVE_PROCESS.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            ACTIVE_PROCESS.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(ACTIVE_PROCESS.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            ACTIVE_PROCESS.wait(timeout=5)
    cleanup_interrupted_download()
    raise SystemExit(143)


def find_downloaded_project(published_file_id: str, steam_root: Path, workshop_root: Path) -> Path | None:
    candidates = [
        workshop_root / published_file_id,
        steam_root / "steamapps" / "workshop" / "content" / APP_ID / published_file_id,
        Path.home() / ".steam" / "steamcmd" / "steamapps" / "workshop" / "content" / APP_ID / published_file_id,
        Path.home() / "Steam" / "steamapps" / "workshop" / "content" / APP_ID / published_file_id,
    ]
    for candidate in candidates:
        if (candidate / "project.json").is_file():
            return candidate
    return None


def install_download(source: Path, target: Path) -> Path:
    if source.resolve() == target.resolve():
        return target

    target.parent.mkdir(parents=True, exist_ok=True)
    staging = target.parent / f".{target.name}.download"
    backup = target.parent / f".{target.name}.backup"
    shutil.rmtree(staging, ignore_errors=True)
    shutil.rmtree(backup, ignore_errors=True)
    shutil.copytree(source, staging)
    target_existed = target.exists()
    try:
        if target_existed:
            target.rename(backup)
        staging.rename(target)
    except (OSError, SystemExit, KeyboardInterrupt):
        if target_existed and backup.exists() and not target.exists():
            backup.rename(target)
        raise
    else:
        shutil.rmtree(backup, ignore_errors=True)
    return target


def download(payload: dict[str, Any]) -> dict[str, Any]:
    global ACTIVE_DOWNLOAD_CLEANUP_PATHS, ACTIVE_PROCESS

    published_file_id = str(payload.get("id") or "").strip()
    username = str(payload.get("username") or "").strip()
    if not published_file_id.isdigit():
        return {"ok": False, "message": "Invalid Workshop item ID"}
    if not username:
        return {"ok": False, "message": "Steam username is missing"}
    if shutil.which("steamcmd") is None:
        return {"ok": False, "message": "Install steamcmd before downloading Workshop items"}

    steam_root = Path(str(payload.get("steam_root") or "~/.local/share/Steam")).expanduser()
    workshop_root_text = str(payload.get("workshop_root") or "").strip()
    if not workshop_root_text:
        return {"ok": False, "message": "Wallpaper Engine Workshop folder is missing"}
    workshop_root = Path(workshop_root_text).expanduser()
    target = workshop_root / published_file_id
    cleanup_candidates = [
        target,
        target.parent / f".{published_file_id}.download",
    ]
    ACTIVE_DOWNLOAD_CLEANUP_PATHS = [path for path in cleanup_candidates if not path.exists()]

    try:
        steamcmd_launcher, steamcmd_environment = prepare_steamcmd_session()
    except OSError:
        cleanup_interrupted_download()
        return {"ok": False, "message": "Could not prepare the SteamCMD login session"}

    command = [
        steamcmd_launcher,
        "+force_install_dir",
        str(steam_root),
        "+login",
        username,
        "+workshop_download_item",
        APP_ID,
        published_file_id,
        "validate",
        "+quit",
    ]
    try:
        ACTIVE_PROCESS = subprocess.Popen(
            command,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            start_new_session=True,
            env=steamcmd_environment,
        )
        output, _ = ACTIVE_PROCESS.communicate(timeout=1200)
    except subprocess.TimeoutExpired:
        if ACTIVE_PROCESS is not None:
            os.killpg(ACTIVE_PROCESS.pid, signal.SIGTERM)
            ACTIVE_PROCESS.wait(timeout=10)
        cleanup_interrupted_download()
        return {"ok": False, "message": "SteamCMD download timed out"}
    except OSError:
        cleanup_interrupted_download()
        return {"ok": False, "message": "Could not start SteamCMD"}
    finally:
        return_code = ACTIVE_PROCESS.returncode if ACTIVE_PROCESS is not None else 1
        ACTIVE_PROCESS = None

    if return_code != 0 or "ERROR! Download item" in output:
        cleanup_interrupted_download()
        if re.search(
            r"(login failure|invalid password|two-factor|steam guard|cached credentials)",
            output,
            re.IGNORECASE,
        ):
            return {
                "ok": False,
                "code": "steamcmd_login_required",
                "message": "SteamCMD login required for Quickshell; sign in once from a terminal",
            }
        return {"ok": False, "message": "SteamCMD could not download this Workshop item"}

    source = find_downloaded_project(published_file_id, steam_root, workshop_root)
    if source is None:
        cleanup_interrupted_download()
        return {"ok": False, "message": "SteamCMD finished but the wallpaper files were not found"}
    try:
        target = install_download(source, target)
    except OSError:
        cleanup_interrupted_download()
        return {"ok": False, "message": "Could not install the downloaded wallpaper"}
    ACTIVE_DOWNLOAD_CLEANUP_PATHS = []
    project_file = target / "project.json"
    try:
        metadata = json.loads(project_file.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        metadata = {}
    return {
        "ok": True,
        "id": published_file_id,
        "path": str(target),
        "title": str(metadata.get("title") or published_file_id),
        "file_size": cached_directory_size(target),
        "modified": project_file.stat().st_mtime_ns // 1_000_000,
    }


def login(username: str) -> int:
    global ACTIVE_PROCESS

    account_name = username.strip()
    if not account_name:
        print("Steam username is missing", file=sys.stderr)
        return 2
    try:
        steamcmd_launcher, steamcmd_environment = prepare_steamcmd_session()
        ACTIVE_PROCESS = subprocess.Popen(
            [steamcmd_launcher, "+login", account_name, "+quit"],
            env=steamcmd_environment,
            start_new_session=True,
        )
        return ACTIVE_PROCESS.wait()
    except OSError:
        print("Could not start the dedicated SteamCMD login session", file=sys.stderr)
        return 1
    finally:
        ACTIVE_PROCESS = None


def remove(payload: dict[str, Any]) -> dict[str, Any]:
    global SIZE_CACHE_DIRTY

    published_file_id = str(payload.get("id") or "").strip()
    target_text = str(payload.get("path") or "").strip()
    if not published_file_id.isdigit() or not target_text:
        return {"ok": False, "message": "Invalid installed wallpaper"}

    target = Path(target_text).expanduser()
    try:
        resolved_target = target.resolve(strict=True)
    except OSError:
        return {"ok": False, "message": "Installed wallpaper was not found"}

    current_path_text = str(payload.get("current_path") or "").strip()
    if current_path_text:
        try:
            if Path(current_path_text).expanduser().resolve() == resolved_target:
                return {"ok": False, "message": "Choose another wallpaper before removing this one"}
        except OSError:
            pass

    allowed_roots: set[Path] = set()
    for root_key in ("workshop_root", "legacy_workshop_root"):
        root_text = str(payload.get(root_key) or "").strip()
        if not root_text:
            continue
        try:
            allowed_roots.add(Path(root_text).expanduser().resolve())
        except OSError:
            continue
    if resolved_target.name != published_file_id or resolved_target.parent not in allowed_roots:
        return {"ok": False, "message": "Refusing to remove a path outside the Workshop folder"}
    if not (resolved_target / "project.json").is_file():
        return {"ok": False, "message": "Installed wallpaper metadata is missing"}

    item = local_project_item(resolved_target, set())
    title = str(item.get("title") if item else published_file_id)
    try:
        shutil.rmtree(resolved_target)
    except OSError:
        return {"ok": False, "message": "Could not delete the wallpaper permanently"}
    load_size_cache()
    removed_cache_entry = SIZE_CACHE.pop(str(resolved_target), None)
    if removed_cache_entry is not None:
        SIZE_CACHE_DIRTY = True
    return {"ok": True, "id": published_file_id, "path": str(resolved_target), "title": title}

def prune_preview_cache(payload: dict[str, Any]) -> dict[str, Any]:
    cache_text = str(payload.get("path") or "").strip()
    if not cache_text:
        return {"ok": False, "message": "Preview cache path is missing"}
    cache_dir = Path(cache_text).expanduser()
    try:
        resolved = cache_dir.resolve()
    except OSError:
        return {"ok": True, "removed": 0, "bytes_removed": 0}
    if resolved.name != "previews" or resolved.parent.name != "wallpaper-engine":
        return {"ok": False, "message": "Refusing to prune an unexpected cache path"}
    if not resolved.is_dir():
        return {"ok": True, "removed": 0, "bytes_removed": 0}

    max_files = max(16, min(1024, int(payload.get("max_files", 256) or 256)))
    max_bytes = max(8 * 1024 * 1024, min(512 * 1024 * 1024, int(payload.get("max_bytes", 64 * 1024 * 1024) or 64 * 1024 * 1024)))
    files: list[tuple[int, int, Path]] = []
    for candidate in resolved.iterdir():
        if not candidate.is_file() or candidate.suffix.casefold() != ".jpg":
            continue
        try:
            stat = candidate.stat()
        except OSError:
            continue
        files.append((stat.st_mtime_ns, stat.st_size, candidate))
    files.sort(reverse=True)

    kept_bytes = 0
    removed = 0
    bytes_removed = 0
    for index, (_modified, size, candidate) in enumerate(files):
        if index < max_files and kept_bytes + size <= max_bytes:
            kept_bytes += size
            continue
        try:
            candidate.unlink()
            removed += 1
            bytes_removed += size
        except OSError:
            continue
    return {"ok": True, "removed": removed, "bytes_removed": bytes_removed}


def main() -> int:
    if len(sys.argv) == 3 and sys.argv[1] == "login":
        return login(sys.argv[2])
    if len(sys.argv) != 2 or sys.argv[1] not in {"search", "list", "subscriptions", "download", "remove", "prune-preview-cache"}:
        return emit({"ok": False, "message": "Usage: wallpaper_workshop.py login USERNAME|search|list|subscriptions|download|remove|prune-preview-cache"})
    payload = read_payload()
    handlers = {
        "search": search,
        "list": list_installed,
        "subscriptions": subscriptions,
        "download": download,
        "remove": remove,
        "prune-preview-cache": prune_preview_cache,
    }
    result = handlers[sys.argv[1]](payload)
    save_size_cache()
    return emit(result)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, terminate_active_process)
    signal.signal(signal.SIGINT, terminate_active_process)
    raise SystemExit(main())
