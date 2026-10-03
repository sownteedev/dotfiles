#!/usr/bin/env python3

import fcntl
import json
import os
import re
import subprocess
import sys
import time


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = os.path.join(SCRIPT_DIR, "..", "include", "window-rules.kdl")
RUNTIME_DIR = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
STATE_FILE = os.path.join(RUNTIME_DIR, "niri-floating-workspaces.json")
STATE_LOCK_FILE = f"{STATE_FILE}.lock"
LOCK_FILE = os.path.join(RUNTIME_DIR, "niri-floating-daemon.lock")
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


def clean_kdl_str(s):
    s = s.strip()
    if s.startswith("r"):
        m = re.match(r'^r#*"(.*)"#*$', s)
        if m:
            return m.group(1)
    if s.startswith('"') and s.endswith('"'):
        return s[1:-1]
    return s


def get_protected_rules(config_file=CONFIG_FILE):
    if not os.path.isfile(config_file):
        return []

    try:
        with open(config_file, "r", encoding="utf-8") as file:
            text = file.read()
    except OSError as error:
        print(f"Unable to read window rules: {error}", flush=True)
        return []

    rules = []
    lines = text.splitlines()
    in_rule = False
    current_rule = {}
    has_open_floating = False
    depth = 0
    attr_pattern = re.compile(r'(app-id|title)\s*=\s*(r#*".*?"#*|".*?"|\S+)')

    for line in lines:
        stripped = line.strip()
        if not in_rule:
            if re.match(r"^/-[ \t]*window-rule", stripped) or stripped.startswith("//"):
                continue
            if re.match(r"^window-rule[ \t]*\{", stripped):
                in_rule = True
                depth = 1
                has_open_floating = "open-floating true" in stripped
                current_rule = {"app_id": None, "title": None}
                for key, val in attr_pattern.findall(stripped):
                    if key == "app-id":
                        current_rule["app_id"] = clean_kdl_str(val)
                    elif key == "title":
                        current_rule["title"] = clean_kdl_str(val)
                continue
        else:
            if stripped.startswith("//"):
                continue
            if "open-floating true" in stripped and "managed-by-toggle-floating-workspace" not in stripped:
                has_open_floating = True
            for key, val in attr_pattern.findall(stripped):
                if key == "app-id":
                    current_rule["app_id"] = clean_kdl_str(val)
                elif key == "title":
                    current_rule["title"] = clean_kdl_str(val)

            depth += stripped.count("{") - stripped.count("}")
            if depth <= 0:
                if has_open_floating and (current_rule["app_id"] or current_rule["title"]):
                    rules.append(current_rule)
                in_rule = False
                depth = 0
                current_rule = {}
                has_open_floating = False

    compiled = []
    for r in rules:
        try:
            compiled.append({
                "app_id": re.compile(r["app_id"]) if r["app_id"] else None,
                "title": re.compile(r["title"]) if r["title"] else None,
                "raw_app_id": r["app_id"],
                "raw_title": r["title"]
            })
        except re.error as error:
            print(f"Ignoring invalid window rule pattern {r}: {error}", flush=True)

    return compiled


def is_protected_window(window, protected_rules):
    app_id = window.get("app_id") or ""
    title = window.get("title") or ""
    for r in protected_rules:
        app_match = True if r["app_id"] is None else bool(r["app_id"].search(app_id))
        title_match = True if r["title"] is None else bool(r["title"].search(title))
        if app_match and title_match:
            return True
    return False


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


def handle_window(window, known_windows, protected_rules):
    window_id = window.get("id")
    workspace_id = window.get("workspace_id")
    is_floating = window.get("is_floating", False)
    if window_id is None or workspace_id is None:
        return

    previous_workspace_id = known_windows.get(window_id)
    known_windows[window_id] = workspace_id

    # If the window is defined as open-floating in window-rules.kdl,
    # never alter its floating state (keep it floating across all workspaces).
    if is_protected_window(window, protected_rules):
        return

    is_new_window = previous_workspace_id is None
    is_moved_window = previous_workspace_id is not None and previous_workspace_id != workspace_id
    if not is_new_window and not is_moved_window:
        return

    floating_workspaces = get_floating_workspaces()
    workspace_is_floating = workspace_id in floating_workspaces
    previous_workspace_was_floating = (
        previous_workspace_id is not None and previous_workspace_id in floating_workspaces
    )

    if workspace_is_floating and not is_floating:
        time.sleep(0.08)
        if set_window_floating(window_id, True):
            arrange_workspace(workspace_id, window_id)
    elif not workspace_is_floating and is_floating and is_moved_window and previous_workspace_was_floating:
        # Only un-float if it was floating because the previous workspace was a floating workspace
        time.sleep(0.08)
        set_window_floating(window_id, False)


def process_event(event, known_windows, protected_rules):
    if "WindowsChanged" in event:
        current_ids = set()
        for window in event["WindowsChanged"].get("windows", []):
            wid = window.get("id")
            if wid is not None:
                current_ids.add(wid)
            handle_window(window, known_windows, protected_rules)
        for wid in list(known_windows.keys()):
            if wid not in current_ids:
                del known_windows[wid]
        return protected_rules

    if "WindowClosed" in event:
        window_id = event["WindowClosed"].get("id")
        if window_id is not None:
            known_windows.pop(window_id, None)
        return protected_rules

    if "WindowOpenedOrChanged" in event:
        window = event["WindowOpenedOrChanged"].get("window") or {}
        handle_window(window, known_windows, protected_rules)
        return protected_rules

    if "ConfigLoaded" in event:
        return get_protected_rules()

    return protected_rules


def listen_for_events():
    known_windows = {}
    protected_rules = get_protected_rules()

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
                protected_rules = process_event(event, known_windows, protected_rules)

        process.wait()
        known_windows.clear()
        reset_floating_state()
        time.sleep(1)


def main():
    if len(sys.argv) > 1:
        arg = sys.argv[1]
        if arg in ("--get-protected", "--get-protected-patterns"):
            rules = get_protected_rules()
            patterns = set()
            for r in rules:
                if r["raw_app_id"]:
                    patterns.add(r["raw_app_id"])
            for p in sorted(patterns):
                print(p)
            return

        if arg == "--filter-toggleable":
            rules = get_protected_rules()
            try:
                data = json.load(sys.stdin)
            except Exception:
                return
            for win in data:
                if not win.get("id"):
                    continue
                if is_protected_window(win, rules):
                    continue
                print(f"{win['id']}\t{str(win.get('is_floating', False)).lower()}")
            return

        if arg == "--is-protected":
            app_id = sys.argv[2] if len(sys.argv) > 2 else ""
            title = sys.argv[3] if len(sys.argv) > 3 else ""
            rules = get_protected_rules()
            sys.exit(0 if is_protected_window({"app_id": app_id, "title": title}, rules) else 1)

    singleton_lock = acquire_singleton_lock()
    if singleton_lock is None:
        return

    reset_floating_state()
    print("Listening for Niri floating workspace events", flush=True)
    listen_for_events()


if __name__ == "__main__":
    main()
