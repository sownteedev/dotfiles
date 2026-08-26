#!/usr/bin/env python3

import fcntl
import json
import os
import re
import subprocess
import time


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
STATE_FILE = os.path.join(RUNTIME_DIR, "niri-floating-workspaces.json")
STATE_LOCK_FILE = f"{STATE_FILE}.lock"
LOCK_FILE = os.path.join(RUNTIME_DIR, "niri-floating-daemon.lock")
TOGGLE_SCRIPT = os.path.join(SCRIPT_DIR, "toogle-floating-workspace")
AUTO_ARRANGE_SCRIPT = os.path.join(SCRIPT_DIR, "niri-auto-arrange.py")


def acquire_singleton_lock():
    os.makedirs(RUNTIME_DIR, exist_ok=True)
    lock = open(LOCK_FILE, "w", encoding="utf-8")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        lock.close()
        return None
    return lock


def reset_floating_state():
    temporary_file = f"{STATE_FILE}.{os.getpid()}.tmp"
    try:
        with open(STATE_LOCK_FILE, "w", encoding="utf-8") as state_lock:
            fcntl.flock(state_lock, fcntl.LOCK_EX)
            with open(temporary_file, "w", encoding="utf-8") as state_file:
                state_file.write("{}\n")
            os.replace(temporary_file, STATE_FILE)
    except OSError as error:
        print(f"Unable to reset floating workspace state: {error}", flush=True)
        try:
            os.unlink(temporary_file)
        except OSError:
            pass


def get_protected_app_patterns():
    try:
        result = subprocess.run(
            [TOGGLE_SCRIPT, "--get-protected-patterns"],
            capture_output=True,
            check=False,
            text=True,
        )
    except OSError as error:
        print(f"Unable to load protected app rules: {error}", flush=True)
        return []

    patterns = []
    for line in result.stdout.splitlines():
        pattern = line.strip()
        if not pattern:
            continue
        try:
            patterns.append(re.compile(pattern))
        except re.error as error:
            print(f"Ignoring unsupported app-id pattern {pattern!r}: {error}", flush=True)
    return patterns


def is_protected_app(app_id, protected_patterns):
    return any(pattern.search(app_id) for pattern in protected_patterns)


def get_floating_workspaces():
    try:
        with open(STATE_FILE, "r", encoding="utf-8") as state_file:
            data = json.load(state_file)
        return {int(key) for key, enabled in data.items() if enabled}
    except (OSError, ValueError, TypeError):
        return set()


def run_niri_action(*arguments):
    try:
        result = subprocess.run(
            ["niri", "msg", "action", *map(str, arguments)],
            capture_output=True,
            check=False,
            text=True,
        )
    except OSError as error:
        print(f"Unable to run Niri action: {error}", flush=True)
        return False

    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip()
        print(f"Niri action failed ({' '.join(map(str, arguments))}): {message}", flush=True)
        return False
    return True


def set_window_floating(window_id, to_floating):
    action = "move-window-to-floating" if to_floating else "move-window-to-tiling"
    if not run_niri_action(action, "--id", window_id):
        return False
    if not to_floating:
        time.sleep(0.18)
        if not run_niri_action("reset-window-height", "--id", window_id):
            return False
        if not run_niri_action("set-window-width", "100%", "--id", window_id):
            return False
    return True


def arrange_workspace(workspace_id, window_id=None):
    command = ["python3", AUTO_ARRANGE_SCRIPT, "--workspace-id", str(workspace_id)]
    if window_id is not None:
        command.extend(("--window-id", str(window_id)))
    result = subprocess.run(
        command,
        capture_output=True,
        check=False,
        text=True,
    )
    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip()
        print(f"Unable to arrange workspace {workspace_id}: {message}", flush=True)


def handle_window(window, known_windows, protected_patterns):
    window_id = window.get("id")
    app_id = window.get("app_id") or ""
    workspace_id = window.get("workspace_id")
    is_floating = window.get("is_floating", False)
    if window_id is None or workspace_id is None:
        return

    previous_workspace_id = known_windows.get(window_id)
    known_windows[window_id] = workspace_id
    if is_protected_app(app_id, protected_patterns):
        return

    is_new_window = previous_workspace_id is None
    is_moved_window = previous_workspace_id is not None and previous_workspace_id != workspace_id
    if not is_new_window and not is_moved_window:
        return

    workspace_is_floating = workspace_id in get_floating_workspaces()
    if workspace_is_floating and not is_floating:
        time.sleep(0.08)
        if set_window_floating(window_id, True):
            arrange_workspace(workspace_id, window_id)
    elif not workspace_is_floating and is_floating and is_moved_window:
        time.sleep(0.08)
        set_window_floating(window_id, False)


def process_event(event, known_windows, protected_patterns):
    if "WindowsChanged" in event:
        known_windows.clear()
        for window in event["WindowsChanged"].get("windows", []):
            handle_window(window, known_windows, protected_patterns)
        return protected_patterns

    if "WindowClosed" in event:
        window_id = event["WindowClosed"].get("id")
        if window_id is not None:
            known_windows.pop(window_id, None)
        return protected_patterns

    if "WindowOpenedOrChanged" in event:
        window = event["WindowOpenedOrChanged"].get("window") or {}
        handle_window(window, known_windows, protected_patterns)
        return protected_patterns

    if "ConfigLoaded" in event:
        return get_protected_app_patterns()

    return protected_patterns


def listen_for_events():
    known_windows = {}
    protected_patterns = get_protected_app_patterns()

    while True:
        try:
            process = subprocess.Popen(
                ["niri", "msg", "-j", "event-stream"],
                stdout=subprocess.PIPE,
                text=True,
            )
        except OSError as error:
            print(f"Unable to start Niri event stream: {error}", flush=True)
            time.sleep(1)
            continue

        if process.stdout is not None:
            for line in process.stdout:
                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    continue
                protected_patterns = process_event(event, known_windows, protected_patterns)

        process.wait()
        known_windows.clear()
        reset_floating_state()
        time.sleep(1)


def main():
    singleton_lock = acquire_singleton_lock()
    if singleton_lock is None:
        return

    reset_floating_state()
    print("Listening for Niri floating workspace events", flush=True)
    listen_for_events()


if __name__ == "__main__":
    main()
