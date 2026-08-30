#!/usr/bin/env python3
"""Synchronize the selected profile image with greetd-readable storage."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Any

IMAGE_EXTENSIONS = {".avif", ".jpeg", ".jpg", ".png", ".webp"}


class SyncError(Exception):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))


def resolve_image(source_text: str) -> Path:
    source = Path(source_text).expanduser()
    if source.is_symlink():
        raise SyncError("unsupported_image", "Symbolic links cannot be used as a profile image")
    try:
        source = source.resolve(strict=True)
    except OSError as error:
        raise SyncError("not_found", "The selected profile image was not found") from error
    if source.is_symlink() or not source.is_file() or source.suffix.lower() not in IMAGE_EXTENSIONS:
        raise SyncError("unsupported_image", "Select a PNG, JPEG, WebP, or AVIF image")
    return source


def atomic_copy(source: Path, destination: Path) -> None:
    descriptor, temporary_name = tempfile.mkstemp(prefix=".profile.", dir=destination.parent)
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as temporary_file, source.open("rb") as source_file:
            shutil.copyfileobj(source_file, temporary_file, length=1024 * 1024)
            temporary_file.flush()
            os.fsync(temporary_file.fileno())
        os.chmod(temporary_path, 0o640)
        os.replace(temporary_path, destination)
    finally:
        temporary_path.unlink(missing_ok=True)


def atomic_manifest(payload: dict[str, Any], destination: Path) -> None:
    descriptor, temporary_name = tempfile.mkstemp(prefix=".profile-manifest.", dir=destination.parent)
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


def clear_profile(destination_dir: Path) -> dict[str, Any]:
    if not destination_dir.exists():
        return {"ok": True, "path": ""}
    if not destination_dir.is_dir() or not os.access(destination_dir, os.W_OK | os.X_OK):
        raise SyncError("destination_unavailable", "The greetd profile directory is not writable")
    for candidate in destination_dir.glob("profile.*"):
        if candidate.is_file() and not candidate.is_symlink():
            candidate.unlink(missing_ok=True)
    return {"ok": True, "path": ""}


def sync_profile(source_text: str, destination_dir: Path) -> dict[str, Any]:
    source = resolve_image(source_text)
    if not destination_dir.is_dir() or not os.access(destination_dir, os.W_OK | os.X_OK):
        raise SyncError("destination_unavailable", "The greetd profile directory is not writable")

    destination = destination_dir / f"profile{source.suffix.lower()}"
    atomic_copy(source, destination)
    manifest_path = destination_dir / "profile.json"
    manifest = {"version": 1, "path": str(destination), "source": source_text}
    atomic_manifest(manifest, manifest_path)
    for candidate in destination_dir.glob("profile.*"):
        if candidate not in {destination, manifest_path} and candidate.is_file() and not candidate.is_symlink():
            candidate.unlink(missing_ok=True)
    return {"ok": True, **manifest}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", nargs="?", default="")
    parser.add_argument("--clear", action="store_true")
    parser.add_argument(
        "--destination",
        default=os.environ.get("GREETD_PROFILE_DIR", "/var/lib/quickshell-greeter"),
    )
    arguments = parser.parse_args()
    destination_dir = Path(arguments.destination).expanduser()

    try:
        result = clear_profile(destination_dir) if arguments.clear or not arguments.source else sync_profile(arguments.source, destination_dir)
    except SyncError as error:
        emit({"ok": False, "code": error.code, "message": str(error)})
        return 1
    except OSError as error:
        emit({"ok": False, "code": "write_failed", "message": f"Could not update the profile image: {error}"})
        return 1
    emit(result)
    return 0


if __name__ == "__main__":
    sys.exit(main())
