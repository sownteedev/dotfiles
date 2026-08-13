#!/usr/bin/env python3
"""Arrange a floating Niri workspace as a centered cascade."""

import argparse
import json
import math
import os
import re
import subprocess


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TOGGLE_SCRIPT = os.path.join(SCRIPT_DIR, "toogle-floating-workspace")


def run_json(*command, fallback):
    try:
        output = subprocess.check_output(command, text=True)
        return json.loads(output)
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError):
        return fallback


def get_workspace(workspace_id=None):
    workspaces = run_json("niri", "msg", "-j", "workspaces", fallback=[])
    if workspace_id is not None:
        return next(
            (workspace for workspace in workspaces if workspace.get("id") == workspace_id),
            None,
        )
    return next((workspace for workspace in workspaces if workspace.get("is_focused")), None)


def get_outputs():
    return run_json("niri", "msg", "-j", "outputs", fallback={})


def get_protected_app_patterns():
    try:
        result = subprocess.run(
            [TOGGLE_SCRIPT, "--get-protected-patterns"],
            capture_output=True,
            check=False,
            text=True,
        )
        patterns = []
        for line in result.stdout.splitlines():
            pattern = line.strip()
            if not pattern:
                continue
            try:
                patterns.append(re.compile(pattern))
            except re.error as error:
                print(f"Ignoring unsupported app-id pattern {pattern!r}: {error}")
        return patterns
    except OSError:
        return []


def focus_key(window):
    timestamp = window.get("focus_timestamp") or {}
    return (
        int(timestamp.get("secs") or 0),
        int(timestamp.get("nanos") or 0),
        int(window.get("id") or 0),
    )


def is_protected_app(app_id, protected_patterns):
    return any(pattern.search(app_id) for pattern in protected_patterns)


def get_windows(workspace_id, protected_patterns):
    windows = run_json("niri", "msg", "-j", "windows", fallback=[])
    arranged = [
        window
        for window in windows
        if window.get("workspace_id") == workspace_id
        and window.get("is_floating")
        and not is_protected_app(window.get("app_id") or "", protected_patterns)
    ]
    # Keep the cascade order stable without changing the user's current focus.
    arranged.sort(key=focus_key)
    return arranged


def centered_rect(area_x, area_y, area_w, area_h, width_ratio, height_ratio):
    width = min(area_w, max(320, int(area_w * width_ratio)))
    height = min(area_h, max(240, int(area_h * height_ratio)))
    x = area_x + (area_w - width) // 2
    y = area_y + (area_h - height) // 2
    return x, y, width, height


def cascade_layout(count, area_x, area_y, area_w, area_h):
    if count == 1:
        return [centered_rect(area_x, area_y, area_w, area_h, 0.72, 0.82)]

    width = min(area_w, max(640, int(area_w * 0.68)))
    height = min(area_h, max(480, int(area_h * 0.76)))
    offset_x = max(72, min(120, int(area_w * 0.05)))
    offset_y = max(44, min(60, int(area_h * 0.045)))

    # Keep the full deck centered even on smaller or vertically oriented
    # outputs. Shrink the offsets before shrinking a usable window.
    max_offset_x = max(0, (area_w - width) // (count - 1))
    max_offset_y = max(0, (area_h - height) // (count - 1))
    offset_x = min(offset_x, max_offset_x)
    offset_y = min(offset_y, max_offset_y)

    deck_width = width + offset_x * (count - 1)
    deck_height = height + offset_y * (count - 1)
    start_x = area_x + (area_w - deck_width) // 2
    start_y = area_y + (area_h - deck_height) // 2

    return [
        (
            start_x + index * offset_x,
            start_y + index * offset_y,
            width,
            height,
        )
        for index in range(count)
    ]


def grid_layout(count, area_x, area_y, area_w, area_h, gap):
    columns = 3 if count <= 9 else math.ceil(math.sqrt(count))
    rows = math.ceil(count / columns)
    width = (area_w - (columns - 1) * gap) // columns
    height = (area_h - (rows - 1) * gap) // rows

    rects = []
    for index in range(count):
        row = index // columns
        column = index % columns
        items_in_row = min(columns, count - row * columns)
        row_width = items_in_row * width + max(0, items_in_row - 1) * gap
        row_x = area_x + (area_w - row_width) // 2
        rects.append(
            (
                row_x + column * (width + gap),
                area_y + row * (height + gap),
                width,
                height,
            )
        )
    return rects


def build_layout(count, monitor_width, monitor_height):
    padding_x = max(48, min(80, int(monitor_width * 0.035)))
    padding_y = max(64, min(80, int(monitor_height * 0.05)))
    gap = max(20, min(30, int(min(monitor_width, monitor_height) * 0.02)))
    area_x = padding_x
    area_y = padding_y
    area_w = max(1, monitor_width - 2 * padding_x)
    area_h = max(1, monitor_height - 2 * padding_y)

    if count <= 5:
        return cascade_layout(count, area_x, area_y, area_w, area_h)
    return grid_layout(count, area_x, area_y, area_w, area_h, gap)


def run_action(*arguments):
    result = subprocess.run(
        ["niri", "msg", "action", *map(str, arguments)],
        capture_output=True,
        check=False,
        text=True,
    )
    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip()
        print(f"niri action failed ({' '.join(map(str, arguments))}): {message}")
        return False
    return True


def apply_rect(window_id, rect):
    x, y, width, height = rect
    return all(
        (
            run_action("set-window-width", width, "--id", window_id),
            run_action("set-window-height", height, "--id", window_id),
            run_action(
                "move-floating-window",
                "-x",
                x,
                "-y",
                y,
                "--id",
                window_id,
            ),
        )
    )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace-id", type=int)
    parser.add_argument("--window-id", type=int)
    arguments = parser.parse_args()

    workspace = get_workspace(arguments.workspace_id)
    if not workspace:
        print("Target workspace is no longer available")
        return 1

    output = get_outputs().get(workspace.get("output"))
    if not output:
        print("Target workspace output is no longer available")
        return 1

    logical = output.get("logical") or {}
    monitor_width = int(logical.get("width") or 1920)
    monitor_height = int(logical.get("height") or 1080)
    windows = get_windows(workspace["id"], get_protected_app_patterns())
    if not windows:
        return 0

    rects = build_layout(len(windows), monitor_width, monitor_height)
    if arguments.window_id is not None:
        for index, window in enumerate(windows):
            if window.get("id") == arguments.window_id:
                return 0 if apply_rect(window["id"], rects[index]) else 1
        print(f"Window {arguments.window_id} is no longer available for arranging")
        return 1

    succeeded = True
    for window, rect in zip(windows, rects):
        succeeded = apply_rect(window["id"], rect) and succeeded
    return 0 if succeeded else 1


if __name__ == "__main__":
    raise SystemExit(main())
