#!/usr/bin/env python3
"""Index installed Wallpaper Engine projects for the SownteeShell library."""

import json
import os
import sys
from pathlib import Path


PREVIEW_NAMES = ("preview.jpg", "preview.jpeg", "preview.png", "preview.gif")
CACHE_FILENAME = "scan_cache.json"
CACHE_VERSION = 2


def _cache_path() -> Path:
    cache_home = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    return cache_home / "quickshell" / "wallpaper-engine" / CACHE_FILENAME


def _load_cache() -> dict:
    path = _cache_path()
    try:
        cache = json.loads(path.read_text(encoding="utf-8"))
        if cache.get("version") != CACHE_VERSION:
            return {}
        return cache
    except (OSError, json.JSONDecodeError, ValueError):
        return {}


def _save_cache(cache: dict) -> None:
    path = _cache_path()
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        tmp = path.with_suffix(".tmp")
        tmp.write_text(
            json.dumps(cache, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8",
        )
        tmp.replace(path)
    except OSError:
        pass


def _project_signature(path: Path) -> str:
    """Return a cache signature that also changes when project.json is edited."""
    try:
        directory_stat = path.stat()
        project_stat = (path / "project.json").stat()
        return f"{directory_stat.st_mtime_ns}:{project_stat.st_mtime_ns}:{project_stat.st_size}"
    except OSError:
        return ""


def _scan_project(project_dir: Path) -> dict | None:
    """Read a single project.json and return its metadata."""
    project_file = project_dir / "project.json"
    if not project_dir.is_dir() or not project_file.is_file():
        return None

    try:
        data = json.loads(project_file.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        return None

    preview = ""
    media_file = str(data.get("file") or "")
    # If project is a video type and has an mp4/webm file, prefer generating thumbnail from the video itself
    # rather than a low-res 160x160 preview.gif
    if media_file:
        video_candidate = project_dir / media_file
        if video_candidate.is_file() and video_candidate.suffix.lower() in (".mp4", ".mkv", ".webm", ".avi", ".mov"):
            preview = str(video_candidate)

    if not preview:
        configured_preview = data.get("preview")
        if configured_preview:
            candidate = project_dir / str(configured_preview)
            if candidate.is_file():
                preview = str(candidate)
    if not preview:
        for name in PREVIEW_NAMES:
            candidate = project_dir / name
            if candidate.is_file():
                preview = str(candidate)
                break

    try:
        modified = project_file.stat().st_mtime_ns // 1_000_000
    except OSError:
        modified = 0

    return {
        "id": project_dir.name,
        "path": str(project_dir),
        "title": str(data.get("title") or project_dir.name),
        "type": str(data.get("type") or "unknown").lower(),
        "file": str(data.get("file") or ""),
        "preview": preview,
        "modified": modified,
    }


def scan(roots):
    cache = _load_cache()
    cached_projects = cache.get("projects", {})
    cached_mtimes = cache.get("mtimes", {})
    dirty = False

    projects = []
    visited = set()
    next_projects: dict[str, dict] = {}
    next_mtimes: dict[str, str] = {}

    for root_text in roots:
        root = Path(root_text).expanduser()
        try:
            root_key = str(root.resolve())
        except OSError:
            root_key = str(root)
        if root_key in visited or not root.is_dir():
            continue
        visited.add(root_key)

        for project_dir in sorted(root.iterdir(), key=lambda path: path.name):
            dir_key = str(project_dir)
            signature = _project_signature(project_dir)
            next_mtimes[dir_key] = signature

            # Directory mtime alone does not change when project.json is
            # edited in place, so cache against both directory and file data.
            if (
                dir_key in cached_projects
                and cached_mtimes.get(dir_key) == signature
                and signature != ""
            ):
                entry = cached_projects[dir_key]
                next_projects[dir_key] = entry
                projects.append(entry)
                continue

            entry = _scan_project(project_dir)
            if entry is not None:
                next_projects[dir_key] = entry
                projects.append(entry)
                dirty = True

    # Detect removals as well so the cache stays in sync.
    if set(next_projects.keys()) != set(cached_projects.keys()):
        dirty = True

    if dirty:
        _save_cache(
            {
                "version": CACHE_VERSION,
                "projects": next_projects,
                "mtimes": next_mtimes,
            }
        )

    projects.sort(key=lambda item: item["title"].casefold())
    return projects


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--project":
        result = _scan_project(Path(sys.argv[2]).expanduser()) or {}
    else:
        result = scan(sys.argv[1:])
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
