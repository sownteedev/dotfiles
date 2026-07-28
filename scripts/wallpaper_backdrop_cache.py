#!/usr/bin/env python3
"""Build and reuse persistent blurred wallpaper backdrops."""

from __future__ import annotations

import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


CACHE_VERSION = "backdrop-v3|resize15-blur4"
MAX_CACHE_BYTES = 96 * 1024 * 1024
MAX_CACHE_FILES = 128


def source_identity(source: Path, stable_identity: str) -> str:
    if stable_identity:
        return f"{CACHE_VERSION}|{stable_identity}"

    stat = source.stat()
    return "|".join(
        (
            CACHE_VERSION,
            str(source.resolve()),
            str(stat.st_size),
            str(stat.st_mtime_ns),
        )
    )


def image_source(source: Path) -> str:
    value = str(source)
    return f"{value}[0]" if source.suffix.lower() == ".gif" else value


def usable_cache(path: Path) -> bool:
    try:
        return path.is_file() and path.stat().st_size > 0
    except OSError:
        return False


def generate_backdrop(source: str, target: Path) -> None:
    if usable_cache(target):
        os.utime(target)
        return

    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{target.stem}-",
        suffix=".png",
        dir=target.parent,
    )
    os.close(descriptor)
    temporary = Path(temporary_name)
    try:
        subprocess.run(
            ["magick", source, "-resize", "15%", "-blur", "0x4", str(temporary)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
            timeout=30,
        )
        if not usable_cache(temporary):
            raise RuntimeError(f"ImageMagick produced an empty backdrop: {temporary}")
        os.replace(temporary, target)
    finally:
        temporary.unlink(missing_ok=True)


def prune_cache(cache_dir: Path, protected: set[Path]) -> None:
    files = [path for path in cache_dir.glob("*.png") if path.is_file()]
    total_bytes = sum(path.stat().st_size for path in files)
    if len(files) <= MAX_CACHE_FILES and total_bytes <= MAX_CACHE_BYTES:
        return

    files.sort(key=lambda path: path.stat().st_mtime_ns)
    remaining_files = len(files)
    for path in files:
        if remaining_files <= MAX_CACHE_FILES and total_bytes <= MAX_CACHE_BYTES:
            break
        if path in protected:
            continue
        try:
            size = path.stat().st_size
            path.unlink()
            total_bytes -= size
            remaining_files -= 1
        except OSError:
            continue


def remove_legacy_variants(cache_dir: Path) -> None:
    for pattern in ("*-main.png", "*-lock.png"):
        for path in cache_dir.glob(pattern):
            try:
                path.unlink()
            except OSError:
                continue


def ensure_cache_version(cache_dir: Path) -> None:
    version_file = cache_dir / ".version"
    try:
        current = version_file.read_text().strip()
    except OSError:
        current = ""
    if current == CACHE_VERSION:
        return

    for path in cache_dir.glob("*.png"):
        try:
            path.unlink()
        except OSError:
            continue

    descriptor, temporary_name = tempfile.mkstemp(
        prefix=".version-",
        dir=cache_dir,
    )
    os.close(descriptor)
    temporary = Path(temporary_name)
    try:
        temporary.write_text(CACHE_VERSION)
        os.replace(temporary, version_file)
    finally:
        temporary.unlink(missing_ok=True)


def main() -> int:
    if len(sys.argv) not in (3, 4, 5):
        print(
            "usage: wallpaper_backdrop_cache.py SOURCE CACHE_DIR "
            "[STABLE_IDENTITY] [GENERATE_IF_MISSING]",
            file=sys.stderr,
        )
        return 2

    source = Path(sys.argv[1]).expanduser()
    cache_dir = Path(sys.argv[2]).expanduser()
    stable_identity = sys.argv[3] if len(sys.argv) >= 4 else ""
    generate_if_missing = len(sys.argv) < 5 or sys.argv[4].lower() == "true"
    if not source.is_file():
        print(f"wallpaper source does not exist: {source}", file=sys.stderr)
        return 1

    magick = shutil.which("magick")
    if not magick:
        print("ImageMagick executable 'magick' was not found", file=sys.stderr)
        return 1

    cache_dir.mkdir(parents=True, exist_ok=True)
    ensure_cache_version(cache_dir)
    key = hashlib.sha256(source_identity(source, stable_identity).encode()).hexdigest()
    backdrop = cache_dir / f"{key}.png"
    source_spec = image_source(source)

    try:
        remove_legacy_variants(cache_dir)
        if not usable_cache(backdrop) and not generate_if_missing:
            return 3
        generate_backdrop(source_spec, backdrop)
        prune_cache(cache_dir, {backdrop})
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f"could not generate wallpaper backdrop: {error}", file=sys.stderr)
        return 1

    print(backdrop)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
