#!/usr/bin/env python3
"""Read and set external monitor brightness through DDC/CI."""

import argparse
import glob
import json
import os
import re
import shutil
import subprocess


def connector_path(connector):
    matches = sorted(glob.glob(f"/sys/class/drm/card*-{connector}"))
    return matches[0] if matches else ""


def connector_bus(connector):
    path = connector_path(connector)
    if not path:
        return None

    candidates = glob.glob(os.path.join(path, "ddc", "i2c-dev", "i2c-*"))
    candidates += glob.glob(os.path.join(path, "i2c-*"))
    for candidate in candidates:
        match = re.search(r"i2c-(\d+)$", candidate)
        if match:
            return int(match.group(1))

    ddc_path = os.path.realpath(os.path.join(path, "ddc"))
    match = re.search(r"i2c-(\d+)(?:/|$)", ddc_path)
    return int(match.group(1)) if match else None


def run_ddc(bus, *arguments):
    result = subprocess.run(
        ["ddcutil", "--bus", str(bus), *arguments],
        capture_output=True,
        check=False,
        text=True,
        timeout=6,
    )
    if result.returncode != 0:
        message = result.stderr.strip() or result.stdout.strip() or "ddcutil failed"
        raise RuntimeError(message.splitlines()[-1])
    return result.stdout


def parse_brightness(output):
    patterns = (
        r"current value\s*=\s*(\d+)\s*,\s*max value\s*=\s*(\d+)",
        r"VCP\s+(?:code\s+)?(?:0x)?10\s+C\s+(\d+)\s+(\d+)",
    )
    for pattern in patterns:
        match = re.search(pattern, output, re.IGNORECASE)
        if match:
            return int(match.group(1)), max(1, int(match.group(2)))
    raise RuntimeError("Could not parse DDC brightness response")


def response(connector, **values):
    result = {"output": connector}
    result.update(values)
    return result


def get_brightness(connector):
    if not shutil.which("ddcutil"):
        return response(connector, available=False, error="Install ddcutil to control this display")
    bus = connector_bus(connector)
    if bus is None:
        return response(connector, available=False, error="This display connection does not expose DDC/CI")
    current, maximum = parse_brightness(run_ddc(bus, "getvcp", "10", "--brief"))
    return response(
        connector,
        available=True,
        backend="ddcutil",
        bus=bus,
        current=current,
        maximum=maximum,
        value=current / maximum,
    )


def set_brightness(connector, value, bus=None, maximum=None):
    if bus is None or maximum is None:
        current = get_brightness(connector)
        if not current.get("available"):
            return current
        bus = int(current["bus"])
        maximum = int(current["maximum"])
    else:
        current = response(
            connector,
            available=True,
            backend="ddcutil",
            bus=bus,
            maximum=maximum,
        )
    target = max(0, min(maximum, round(float(value) * maximum)))
    run_ddc(bus, "setvcp", "10", str(target))
    current.update(current=target, value=target / maximum)
    return current


def main():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="action", required=True)
    get_parser = subparsers.add_parser("get")
    get_parser.add_argument("output")
    set_parser = subparsers.add_parser("set")
    set_parser.add_argument("output")
    set_parser.add_argument("value", type=float)
    set_parser.add_argument("bus", type=int, nargs="?")
    set_parser.add_argument("maximum", type=int, nargs="?")
    args = parser.parse_args()

    try:
        result = get_brightness(args.output) if args.action == "get" else set_brightness(args.output, args.value, args.bus, args.maximum)
        print(json.dumps(result))
        return 0 if result.get("available") else 2
    except (OSError, RuntimeError, subprocess.TimeoutExpired, ValueError) as error:
        print(json.dumps(response(args.output, available=False, error=str(error))))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
