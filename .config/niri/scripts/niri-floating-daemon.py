#!/usr/bin/env python3
import json
import subprocess
import os
import time

STATE_FILE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "niri-floating-workspaces.json")
TOGGLE_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "toogle-floating-workspace")

def get_protected_app_ids():
    try:
        result = subprocess.run([TOGGLE_SCRIPT, "--get-protected"], capture_output=True, text=True)
        return set(line.strip() for line in result.stdout.split('\n') if line.strip())
    except Exception as e:
        print(f"Error getting protected apps: {e}")
        return set()

def get_floating_workspaces():
    if not os.path.exists(STATE_FILE):
        return set()
    try:
        with open(STATE_FILE, 'r') as f:
            data = json.load(f)
            return {int(k) for k, v in data.items() if v}
    except Exception:
        return set()

def set_window_floating(window_id, to_floating=True):
    try:
        action = "move-window-to-floating" if to_floating else "move-window-to-tiling"
        res = subprocess.run(["niri", "msg", "action", action, "--id", str(window_id)], capture_output=True, text=True)
        if res.returncode != 0:
            print(f"Failed to set window {window_id} to floating={to_floating}: {res.stderr}")
        if not to_floating:
            subprocess.run(["niri", "msg", "action", "focus-window", "--id", str(window_id)], capture_output=True)
            subprocess.run(["niri", "msg", "action", "set-column-width", "100%"], capture_output=True)
    except Exception as e:
        print(f"Exception in set_window_floating: {e}")

def main():
    protected_apps = get_protected_app_ids()
    print(f"Protected apps: {protected_apps}")
    print("Listening for niri events...")

    # Start niri event stream
    process = subprocess.Popen(
        ["niri", "msg", "-j", "event-stream"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    known_windows = {}

    while True:
        line = process.stdout.readline()
        if not line:
            break

        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue

        if "WindowClosed" in event:
            window_id = event["WindowClosed"].get("window", {}).get("id")
            if window_id is not None and window_id in known_windows:
                del known_windows[window_id]
            continue

        # We care about WindowOpenedOrChanged
        if "WindowOpenedOrChanged" in event:
            window = event["WindowOpenedOrChanged"]["window"]
            window_id = window.get("id")
            app_id = window.get("app_id")
            workspace_id = window.get("workspace_id")
            is_floating = window.get("is_floating", False)

            if window_id is None or workspace_id is None:
                continue

            prev_workspace_id = known_windows.get(window_id)
            known_windows[window_id] = workspace_id

            if app_id in protected_apps:
                continue

            is_new_window = (prev_workspace_id is None)
            is_moved_window = (prev_workspace_id is not None and prev_workspace_id != workspace_id)

            if is_new_window or is_moved_window:
                floating_workspaces = get_floating_workspaces()
                is_workspace_floating = workspace_id in floating_workspaces

                if is_workspace_floating and not is_floating:
                    print(f"Window {window_id} ({app_id}) moved to floating workspace {workspace_id}. Setting to floating.")
                    time.sleep(0.1)
                    set_window_floating(window_id, to_floating=True)
                    subprocess.run(["python3", os.path.join(os.path.dirname(os.path.abspath(__file__)), "niri-auto-arrange.py")])
                elif not is_workspace_floating and is_floating:
                    if is_moved_window:
                        print(f"Window {window_id} ({app_id}) moved to tiled workspace {workspace_id}. Setting to tiled.")
                        time.sleep(0.1)
                        set_window_floating(window_id, to_floating=False)
                    else:
                        print(f"Window {window_id} ({app_id}) opened natively floating in tiled workspace. Keeping it floating.")

if __name__ == "__main__":
    main()
