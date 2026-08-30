#!/usr/bin/env python3
"""Join screenshot layers edge to edge without loading them into QML."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


class StitchError(RuntimeError):
    """Expected user-facing stitch failure."""


def emit(payload: dict[str, object]) -> None:
    print(json.dumps(payload, ensure_ascii=False), flush=True)


def executable(name: str) -> str:
    path = shutil.which(name)
    if not path:
        raise StitchError(f"Required command '{name}' was not found")
    return path


def run(command: list[str], *, timeout: float = 60.0) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as error:
        raise StitchError("Image processing timed out") from error
    except subprocess.CalledProcessError as error:
        message = (error.stderr or error.stdout or "Image processing failed").strip()
        raise StitchError(message.splitlines()[-1] if message else "Image processing failed") from error


def image_dimensions(magick: str, path: Path) -> tuple[int, int]:
    if not path.is_file():
        raise StitchError(f"Image not found: {path}")
    result = run(
        [magick, "identify", "-quiet", "-format", "%w %h", f"{path}[0]"],
        timeout=15.0,
    )
    try:
        width, height = (int(value) for value in result.stdout.split())
    except (TypeError, ValueError) as error:
        raise StitchError(f"Could not read image dimensions: {path.name}") from error
    if width <= 0 or height <= 0:
        raise StitchError(f"Invalid image dimensions: {path.name}")
    return width, height


def normalized_image(
    magick: str,
    source: Path,
    destination: Path,
    orientation: str,
    target_size: int,
) -> None:
    resize = f"{target_size}x" if orientation == "vertical" else f"x{target_size}"
    run(
        [
            magick,
            f"{source}[0]",
            "-auto-orient",
            "-resize",
            resize,
            str(destination),
        ],
        timeout=90.0,
    )


def stitch_images(paths: list[str], output: str, orientation: str) -> dict[str, object]:
    if len(paths) != 2:
        raise StitchError("Exactly two images are required")
    if orientation not in {"vertical", "horizontal"}:
        raise StitchError("Unsupported stitch direction")
    magick = executable("magick")
    sources = [Path(path).expanduser().resolve() for path in paths]
    dimensions = [image_dimensions(magick, path) for path in sources]
    target_size = max(size[0] if orientation == "vertical" else size[1] for size in dimensions)
    output_path = Path(output).expanduser().resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="quickshell-stitch-work-") as work_dir_text:
        work_dir = Path(work_dir_text)
        normalized: list[Path] = []
        for index, source in enumerate(sources):
            destination = work_dir / f"image-{index:02d}.png"
            normalized_image(magick, source, destination, orientation, target_size)
            normalized.append(destination)

        command = [magick]
        command.extend(str(image) for image in normalized)

        temporary_output = output_path.with_name(f".{output_path.name}.{os.getpid()}.tmp.png")
        try:
            command.extend(["-background", "none", "-append" if orientation == "vertical" else "+append", str(temporary_output)])
            run(command, timeout=180.0)
            width, height = image_dimensions(magick, temporary_output)
            os.replace(temporary_output, output_path)
        finally:
            temporary_output.unlink(missing_ok=True)

    return {
        "success": True,
        "path": str(output_path),
        "width": width,
        "height": height,
    }


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    merge_parser = subparsers.add_parser("merge")
    merge_parser.add_argument("--orientation", choices=("vertical", "horizontal"), default="vertical")
    merge_parser.add_argument("--output", required=True)
    merge_parser.add_argument("paths", nargs="+")
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    try:
        emit(stitch_images(arguments.paths, arguments.output, arguments.orientation))
        return 0
    except StitchError as error:
        emit({"success": False, "error": str(error)})
        return 1
    except Exception as error:  # Keep QML errors concise while preserving diagnostics.
        emit({"success": False, "error": str(error) or "Image stitching failed"})
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
