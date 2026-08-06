#!/usr/bin/env python3
"""Scan Steam Workshop Wallpaper Engine projects for the Quickshell UI."""

import json
import os
import sys
from pathlib import Path


PREVIEW_NAMES = ("preview.jpg", "preview.jpeg", "preview.png", "preview.gif")
CACHE_FILENAME = "scan_cache.json"


def _cache_path() -> Path:
    return Path.home() / ".cache" / "quickshell" / "wallpaper-engine" / CACHE_FILENAME


def _load_cache() -> dict:
    path = _cache_path()
    try:
        return json.loads(path.read_text(encoding="utf-8"))
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


def _dir_mtime(path: Path) -> int:
    """Return directory mtime in milliseconds, 0 on error."""
    try:
        return path.stat().st_mtime_ns // 1_000_000
    except OSError:
        return 0


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
    next_mtimes: dict[str, int] = {}

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
            mtime = _dir_mtime(project_dir)
            next_mtimes[dir_key] = mtime

            # Reuse cached entry if the directory mtime has not changed.
            if (
                dir_key in cached_projects
                and cached_mtimes.get(dir_key) == mtime
                and mtime > 0
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
        _save_cache({"projects": next_projects, "mtimes": next_mtimes})

    projects.sort(key=lambda item: item["title"].casefold())
    return projects


if __name__ == "__main__":
    print(json.dumps(scan(sys.argv[1:]), ensure_ascii=False, separators=(",", ":")))
