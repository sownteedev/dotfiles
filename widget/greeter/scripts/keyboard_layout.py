#!/usr/bin/env python3
"""Report the keyboard layout used by the standalone greeter."""

from __future__ import annotations

import json
import os
import subprocess


def detected_layout() -> str:
    for name in ("GREETD_KEYBOARD_LAYOUT", "XKB_DEFAULT_LAYOUT"):
        value = os.environ.get(name, "").strip()
        if value:
            return value.split(",", 1)[0]

    try:
        process = subprocess.run(
            ["localectl", "show", "--property=X11Layout", "--value"],
            check=False,
            capture_output=True,
            text=True,
        )
        value = process.stdout.strip()
        if process.returncode == 0 and value and value.lower() != "n/a":
            return value.split(",", 1)[0]
    except OSError:
        pass

    locale = os.environ.get("LC_ALL") or os.environ.get("LC_CTYPE") or os.environ.get("LANG", "")
    return "vi" if locale.lower().startswith("vi") else "us"


layout = detected_layout().strip().lower() or "us"
print(json.dumps({"layout": layout, "label": layout[:5].upper()}, separators=(",", ":")))
