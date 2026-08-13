#!/usr/bin/env python3
"""Switch Sunshine's display and encoder to the GPU owning a DRM connector."""

import argparse
import glob
import json
import os
import re
import subprocess
import tempfile
import time


INTEL_VENDOR = "0x8086"
AMD_VENDOR = "0x1002"
NVIDIA_VENDOR = "0x10de"
SUNSHINE_UNITS = (
    "app-dev.lizardbyte.app.Sunshine.service",
    "sunshine.service",
)


def connector_card(connector):
    matches = sorted(glob.glob(f"/sys/class/drm/card*-{connector}"))
    if not matches:
        raise RuntimeError(f"DRM connector not found: {connector}")
    match = re.match(r"(card\d+)-", os.path.basename(matches[0]))
    if not match:
        raise RuntimeError(f"Could not resolve the DRM card for {connector}")
    return match.group(1)


def read_text(path):
    with open(path, encoding="utf-8") as handle:
        return handle.read().strip()


def read_config(path):
    try:
        content = read_text(path)
    except OSError:
        return {}
    values = {}
    for line in content.splitlines():
        match = re.match(r"^\s*([A-Za-z0-9_]+)\s*=\s*(.*?)\s*$", line)
        if match:
            values[match.group(1)] = match.group(2).strip().strip('"')
    return values


def render_node(card):
    candidates = sorted(glob.glob(f"/sys/class/drm/{card}/device/drm/renderD*"))
    if not candidates:
        raise RuntimeError(f"No render node is available for {card}")
    return "/dev/dri/" + os.path.basename(candidates[0])


def profile_for_output(connector):
    card = connector_card(connector)
    vendor = read_text(f"/sys/class/drm/{card}/device/vendor").lower()
    if vendor == INTEL_VENDOR:
        encoder = "vaapi"
        label = "Intel VA-API"
    elif vendor == NVIDIA_VENDOR:
        encoder = "nvenc"
        label = "NVIDIA NVENC"
    else:
        raise RuntimeError(f"Unsupported GPU vendor for {connector}: {vendor}")
    return {
        "adapter_name": render_node(card),
        "card": card,
        "encoder": encoder,
        "label": label,
        "vendor": vendor,
    }


def encoder_label(encoder, adapter_name):
    cleaned = str(encoder or "").lower()
    if cleaned == "nvenc":
        return "NVIDIA NVENC"
    if cleaned == "vaapi":
        render_node_name = os.path.basename(str(adapter_name or ""))
        vendor_path = f"/sys/class/drm/{render_node_name}/device/vendor"
        try:
            vendor = read_text(vendor_path).lower()
        except OSError:
            vendor = ""
        if vendor == INTEL_VENDOR:
            return "Intel VA-API"
        if vendor == AMD_VENDOR:
            return "AMD VA-API"
        return "VA-API"
    return cleaned.upper() if cleaned else "Sunshine"


def update_config(path, values):
    try:
        content = read_text(path)
    except OSError:
        content = ""
    lines = content.splitlines()
    remaining = dict(values)
    updated = []
    for line in lines:
        match = re.match(r"^\s*([A-Za-z0-9_]+)\s*=", line)
        key = match.group(1) if match else ""
        if key in remaining:
            updated.append(f"{key} = {remaining.pop(key)}")
        else:
            updated.append(line)
    for key, value in remaining.items():
        updated.append(f"{key} = {value}")

    next_content = "\n".join(updated).strip() + "\n"
    if next_content == content.strip() + ("\n" if content.strip() else ""):
        return False
    directory = os.path.dirname(path) or "."
    os.makedirs(directory, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=directory, delete=False) as handle:
        handle.write(next_content)
        temp_path = handle.name
    os.replace(temp_path, path)
    return True


def restart_sunshine():
    errors = []
    for unit in SUNSHINE_UNITS:
        result = subprocess.run(
            ["systemctl", "--user", "restart", unit],
            capture_output=True,
            check=False,
            text=True,
        )
        if result.returncode == 0:
            return unit
        errors.append(result.stderr.strip() or result.stdout.strip())
    raise RuntimeError(next((error for error in errors if error), "Could not restart Sunshine"))


def active_sunshine_units():
    active = []
    for unit in SUNSHINE_UNITS:
        result = subprocess.run(
            ["systemctl", "--user", "is-active", "--quiet", unit],
            capture_output=True,
            check=False,
            text=True,
        )
        if result.returncode == 0:
            active.append(unit)
    return active or list(SUNSHINE_UNITS)


def output_from_journal(unit, display_id):
    result = subprocess.run(
        [
            "journalctl",
            "--user",
            "-u",
            unit,
            "--grep",
            r"Monitor [0-9]+ is ",
            "-n",
            "100",
            "--no-pager",
            "-o",
            "cat",
        ],
        capture_output=True,
        check=False,
        text=True,
    )
    if result.returncode != 0:
        return None
    pattern = re.compile(r"Monitor\s+(\d+)\s+is\s+([^:]+):")
    for detected_id, output_name in reversed(pattern.findall(result.stdout)):
        if int(detected_id) == display_id:
            return output_name.strip()
    return None


def current_status(path):
    config = read_config(path)
    encoder = config.get("encoder", "")
    adapter_name = config.get("adapter_name", "")
    raw_display_id = config.get("output_name", "")
    if not encoder or raw_display_id == "":
        return {"configured": False}
    try:
        display_id = int(raw_display_id)
    except ValueError as error:
        raise RuntimeError(f"Invalid Sunshine output_name: {raw_display_id}") from error

    output = ""
    service = ""
    for unit in active_sunshine_units():
        detected_output = output_from_journal(unit, display_id)
        if detected_output:
            output = detected_output
            service = unit
            break
    return {
        "adapter_name": adapter_name,
        "configured": True,
        "display_id": display_id,
        "encoder": encoder,
        "label": encoder_label(encoder, adapter_name),
        "output": output,
        "service": service,
    }


def monitor_id_from_journal(unit, connector, since_epoch, timeout=4.0):
    deadline = time.monotonic() + timeout
    pattern = re.compile(r"Monitor\s+(\d+)\s+is\s+([^:]+):")
    while time.monotonic() < deadline:
        result = subprocess.run(
            [
                "journalctl",
                "--user",
                "-u",
                unit,
                f"--since=@{since_epoch}",
                "--no-pager",
                "-o",
                "cat",
            ],
            capture_output=True,
            check=False,
            text=True,
        )
        if result.returncode == 0:
            matches = pattern.findall(result.stdout)
            for display_id, output_name in reversed(matches):
                if output_name.strip() == connector:
                    return int(display_id)
        time.sleep(0.15)
    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--status", action="store_true")
    parser.add_argument("config")
    parser.add_argument("output", nargs="?")
    parser.add_argument("display_id", nargs="?", type=int)
    args = parser.parse_args()
    try:
        if args.status:
            print(json.dumps(current_status(args.config)))
            return 0
        if args.output is None or args.display_id is None:
            parser.error("output and display_id are required unless --status is used")
        profile = profile_for_output(args.output)
        display_id = max(0, args.display_id)
        changed = update_config(
            args.config,
            {
                "adapter_name": profile["adapter_name"],
                "encoder": profile["encoder"],
                "output_name": str(display_id),
            },
        )
        restart_started = int(time.time()) - 1
        unit = restart_sunshine()
        detected_id = monitor_id_from_journal(unit, args.output, restart_started)
        if detected_id is not None and detected_id != display_id:
            display_id = detected_id
            changed = update_config(args.config, {"output_name": str(display_id)}) or changed
            unit = restart_sunshine()
        profile.update(
            changed=changed,
            display_id=display_id,
            display_verified=detected_id is not None,
            output=args.output,
            service=unit,
        )
        print(json.dumps(profile))
    except (OSError, RuntimeError, ValueError) as error:
        print(json.dumps({"error": str(error), "output": args.output}))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
