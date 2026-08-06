#!/usr/bin/env python3
"""Wait for a complete, visually usable wallpaper frame."""

import os
import shutil
import subprocess
import sys
import time


def frame_is_usable(path):
    """Reject undecodable and mostly-black renderer startup frames."""
    magick = shutil.which("magick")
    if not magick:
        # ImageMagick is already a wallpaper dependency, but do not make the
        # probe fail forever if it is temporarily unavailable.
        return True

    try:
        result = subprocess.run(
            [
                magick,
                path,
                "-resize",
                "64x64!",
                "-colorspace",
                "RGB",
                "-format",
                "%[fx:mean] %[fx:standard_deviation]",
                "info:",
            ],
            check=True,
            capture_output=True,
            text=True,
            timeout=2.0,
        )
        mean, deviation = (float(value) for value in result.stdout.split())
    except (OSError, subprocess.SubprocessError, ValueError):
        return False

    # A valid dark wallpaper can have a low mean while still containing useful
    # detail. Startup corruption from linux-wallpaperengine is both nearly
    # black and low-variance (often with a few coloured blocks at the bottom).
    return mean >= 0.01 or deviation >= 0.07


def wait_for_file(path, timeout):
    deadline = time.monotonic() + timeout
    previous_signature = None
    rejected_signature = None
    stable_reads = 0

    while time.monotonic() < deadline:
        try:
            stat = os.stat(path)
            signature = (stat.st_size, stat.st_mtime_ns)
            if stat.st_size > 0 and signature == previous_signature:
                stable_reads += 1
                if stable_reads >= 2:
                    if signature == rejected_signature:
                        time.sleep(0.10)
                        continue
                    if frame_is_usable(path):
                        return 0
                    # linux-wallpaperengine normally writes this screenshot
                    # once. Keep polling in case it replaces the file, but do
                    # not let an invalid frame become the persisted backdrop.
                    rejected_signature = signature
                    stable_reads = 0
            else:
                stable_reads = 0
            previous_signature = signature
        except OSError:
            previous_signature = None
            stable_reads = 0
        time.sleep(0.10)

    return 1


def main():
    if len(sys.argv) < 2:
        return 2
    return wait_for_file(sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else 4.0)


if __name__ == "__main__":
    raise SystemExit(main())
