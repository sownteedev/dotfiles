#!/usr/bin/env python3
"""Read and update supported V4L2 camera controls for SownteeShell."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path


CONTROL_RE = re.compile(
    r"^\s*(?P<name>[A-Za-z0-9_]+)\s+0x[0-9a-f]+\s+"
    r"\((?P<kind>int|int64|bool|menu|bitmask|rect|string)\)\s*:"
    r"\s*(?P<details>.*)$"
)
NUMBER_RE = re.compile(r"(?P<key>min|max|step|default|value)=(?P<value>-?0x[0-9a-fA-F]+|-?[0-9]+)")
MENU_RE = re.compile(r"^\s*(?P<value>[0-9]+):\s+(?P<label>.*)$")


class CameraError(RuntimeError):
    pass


def run_v4l2(device: str, *arguments: str) -> str:
    command = ["/usr/bin/v4l2-ctl", "-d", device, *arguments]
    result = subprocess.run(command, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or "v4l2-ctl failed"
        raise CameraError(message)
    return result.stdout


def parse_number(value: str) -> int:
    return int(value, 0)


def parse_controls(output: str) -> list[dict[str, object]]:
    controls: list[dict[str, object]] = []
    current: dict[str, object] | None = None

    for line in output.splitlines():
        match = CONTROL_RE.match(line)
        if match:
            details = match.group("details")
            control: dict[str, object] = {
                "name": match.group("name"),
                "kind": match.group("kind"),
                "inactive": "inactive" in details,
                "disabled": "disabled" in details,
                "options": [],
            }
            for number in NUMBER_RE.finditer(details):
                control[number.group("key")] = parse_number(number.group("value"))
            value_match = re.search(r"value=(?:0x[0-9a-fA-F]+|[-0-9]+)(?:\s+\((?P<label>[^)]*)\))?", details)
            if value_match and value_match.group("label"):
                control["valueLabel"] = value_match.group("label")
            controls.append(control)
            current = control
            continue

        if current is not None and current["kind"] == "menu":
            menu_match = MENU_RE.match(line)
            if menu_match:
                options = current["options"]
                assert isinstance(options, list)
                options.append({
                    "value": int(menu_match.group("value")),
                    "label": menu_match.group("label").strip(),
                })

    supported: list[dict[str, object]] = []
    for control in controls:
        if control["kind"] not in {"int", "int64", "bool", "menu"}:
            continue
        if "value" not in control:
            continue
        if control["kind"] in {"int", "int64"} and not all(key in control for key in ("min", "max", "step", "default")):
            continue
        if control["kind"] == "menu" and not control.get("options"):
            continue
        supported.append(control)
    return supported


def list_controls(device: str) -> list[dict[str, object]]:
    return parse_controls(run_v4l2(device, "--list-ctrls-menus"))


def cache_root() -> Path:
    cache_home = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache")
    path = Path(cache_home) / "sownteeshell" / "camera-controls"
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    return path


def profile_path(device: str) -> Path:
    identity = os.path.realpath(device)
    digest = hashlib.sha256(identity.encode("utf-8")).hexdigest()[:20]
    return cache_root() / f"{digest}.json"


def writable_controls(controls: list[dict[str, object]]) -> list[dict[str, object]]:
    return [control for control in controls if not control.get("inactive") and not control.get("disabled")]


def apply_values(device: str, values: dict[str, object], controls: list[dict[str, object]]) -> None:
    available = {str(control["name"]): control for control in writable_controls(controls)}
    for name, value in values.items():
        control = available.get(str(name))
        if control is None:
            continue
        if control["kind"] == "bool":
            value = 1 if bool(value) else 0
        run_v4l2(device, f"--set-ctrl={name}={value}")


def result(device: str, controls: list[dict[str, object]], message: str = "") -> dict[str, object]:
    profile = profile_path(device)
    return {
        "ok": True,
        "device": device,
        "controls": controls,
        "saved": profile.exists(),
        "message": message,
    }


def handle(args: argparse.Namespace) -> dict[str, object]:
    controls = list_controls(args.device)
    if args.action == "list":
        return result(args.device, controls)

    if args.action == "set":
        names = {str(control["name"]): control for control in writable_controls(controls)}
        control = names.get(args.name)
        if control is None:
            raise CameraError(f"Control is unavailable or read-only: {args.name}")
        value: object = int(args.value, 0)
        if control["kind"] == "bool":
            value = 1 if value else 0
        run_v4l2(args.device, f"--set-ctrl={args.name}={value}")
        return result(args.device, list_controls(args.device), f"Updated {args.name}")

    if args.action == "reset":
        values = {
            str(control["name"]): control["default"]
            for control in writable_controls(controls)
            if "default" in control
        }
        apply_values(args.device, values, controls)
        return result(args.device, list_controls(args.device), "Reset supported controls to driver defaults")

    if args.action == "set-values":
        values_json = args.values_json or args.name
        if values_json is None:
            raise CameraError("Camera settings snapshot is required")
        try:
            values = json.loads(values_json)
        except json.JSONDecodeError as error:
            raise CameraError(f"Invalid camera settings snapshot: {error}") from error
        if not isinstance(values, dict):
            raise CameraError("Camera settings snapshot must be an object")
        apply_values(args.device, values, controls)
        return result(args.device, list_controls(args.device), "Restored camera settings")

    profile = profile_path(args.device)
    if args.action == "save":
        values = {
            str(control["name"]): control["value"]
            for control in writable_controls(controls)
            if "value" in control
        }
        profile.write_text(json.dumps({"device": os.path.realpath(args.device), "values": values}, indent=2) + "\n", encoding="utf-8")
        return result(args.device, controls, "Saved camera profile")

    if args.action == "apply":
        if not profile.exists():
            raise CameraError("No saved profile exists for this camera")
        try:
            saved = json.loads(profile.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as error:
            raise CameraError(f"Could not read saved camera profile: {error}") from error
        apply_values(args.device, saved.get("values", {}), controls)
        return result(args.device, list_controls(args.device), "Applied saved camera profile")

    raise CameraError(f"Unknown action: {args.action}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("action", choices=("list", "set", "reset", "set-values", "save", "apply"))
    parser.add_argument("device")
    parser.add_argument("name", nargs="?")
    parser.add_argument("value", nargs="?")
    parser.add_argument("values_json", nargs="?")
    args = parser.parse_args()
    if args.action == "set" and (args.name is None or args.value is None):
        parser.error("set requires a control name and value")
    if args.action == "set-values" and args.name is None and args.values_json is None:
        parser.error("set-values requires a JSON object")
    try:
        print(json.dumps(handle(args), ensure_ascii=False))
        return 0
    except (CameraError, OSError) as error:
        print(json.dumps({"ok": False, "message": str(error)}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    sys.exit(main())
