#!/usr/bin/env python3
"""Synchronize user-selected greeter settings into greetd-readable storage."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
from pathlib import Path
from typing import Any


class SyncError(Exception):
    pass


def emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))


def normalize_session(value: str) -> str:
    session = value.strip()[:80]
    if not re.fullmatch(r"[A-Za-z0-9._+-]+", session):
        raise SyncError("Select a valid installed desktop session")
    return session


def write_manifest(destination_dir: Path, default_session: str, remember_last: bool) -> dict[str, Any]:
    if destination_dir.is_symlink() or not destination_dir.is_dir():
        raise SyncError("Greetd storage is not installed. Run the greetd installer first")

    destination = destination_dir / "settings.json"
    payload = {
        "defaultSession": normalize_session(default_session),
        "rememberLastSession": remember_last,
    }
    descriptor, temporary_name = tempfile.mkstemp(prefix=".greeter-settings.", dir=destination_dir)
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as temporary_file:
            json.dump(payload, temporary_file, ensure_ascii=False, separators=(",", ":"))
            temporary_file.write("\n")
            temporary_file.flush()
            os.fsync(temporary_file.fileno())
        os.chmod(temporary_path, 0o640)
        os.replace(temporary_path, destination)
    finally:
        temporary_path.unlink(missing_ok=True)
    return {"ok": True, "path": str(destination), **payload}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--default-session", default="niri")
    parser.add_argument("--remember-last-session", choices=("true", "false"), default="false")
    parser.add_argument(
        "--destination",
        default=os.environ.get("GREETD_SETTINGS_DIR", "/var/lib/quickshell-greeter"),
    )
    arguments = parser.parse_args()
    try:
        result = write_manifest(
            Path(arguments.destination).expanduser(),
            arguments.default_session,
            arguments.remember_last_session == "true",
        )
    except (OSError, SyncError) as error:
        emit({"ok": False, "message": str(error)})
        return 1
    emit(result)
    return 0


if __name__ == "__main__":
    sys.exit(main())
