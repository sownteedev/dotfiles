#!/usr/bin/env python3
"""Synchronize a wallpaper and its colors with the greetd data directory."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


IMAGE_EXTENSIONS = {".avif", ".jpeg", ".jpg", ".png", ".webp"}
VIDEO_EXTENSIONS = {".avi", ".m4v", ".mkv", ".mov", ".mp4", ".webm"}
REQUIRED_MD3_COLORS = {
    "background",
    "error",
    "error_container",
    "on_background",
    "on_error",
    "on_error_container",
    "on_primary",
    "on_primary_container",
    "on_surface",
    "on_surface_variant",
    "outline",
    "outline_variant",
    "primary",
    "primary_container",
    "scrim",
    "shadow",
    "surface",
    "surface_bright",
    "surface_container",
    "surface_container_high",
    "surface_container_highest",
    "surface_container_low",
    "surface_container_lowest",
    "tertiary",
}


class SyncError(Exception):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))


def resolve_image(source_text: str) -> Path:
    source = Path(source_text).expanduser()
    if source.is_symlink():
        raise SyncError("unsupported_image", "Symbolic links cannot be used as the greetd background")
    try:
        source = source.resolve(strict=True)
    except OSError as error:
        raise SyncError("not_found", "The selected Wallhaven image was not found") from error
    if source.is_symlink() or not source.is_file() or source.suffix.lower() not in IMAGE_EXTENSIONS:
        raise SyncError("unsupported_image", "The selected file is not a supported image")
    return source


def resolve_engine_video(source_text: str) -> Path:
    project_dir = Path(source_text).expanduser()
    if project_dir.is_symlink():
        raise SyncError("invalid_project", "Symbolic links cannot be used as Wallpaper Engine projects")
    try:
        project_dir = project_dir.resolve(strict=True)
    except OSError as error:
        raise SyncError("not_found", "The Wallpaper Engine project was not found") from error
    if not project_dir.is_dir():
        raise SyncError("invalid_project", "The selected Wallpaper Engine path is not a project")

    project_file = project_dir / "project.json"
    try:
        metadata = json.loads(project_file.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise SyncError("invalid_project", "Could not read the Wallpaper Engine project") from error

    if str(metadata.get("type") or "").casefold() != "video":
        raise SyncError("unsupported_project_type", "Only Wallpaper Engine video projects can be used by greetd")

    media_name = str(metadata.get("file") or "").strip()
    if not media_name:
        raise SyncError("missing_video", "The Wallpaper Engine project does not define a video file")
    try:
        media_path = (project_dir / media_name).resolve(strict=True)
    except OSError as error:
        raise SyncError("missing_video", "The Wallpaper Engine video file was not found") from error
    if project_dir not in media_path.parents or not media_path.is_file():
        raise SyncError("unsafe_video_path", "The Wallpaper Engine video path is outside its project")
    if media_path.suffix.lower() not in VIDEO_EXTENSIONS:
        raise SyncError("unsupported_video", "The Wallpaper Engine project uses an unsupported video format")
    return media_path


def atomic_copy(source: Path, destination: Path) -> None:
    file_descriptor, temporary_name = tempfile.mkstemp(prefix=".background.", dir=destination.parent)
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(file_descriptor, "wb") as temporary_file, source.open("rb") as source_file:
            shutil.copyfileobj(source_file, temporary_file, length=1024 * 1024)
            temporary_file.flush()
            os.fsync(temporary_file.fileno())
        os.chmod(temporary_path, 0o640)
        os.replace(temporary_path, destination)
    finally:
        temporary_path.unlink(missing_ok=True)


def atomic_manifest(payload: dict[str, Any], destination: Path) -> None:
    file_descriptor, temporary_name = tempfile.mkstemp(prefix=".background-manifest.", dir=destination.parent)
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(file_descriptor, "w", encoding="utf-8") as temporary_file:
            json.dump(payload, temporary_file, ensure_ascii=False, separators=(",", ":"))
            temporary_file.write("\n")
            temporary_file.flush()
            os.fsync(temporary_file.fileno())
        os.chmod(temporary_path, 0o640)
        os.replace(temporary_path, destination)
    finally:
        temporary_path.unlink(missing_ok=True)

def video_sample_time(source: Path) -> float:
    if shutil.which("ffprobe") is None:
        return 0.5
    try:
        result = subprocess.run(
            [
                "ffprobe",
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "default=noprint_wrappers=1:nokey=1",
                str(source),
            ],
            capture_output=True,
            check=False,
            text=True,
            timeout=15,
        )
    except subprocess.TimeoutExpired:
        return 0.5
    try:
        duration = float(result.stdout.strip())
    except (TypeError, ValueError):
        return 0.5
    if duration <= 0:
        return 0.5
    return min(10.0, max(0.5, duration * 0.1))

def render_palette_frame(source: Path, video: bool, temporary_dir: Path) -> Path:
    if shutil.which("ffmpeg") is None:
        raise SyncError("missing_dependency", "ffmpeg is required to generate the greetd color palette")

    frame_path = temporary_dir / "palette-source.png"
    sample_times = [video_sample_time(source), None] if video else [None]
    result: subprocess.CompletedProcess[str] | None = None
    for sample_time in sample_times:
        frame_path.unlink(missing_ok=True)
        seek_arguments = ["-ss", f"{sample_time:.3f}"] if sample_time is not None else []
        command = [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            *seek_arguments,
            "-i",
            str(source),
            "-frames:v",
            "1",
            "-vf",
            "scale=960:-2:force_original_aspect_ratio=decrease",
            str(frame_path),
        ]
        try:
            result = subprocess.run(command, capture_output=True, check=False, text=True, timeout=60)
        except subprocess.TimeoutExpired:
            continue
        if result.returncode == 0 and frame_path.is_file() and frame_path.stat().st_size > 0:
            return frame_path
    message = result.stderr.strip() if result is not None else ""
    if not message:
        message = "Could not render the selected greetd background"
    raise SyncError("palette_frame_failed", message)

def generate_theme_snapshot(palette_source: Path, source_text: str, temporary_dir: Path) -> dict[str, Any]:
    if shutil.which("matugen") is None:
        raise SyncError("missing_dependency", "Matugen is required to generate the greetd color palette")

    config_path = temporary_dir / "matugen.toml"
    config_path.write_text("[config]\nversion_check = false\n\n[templates]\n", encoding="utf-8")
    try:
        result = subprocess.run(
            [
                "matugen",
                "--config",
                str(config_path),
                "image",
                str(palette_source),
                "--type",
                "scheme-tonal-spot",
                "--mode",
                "dark",
                "--source-color-index",
                "0",
                "--continue-on-error",
                "--json",
                "hex",
                "--dry-run",
                "--quiet",
            ],
            capture_output=True,
            check=False,
            text=True,
            timeout=60,
        )
    except subprocess.TimeoutExpired as error:
        raise SyncError("palette_generation_failed", "Matugen timed out while generating the greetd color palette") from error
    if result.returncode != 0:
        raise SyncError("palette_generation_failed", result.stderr.strip() or "Matugen could not generate the greetd color palette")
    try:
        matugen_data = json.loads(result.stdout)
        color_data = matugen_data["colors"]
        md3 = {
            name: variants["default"]["color"]
            for name, variants in color_data.items()
            if isinstance(variants, dict)
            and isinstance(variants.get("default"), dict)
            and isinstance(variants["default"].get("color"), str)
        }
    except (KeyError, TypeError, json.JSONDecodeError) as error:
        raise SyncError("palette_generation_failed", "Matugen returned an invalid greetd color palette") from error
    missing_colors = REQUIRED_MD3_COLORS.difference(md3)
    if missing_colors:
        raise SyncError("palette_generation_failed", "Matugen did not return all required greetd colors")
    return {
        "mode": "dark",
        "source": source_text,
        "md3": md3,
    }


def sync_background(kind: str, source_text: str, destination_text: str) -> dict[str, Any]:
    source = resolve_image(source_text) if kind == "image" else resolve_engine_video(source_text)
    destination_dir = Path(destination_text).expanduser()
    if not destination_dir.is_dir() or not os.access(destination_dir, os.W_OK | os.X_OK):
        raise SyncError("destination_unavailable", "The greetd background directory is not writable")

    with tempfile.TemporaryDirectory(prefix="greetd-palette-") as temporary_name:
        temporary_dir = Path(temporary_name)
        palette_source = render_palette_frame(source, kind == "engine-video", temporary_dir)
        theme_snapshot = generate_theme_snapshot(palette_source, source_text, temporary_dir)

    destination = destination_dir / f"background{source.suffix.lower()}"
    atomic_copy(source, destination)
    theme_path = destination_dir / "colors.json"
    atomic_manifest(theme_snapshot, theme_path)
    manifest_path = destination_dir / "background.json"
    manifest = {
        "version": 1,
        "kind": kind,
        "path": str(destination),
        "source": source_text,
    }
    atomic_manifest(manifest, manifest_path)

    for candidate in destination_dir.glob("background.*"):
        if candidate not in {destination, manifest_path} and candidate.is_file() and not candidate.is_symlink():
            candidate.unlink(missing_ok=True)
    return {"ok": True, "theme_path": str(theme_path), **manifest}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("kind", choices=("image", "engine-video"))
    parser.add_argument("source")
    parser.add_argument(
        "--destination",
        default=os.environ.get("GREETD_BACKGROUND_DIR", "/var/lib/quickshell-greeter"),
    )
    arguments = parser.parse_args()

    try:
        result = sync_background(arguments.kind, arguments.source, arguments.destination)
    except SyncError as error:
        emit({"ok": False, "code": error.code, "message": str(error)})
        return 1
    except OSError as error:
        emit({"ok": False, "code": "write_failed", "message": f"Could not update the greetd background: {error}"})
        return 1
    emit(result)
    return 0


if __name__ == "__main__":
    sys.exit(main())
