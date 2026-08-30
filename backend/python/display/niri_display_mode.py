#!/usr/bin/env python3
"""Apply internal, external, or extended display modes through Niri IPC."""

import json
import subprocess
import sys


def run_niri(*arguments):
    result = subprocess.run(
        ["niri", "msg", *arguments],
        capture_output=True,
        check=False,
        text=True,
    )
    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or "niri IPC failed"
        raise RuntimeError(message)
    return result.stdout


def output_names():
    outputs = json.loads(run_niri("-j", "outputs"))
    return [str(output.get("name") or key) for key, output in outputs.items()]


def set_output(name, enabled):
    run_niri("output", name, "on" if enabled else "off")


def is_internal_output(name):
    return name.startswith(("eDP-", "LVDS-", "DSI-"))


def apply_mode(mode, preferred_external=""):
    names = output_names()
    internal = [name for name in names if is_internal_output(name)]
    external = [name for name in names if name not in internal]

    if mode == "internal":
        if not internal:
            raise RuntimeError("No internal display is connected")
        target = internal[0]
        set_output(target, True)
        for name in names:
            if name != target:
                set_output(name, False)
        return target

    if mode == "extend":
        if not internal or not external:
            raise RuntimeError("Extend requires an internal and an external display")
        for name in names:
            set_output(name, True)
        return preferred_external if preferred_external in external else external[0]

    if mode == "external":
        if not external:
            raise RuntimeError("No external display is connected")
        target = preferred_external if preferred_external in external else external[0]
        # Make sure the destination is alive before disabling every fallback.
        set_output(target, True)
        for name in names:
            if name != target:
                set_output(name, False)
        return target

    raise RuntimeError("Duplicate is not supported natively by Niri")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    preferred_external = sys.argv[2] if len(sys.argv) > 2 else ""
    try:
        target = apply_mode(mode, preferred_external)
        print(json.dumps({"mode": mode, "target": target}))
    except (json.JSONDecodeError, OSError, RuntimeError) as error:
        print(json.dumps({"error": str(error)}))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
