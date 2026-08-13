#!/usr/bin/env python3
"""Persist newly detected Niri outputs using stable hardware identities."""

import argparse
import json
import os
import re
import tempfile


def clean_part(value):
    return " ".join(str(value or "").split())


def hardware_id(output):
    make = clean_part(output.get("make"))
    model = clean_part(output.get("model"))
    connector = clean_part(output.get("name"))
    if not make or not model:
        return connector
    serial = clean_part(output.get("serial")) or "Unknown"
    identity = " ".join(part for part in (make, model, serial) if part)
    return identity or connector


def output_id_map(outputs):
    candidates = [hardware_id(output) for output in outputs]
    counts = {candidate: candidates.count(candidate) for candidate in set(candidates)}
    result = {}
    for output, candidate in zip(outputs, candidates):
        connector = clean_part(output.get("name"))
        result[connector] = connector if not candidate or counts[candidate] > 1 else candidate
    return result


def best_mode(output):
    modes = output.get("modes") or []
    if not modes:
        return "1920x1080@60.000"
    mode = max(
        modes,
        key=lambda item: (
            int(item.get("width") or 0) * int(item.get("height") or 0),
            int(item.get("refresh_rate") or 0),
            bool(item.get("is_preferred")),
        ),
    )
    return format_mode(mode)


def current_mode(output):
    modes = output.get("modes") or []
    selected = output.get("current_mode")
    if isinstance(selected, int) and not isinstance(selected, bool):
        if 0 <= selected < len(modes):
            return format_mode(modes[selected])
    elif isinstance(selected, dict):
        return format_mode(selected)
    return best_mode(output)


def format_mode(mode):
    refresh = int(mode.get("refresh_rate") or 60000) / 1000
    return f'{int(mode.get("width") or 1920)}x{int(mode.get("height") or 1080)}@{refresh:.3f}'


def escape_kdl(value):
    return str(value).replace("\\", "\\\\").replace('"', '\\"')


def active_output_exists(content, name):
    pattern = rf'^\s*output\s+"{re.escape(name)}"\s*\{{'
    return re.search(pattern, content, re.MULTILINE) is not None


def disable_connector_block(content, connector):
    pattern = rf'^(\s*)output\s+"{re.escape(connector)}"\s*\{{'
    replacement = rf'\1/-output "{escape_kdl(connector)}" {{'
    return re.subn(pattern, replacement, content, count=1, flags=re.MULTILINE)


def output_block(identity, output, fallback_x):
    logical = output.get("logical") or {}
    x = int(logical.get("x") if logical.get("x") is not None else fallback_x)
    y = int(logical.get("y") or 0)
    scale = float(logical.get("scale") or 1.0)
    transform = clean_part(logical.get("transform")).lower() or "normal"
    return (
        f'output "{escape_kdl(identity)}" {{\n'
        f'    mode "{current_mode(output)}"\n'
        f'    scale {scale:g}\n'
        f'    transform "{escape_kdl(transform)}"\n'
        f'    position x={x} y={y}\n'
        '    // variable-refresh-rate on-demand=true\n'
        '    // focus-at-startup\n'
        '}\n'
    )


def write_atomic(path, content):
    directory = os.path.dirname(path) or "."
    os.makedirs(directory, exist_ok=True)
    try:
        current_mode = os.stat(path).st_mode & 0o777
    except OSError:
        current_mode = 0o644
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=directory, delete=False) as handle:
        handle.write(content)
        temp_path = handle.name
    os.chmod(temp_path, current_mode)
    os.replace(temp_path, path)


def sync_outputs(config_path, outputs):
    try:
        with open(config_path, encoding="utf-8") as handle:
            content = handle.read()
    except OSError:
        content = ""

    identities = output_id_map(outputs)
    changed = False
    created = []
    active_right = max(
        (
            int((output.get("logical") or {}).get("x") or 0)
            + int((output.get("logical") or {}).get("width") or 0)
            for output in outputs
            if output.get("logical")
        ),
        default=0,
    )

    for output in outputs:
        connector = clean_part(output.get("name"))
        identity = identities.get(connector, connector)
        if not connector or not identity:
            continue

        if identity != connector:
            content, substitutions = disable_connector_block(content, connector)
            changed = changed or substitutions > 0

        if active_output_exists(content, identity):
            continue

        content = content.rstrip() + "\n\n" + output_block(identity, output, active_right)
        created.append(identity)
        changed = True

    if changed:
        write_atomic(config_path, content.rstrip() + "\n")

    return {"changed": changed, "created": created, "identities": identities}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("config")
    parser.add_argument("outputs_json")
    args = parser.parse_args()
    try:
        outputs = json.loads(args.outputs_json)
        if not isinstance(outputs, list):
            raise ValueError("outputs payload must be a list")
        print(json.dumps(sync_outputs(args.config, outputs)))
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(json.dumps({"changed": False, "error": str(error)}))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
