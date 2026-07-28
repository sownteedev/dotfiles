#!/usr/bin/env python3
"""Wait until a renderer has finished writing a wallpaper frame."""

import os
import sys
import time


def wait_for_file(path, timeout):
    deadline = time.monotonic() + timeout
    previous_size = -1
    stable_reads = 0

    while time.monotonic() < deadline:
        try:
            size = os.path.getsize(path)
            if size > 0 and size == previous_size:
                stable_reads += 1
                if stable_reads >= 2:
                    return 0
            else:
                stable_reads = 0
            previous_size = size
        except OSError:
            previous_size = -1
            stable_reads = 0
        time.sleep(0.05)

    return 1


def main():
    if len(sys.argv) < 2:
        return 2
    return wait_for_file(sys.argv[1], float(sys.argv[2]) if len(sys.argv) > 2 else 4.0)


if __name__ == "__main__":
    raise SystemExit(main())
