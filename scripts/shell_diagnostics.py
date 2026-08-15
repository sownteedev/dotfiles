#!/usr/bin/env python3
"""On-demand Quickshell dependency and cache diagnostics."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


CACHE_ROOT = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "quickshell"
CACHE_SCOPES = {
    "wallpaper-previews": ("Wallpaper previews", CACHE_ROOT / "wallpaper-preview"),
    "engine-previews": ("Video previews", CACHE_ROOT / "wallpaper-engine" / "previews"),
    "backdrops": ("Generated backdrops", CACHE_ROOT / "backdrops"),
}
DEPENDENCIES = (
    ("quickshell", "Shell runtime", True),
    ("niri", "Compositor", True),
    ("swayidle", "Idle and power policy", True),
    ("cliphist", "Clipboard history", True),
    ("wl-copy", "Wayland clipboard", True),
    ("gpu-screen-recorder", "Screen recording", False),
    ("matugen", "Dynamic colors", False),
    ("ffmpeg", "Video thumbnails", False),
    ("magick", "Image thumbnails", False),
    ("mpvpaper", "Live wallpapers", False),
    ("linux-wallpaperengine", "Wallpaper Engine playback", False),
    ("steamcmd", "Workshop downloads", False),
)


def directory_size(path: Path) -> int:
    if not path.exists():
        return 0
    total = 0
    for entry in path.rglob("*"):
        try:
            if entry.is_file() and not entry.is_symlink():
                total += entry.stat().st_size
        except OSError:
            continue
    return total


def unit_state(unit: str) -> str:
    result = subprocess.run(
        ["systemctl", "--user", "is-active", unit],
        capture_output=True,
        text=True,
        check=False,
        timeout=4,
    )
    state = result.stdout.strip()
    return state if state else "inactive"


def snapshot() -> dict[str, object]:
    dependencies = [
        {
            "name": command,
            "description": description,
            "required": required,
            "available": shutil.which(command) is not None,
        }
        for command, description, required in DEPENDENCIES
    ]
    caches = [
        {
            "scope": scope,
            "label": label,
            "path": str(path),
            "bytes": directory_size(path),
        }
        for scope, (label, path) in CACHE_SCOPES.items()
    ]
    return {
        "ok": True,
        "dependencies": dependencies,
        "caches": caches,
        "services": [
            {"name": "quickshell-idle.service", "state": unit_state("quickshell-idle.service")},
            {"name": "quickshell-caffeine-inhibitor.service", "state": unit_state("quickshell-caffeine-inhibitor.service")},
        ],
    }


def clear_cache(scope: str) -> dict[str, object]:
    cache_entry = CACHE_SCOPES.get(scope)
    if cache_entry is None:
        raise ValueError("Unknown cache scope")
    _, path = cache_entry
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True, exist_ok=True)
    return {"ok": True, "message": f"Cleared {scope} cache"}


def main() -> int:
    try:
        command = sys.argv[1] if len(sys.argv) > 1 else "snapshot"
        result = snapshot() if command == "snapshot" else clear_cache(sys.argv[2]) if command == "clear" and len(sys.argv) > 2 else None
        if result is None:
            raise ValueError("Unknown diagnostics command")
        print(json.dumps(result, ensure_ascii=False))
        return 0
    except Exception as error:
        print(json.dumps({"ok": False, "message": str(error)}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
