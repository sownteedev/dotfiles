#!/usr/bin/env python3
"""Scan Steam Workshop Wallpaper Engine projects for the Quickshell UI."""

import json
import sys
from pathlib import Path


PREVIEW_NAMES = ("preview.jpg", "preview.jpeg", "preview.png", "preview.gif")


def scan(roots):
    projects = []
    visited = set()

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
            project_file = project_dir / "project.json"
            if not project_dir.is_dir() or not project_file.is_file():
                continue
            try:
                data = json.loads(project_file.read_text(encoding="utf-8"))
            except (OSError, UnicodeDecodeError, json.JSONDecodeError):
                continue

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

            projects.append(
                {
                    "id": project_dir.name,
                    "path": str(project_dir),
                    "title": str(data.get("title") or project_dir.name),
                    "type": str(data.get("type") or "unknown").lower(),
                    "file": str(data.get("file") or ""),
                    "preview": preview,
                    "modified": modified,
                }
            )

    projects.sort(key=lambda item: item["title"].casefold())
    return projects


if __name__ == "__main__":
    print(json.dumps(scan(sys.argv[1:]), ensure_ascii=False, separators=(",", ":")))
