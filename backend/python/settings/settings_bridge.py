#!/usr/bin/env python3
"""Small, on-demand bridge between the Settings Hub and text configs.

The script has no daemon mode: Quickshell starts it only when the hub opens or
when a value is saved.  Writes are atomic and Niri changes are validated before
the live configuration is reloaded.
"""

from __future__ import annotations

import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


QUICKSHELL_DIR = Path(__file__).resolve().parents[3]
DOTFILES_DIR = QUICKSHELL_DIR.parent
DOTF_DIR = DOTFILES_DIR / "dotf"
NIRI_DIR = DOTF_DIR / ".config" / "niri"
INCLUDE_DIR = NIRI_DIR / "include"
CONFIG_QML = QUICKSHELL_DIR / "Config.qml"
RUNTIME_SETTINGS_PATH = (
    Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    / "quickshell"
    / "settings.json"
)


ACTION_NAMES = {
    "show-hotkey-overlay": "Show Niri hotkey overlay",
    "focus-column-left": "Focus column left",
    "focus-column-right": "Focus column right",
    "focus-window-up": "Focus window above",
    "focus-window-down": "Focus window below",
    "move-column-left": "Move column left",
    "move-column-right": "Move column right",
    "move-window-up": "Move window up",
    "move-window-down": "Move window down",
    "focus-window-or-workspace-down": "Focus window or workspace below",
    "focus-window-or-workspace-up": "Focus window or workspace above",
    "move-window-down-or-to-workspace-down": "Move window or workspace down",
    "move-window-up-or-to-workspace-up": "Move window or workspace up",
    "toggle-column-tabbed-display": "Toggle tabbed columns",
    "focus-monitor-left": "Focus monitor left",
    "focus-monitor-right": "Focus monitor right",
    "focus-monitor-up": "Focus monitor above",
    "focus-monitor-down": "Focus monitor below",
    "move-column-to-monitor-left": "Move column to monitor left",
    "move-column-to-monitor-right": "Move column to monitor right",
    "move-column-to-monitor-up": "Move column to monitor above",
    "move-column-to-monitor-down": "Move column to monitor below",
    "toggle-overview": "Toggle overview",
    "focus-workspace-previous": "Focus previous workspace",
    "move-workspace-up": "Move workspace up",
    "move-workspace-down": "Move workspace down",
    "maximize-window-to-edges": "Maximize window",
    "fullscreen-window": "Toggle fullscreen",
    "toggle-window-floating": "Toggle window floating",
    "switch-focus-between-floating-and-tiling": "Switch floating / tiled focus",
    "center-column": "Center focused column",
    "center-visible-columns": "Center visible columns",
    "quit": "Exit Niri",
}

ANIMATION_NAMES = (
    "workspace-switch",
    "window-open",
    "window-close",
    "horizontal-view-movement",
    "window-movement",
    "window-resize",
    "config-notification-open-close",
    "exit-confirmation-open-close",
    "screenshot-ui-open",
    "overview-open-close",
    "recent-windows-close",
)

EDITABLE_NIRI_FILES = {
    "autostart.kdl",
    "environment.kdl",
    "layer-rules.kdl",
    "window-rules.kdl",
    "workspaces.kdl",
}

INPUT_SECTION_NAMES = {
    "Keyboard": "keyboard",
    "Touchpad": "touchpad",
    "Mouse": "mouse",
    "Trackpoint": "trackpoint",
    "Trackball": "trackball",
    "Tablet": "tablet",
    "Touch": "touch",
}


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def atomic_write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o644
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        os.fchmod(fd, mode)
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(text)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp_name, path)
    finally:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)


def apply_niri_changes(
    updates: dict[Path, str], success_message: str
) -> dict[str, object]:
    """Validate a complete candidate tree before exposing any live changes."""
    if not shutil.which("niri"):
        return {"ok": False, "message": "Niri is not installed"}

    for path in updates:
        try:
            path.relative_to(NIRI_DIR)
        except ValueError as error:
            raise ValueError(f"Refusing to edit a file outside {NIRI_DIR}") from error

    with tempfile.TemporaryDirectory(prefix="quickshell-niri-") as temp_dir:
        candidate_dir = Path(temp_dir) / "niri"
        shutil.copytree(NIRI_DIR, candidate_dir)
        for path, content in updates.items():
            atomic_write(candidate_dir / path.relative_to(NIRI_DIR), content)
        validation = subprocess.run(
            ["niri", "validate", "-c", str(candidate_dir / "config.kdl")],
            capture_output=True,
            text=True,
            check=False,
            timeout=20,
        )
    if validation.returncode != 0:
        message = (validation.stderr or validation.stdout).strip()
        return {"ok": False, "message": f"Niri rejected the change: {message}"}

    originals = {path: read(path) for path in updates}
    try:
        for path, content in updates.items():
            atomic_write(path, content)
        reload_result = subprocess.run(
            ["niri", "msg", "action", "load-config-file"],
            capture_output=True,
            text=True,
            check=False,
            timeout=10,
        )
        if reload_result.returncode != 0:
            message = (reload_result.stderr or reload_result.stdout).strip()
            raise RuntimeError(message or "Niri did not reload the config")
    except Exception as error:
        for path, content in originals.items():
            atomic_write(path, content)
        subprocess.run(
            ["niri", "msg", "action", "load-config-file"],
            capture_output=True,
            check=False,
            timeout=10,
        )
        return {"ok": False, "message": f"Could not apply Niri config: {error}"}
    return {"ok": True, "message": success_message}


def qml_string(source: str, name: str, default: str = "") -> str:
    match = re.search(rf"property\s+string\s+{re.escape(name)}\s*:\s*\"((?:\\.|[^\"])*)\"", source)
    if not match:
        return default
    try:
        return json.loads(f'"{match.group(1)}"')
    except json.JSONDecodeError:
        return match.group(1)


def qml_int(source: str, name: str, default: int) -> int:
    match = re.search(rf"property\s+int\s+{re.escape(name)}\s*:\s*(\d+)", source)
    return int(match.group(1)) if match else default


def qml_bool(source: str, name: str, default: bool) -> bool:
    match = re.search(
        rf"property\s+bool\s+{re.escape(name)}\s*:\s*(true|false)",
        source,
    )
    return match.group(1) == "true" if match else default


def kdl_float(value: float) -> str:
    text = f"{float(value):.6f}".rstrip("0").rstrip(".")
    return text if "." in text else text + ".0"


def block_number(block: str, name: str, default: float) -> float:
    match = re.search(rf"(?m)^\s*{re.escape(name)}\s+([\d.]+)", block)
    return float(match.group(1)) if match else default


def block_number_any(block: str, name: str, default: float) -> float:
    """Read an active or commented numeric setting from a known config block."""
    match = re.search(
        rf"(?m)^\s*(?://\s*)?{re.escape(name)}\s+([-\d.]+)",
        block,
    )
    return float(match.group(1)) if match else default


def block_string(block: str, name: str, default: str = "") -> str:
    match = re.search(rf'(?m)^\s*(?://\s*)?{re.escape(name)}\s+"([^"]*)"', block)
    return match.group(1) if match else default


def block_bool(block: str, name: str, default: bool) -> bool:
    match = re.search(
        rf"(?m)^\s*(?://\s*)?{re.escape(name)}\s+(true|false)",
        block,
    )
    return match.group(1) == "true" if match else default


def block_attribute_number(block: str, name: str, attribute: str, default: float) -> float:
    match = re.search(
        rf"(?m)^\s*(?://\s*)?{re.escape(name)}\s+{re.escape(attribute)}=([-\d.]+)",
        block,
    )
    return float(match.group(1)) if match else default


def block_raw_setting(block: str, name: str, default: str = "") -> tuple[bool, str]:
    match = re.search(
        rf"(?m)^\s*(?P<comment>//\s*)?{re.escape(name)}\s+(?P<value>[^\n]+?)\s*$",
        block,
    )
    if not match:
        return False, default
    return match.group("comment") is None, match.group("value").strip()


def dimension_entries(block: str) -> str:
    entries: list[str] = []
    for raw in block.splitlines():
        match = re.match(r"^\s*(proportion|fixed)\s+([-\d.]+)\s*;?\s*$", raw)
        if match:
            entries.append(f"{match.group(1)} {match.group(2)}")
    return ", ".join(entries)


def set_optional_raw_line(block: str, name: str, value: str, enabled: bool, label: str) -> str:
    clean = value.strip()
    if not clean or any(character in clean for character in "{};\n\r"):
        raise ValueError(f"Invalid {label}")
    rendered = f"{name} {clean}"
    pattern = rf"(?m)^([ \t]*)(?://[ \t]*)?{re.escape(name)}\s+[^\n]+$"
    if re.search(pattern, block):
        return re.sub(
            pattern,
            lambda match: f"{match.group(1)}{'' if enabled else '// '}{rendered}",
            block,
            count=1,
        )
    trailing = re.search(r"(\n[ \t]*)$", block)
    if trailing:
        closing_indent = trailing.group(1)[1:]
        item_indent = closing_indent + "    "
        return (
            block[: trailing.start()]
            + f"\n{item_indent}{'' if enabled else '// '}{rendered}"
            + trailing.group(1)
        )
    return block + f"\n    {'' if enabled else '// '}{rendered}\n"


def render_dimension_entries(block: str, raw_value: str, label: str) -> str:
    parts = [part.strip() for part in re.split(r"[,;]", raw_value) if part.strip()]
    if not parts:
        raise ValueError(f"{label} needs at least one entry")
    rendered: list[str] = []
    for part in parts:
        match = re.fullmatch(r"(proportion|fixed)\s+([-+]?\d+(?:\.\d+)?)", part)
        if not match:
            raise ValueError(f"Invalid {label} entry: {part!r}")
        kind, number = match.groups()
        value = float(number)
        if kind == "proportion" and not 0 < value <= 1:
            raise ValueError(f"{label} proportion must be between 0 and 1")
        if kind == "fixed" and value <= 0:
            raise ValueError(f"{label} fixed size must be positive")
        encoded = str(int(round(value))) if kind == "fixed" else kdl_float(value)
        rendered.append(f"        {kind} {encoded}")
    return "\n" + "\n".join(rendered) + "\n    "


def set_number_line(block: str, name: str, value: float, label: str) -> str:
    return replace_once(
        block,
        rf"(?m)^([ \t]*)(?://[ \t]*)?{re.escape(name)}\s+[-\d.]+",
        lambda match: f"{match.group(1)}{name} {kdl_float(value)}",
        label,
    )


def set_integer_line(block: str, name: str, value: int, label: str) -> str:
    return replace_once(
        block,
        rf"(?m)^([ \t]*)(?://[ \t]*)?{re.escape(name)}\s+[-\d.]+",
        lambda match: f"{match.group(1)}{name} {int(value)}",
        label,
    )


def set_string_line(block: str, name: str, value: str, label: str) -> str:
    return replace_once(
        block,
        rf'(?m)^([ \t]*)(?://[ \t]*)?{re.escape(name)}\s+"[^"]*"',
        lambda match: f"{match.group(1)}{name} {json.dumps(value)}",
        label,
    )


def set_bool_line(block: str, name: str, value: bool, label: str) -> str:
    return replace_once(
        block,
        rf"(?m)^([ \t]*)(?://[ \t]*)?{re.escape(name)}\s+(?:true|false)",
        lambda match: f"{match.group(1)}{name} {'true' if value else 'false'}",
        label,
    )


def set_attribute_number_line(
    block: str,
    name: str,
    attribute: str,
    value: float,
    label: str,
) -> str:
    return replace_once(
        block,
        rf"(?m)^([ \t]*)(?://[ \t]*)?{re.escape(name)}\s+{re.escape(attribute)}=[-\d.]+",
        lambda match: f"{match.group(1)}{name} {attribute}={kdl_float(value)}",
        label,
    )


def block_offset(block: str) -> tuple[float, float]:
    match = re.search(r"(?m)^\s*offset\s+x=([-\d.]+)\s+y=([-\d.]+)", block)
    if not match:
        return 0.0, 0.0
    return float(match.group(1)), float(match.group(2))


def active_lines(block: str) -> list[dict[str, object]]:
    lines: list[dict[str, object]] = []
    for raw in block.splitlines():
        line = raw.strip()
        if not line or line.startswith("//") or line in ("{", "}") or line.endswith("{"):
            continue
        lines.append({"index": len(lines), "text": line.rstrip(";")})
    return lines


def parse_input_line(raw: str) -> tuple[str, bool] | None:
    stripped = raw.strip()
    if not stripped or stripped in ("{", "}") or stripped.endswith("{"):
        return None
    enabled = not stripped.startswith("//")
    text = stripped[2:].strip() if not enabled else stripped
    text = text.rstrip(";")
    if not text or text in ("off", "on") or text.endswith("{"):
        return None
    return text, enabled


def input_lines(block: str) -> list[dict[str, object]]:
    lines: list[dict[str, object]] = []
    for raw in block.splitlines():
        parsed = parse_input_line(raw)
        if parsed is None:
            continue
        text, enabled = parsed
        lines.append({
            "index": len(lines),
            "text": text,
            "enabled": enabled,
        })
    return lines


def find_block(source: str, name: str) -> str:
    match = re.search(rf"(?m)^\s*{re.escape(name)}\s*\{{", source)
    if not match:
        return ""
    start = match.end()
    depth = 1
    for index in range(start, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start:index]
    return ""


def find_any_block(source: str, name: str) -> str:
    match = re.search(rf"(?m)^\s*(?:/-)?{re.escape(name)}(?:\s+[^\{{\n]+)?\s*\{{", source)
    if not match:
        return ""
    start = match.end()
    depth = 1
    for index in range(start, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[start:index]
    return ""


def block_enabled(source: str, name: str) -> bool:
    return bool(re.search(rf"(?m)^\s*{re.escape(name)}(?:\s+[^\{{\n]+)?\s*\{{", source))


def flag_enabled(source: str, name: str) -> bool:
    return bool(re.search(rf"(?m)^\s*{re.escape(name)}\s*$", source))


def explicit_state_enabled(source: str, default: bool) -> bool:
    """Read an explicit KDL `on`/`off` state, falling back to Niri's default."""
    if flag_enabled(source, "on"):
        return True
    if flag_enabled(source, "off"):
        return False
    return default


def parse_recent_binds(block: str) -> list[dict[str, str]]:
    bindings: list[dict[str, str]] = []
    pattern = re.compile(
        r'^\s*([^\s/{][^{]*?)\s*\{\s*'
        r'(next-window|previous-window)'
        r'((?:\s+[a-z-]+="[^"]*")*)\s*;\s*\}\s*$'
    )
    for raw in block.splitlines():
        match = pattern.match(raw)
        if not match:
            continue
        key, direction, attributes = match.groups()
        filter_match = re.search(r'\bfilter="([^"]*)"', attributes)
        scope_match = re.search(r'\bscope="([^"]*)"', attributes)
        bindings.append({
            "key": key.strip(),
            "direction": direction,
            "filter": filter_match.group(1) if filter_match else "",
            "scope": scope_match.group(1) if scope_match else "",
        })
    return bindings


def toggle_block(source: str, name: str, enabled: bool) -> str:
    pattern = rf"(?m)^([ \t]*)(?:/-)?({re.escape(name)}(?:[ \t]+[^\{{\n]+)?[ \t]*\{{)"
    replacement = rf"\g<1>{'' if enabled else '/-'}\g<2>"
    return replace_once(source, pattern, replacement, f"{name} block")


def set_flag(source: str, name: str, enabled: bool) -> str:
    pattern = rf"(?m)^([ \t]*)(?://[ \t]*)?{re.escape(name)}[ \t]*$"
    replacement = rf"\g<1>{'' if enabled else '// '}{name}"
    return replace_once(source, pattern, replacement, name)


def update_block(source: str, name: str, updater) -> str:
    match = re.search(rf"(?m)^\s*(?:/-)?{re.escape(name)}(?:\s+[^\{{\n]+)?\s*\{{", source)
    if not match:
        raise ValueError(f"Could not find {name} block")
    start = match.end()
    depth = 1
    end = -1
    for index in range(start, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                end = index
                break
    if end < 0:
        raise ValueError(f"The {name} block is incomplete")
    return source[:start] + updater(source[start:end]) + source[end:]


def set_block_flag(source: str, block_name: str, flag_name: str, enabled: bool) -> str:
    return update_block(source, block_name, lambda block: set_flag(block, flag_name, enabled))


def set_explicit_block_state(source: str, block_name: str, enabled: bool) -> str:
    """Write one active `on` or `off` node inside a Niri block.

    Layout settings live in an included file.  In particular, an included
    `border {}` does not enable borders, so relying on an absent/commented
    `off` node gives the wrong result.  Keep the state explicit for all blocks
    that accept both nodes.
    """

    def update_state(block: str) -> str:
        state_pattern = re.compile(r"(?m)^([ \t]*)(?://[ \t]*)?(on|off)[ \t]*$")
        matches = list(state_pattern.finditer(block))
        desired = "on" if enabled else "off"

        if not matches:
            indent_match = re.search(r"(?m)^([ \t]+)\S", block)
            indent = indent_match.group(1) if indent_match else "        "
            return "\n" + indent + desired + "\n" + block.lstrip("\n")

        chunks: list[str] = []
        cursor = 0
        for index, match in enumerate(matches):
            chunks.append(block[cursor:match.start()])
            indent, state = match.groups()
            chunks.append(indent + (desired if index == 0 else f"// {state}"))
            cursor = match.end()
        chunks.append(block[cursor:])
        return "".join(chunks)

    return update_block(source, block_name, update_state)


def set_prefixed_line(source: str, name: str, enabled: bool) -> str:
    pattern = rf"(?m)^([ \t]*)(?://[ \t]*)?({re.escape(name)}(?:[ \t]+.*)?)$"
    replacement = rf"\g<1>{'' if enabled else '// '}\g<2>"
    return replace_once(source, pattern, replacement, name)


def set_unique_option_line(source: str, name: str, enabled: bool, suffix: str = "") -> str:
    """Activate one option variant and comment every duplicate example line."""
    pattern = re.compile(
        rf"(?m)^([ \t]*)(?://[ \t]*)?{re.escape(name)}(?:[ \t]+.*)?$"
    )
    matches = list(pattern.finditer(source))
    if not matches:
        raise ValueError(f"Could not find {name}")
    desired = name + (f" {suffix}" if suffix else "")
    chunks: list[str] = []
    cursor = 0
    for index, match in enumerate(matches):
        chunks.append(source[cursor:match.start()])
        indent = match.group(1)
        chunks.append(indent + (desired if enabled and index == 0 else f"// {desired}"))
        cursor = match.end()
    chunks.append(source[cursor:])
    return "".join(chunks)


def event_action(source: str, name: str) -> str:
    block = find_any_block(source, name)
    match = re.search(r"(?m)^\s*(spawn(?:-sh)?\s+.+?)\s*;?\s*$", block)
    return match.group(1).strip() if match else ""


def set_event_action(source: str, name: str, action: str) -> str:
    clean = action.strip().rstrip(";")
    if not clean.startswith(("spawn ", "spawn-sh ")):
        raise ValueError(f"{name} action must start with spawn or spawn-sh")
    if any(character in clean for character in "{}\n\r"):
        raise ValueError(f"{name} action must be one KDL line")

    def update_event(block: str) -> str:
        return replace_once(
            block,
            r"(?m)^([ \t]*)spawn(?:-sh)?[ \t]+.+?[ \t]*;?[ \t]*$",
            lambda match: match.group(1) + clean,
            f"{name} action",
        )

    return update_block(source, name, update_event)


def animation_snapshot(source: str) -> dict[str, object]:
    slowdown = re.search(r"(?m)^\s*(?://\s*)?slowdown\s+([\d.]+)", source)
    entries = []
    for name in ANIMATION_NAMES:
        block = find_any_block(source, name)
        spec = ""
        for raw in block.splitlines():
            line = raw.strip()
            if line and not line.startswith("//"):
                spec = line.rstrip(";")
                break
        entries.append({
            "name": name,
            "enabled": block_enabled(source, name),
            "spec": spec,
        })
    return {
        "enabled": not flag_enabled(source, "off"),
        "slowdown": float(slowdown.group(1)) if slowdown else 1.0,
        "entries": entries,
    }


def behavior_snapshot(
    behavior_source: str,
    cursor_source: str,
    input_source: str,
    switch_events_source: str,
) -> dict[str, object]:
    screenshot = re.search(r'(?m)^\s*screenshot-path\s+(null|"(?:\\.|[^"])*")', behavior_source)
    screenshot_path = ""
    screenshot_saving_enabled = bool(screenshot and screenshot.group(1) != "null")
    if screenshot and screenshot.group(1) != "null":
        try:
            screenshot_path = json.loads(screenshot.group(1))
        except json.JSONDecodeError:
            screenshot_path = screenshot.group(1).strip('"')

    hotkey_overlay = find_block(behavior_source, "hotkey-overlay")
    xwayland = find_any_block(behavior_source, "xwayland-satellite")
    cursor = find_block(cursor_source, "cursor")
    input_block = find_block(input_source, "input")
    gestures = find_block(behavior_source, "gestures")
    dnd_view = find_block(gestures, "dnd-edge-view-scroll")
    dnd_workspace = find_block(gestures, "dnd-edge-workspace-switch")
    hot_corners = find_block(gestures, "hot-corners")
    hot_corners_enabled = not flag_enabled(hot_corners, "off")
    hot_corner_states = {
        "top-left": flag_enabled(hot_corners, "top-left"),
        "top-right": flag_enabled(hot_corners, "top-right"),
        "bottom-left": flag_enabled(hot_corners, "bottom-left"),
        "bottom-right": flag_enabled(hot_corners, "bottom-right"),
    }
    # Niri uses top-left when hot corners are enabled without an explicit
    # corner, so reflect the effective state in the settings UI.
    if hot_corners_enabled and not any(hot_corner_states.values()):
        hot_corner_states["top-left"] = True
    warp = re.search(r'(?m)^\s*warp-mouse-to-focus(?:\s+mode="([^"]+)")?\s*$', input_block)
    focus_follows = re.search(
        r'(?m)^\s*focus-follows-mouse(?:\s+max-scroll-amount="([^"]+)")?\s*$',
        input_block,
    )

    def number(block: str, name: str, default: float) -> float:
        match = re.search(rf"(?m)^\s*{re.escape(name)}\s+([\d.]+)", block)
        return float(match.group(1)) if match else default

    cursor_timeout = re.search(r"(?m)^\s*(?://\s*)?hide-after-inactive-ms\s+(\d+)", cursor)
    cursor_theme = re.search(r'(?m)^\s*xcursor-theme\s+"([^"]+)"', cursor)
    cursor_size = re.search(r"(?m)^\s*xcursor-size\s+(\d+)", cursor)
    active_mod_key = re.search(r'(?m)^\s*mod-key\s+"([^"]+)"\s*$', input_block)
    active_nested_mod_key = re.search(r'(?m)^\s*mod-key-nested\s+"([^"]+)"\s*$', input_block)
    return {
        "showHotkeyOverlayAtStartup": not flag_enabled(hotkey_overlay, "skip-at-startup"),
        "preferNoCsd": flag_enabled(behavior_source, "prefer-no-csd"),
        "screenshotSavingEnabled": screenshot_saving_enabled,
        "screenshotPath": screenshot_path,
        "hideUnboundHotkeys": flag_enabled(behavior_source, "hide-not-bound"),
        "disablePrimaryClipboard": block_enabled(behavior_source, "clipboard"),
        "disableConfigError": block_enabled(behavior_source, "config-notification"),
        "xwaylandEnabled": block_enabled(behavior_source, "xwayland-satellite"),
        "xwaylandPath": block_string(xwayland, "path", "xwayland-satellite"),
        # Blur is available by default.  Omitting the block only drops its
        # custom quality values; an active nested `off` is what disables it.

        "switchEvents": block_enabled(switch_events_source, "switch-events"),
        "hideCursorWhileTyping": flag_enabled(cursor, "hide-when-typing"),
        "cursorTimeoutEnabled": bool(re.search(r"(?m)^\s*hide-after-inactive-ms\s+\d+", cursor)),
        "cursorTimeoutMs": int(cursor_timeout.group(1)) if cursor_timeout else 1000,
        "cursorTheme": cursor_theme.group(1) if cursor_theme else "",
        "cursorSize": int(cursor_size.group(1)) if cursor_size else 24,
        "disablePowerKeyHandling": flag_enabled(input_block, "disable-power-key-handling"),
        "warpMouseToFocus": bool(warp),
        "warpMouseMode": warp.group(1) if warp and warp.group(1) else "separate",
        "focusFollowsMouse": bool(focus_follows),
        "focusFollowsMaxScrollAmount": focus_follows.group(1) if focus_follows and focus_follows.group(1) else "0%",
        "workspaceAutoBackAndForth": flag_enabled(input_block, "workspace-auto-back-and-forth"),
        "modKey": active_mod_key.group(1) if active_mod_key else "",
        "modKeyNested": active_nested_mod_key.group(1) if active_nested_mod_key else "",
        "dndViewTriggerWidth": int(number(dnd_view, "trigger-width", 30)),
        "dndViewDelayMs": int(number(dnd_view, "delay-ms", 100)),
        "dndViewMaxSpeed": int(number(dnd_view, "max-speed", 1500)),
        "dndWorkspaceTriggerHeight": int(number(dnd_workspace, "trigger-height", 50)),
        "dndWorkspaceDelayMs": int(number(dnd_workspace, "delay-ms", 100)),
        "dndWorkspaceMaxSpeed": int(number(dnd_workspace, "max-speed", 1500)),
        "hotCornersEnabled": hot_corners_enabled,
        "hotCornerTopLeft": hot_corner_states["top-left"],
        "hotCornerTopRight": hot_corner_states["top-right"],
        "hotCornerBottomLeft": hot_corner_states["bottom-left"],
        "hotCornerBottomRight": hot_corner_states["bottom-right"],
        "lidCloseAction": event_action(switch_events_source, "lid-close"),
        "lidOpenAction": event_action(switch_events_source, "lid-open"),
        "tabletModeOnAction": event_action(switch_events_source, "tablet-mode-on"),
        "tabletModeOffAction": event_action(switch_events_source, "tablet-mode-off"),
    }


def pretty_key(raw: str) -> str:
    key = re.sub(r"\s+(?:repeat|cooldown-ms|allow-when-locked)=[^\s]+", "", raw).strip()
    replacements = {
        "Mod": "Super",
        "XF86AudioRaiseVolume": "Volume +",
        "XF86AudioLowerVolume": "Volume −",
        "XF86AudioMute": "Mute",
        "XF86AudioMicMute": "Mic mute",
        "XF86MonBrightnessUp": "Brightness +",
        "XF86MonBrightnessDown": "Brightness −",
        "Return": "Enter",
        "Equal": "=",
        "Minus": "−",
    }
    parts = key.split("+")
    return " + ".join(replacements.get(part, part) for part in parts)


def unquote_command(body: str) -> tuple[str, str]:
    match = re.match(r"(spawn-sh|spawn)\s+(.+)$", body)
    if not match:
        return "", ""
    command_type, encoded = match.groups()
    try:
        args = shlex.split(encoded)
    except ValueError:
        args = [encoded.strip('"')]
    command = " ".join(args)
    return command_type, command


def action_description(body: str) -> str:
    clean = body.strip().rstrip(";")
    command_type, command = unquote_command(clean)
    if command_type:
        lower = command.lower()
        known = (
            ("blackbox-terminal", "Open terminal"),
            ("launcher toggle", "Open application launcher"),
            ("lockscreen", "Lock screen"),
            ("wallpaper toggle", "Open wallpaper selector"),
            ("killall quickshell", "Reload Quickshell"),
            ("nautilus", "Open file manager"),
            ("missioncenter", "Open system monitor"),
            ("hyprpicker", "Pick screen color"),
            ("gnome-control-center", "Open system settings"),
            ("screenshot", "Capture screenshot"),
            ("togglerecording", "Toggle screen recording"),
            ("set-sink-volume", "Change output volume"),
            ("set-source-volume", "Change microphone volume"),
            ("set-sink-mute", "Toggle output mute"),
            ("set-mute @default_audio_source@", "Toggle microphone mute"),
            ("brightnessctl", "Change screen brightness"),
            ("focus-app", "Focus app workspace"),
            ("toogle-floating-workspace", "Toggle workspace floating layout"),
        )
        for needle, label in known:
            if needle in lower:
                return label
        first = Path(command.split()[0]).name if command else "command"
        return f"Run {first}"

    action = clean.split()[0] if clean else ""
    if action in ACTION_NAMES:
        return ACTION_NAMES[action]
    if action == "focus-workspace":
        return f"Focus workspace {clean.split()[-1]}"
    if action == "move-column-to-workspace":
        return f"Move column to workspace {clean.split()[-1]}"
    if action == "set-column-width":
        return f"Change column width {clean.split()[-1].strip(chr(34))}"
    if action == "set-window-height":
        return f"Change window height {clean.split()[-1].strip(chr(34))}"
    return action.replace("-", " ").capitalize() if action else "Niri action"


def category_for(key: str, body: str, description: str) -> str:
    text = f"{key} {body} {description}".lower()
    if "audio" in text or "volume" in text or "mic mute" in text:
        return "Media"
    if "brightness" in text:
        return "Backlight"
    if "screenshot" in text or "recording" in text:
        return "Capture"
    if "monitor" in text:
        return "Monitor"
    if "workspace" in text or "overview" in text or "focus-app" in text:
        return "Workspace"
    if any(word in text for word in ("launcher", "terminal", "file manager", "system monitor", "system settings", "pick screen color")):
        return "Applications"
    if any(word in text for word in ("quickshell", "lock screen", "wallpaper", "exit niri", "hotkey overlay")):
        return "Shell"
    if any(word in text for word in ("window", "column", "floating", "fullscreen", "width", "height")):
        return "Window"
    return "Other"


def parse_binds(source: str) -> list[dict[str, object]]:
    groups: dict[str, list[dict[str, str]]] = {}
    pattern = re.compile(r"^\s*([^/{][^{]*?)\s*\{\s*(.*?)\s*;\s*\}\s*$")
    for raw in source.splitlines():
        line = raw.strip()
        if not line or line.startswith("//"):
            continue
        match = pattern.match(raw)
        if not match:
            continue
        key, body = (part.strip() for part in match.groups())
        raw_key = key.split()[0]
        description = action_description(body)
        category = category_for(key, body, description)
        groups.setdefault(category, []).append({
            "key": pretty_key(key),
            "rawKey": raw_key,
            "rawHeader": key,
            "description": description,
        })

    order = ["Window", "Applications", "Workspace", "Shell", "Capture", "Monitor", "Media", "Backlight", "Other"]
    icons = {
        "Window": "window-new-symbolic",
        "Applications": "view-app-grid-symbolic",
        "Workspace": "view-grid-symbolic",
        "Shell": "utilities-terminal-symbolic",
        "Capture": "camera-photo-symbolic",
        "Monitor": "video-display-symbolic",
        "Media": "audio-volume-high-symbolic",
        "Backlight": "display-brightness-symbolic",
        "Other": "applications-system-symbolic",
    }
    # Balanced masonry columns. Assign each card to the shorter of two readable columns.
    column_sizes = [0, 0]
    result: list[dict[str, object]] = []
    for name in order:
        items = groups.get(name)
        if not items:
            continue
        column = min(range(2), key=column_sizes.__getitem__)
        column_sizes[column] += len(items) + 2
        result.append({"name": name, "icon": icons[name], "column": column, "items": items})
    return result


def snapshot() -> dict[str, object]:
    layout_source = read(INCLUDE_DIR / "layout.kdl")
    input_source = read(INCLUDE_DIR / "input.kdl")
    animation_source = read(INCLUDE_DIR / "animations.kdl")
    behavior_source = read(INCLUDE_DIR / "behavior.kdl")
    cursor_source = read(INCLUDE_DIR / "cursor.kdl")
    switch_events_source = read(INCLUDE_DIR / "switch-events.kdl")
    config_source = read(CONFIG_QML)
    border_block = find_block(layout_source, "border")
    focus_ring_block = find_block(layout_source, "focus-ring")
    shadow_block = find_block(layout_source, "shadow")
    shadow_offset = block_offset(shadow_block)
    tab_indicator_block = find_block(layout_source, "tab-indicator")
    insert_hint_block = find_block(layout_source, "insert-hint")
    default_width_block = find_block(layout_source, "default-column-width")
    preset_widths_block = find_any_block(layout_source, "preset-column-widths")
    preset_heights_block = find_any_block(layout_source, "preset-window-heights")
    struts_block = find_any_block(layout_source, "struts")
    blur_block = find_any_block(layout_source, "blur")
    
    def snapshot_number(block: str, name: str, default: float) -> float:
        match = re.search(rf"(?m)^\s*{re.escape(name)}\s+([\d.]+)", block)
        return float(match.group(1)) if match else default

    overview_block = find_block(layout_source, "overview")
    workspace_shadow_block = find_block(overview_block, "workspace-shadow")
    workspace_shadow_offset = block_offset(workspace_shadow_block)
    blur_block = find_any_block(layout_source, "blur")
    recent_windows_block = find_any_block(layout_source, "recent-windows")
    recent_highlight_block = find_any_block(recent_windows_block, "highlight")
    recent_previews_block = find_any_block(recent_windows_block, "previews")
    recent_binds_block = find_any_block(recent_windows_block, "binds")
    def snapshot_number(block: str, name: str, default: float) -> float:
        match = re.search(rf"(?m)^\\s*{re.escape(name)}\\s+([\\d.]+)", block)
        return float(match.group(1)) if match else default

    gaps = re.search(r"(?m)^\s*gaps\s+([\d.]+)", layout_source)
    border_width = re.search(r"(?m)^\s*width\s+([\d.]+)", border_block)
    center = re.search(r"(?m)^\s*center-focused-column\s+\"([^\"]+)\"", layout_source)
    default_display = re.search(r'(?m)^\s*default-column-display\s+"([^"]+)"', layout_source)
    default_width_proportion = re.search(r"(?m)^\s*proportion\s+([\d.]+)", default_width_block)
    default_width_fixed = re.search(r"(?m)^\s*fixed\s+([\d.]+)", default_width_block)
    overview_zoom = re.search(r"(?m)^\s*zoom\s+([\d.]+)", overview_block)
    border_active_gradient = block_raw_setting(border_block, "active-gradient", 'from="#80c8ff" to="#c7ff7f" angle=45')
    border_inactive_gradient = block_raw_setting(border_block, "inactive-gradient", 'from="#505050" to="#808080" angle=45')
    border_urgent_gradient = block_raw_setting(border_block, "urgent-gradient", 'from="#800" to="#a33" angle=45')
    focus_active_gradient = block_raw_setting(focus_ring_block, "active-gradient", 'from="#80c8ff" to="#bbddff" angle=45')
    focus_inactive_gradient = block_raw_setting(focus_ring_block, "inactive-gradient", 'from="#505050" to="#808080" angle=45')
    focus_urgent_gradient = block_raw_setting(focus_ring_block, "urgent-gradient", 'from="#800" to="#a33" angle=45')
    tab_active_gradient = block_raw_setting(tab_indicator_block, "active-gradient", 'from="#80c8ff" to="#bbddff" angle=45')
    tab_inactive_gradient = block_raw_setting(tab_indicator_block, "inactive-gradient", 'from="#505050" to="#808080" angle=45')
    tab_urgent_gradient = block_raw_setting(tab_indicator_block, "urgent-gradient", 'from="#800" to="#a33" angle=45')
    insert_gradient = block_raw_setting(insert_hint_block, "gradient", 'from="#ffbb6680" to="#ffc88080" angle=45')
    quickshell_settings: dict[str, object] = {
        "fontName": qml_string(config_source, "fontName", "Inter"),
        "greeterDefaultSession": qml_string(config_source, "greeterDefaultSession", "niri"),
        "greeterRememberLastSession": qml_bool(config_source, "greeterRememberLastSession", False),
        "audioMaxVolume": 1.0,
        "barDensity": "comfortable",
        "barHeight": 50,
        "barShowActiveClient": True,
        "barShowBattery": True,
        "barShowBluetooth": True,
        "barShowClock": True,
        "barShowMedia": True,
        "barShowMicrophone": True,
        "barShowNetwork": True,
        "barShowNotifications": True,
        "barShowRecording": True,
        "barShowSysTray": True,
        "barShowWeather": True,
        "barShowWorkspaces": True,
        "caffeineAutoDisableMinutes": 0,
        "cavaEnabled": True,
        "idleBatteryDisplayTimeout": 300,
        "idleBatteryLockTimeout": 300,
        "idleBatterySleepAction": "suspend",
        "idleBatterySuspendTimeout": 900,
        "idleDimDuration": 5,
        "idleDimOpacity": 0.55,
        "idleDisplayTimeout": 600,
        "idleEnabled": True,
        "idleLockBeforeSleep": True,
        "idleLockedDisplayTimeout": 60,
        "idleLockTimeout": 600,
        "idleRespectInhibitors": True,
        "idleSeparatePowerProfiles": False,
        "idleSleepAction": "suspend",
        "idleSuspendTimeout": 0,
        "lockFaceMaxAttempts": qml_int(config_source, "lockFaceMaxAttempts", 3),
        "lockFaceRetryOnWake": qml_bool(config_source, "lockFaceRetryOnWake", True),
        "launcherCalculatorAngleMode": qml_string(config_source, "launcherCalculatorAngleMode", "rad"),
        "launcherCalculatorEnabled": True,
        "launcherCalculatorPrefix": "=",
        "launcherClipboardAutoPaste": True,
        "launcherClipboardEnabled": True,
        "launcherClipboardPrefix": "c",
        "launcherEmojiEnabled": True,
        "launcherEmojiPrefix": "e",
        "launcherFilesEnabled": True,
        "launcherFilesPrefix": "f",
        "launcherFuzzySearch": True,
        "launcherGifEnabled": True,
        "launcherGifPrefix": "g",
        "launcherKlipyApiKey": qml_string(config_source, "launcherKlipyApiKey"),
        "launcherMaxResults": 20,
        "launcherStickerEnabled": True,
        "launcherStickerPrefix": "s",
        "notificationBlockedApps": "",
        "notificationCriticalTimeout": 0,
        "notificationDndEnd": "07:00",
        "notificationDndScheduleEnabled": False,
        "notificationDndStart": "23:00",
        "notificationHistoryExcludedApps": "",
        "notificationHistoryLimit": 100,
        "notificationLowTimeout": 5000,
        "notificationLockscreenPrivacy": qml_string(config_source, "notificationLockscreenPrivacy", "hidden"),
        "notificationMaxVisible": 3,
        "notificationNormalTimeout": 5000,
        "notificationPopupDuration": 5000,
        "notificationPosition": "top",
        "notificationShowInFullscreen": True,
        "notificationShowOnLock": False,
        "osdDuration": 2000,
        "osdEnabled": True,
        "osdPosition": "bottom",
        "osdShowBrightness": True,
        "osdShowMicrophone": True,
        "osdShowVolume": True,
        "profileImagePath": qml_string(config_source, "profileImagePath"),
        "shellAnimationScale": 1.0,
        "shellBlurBarEnabled": True,
        "shellBlurBarOpacityDark": 0.24,
        "shellBlurBarOpacityLight": 0.86,
        "shellBlurControlLeftEnabled": True,
        "shellBlurControlRightEnabled": True,
        "shellBlurDockEnabled": True,
        "shellBlurLauncherEnabled": True,
        "shellBlurNotificationEnabled": True,
        "shellBlurOsdEnabled": True,
        "shellBlurPanelOpacityDark": 0.76,
        "shellBlurPanelOpacityLight": 0.88,
        "shellBlurSettingsEnabled": True,
        "shellComponentShadowBlur": 10.0,
        "shellComponentShadowEnabled": True,
        "shellComponentShadowOffsetX": 0.0,
        "shellComponentShadowOffsetY": 2.0,
        "shellComponentShadowOpacity": 0.18,
        "shellComponentShadowSpread": 0.0,
        "shellLowPowerMode": False,
        "shellReducedMotion": False,
        "shellShadowBlur": 18.0,
        "shellShadowEnabled": True,
        "shellShadowOffsetX": 0.0,
        "shellShadowOffsetY": 3.0,
        "shellShadowOpacity": 0.28,
        "shellShadowSpread": 1.0,
        "latLon": qml_string(config_source, "latLon"),
        "apiWeather": qml_string(config_source, "apiWeather"),
        "steamUsername": qml_string(config_source, "steamUsername"),
        "steamWebApiKey": qml_string(config_source, "steamWebApiKey"),
        "wallhavenUsername": qml_string(config_source, "wallhavenUsername"),
        "wallhavenApiKey": qml_string(config_source, "wallhavenApiKey"),
        "wallhavenShowNsfw": qml_bool(config_source, "wallhavenShowNsfw", False),
        "wallpaperWorkshopShowNsfw": qml_bool(config_source, "wallpaperWorkshopShowNsfw", False),
        "wallFolderPath": qml_string(config_source, "wallFolderPath"),
        "liveWallFolderPath": qml_string(config_source, "liveWallFolderPath"),
        "wallpaperBatteryFps": qml_int(config_source, "wallpaperBatteryFps", 20),
        "wallpaperEngineFps": qml_int(config_source, "wallpaperEngineFps", 30),
        "wallpaperPauseOnFullscreen": qml_bool(config_source, "wallpaperPauseOnFullscreen", True),
        "wallpaperPauseOnLock": qml_bool(config_source, "wallpaperPauseOnLock", True),
        "wallpaperScalingMode": qml_string(config_source, "wallpaperScalingMode", "fill"),
        "wallpaperTransitionDuration": qml_int(config_source, "wallpaperTransitionDuration", 360),
        "matugenEnabled": qml_bool(config_source, "matugenEnabled", True),
        "matugenAnimateColors": qml_bool(config_source, "matugenAnimateColors", True),
        "matugenTransitionDuration": qml_int(config_source, "matugenTransitionDuration", 300),
        "captureScreenshotDirPath": qml_string(config_source, "captureScreenshotDirPath"),
        "captureRecordingDirPath": qml_string(config_source, "captureRecordingDirPath"),
        "captureAutoCopyScreenshot": qml_bool(config_source, "captureAutoCopyScreenshot", True),
        "captureAutoCopyRecording": qml_bool(config_source, "captureAutoCopyRecording", True),
        "captureRecordingFps": qml_int(config_source, "captureRecordingFps", 60),
        "captureRecordingCodec": qml_string(config_source, "captureRecordingCodec", "hevc"),
        "captureRecordingCountdown": qml_int(config_source, "captureRecordingCountdown", 0),
        "captureRecordingCursor": qml_bool(config_source, "captureRecordingCursor", True),
        "captureRecordingQuality": qml_string(config_source, "captureRecordingQuality", "high"),
        "captureRecordingMicrophone": qml_bool(config_source, "captureRecordingMicrophone", False),
        "captureRecordingMicrophoneSource": qml_string(
            config_source, "captureRecordingMicrophoneSource", "default_input"
        ),
        "captureRecordingMode": qml_string(config_source, "captureRecordingMode", "region"),
        "captureScreenshotAction": qml_string(
            config_source, "captureScreenshotAction", "notification"
        ),
        "captureScreenshotFilenameTemplate": qml_string(
            config_source, "captureScreenshotFilenameTemplate", "{date}_{time}-edited"
        ),
        "captureScreenshotFormat": qml_string(config_source, "captureScreenshotFormat", "png"),
        "captureScreenshotQuality": qml_int(config_source, "captureScreenshotQuality", 90),
        "captureEditorTool": qml_string(config_source, "captureEditorTool", "pen"),
        "captureEditorColor": qml_string(config_source, "captureEditorColor", "#ff3b30"),
        "captureEditorWidth": qml_int(config_source, "captureEditorWidth", 6),
        "wallpaperEngineAssetsDirPath": qml_string(config_source, "wallpaperEngineAssetsDirPath"),
        "wallpaperEngineWorkshopDirPath": qml_string(config_source, "wallpaperEngineWorkshopDirPath"),
        "temperatureUnit": qml_string(config_source, "temperatureUnit", "celsius"),
    }
    if RUNTIME_SETTINGS_PATH.exists():
        try:
            runtime_settings = json.loads(RUNTIME_SETTINGS_PATH.read_text(encoding="utf-8"))
            if isinstance(runtime_settings, dict):
                legacy_notification_timeout = runtime_settings.get("notificationPopupDuration", 5000)
                if "notificationLowTimeout" not in runtime_settings:
                    quickshell_settings["notificationLowTimeout"] = legacy_notification_timeout
                if "notificationNormalTimeout" not in runtime_settings:
                    quickshell_settings["notificationNormalTimeout"] = legacy_notification_timeout
                legacy_blur = bool(runtime_settings.get("shellBlurEnabled", True))
                for key in (
                    "shellBlurBarEnabled",
                    "shellBlurControlLeftEnabled",
                    "shellBlurControlRightEnabled",
                    "shellBlurDockEnabled",
                    "shellBlurLauncherEnabled",
                    "shellBlurNotificationEnabled",
                    "shellBlurOsdEnabled",
                    "shellBlurSettingsEnabled",
                ):
                    if key not in runtime_settings:
                        quickshell_settings[key] = legacy_blur
                quickshell_settings.update(
                    {
                        key: value
                        for key, value in runtime_settings.items()
                        if key in quickshell_settings
                    }
                )
        except (OSError, json.JSONDecodeError):
            pass
    privacy_mode = str(quickshell_settings.get("notificationLockscreenPrivacy", "")).lower()
    if privacy_mode not in ("hidden", "icons", "full"):
        quickshell_settings["notificationLockscreenPrivacy"] = (
            "full" if bool(quickshell_settings.get("notificationShowOnLock", False)) else "hidden"
        )
    return {
        "niri": {
            "keybindGroups": parse_binds(read(INCLUDE_DIR / "keybinds.kdl")),
            "layout": {
                "gaps": float(gaps.group(1)) if gaps else 0,
                "borderWidth": float(border_width.group(1)) if border_width else 0,
                "shadow": explicit_state_enabled(shadow_block, False),
                "centerFocused": center.group(1) if center else "never",
                "alwaysCenterSingle": bool(re.search(r"(?m)^\s*always-center-single-column\s*$", layout_source)),
                "emptyWorkspaceAboveFirst": flag_enabled(layout_source, "empty-workspace-above-first"),
                "defaultColumnDisplay": default_display.group(1) if default_display else "normal",
                "backgroundColor": block_string(find_block(layout_source, "layout"), "background-color", "transparent"),
                "defaultColumnWidthMode": "fixed" if default_width_fixed else ("proportion" if default_width_proportion else "auto"),
                "defaultColumnWidth": float(default_width_fixed.group(1)) if default_width_fixed else (float(default_width_proportion.group(1)) if default_width_proportion else 1.0),
                "presetColumnWidthsEnabled": block_enabled(layout_source, "preset-column-widths"),
                "presetColumnWidths": dimension_entries(preset_widths_block) or "proportion 0.33333, proportion 0.5, proportion 0.66667",
                "presetWindowHeightsEnabled": block_enabled(layout_source, "preset-window-heights"),
                "presetWindowHeights": dimension_entries(preset_heights_block) or "proportion 0.33333, proportion 0.5, proportion 0.66667",
                "strutsEnabled": block_enabled(layout_source, "struts"),
                "strutLeft": block_number_any(struts_block, "left", 0),
                "strutRight": block_number_any(struts_block, "right", 0),
                "strutTop": block_number_any(struts_block, "top", 0),
                "strutBottom": block_number_any(struts_block, "bottom", 0),
                "overviewZoom": float(overview_zoom.group(1)) if overview_zoom else 0.4,
                "overviewBackdropColor": block_string(overview_block, "backdrop-color", "#0a0a0a"),
                "workspaceShadowEnabled": explicit_state_enabled(workspace_shadow_block, True),
                "workspaceShadowSoftness": block_number(workspace_shadow_block, "softness", 30),
                "workspaceShadowSpread": block_number(workspace_shadow_block, "spread", 5),
                "workspaceShadowOffsetX": workspace_shadow_offset[0],
                "workspaceShadowOffsetY": workspace_shadow_offset[1],
                "workspaceShadowColor": block_string(workspace_shadow_block, "color", "#000000"),
                "borderEnabled": explicit_state_enabled(border_block, False),
                "borderActiveColor": block_string(border_block, "active-color", "#222222"),
                "borderInactiveColor": block_string(border_block, "inactive-color", "#222222"),
                "borderUrgentColor": block_string(border_block, "urgent-color", "#9b0000"),
                "borderGradientEnabled": border_active_gradient[0] or border_inactive_gradient[0] or border_urgent_gradient[0],
                "borderActiveGradient": border_active_gradient[1],
                "borderInactiveGradient": border_inactive_gradient[1],
                "borderUrgentGradient": border_urgent_gradient[1],
                "focusRingEnabled": explicit_state_enabled(focus_ring_block, True),
                "focusRingWidth": block_number_any(focus_ring_block, "width", 4),
                "focusRingActiveColor": block_string(focus_ring_block, "active-color", "#7fc8ff"),
                "focusRingInactiveColor": block_string(focus_ring_block, "inactive-color", "#505050"),
                "focusRingUrgentColor": block_string(focus_ring_block, "urgent-color", "#9b0000"),
                "focusRingGradientEnabled": focus_active_gradient[0] or focus_inactive_gradient[0] or focus_urgent_gradient[0],
                "focusRingActiveGradient": focus_active_gradient[1],
                "focusRingInactiveGradient": focus_inactive_gradient[1],
                "focusRingUrgentGradient": focus_urgent_gradient[1],
                "tabIndicatorEnabled": explicit_state_enabled(
                    tab_indicator_block,
                    True,
                ),
                "tabHideSingle": flag_enabled(tab_indicator_block, "hide-when-single-tab"),
                "tabPlaceWithinColumn": flag_enabled(tab_indicator_block, "place-within-column"),
                "tabGap": block_number_any(tab_indicator_block, "gap", 5),
                "tabWidth": block_number_any(tab_indicator_block, "width", 4),
                "tabLength": block_attribute_number(tab_indicator_block, "length", "total-proportion", 1),
                "tabPosition": block_string(tab_indicator_block, "position", "right"),
                "tabGapsBetween": block_number_any(tab_indicator_block, "gaps-between-tabs", 2),
                "tabCornerRadius": block_number_any(tab_indicator_block, "corner-radius", 8),
                "tabActiveColor": block_string(tab_indicator_block, "active-color", "#7fc8ff"),
                "tabInactiveColor": block_string(tab_indicator_block, "inactive-color", "#505050"),
                "tabUrgentColor": block_string(tab_indicator_block, "urgent-color", "#9b0000"),
                "tabGradientEnabled": tab_active_gradient[0] or tab_inactive_gradient[0] or tab_urgent_gradient[0],
                "tabActiveGradient": tab_active_gradient[1],
                "tabInactiveGradient": tab_inactive_gradient[1],
                "tabUrgentGradient": tab_urgent_gradient[1],
                "insertHintEnabled": explicit_state_enabled(
                    insert_hint_block,
                    True,
                ),
                "insertHintColor": block_string(insert_hint_block, "color", "#7fc8ff80"),
                "insertHintGradientEnabled": insert_gradient[0],
                "insertHintGradient": insert_gradient[1],
                "shadowSoftness": block_number_any(shadow_block, "softness", 20),
                "shadowSpread": block_number_any(shadow_block, "spread", 5),
                "shadowOffsetX": shadow_offset[0],
                "shadowOffsetY": shadow_offset[1],
                "shadowDrawBehind": block_bool(shadow_block, "draw-behind-window", True),
                "shadowColor": block_string(shadow_block, "color", "#000000"),
                "shadowInactiveColor": block_string(shadow_block, "inactive-color", "#00000054"),
                # recent-windows is enabled by default in Niri.  Omitting or
                # slashdash-commenting the block does not disable it; only an
                # active `off` node inside an active block does.
                "blurEnabled": not (
                    block_enabled(layout_source, "blur")
                    and flag_enabled(blur_block, "off")
                ),
                "blurPasses": snapshot_number(blur_block, "passes", 3),
                "blurOffset": snapshot_number(blur_block, "offset", 3.0),
                "blurNoise": snapshot_number(blur_block, "noise", 0.02),
                "blurSaturation": snapshot_number(blur_block, "saturation", 1.5),

                "recentWindows": not (
                    block_enabled(layout_source, "recent-windows")
                    and flag_enabled(recent_windows_block, "off")
                ),
                "recentDebounceMs": int(block_number(recent_windows_block, "debounce-ms", 750)),
                "recentOpenDelayMs": int(block_number(recent_windows_block, "open-delay-ms", 150)),
                "recentHighlightActiveColor": block_string(recent_highlight_block, "active-color", "#999999ff"),
                "recentHighlightUrgentColor": block_string(recent_highlight_block, "urgent-color", "#ff9999ff"),
                "recentHighlightPadding": int(block_number(recent_highlight_block, "padding", 30)),
                "recentHighlightCornerRadius": int(block_number(recent_highlight_block, "corner-radius", 0)),
                "recentPreviewHeight": int(block_number(recent_previews_block, "max-height", 480)),
                "recentPreviewScale": block_number(recent_previews_block, "max-scale", 0.5),
                "recentBinds": parse_recent_binds(recent_binds_block),
            },
            "input": {
                "Keyboard": input_lines(find_block(input_source, "keyboard")),
                "Touchpad": input_lines(find_block(input_source, "touchpad")),
                "Mouse": input_lines(find_block(input_source, "mouse")),
                "Trackpoint": input_lines(find_block(input_source, "trackpoint")),
                "Trackball": input_lines(find_block(input_source, "trackball")),
                "Tablet": input_lines(find_block(input_source, "tablet")),
                "Touch": input_lines(find_block(input_source, "touch")),
            },
            "inputEnabled": {
                "Touchpad": not flag_enabled(find_block(input_source, "touchpad"), "off"),
                "Mouse": not flag_enabled(find_block(input_source, "mouse"), "off"),
                "Trackpoint": not flag_enabled(find_block(input_source, "trackpoint"), "off"),
                "Trackball": not flag_enabled(find_block(input_source, "trackball"), "off"),
                "Tablet": not flag_enabled(find_block(input_source, "tablet"), "off"),
                "Touch": not flag_enabled(find_block(input_source, "touch"), "off"),
            },
            "animations": animation_snapshot(animation_source),
            "behavior": behavior_snapshot(
                behavior_source,
                cursor_source,
                input_source,
                switch_events_source,
            ),
            "files": {
                name: read(INCLUDE_DIR / name)
                for name in sorted(EDITABLE_NIRI_FILES)
            },
        },
        "quickshell": quickshell_settings,
    }


def replace_once(source: str, pattern: str, replacement: str, label: str, flags: int = 0) -> str:
    result, count = re.subn(pattern, replacement, source, count=1, flags=flags)
    if count != 1:
        raise ValueError(f"Could not find {label}")
    return result


def set_layout(payload: dict[str, object]) -> dict[str, object]:
    layout_path = INCLUDE_DIR / "layout.kdl"
    original = read(layout_path)
    gaps = max(0.0, min(64.0, float(payload.get("gaps", 10))))
    border_width = max(0.0, min(64.0, float(payload.get("borderWidth", 1))))
    shadow = bool(payload.get("shadow", True))
    center_focused = str(payload.get("centerFocused", "on-overflow"))
    if center_focused not in ("never", "always", "on-overflow"):
        center_focused = "on-overflow"
    default_display = str(payload.get("defaultColumnDisplay", "normal"))
    if default_display not in ("normal", "tabbed"):
        default_display = "normal"
    default_width_mode = str(payload.get("defaultColumnWidthMode", "proportion"))
    if default_width_mode not in ("auto", "proportion", "fixed"):
        default_width_mode = "proportion"
    default_width = float(payload.get("defaultColumnWidth", 1.0))
    if default_width_mode == "proportion":
        default_width = max(0.01, min(1.0, default_width))
    elif default_width_mode == "fixed":
        default_width = max(1.0, min(16384.0, default_width))
    preset_widths_enabled = bool(payload.get("presetColumnWidthsEnabled", False))
    preset_widths = str(payload.get("presetColumnWidths", "proportion 0.33333, proportion 0.5, proportion 0.66667"))
    preset_heights_enabled = bool(payload.get("presetWindowHeightsEnabled", False))
    preset_heights = str(payload.get("presetWindowHeights", "proportion 0.33333, proportion 0.5, proportion 0.66667"))
    struts_enabled = bool(payload.get("strutsEnabled", False))
    strut_left = max(-4096.0, min(4096.0, float(payload.get("strutLeft", 0))))
    strut_right = max(-4096.0, min(4096.0, float(payload.get("strutRight", 0))))
    strut_top = max(-4096.0, min(4096.0, float(payload.get("strutTop", 0))))
    strut_bottom = max(-4096.0, min(4096.0, float(payload.get("strutBottom", 0))))
    overview_zoom = max(0.1, min(1.0, float(payload.get("overviewZoom", 0.4))))
    overview_backdrop = str(payload.get("overviewBackdropColor", "#0a0a0a")).replace('"', "").strip() or "#0a0a0a"
    workspace_shadow_enabled = bool(payload.get("workspaceShadowEnabled", True))
    workspace_shadow_softness = max(0.0, min(100.0, float(payload.get("workspaceShadowSoftness", 30))))
    workspace_shadow_spread = max(0.0, min(100.0, float(payload.get("workspaceShadowSpread", 5))))
    workspace_shadow_offset_x = max(-100.0, min(100.0, float(payload.get("workspaceShadowOffsetX", 0))))
    workspace_shadow_offset_y = max(-100.0, min(100.0, float(payload.get("workspaceShadowOffsetY", 0))))
    workspace_shadow_color = str(payload.get("workspaceShadowColor", "#000000")).replace('"', "").strip() or "#000000"
    clean_color = lambda key, fallback: str(payload.get(key, fallback)).replace('"', "").strip() or fallback
    background_color = clean_color("backgroundColor", "transparent")
    border_active_color = clean_color("borderActiveColor", "#222222")
    border_inactive_color = clean_color("borderInactiveColor", "#222222")
    border_urgent_color = clean_color("borderUrgentColor", "#9b0000")
    border_gradient_enabled = bool(payload.get("borderGradientEnabled", False))
    border_active_gradient = str(payload.get("borderActiveGradient", 'from="#80c8ff" to="#c7ff7f" angle=45'))
    border_inactive_gradient = str(payload.get("borderInactiveGradient", 'from="#505050" to="#808080" angle=45'))
    border_urgent_gradient = str(payload.get("borderUrgentGradient", 'from="#800" to="#a33" angle=45'))
    focus_ring_width = max(0.0, min(64.0, float(payload.get("focusRingWidth", 4))))
    focus_ring_active_color = clean_color("focusRingActiveColor", "#7fc8ff")
    focus_ring_inactive_color = clean_color("focusRingInactiveColor", "#505050")
    focus_ring_urgent_color = clean_color("focusRingUrgentColor", "#9b0000")
    focus_gradient_enabled = bool(payload.get("focusRingGradientEnabled", False))
    focus_active_gradient = str(payload.get("focusRingActiveGradient", 'from="#80c8ff" to="#bbddff" angle=45'))
    focus_inactive_gradient = str(payload.get("focusRingInactiveGradient", 'from="#505050" to="#808080" angle=45'))
    focus_urgent_gradient = str(payload.get("focusRingUrgentGradient", 'from="#800" to="#a33" angle=45'))
    shadow_softness = max(0.0, min(100.0, float(payload.get("shadowSoftness", 20))))
    shadow_spread = max(0.0, min(100.0, float(payload.get("shadowSpread", 5))))
    shadow_offset_x = max(-100.0, min(100.0, float(payload.get("shadowOffsetX", 0))))
    shadow_offset_y = max(-100.0, min(100.0, float(payload.get("shadowOffsetY", 0))))
    shadow_draw_behind = bool(payload.get("shadowDrawBehind", True))
    shadow_color = clean_color("shadowColor", "#000000")
    shadow_inactive_color = clean_color("shadowInactiveColor", "#00000054")
    tab_gap = max(-64.0, min(64.0, float(payload.get("tabGap", 5))))
    tab_width = max(0.1, min(64.0, float(payload.get("tabWidth", 4))))
    tab_length = max(0.05, min(1.0, float(payload.get("tabLength", 1))))
    tab_position = str(payload.get("tabPosition", "right"))
    if tab_position not in ("left", "right", "top", "bottom"):
        tab_position = "right"
    tab_gaps_between = max(0.0, min(64.0, float(payload.get("tabGapsBetween", 2))))
    tab_corner_radius = max(0.0, min(256.0, float(payload.get("tabCornerRadius", 8))))
    tab_active_color = clean_color("tabActiveColor", "#7fc8ff")
    tab_inactive_color = clean_color("tabInactiveColor", "#505050")
    tab_urgent_color = clean_color("tabUrgentColor", "#9b0000")
    tab_gradient_enabled = bool(payload.get("tabGradientEnabled", False))
    tab_active_gradient = str(payload.get("tabActiveGradient", 'from="#80c8ff" to="#bbddff" angle=45'))
    tab_inactive_gradient = str(payload.get("tabInactiveGradient", 'from="#505050" to="#808080" angle=45'))
    tab_urgent_gradient = str(payload.get("tabUrgentGradient", 'from="#800" to="#a33" angle=45'))
    insert_hint_color = clean_color("insertHintColor", "#7fc8ff80")
    insert_gradient_enabled = bool(payload.get("insertHintGradientEnabled", False))
    insert_gradient = str(payload.get("insertHintGradient", 'from="#ffbb6680" to="#ffc88080" angle=45'))
    insert_gradient = str(payload.get("insertHintGradient", 'from="#ffbb6680" to="#ffc88080" angle=45'))

    blur_values = (
        ("passes", max(1, min(8, int(payload.get("blurPasses", 3))))),
        ("offset", max(0.1, min(10.0, float(payload.get("blurOffset", 3.0))))),
        ("noise", max(0.0, min(1.0, float(payload.get("blurNoise", 0.02))))),
        ("saturation", max(0.0, min(5.0, float(payload.get("blurSaturation", 1.5))))),
    )

    updated = replace_once(original, r"(?m)^(\s*gaps\s+)[\d.]+", rf"\g<1>{kdl_float(gaps)}", "layout gaps")
    updated = replace_once(updated, r"(?ms)(\bborder\s*\{.*?^\s*width\s+)[\d.]+", rf"\g<1>{kdl_float(border_width)}", "border width")
    updated = set_explicit_block_state(updated, "shadow", shadow)
    updated = replace_once(
        updated,
        r'(?m)^(\s*center-focused-column\s+)"[^"]+"',
        rf'\g<1>"{center_focused}"',
        "focused column mode",
    )
    updated = set_flag(updated, "always-center-single-column", bool(payload.get("alwaysCenterSingle", True)))
    updated = set_flag(updated, "empty-workspace-above-first", bool(payload.get("emptyWorkspaceAboveFirst", False)))
    updated = replace_once(
        updated,
        r'(?m)^(\s*background-color\s+)"[^"]*"',
        lambda match: match.group(1) + json.dumps(background_color),
        "layout background color",
    )
    updated = replace_once(
        updated,
        r'(?m)^(\s*)(?://\s*)?default-column-display\s+"[^"]+"\s*$',
        lambda match: match.group(1) + ("" if default_display == "tabbed" else "// ") + 'default-column-display "tabbed"',
        "default column display",
    )
    updated = update_block(
        updated,
        "default-column-width",
        lambda _block: (
            ""
            if default_width_mode == "auto"
            else (
                f" fixed {int(round(default_width))}; "
                if default_width_mode == "fixed"
                else f" proportion {kdl_float(default_width)}; "
            )
        ),
    )
    updated = toggle_block(updated, "preset-column-widths", preset_widths_enabled)
    updated = update_block(updated, "preset-column-widths", lambda block: render_dimension_entries(block, preset_widths, "preset column widths"))
    updated = toggle_block(updated, "preset-window-heights", preset_heights_enabled)
    updated = update_block(updated, "preset-window-heights", lambda block: render_dimension_entries(block, preset_heights, "preset window heights"))
    updated = toggle_block(updated, "struts", struts_enabled)

    def update_struts(block: str) -> str:
        result = set_number_line(block, "left", strut_left, "left strut")
        result = set_number_line(result, "right", strut_right, "right strut")
        result = set_number_line(result, "top", strut_top, "top strut")
        return set_number_line(result, "bottom", strut_bottom, "bottom strut")

    updated = update_block(updated, "struts", update_struts)
    updated = replace_once(
        updated,
        r"(?ms)(\boverview\s*\{.*?^\s*zoom\s+)[\d.]+",
        rf"\g<1>{kdl_float(overview_zoom)}",
        "overview zoom",
    )
    updated = replace_once(
        updated,
        r'(?ms)(\boverview\s*\{.*?^\s*backdrop-color\s+)"[^"]*"',
        lambda match: match.group(1) + json.dumps(overview_backdrop),
        "overview backdrop color",
    )
    updated = set_explicit_block_state(updated, "workspace-shadow", workspace_shadow_enabled)

    def update_workspace_shadow(block: str) -> str:
        result = replace_once(
            block,
            r"(?m)^(\s*softness\s+)[\d.]+",
            rf"\g<1>{kdl_float(workspace_shadow_softness)}",
            "workspace shadow softness",
        )
        result = replace_once(
            result,
            r"(?m)^(\s*spread\s+)[\d.]+",
            rf"\g<1>{kdl_float(workspace_shadow_spread)}",
            "workspace shadow spread",
        )
        result = replace_once(
            result,
            r"(?m)^(\s*offset\s+)x=[-\d.]+\s+y=[-\d.]+",
            rf"\g<1>x={kdl_float(workspace_shadow_offset_x)} y={kdl_float(workspace_shadow_offset_y)}",
            "workspace shadow offset",
        )
        return replace_once(
            result,
            r'(?m)^(\s*color\s+)"[^"]*"',
            lambda match: match.group(1) + json.dumps(workspace_shadow_color),
            "workspace shadow color",
        )

    updated = update_block(updated, "workspace-shadow", update_workspace_shadow)
    updated = set_explicit_block_state(updated, "border", bool(payload.get("borderEnabled", True)))
    updated = set_explicit_block_state(updated, "focus-ring", bool(payload.get("focusRingEnabled", False)))
    updated = set_explicit_block_state(
        updated,
        "tab-indicator",
        bool(payload.get("tabIndicatorEnabled", False)),
    )
    updated = set_explicit_block_state(
        updated,
        "insert-hint",
        bool(payload.get("insertHintEnabled", False)),
    )

    updated = toggle_block(updated, "blur", True)
    updated = set_block_flag(
        updated,
        "blur",
        "off",
        not bool(payload.get("blurEnabled", True)),
    )
    for name, value in blur_values:
        encoded = str(value) if name == "passes" else kdl_float(value)
        updated = replace_once(
            updated,
            rf"(?ms)((?:/-)?blur\s*\{{.*?^\s*{name}\s+)[\d.]+",
            rf"\g<1>{encoded}",
            f"blur {name}",
        )

    def update_border(block: str) -> str:
        result = set_string_line(block, "active-color", border_active_color, "border active color")
        result = set_string_line(result, "inactive-color", border_inactive_color, "border inactive color")
        result = set_string_line(result, "urgent-color", border_urgent_color, "border urgent color")
        result = set_optional_raw_line(result, "active-gradient", border_active_gradient, border_gradient_enabled, "border active gradient")
        result = set_optional_raw_line(result, "inactive-gradient", border_inactive_gradient, border_gradient_enabled, "border inactive gradient")
        return set_optional_raw_line(result, "urgent-gradient", border_urgent_gradient, border_gradient_enabled, "border urgent gradient")

    def update_focus_ring(block: str) -> str:
        result = set_number_line(block, "width", focus_ring_width, "focus ring width")
        result = set_string_line(result, "active-color", focus_ring_active_color, "focus ring active color")
        result = set_string_line(result, "inactive-color", focus_ring_inactive_color, "focus ring inactive color")
        result = set_string_line(result, "urgent-color", focus_ring_urgent_color, "focus ring urgent color")
        result = set_optional_raw_line(result, "active-gradient", focus_active_gradient, focus_gradient_enabled, "focus ring active gradient")
        result = set_optional_raw_line(result, "inactive-gradient", focus_inactive_gradient, focus_gradient_enabled, "focus ring inactive gradient")
        return set_optional_raw_line(result, "urgent-gradient", focus_urgent_gradient, focus_gradient_enabled, "focus ring urgent gradient")

    def update_shadow(block: str) -> str:
        result = set_number_line(block, "softness", shadow_softness, "shadow softness")
        result = set_number_line(result, "spread", shadow_spread, "shadow spread")
        result = replace_once(
            result,
            r"(?m)^([ \t]*)(?://[ \t]*)?offset\s+x=[-\d.]+\s+y=[-\d.]+",
            lambda match: f"{match.group(1)}offset x={kdl_float(shadow_offset_x)} y={kdl_float(shadow_offset_y)}",
            "shadow offset",
        )
        result = set_bool_line(result, "draw-behind-window", shadow_draw_behind, "shadow draw behind")
        result = set_string_line(result, "color", shadow_color, "shadow color")
        return set_string_line(result, "inactive-color", shadow_inactive_color, "shadow inactive color")

    def update_tab_indicator(block: str) -> str:
        result = set_flag(block, "hide-when-single-tab", bool(payload.get("tabHideSingle", True)))
        result = set_flag(result, "place-within-column", bool(payload.get("tabPlaceWithinColumn", True)))
        result = set_number_line(result, "gap", tab_gap, "tab indicator gap")
        result = set_number_line(result, "width", tab_width, "tab indicator width")
        result = set_attribute_number_line(result, "length", "total-proportion", tab_length, "tab indicator length")
        result = set_string_line(result, "position", tab_position, "tab indicator position")
        result = set_number_line(result, "gaps-between-tabs", tab_gaps_between, "tab gaps")
        result = set_number_line(result, "corner-radius", tab_corner_radius, "tab corner radius")
        result = set_string_line(result, "active-color", tab_active_color, "tab active color")
        result = set_string_line(result, "inactive-color", tab_inactive_color, "tab inactive color")
        result = set_string_line(result, "urgent-color", tab_urgent_color, "tab urgent color")
        result = set_optional_raw_line(result, "active-gradient", tab_active_gradient, tab_gradient_enabled, "tab active gradient")
        result = set_optional_raw_line(result, "inactive-gradient", tab_inactive_gradient, tab_gradient_enabled, "tab inactive gradient")
        return set_optional_raw_line(result, "urgent-gradient", tab_urgent_gradient, tab_gradient_enabled, "tab urgent gradient")

    updated = update_block(updated, "border", update_border)
    updated = update_block(updated, "focus-ring", update_focus_ring)
    updated = update_block(updated, "shadow", update_shadow)
    updated = update_block(updated, "tab-indicator", update_tab_indicator)
    updated = update_block(
        updated,
        "insert-hint",
        lambda block: set_optional_raw_line(
            set_string_line(block, "color", insert_hint_color, "insert hint color"),
            "gradient",
            insert_gradient,
            insert_gradient_enabled,
            "insert hint gradient",
        ),
    )

    # Keep the block active so its timing, previews and binds remain editable.
    # Niri disables this default-on feature through the nested `off` node.
    recent_windows_enabled = bool(payload.get("recentWindows", True))
    updated = toggle_block(updated, "recent-windows", True)
    updated = set_block_flag(updated, "recent-windows", "off", not recent_windows_enabled)
    recent_debounce = max(0, min(5000, int(payload.get("recentDebounceMs", 750))))
    recent_open_delay = max(0, min(5000, int(payload.get("recentOpenDelayMs", 150))))
    recent_active_color = str(payload.get("recentHighlightActiveColor", "#999999ff")).replace('"', "").strip() or "#999999ff"
    recent_urgent_color = str(payload.get("recentHighlightUrgentColor", "#ff9999ff")).replace('"', "").strip() or "#ff9999ff"
    recent_padding = max(0, min(256, int(payload.get("recentHighlightPadding", 30))))
    recent_corner_radius = max(0, min(256, int(payload.get("recentHighlightCornerRadius", 0))))
    recent_preview_height = max(64, min(2160, int(payload.get("recentPreviewHeight", 480))))
    recent_preview_scale = max(0.05, min(1.0, float(payload.get("recentPreviewScale", 0.5))))
    recent_binds = payload.get("recentBinds", [])
    if not isinstance(recent_binds, list):
        raise ValueError("Recent windows binds must be a list")

    def update_recent_highlight(block: str) -> str:
        result = replace_once(
            block,
            r'(?m)^(\s*active-color\s+)"[^"]*"',
            lambda match: match.group(1) + json.dumps(recent_active_color),
            "recent windows active highlight color",
        )
        result = replace_once(
            result,
            r'(?m)^(\s*urgent-color\s+)"[^"]*"',
            lambda match: match.group(1) + json.dumps(recent_urgent_color),
            "recent windows urgent highlight color",
        )
        result = replace_once(
            result,
            r"(?m)^(\s*padding\s+)[\d.]+",
            rf"\g<1>{recent_padding}",
            "recent windows highlight padding",
        )
        return replace_once(
            result,
            r"(?m)^(\s*corner-radius\s+)[\d.]+",
            rf"\g<1>{recent_corner_radius}",
            "recent windows highlight corner radius",
        )

    def update_recent_previews(block: str) -> str:
        result = replace_once(
            block,
            r"(?m)^(\s*max-height\s+)[\d.]+",
            rf"\g<1>{recent_preview_height}",
            "recent windows preview height",
        )
        return replace_once(
            result,
            r"(?m)^(\s*max-scale\s+)[\d.]+",
            rf"\g<1>{kdl_float(recent_preview_scale)}",
            "recent windows preview scale",
        )

    def render_recent_binds(_block: str) -> str:
        rendered: list[str] = []
        for binding in recent_binds:
            if not isinstance(binding, dict):
                raise ValueError("Invalid recent windows binding")
            key = str(binding.get("key", "")).strip()
            if not key or any(character in key for character in "{};\n\r"):
                raise ValueError(f"Invalid recent windows key: {key!r}")
            direction = str(binding.get("direction", "next-window"))
            if direction not in ("next-window", "previous-window"):
                direction = "next-window"
            filter_value = str(binding.get("filter", ""))
            if filter_value not in ("", "app-id"):
                filter_value = ""
            scope = str(binding.get("scope", ""))
            if scope not in ("", "all", "output", "workspace"):
                scope = ""
            attributes = ""
            if scope:
                attributes += f' scope="{scope}"'
            if filter_value:
                attributes += f' filter="{filter_value}"'
            rendered.append(f"        {key} {{ {direction}{attributes}; }}")
        return "\n" + "\n".join(rendered) + "\n    "

    def update_recent_windows(block: str) -> str:
        result = replace_once(
            block,
            r"(?m)^(\s*debounce-ms\s+)[\d.]+",
            rf"\g<1>{recent_debounce}",
            "recent windows debounce",
        )
        result = replace_once(
            result,
            r"(?m)^(\s*open-delay-ms\s+)[\d.]+",
            rf"\g<1>{recent_open_delay}",
            "recent windows open delay",
        )
        result = update_block(result, "highlight", update_recent_highlight)
        result = update_block(result, "previews", update_recent_previews)
        return update_block(result, "binds", render_recent_binds)

    updated = update_block(updated, "recent-windows", update_recent_windows)

    return apply_niri_changes({layout_path: updated}, "Niri layout applied")


def set_animation_global(payload: dict[str, object]) -> dict[str, object]:
    path = INCLUDE_DIR / "animations.kdl"
    original = read(path)
    enabled = bool(payload.get("enabled", True))
    try:
        slowdown = float(payload.get("slowdown", 1.0))
    except (TypeError, ValueError):
        slowdown = 1.0
    slowdown = max(0.05, min(10.0, slowdown))

    updated = set_flag(original, "off", not enabled)
    updated = replace_once(
        updated,
        r"(?m)^(\s*)(?://\s*)?slowdown\s+[\d.]+\s*$",
        rf"\g<1>slowdown {slowdown:g}",
        "animation slowdown",
    )
    return apply_niri_changes({path: updated}, "Animation settings applied")


def set_animation_entry(payload: dict[str, object]) -> dict[str, object]:
    path = INCLUDE_DIR / "animations.kdl"
    original = read(path)
    name = str(payload.get("name", "")).strip()
    if name not in ANIMATION_NAMES:
        return {"ok": False, "message": "Unknown animation"}
    updated = toggle_block(original, name, bool(payload.get("enabled", False)))
    return apply_niri_changes({path: updated}, f"{name} animation updated")


def set_behavior(payload: dict[str, object]) -> dict[str, object]:
    behavior_path = INCLUDE_DIR / "behavior.kdl"
    cursor_path = INCLUDE_DIR / "cursor.kdl"
    input_path = INCLUDE_DIR / "input.kdl"
    switch_events_path = INCLUDE_DIR / "switch-events.kdl"
    originals = {
        behavior_path: read(behavior_path),
        cursor_path: read(cursor_path),
        input_path: read(input_path),
        switch_events_path: read(switch_events_path),
    }
    behavior = originals[behavior_path]
    cursor = originals[cursor_path]
    input_source = originals[input_path]
    switch_events = originals[switch_events_path]

    behavior = set_flag(behavior, "skip-at-startup", not bool(payload.get("showHotkeyOverlayAtStartup", False)))
    behavior = set_flag(behavior, "prefer-no-csd", bool(payload.get("preferNoCsd", True)))
    behavior = set_flag(behavior, "hide-not-bound", bool(payload.get("hideUnboundHotkeys", False)))
    behavior = toggle_block(behavior, "clipboard", bool(payload.get("disablePrimaryClipboard", False)))
    behavior = toggle_block(behavior, "config-notification", bool(payload.get("disableConfigError", False)))
    behavior = toggle_block(behavior, "xwayland-satellite", bool(payload.get("xwaylandEnabled", False)))
    xwayland_path = str(payload.get("xwaylandPath", "xwayland-satellite")).strip() or "xwayland-satellite"
    behavior = update_block(
        behavior,
        "xwayland-satellite",
        lambda block: set_string_line(block, "path", xwayland_path, "Xwayland path"),
    )
    # Keep the quality block active and express the effective state through
    # Niri's default-on `off` flag.

    switch_events = toggle_block(switch_events, "switch-events", bool(payload.get("switchEvents", False)))

    screenshot_path = str(payload.get("screenshotPath", "")).strip()
    screenshot_enabled = bool(payload.get("screenshotSavingEnabled", True))
    if screenshot_enabled and not screenshot_path:
        screenshot_path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png"
    screenshot_value = json.dumps(screenshot_path, ensure_ascii=False) if screenshot_enabled else "null"
    behavior = replace_once(
        behavior,
        r"(?m)^(\s*)screenshot-path\s+(?:null|\"(?:\\.|[^\"])*\")\s*$",
        lambda match: match.group(1) + "screenshot-path " + screenshot_value,
        "screenshot path",
    )



    cursor = set_flag(cursor, "hide-when-typing", bool(payload.get("hideCursorWhileTyping", False)))
    timeout = max(100, min(600000, int(payload.get("cursorTimeoutMs", 1000))))
    timeout_enabled = bool(payload.get("cursorTimeoutEnabled", False))
    cursor = replace_once(
        cursor,
        r"(?m)^(\s*)(?://\s*)?hide-after-inactive-ms\s+\d+\s*$",
        rf"\g<1>{'' if timeout_enabled else '// '}hide-after-inactive-ms {timeout}",
        "cursor inactivity timeout",
    )
    cursor_theme = str(payload.get("cursorTheme", "")).strip() or "default"
    cursor_size = max(8, min(128, int(payload.get("cursorSize", 24))))
    cursor = replace_once(
        cursor,
        r'(?m)^(\s*xcursor-theme\s+)"[^"]+"',
        lambda match: match.group(1) + json.dumps(cursor_theme, ensure_ascii=False),
        "cursor theme",
    )
    cursor = replace_once(cursor, r"(?m)^(\s*xcursor-size\s+)\d+", rf"\g<1>{cursor_size}", "cursor size")

    input_source = set_flag(
        input_source,
        "disable-power-key-handling",
        bool(payload.get("disablePowerKeyHandling", False)),
    )
    warp_mode = str(payload.get("warpMouseMode", "separate"))
    if warp_mode not in ("separate", "center-xy", "center-xy-always"):
        warp_mode = "separate"
    warp_suffix = "" if warp_mode == "separate" else f'mode="{warp_mode}"'
    input_source = set_unique_option_line(
        input_source,
        "warp-mouse-to-focus",
        bool(payload.get("warpMouseToFocus", False)),
        warp_suffix,
    )
    max_scroll_raw = str(payload.get("focusFollowsMaxScrollAmount", "0%")).strip()
    max_scroll_match = re.fullmatch(r"(\d+(?:\.\d+)?)%", max_scroll_raw)
    max_scroll = min(100.0, max(0.0, float(max_scroll_match.group(1)))) if max_scroll_match else 0.0
    max_scroll_text = f"{max_scroll:g}%"
    input_source = set_unique_option_line(
        input_source,
        "focus-follows-mouse",
        bool(payload.get("focusFollowsMouse", False)),
        f'max-scroll-amount="{max_scroll_text}"',
    )
    input_source = set_flag(
        input_source,
        "workspace-auto-back-and-forth",
        bool(payload.get("workspaceAutoBackAndForth", False)),
    )
    valid_modifiers = {"", "Super", "Alt", "Mod3", "Mod5", "Ctrl", "Shift"}
    mod_key = str(payload.get("modKey", "")).strip()
    mod_key_nested = str(payload.get("modKeyNested", "")).strip()
    if mod_key not in valid_modifiers or mod_key_nested not in valid_modifiers:
        raise ValueError("Invalid Niri modifier")
    input_source = set_unique_option_line(input_source, "mod-key", bool(mod_key), json.dumps(mod_key) if mod_key else '"Super"')
    input_source = set_unique_option_line(input_source, "mod-key-nested", bool(mod_key_nested), json.dumps(mod_key_nested) if mod_key_nested else '"Alt"')

    dnd_view_trigger_width = max(1, min(1000, int(payload.get("dndViewTriggerWidth", 30))))
    dnd_view_delay = max(0, min(60000, int(payload.get("dndViewDelayMs", 100))))
    dnd_view_max_speed = max(1, min(100000, int(payload.get("dndViewMaxSpeed", 1500))))
    dnd_workspace_trigger_height = max(1, min(1000, int(payload.get("dndWorkspaceTriggerHeight", 50))))
    dnd_workspace_delay = max(0, min(60000, int(payload.get("dndWorkspaceDelayMs", 100))))
    dnd_workspace_max_speed = max(1, min(100000, int(payload.get("dndWorkspaceMaxSpeed", 1500))))
    hot_corners_enabled = bool(payload.get("hotCornersEnabled", True))
    hot_corner_top_left = bool(payload.get("hotCornerTopLeft", True))
    hot_corner_top_right = bool(payload.get("hotCornerTopRight", False))
    hot_corner_bottom_left = bool(payload.get("hotCornerBottomLeft", False))
    hot_corner_bottom_right = bool(payload.get("hotCornerBottomRight", False))
    if hot_corners_enabled and not any((
        hot_corner_top_left,
        hot_corner_top_right,
        hot_corner_bottom_left,
        hot_corner_bottom_right,
    )):
        hot_corner_top_left = True

    def update_gestures(block: str) -> str:
        block = update_block(
            block,
            "dnd-edge-view-scroll",
            lambda inner: set_integer_line(
                set_integer_line(
                    set_integer_line(inner, "trigger-width", dnd_view_trigger_width, "DnD view trigger width"),
                    "delay-ms",
                    dnd_view_delay,
                    "DnD view delay",
                ),
                "max-speed",
                dnd_view_max_speed,
                "DnD view maximum speed",
            ),
        )
        block = update_block(
            block,
            "dnd-edge-workspace-switch",
            lambda inner: set_integer_line(
                set_integer_line(
                    set_integer_line(
                        inner,
                        "trigger-height",
                        dnd_workspace_trigger_height,
                        "DnD workspace trigger height",
                    ),
                    "delay-ms",
                    dnd_workspace_delay,
                    "DnD workspace delay",
                ),
                "max-speed",
                dnd_workspace_max_speed,
                "DnD workspace maximum speed",
            ),
        )

        def update_hot_corners(inner: str) -> str:
            inner = set_flag(inner, "off", not hot_corners_enabled)
            inner = set_flag(inner, "top-left", hot_corner_top_left)
            inner = set_flag(inner, "top-right", hot_corner_top_right)
            inner = set_flag(inner, "bottom-left", hot_corner_bottom_left)
            return set_flag(inner, "bottom-right", hot_corner_bottom_right)

        return update_block(block, "hot-corners", update_hot_corners)

    behavior = update_block(behavior, "gestures", update_gestures)

    switch_events = set_event_action(switch_events, "lid-close", str(payload.get("lidCloseAction", "")))
    switch_events = set_event_action(switch_events, "lid-open", str(payload.get("lidOpenAction", "")))
    switch_events = set_event_action(switch_events, "tablet-mode-on", str(payload.get("tabletModeOnAction", "")))
    switch_events = set_event_action(switch_events, "tablet-mode-off", str(payload.get("tabletModeOffAction", "")))

    updated_files = {
        behavior_path: behavior,
        cursor_path: cursor,
        input_path: input_source,
        switch_events_path: switch_events,
    }
    return apply_niri_changes(updated_files, "Niri behavior applied")


def set_niri_file(payload: dict[str, object]) -> dict[str, object]:
    name = str(payload.get("fileName", "")).strip()
    if name not in EDITABLE_NIRI_FILES:
        return {"ok": False, "message": "This Niri file is not editable here"}
    content = str(payload.get("content", ""))
    if not content.strip():
        return {"ok": False, "message": "Config file cannot be empty"}
    if not content.endswith("\n"):
        content += "\n"
    path = INCLUDE_DIR / name
    return apply_niri_changes({path: content}, f"{name} applied")


def set_keybind(payload: dict[str, object]) -> dict[str, object]:
    path = INCLUDE_DIR / "keybinds.kdl"
    original = read(path)
    old_header = str(payload.get("oldHeader", "")).strip()
    new_key = str(payload.get("newKey", "")).strip()
    if not old_header or not new_key:
        return {"ok": False, "message": "A key combination is required"}
    if not re.fullmatch(r"[A-Za-z0-9_+\-]+", new_key):
        return {"ok": False, "message": "The captured key combination is not valid for Niri"}

    old_key = old_header.split()[0]
    binding_pattern = re.compile(r"^\s*([^/{][^{]*?)\s*\{")
    for raw in original.splitlines():
        match = binding_pattern.match(raw)
        if not match:
            continue
        header = match.group(1).strip()
        if header != old_header and header.split()[0] == new_key:
            return {"ok": False, "message": f"{pretty_key(new_key)} is already assigned"}

    lines = original.splitlines(keepends=True)
    replaced = False
    for index, raw in enumerate(lines):
        match = binding_pattern.match(raw)
        if not match or match.group(1).strip() != old_header:
            continue
        header_start, header_end = match.span(1)
        option_suffix = old_header[len(old_key):]
        lines[index] = raw[:header_start] + new_key + option_suffix + raw[header_end:]
        replaced = True
        break
    if not replaced:
        return {"ok": False, "message": "The keybind changed on disk; refresh and try again"}

    return apply_niri_changes(
        {path: "".join(lines)}, f"Keybind changed to {pretty_key(new_key)}"
    )


def update_input_entry(original: str, block_name: str, entry_index: int, updater) -> str:
    block_match = re.search(rf"(?m)^\s*{re.escape(block_name)}\s*\{{", original)
    if not block_match:
        raise ValueError(f"Could not find the {block_name} block")
    start = block_match.end()
    depth = 1
    end = -1
    for offset in range(start, len(original)):
        if original[offset] == "{":
            depth += 1
        elif original[offset] == "}":
            depth -= 1
            if depth == 0:
                end = offset
                break
    if end < 0:
        raise ValueError(f"The {block_name} block is incomplete")

    block = original[start:end]
    lines = block.splitlines(keepends=True)
    active_index = -1
    replaced = False
    for index, raw in enumerate(lines):
        parsed = parse_input_line(raw)
        if parsed is None:
            continue
        active_index += 1
        if active_index != entry_index:
            continue
        lines[index] = updater(raw, parsed)
        replaced = True
        break
    if not replaced:
        raise ValueError("The input setting changed on disk; refresh and try again")
    return original[:start] + "".join(lines) + original[end:]


def set_input(payload: dict[str, object]) -> dict[str, object]:
    path = INCLUDE_DIR / "input.kdl"
    original = read(path)
    section = str(payload.get("section", "")).strip()
    entry_index = int(payload.get("entryIndex", -1))
    new_line = str(payload.get("value", "")).strip().rstrip(";")
    block_name = INPUT_SECTION_NAMES.get(section)
    if not block_name or entry_index < 0:
        return {"ok": False, "message": "Unknown input setting"}
    if not new_line or "\n" in new_line or any(char in new_line for char in "{}"):
        return {"ok": False, "message": "Input values must be a single KDL setting"}

    def replace_value(raw: str, parsed: tuple[str, bool]) -> str:
        _, enabled = parsed
        indent = raw[: len(raw) - len(raw.lstrip())]
        ending = "\n" if raw.endswith("\n") else ""
        prefix = "" if enabled else "// "
        return indent + prefix + new_line + ending

    try:
        updated = update_input_entry(original, block_name, entry_index, replace_value)
    except ValueError as error:
        return {"ok": False, "message": str(error)}
    return apply_niri_changes({path: updated}, f"{section} setting updated")


def set_input_enabled(payload: dict[str, object]) -> dict[str, object]:
    path = INCLUDE_DIR / "input.kdl"
    original = read(path)
    section = str(payload.get("section", "")).strip()
    block_names = {
        name: block
        for name, block in INPUT_SECTION_NAMES.items()
        if name != "Keyboard"
    }
    block_name = block_names.get(section)
    if not block_name:
        return {"ok": False, "message": "This input section cannot be disabled"}
    updated = set_block_flag(original, block_name, "off", not bool(payload.get("enabled", True)))
    return apply_niri_changes({path: updated}, f"{section} state updated")


def set_input_entry_enabled(payload: dict[str, object]) -> dict[str, object]:
    path = INCLUDE_DIR / "input.kdl"
    original = read(path)
    section = str(payload.get("section", "")).strip()
    entry_index = int(payload.get("entryIndex", -1))
    enabled = bool(payload.get("enabled", True))
    block_name = INPUT_SECTION_NAMES.get(section)
    if not block_name or entry_index < 0:
        return {"ok": False, "message": "Unknown input setting"}

    def toggle_value(raw: str, parsed: tuple[str, bool]) -> str:
        text, _ = parsed
        indent = raw[: len(raw) - len(raw.lstrip())]
        ending = "\n" if raw.endswith("\n") else ""
        return indent + ("" if enabled else "// ") + text + ending

    try:
        updated = update_input_entry(original, block_name, entry_index, toggle_value)
    except ValueError as error:
        return {"ok": False, "message": str(error)}
    return apply_niri_changes({path: updated}, f"{section} option updated")


def set_quickshell(payload: dict[str, object]) -> dict[str, object]:
    defaults: dict[str, object] = {
        "fontName": "Inter",
        "greeterDefaultSession": "niri",
        "greeterRememberLastSession": False,
        "audioMaxVolume": 1.0,
        "barDensity": "comfortable",
        "barHeight": 50,
        "barShowActiveClient": True,
        "barShowBattery": True,
        "barShowBluetooth": True,
        "barShowClock": True,
        "barShowMedia": True,
        "barShowMicrophone": True,
        "barShowNetwork": True,
        "barShowNotifications": True,
        "barShowRecording": True,
        "barShowSysTray": True,
        "barShowWeather": True,
        "barShowWorkspaces": True,
        "caffeineAutoDisableMinutes": 0,
        "cavaEnabled": True,
        "idleBatteryDisplayTimeout": 300,
        "idleBatteryLockTimeout": 300,
        "idleBatterySleepAction": "suspend",
        "idleBatterySuspendTimeout": 900,
        "idleDimDuration": 5,
        "idleDimOpacity": 0.55,
        "idleDisplayTimeout": 600,
        "idleEnabled": True,
        "idleLockBeforeSleep": True,
        "idleLockedDisplayTimeout": 60,
        "idleLockTimeout": 600,
        "idleRespectInhibitors": True,
        "idleSeparatePowerProfiles": False,
        "idleSleepAction": "suspend",
        "idleSuspendTimeout": 0,
        "lockFaceMaxAttempts": 3,
        "lockFaceRetryOnWake": True,
        "launcherCalculatorAngleMode": "rad",
        "launcherCalculatorEnabled": True,
        "launcherCalculatorPrefix": "=",
        "launcherClipboardAutoPaste": True,
        "launcherClipboardEnabled": True,
        "launcherClipboardPrefix": "c",
        "launcherEmojiEnabled": True,
        "launcherEmojiPrefix": "e",
        "launcherFilesEnabled": True,
        "launcherFilesPrefix": "f",
        "launcherFuzzySearch": True,
        "launcherGifEnabled": True,
        "launcherGifPrefix": "g",
        "launcherKlipyApiKey": "",
        "launcherMaxResults": 20,
        "launcherStickerEnabled": True,
        "launcherStickerPrefix": "s",
        "notificationBlockedApps": "",
        "notificationCriticalTimeout": 0,
        "notificationDndEnd": "07:00",
        "notificationDndScheduleEnabled": False,
        "notificationDndStart": "23:00",
        "notificationHistoryExcludedApps": "",
        "notificationHistoryLimit": 100,
        "notificationLowTimeout": 5000,
        "notificationLockscreenPrivacy": "hidden",
        "notificationMaxVisible": 3,
        "notificationNormalTimeout": 5000,
        "notificationPopupDuration": 5000,
        "notificationPosition": "top",
        "notificationShowInFullscreen": True,
        "notificationShowOnLock": False,
        "osdDuration": 2000,
        "osdEnabled": True,
        "osdPosition": "bottom",
        "osdShowBrightness": True,
        "osdShowMicrophone": True,
        "osdShowVolume": True,
        "profileImagePath": "",
        "shellAnimationScale": 1.0,
        "shellBlurBarEnabled": True,
        "shellBlurBarOpacityDark": 0.24,
        "shellBlurBarOpacityLight": 0.86,
        "shellBlurControlLeftEnabled": True,
        "shellBlurControlRightEnabled": True,
        "shellBlurDockEnabled": True,
        "shellBlurLauncherEnabled": True,
        "shellBlurNotificationEnabled": True,
        "shellBlurOsdEnabled": True,
        "shellBlurPanelOpacityDark": 0.76,
        "shellBlurPanelOpacityLight": 0.88,
        "shellBlurSettingsEnabled": True,
        "shellComponentShadowBlur": 10.0,
        "shellComponentShadowEnabled": True,
        "shellComponentShadowOffsetX": 0.0,
        "shellComponentShadowOffsetY": 2.0,
        "shellComponentShadowOpacity": 0.18,
        "shellComponentShadowSpread": 0.0,
        "shellLowPowerMode": False,
        "shellReducedMotion": False,
        "shellShadowBlur": 18.0,
        "shellShadowEnabled": True,
        "shellShadowOffsetX": 0.0,
        "shellShadowOffsetY": 3.0,
        "shellShadowOpacity": 0.28,
        "shellShadowSpread": 1.0,
        "latLon": "",
        "apiWeather": "",
        "steamUsername": "",
        "steamWebApiKey": "",
        "wallhavenUsername": "",
        "wallhavenApiKey": "",
        "wallhavenShowNsfw": False,
        "wallpaperWorkshopShowNsfw": False,
        "wallFolderPath": "~/Dotfiles/dotf/.walls",
        "liveWallFolderPath": "~/Dotfiles/dotf/.walls/live",
        "wallpaperBatteryFps": 20,
        "wallpaperEngineFps": 30,
        "wallpaperPauseOnFullscreen": True,
        "wallpaperPauseOnLock": True,
        "wallpaperScalingMode": "fill",
        "wallpaperTransitionDuration": 360,
        "matugenEnabled": True,
        "matugenAnimateColors": True,
        "matugenTransitionDuration": 300,
        "captureScreenshotDirPath": "~/Pictures/Screenshots",
        "captureRecordingDirPath": "~/Videos",
        "captureAutoCopyScreenshot": True,
        "captureAutoCopyRecording": True,
        "captureRecordingFps": 60,
        "captureRecordingCodec": "hevc",
        "captureRecordingCountdown": 0,
        "captureRecordingCursor": True,
        "captureRecordingQuality": "high",
        "captureRecordingMicrophone": False,
        "captureRecordingMicrophoneSource": "default_input",
        "captureRecordingMode": "region",
        "captureScreenshotAction": "notification",
        "captureScreenshotFilenameTemplate": "{date}_{time}-edited",
        "captureScreenshotFormat": "png",
        "captureScreenshotQuality": 90,
        "captureEditorTool": "pen",
        "captureEditorColor": "#ff3b30",
        "captureEditorWidth": 6,
        "wallpaperEngineAssetsDirPath": "~/.local/share/Steam/steamapps/common/wallpaper_engine/assets",
        "wallpaperEngineWorkshopDirPath": "~/.local/share/Steam/steamapps/workshop/content/431960",
        "clock24h": True,
        "temperatureUnit": "celsius",
    }
    stored: dict[str, object] = {}
    if RUNTIME_SETTINGS_PATH.exists():
        try:
            decoded = json.loads(RUNTIME_SETTINGS_PATH.read_text(encoding="utf-8"))
            if isinstance(decoded, dict):
                stored = decoded
        except (OSError, json.JSONDecodeError):
            stored = {}

    legacy_notification_timeout = stored.get("notificationPopupDuration", defaults["notificationPopupDuration"])
    if "notificationLowTimeout" not in stored:
        stored["notificationLowTimeout"] = legacy_notification_timeout
    if "notificationNormalTimeout" not in stored:
        stored["notificationNormalTimeout"] = legacy_notification_timeout
    if str(stored.get("notificationLockscreenPrivacy", "")).lower() not in ("hidden", "icons", "full"):
        stored["notificationLockscreenPrivacy"] = "full" if bool(stored.get("notificationShowOnLock", False)) else "hidden"
    if str(payload.get("notificationLockscreenPrivacy", "")).lower() not in ("hidden", "icons", "full") and "notificationShowOnLock" in payload:
        payload["notificationLockscreenPrivacy"] = "full" if bool(payload.get("notificationShowOnLock")) else "hidden"

    legacy_blur = bool(stored.get("shellBlurEnabled", True))
    for key in (
        "shellBlurBarEnabled",
        "shellBlurControlLeftEnabled",
        "shellBlurControlRightEnabled",
        "shellBlurDockEnabled",
        "shellBlurLauncherEnabled",
        "shellBlurNotificationEnabled",
        "shellBlurOsdEnabled",
        "shellBlurSettingsEnabled",
    ):
        if key not in stored:
            stored[key] = legacy_blur

    merged = defaults.copy()
    merged.update({key: value for key, value in stored.items() if key in defaults})
    merged.update({key: value for key, value in payload.items() if key in defaults})
    settings = merged.copy()

    for name in (
        "fontName", "greeterDefaultSession", "profileImagePath", "latLon", "apiWeather", "steamUsername", "steamWebApiKey",
        "launcherKlipyApiKey",
        "wallhavenUsername", "wallhavenApiKey", "wallFolderPath", "liveWallFolderPath",
        "wallpaperScalingMode",
        "captureScreenshotDirPath", "captureRecordingDirPath", "captureRecordingCodec",
        "captureRecordingQuality", "captureRecordingMicrophoneSource", "captureRecordingMode",
        "captureScreenshotAction", "captureScreenshotFilenameTemplate", "captureScreenshotFormat",
        "captureEditorTool", "captureEditorColor",
        "wallpaperEngineAssetsDirPath", "wallpaperEngineWorkshopDirPath",
        "notificationBlockedApps", "notificationHistoryExcludedApps", "notificationLockscreenPrivacy",
    ):
        settings[name] = str(merged.get(name, defaults[name])).strip()
    settings["fontName"] = settings["fontName"] or "Inter"
    greeter_session = re.sub(r"[^A-Za-z0-9._+-]", "", settings["greeterDefaultSession"][:80])
    settings["greeterDefaultSession"] = greeter_session or "niri"

    prefix_defaults = (
        ("launcherClipboardPrefix", "c"),
        ("launcherFilesPrefix", "f"),
        ("launcherCalculatorPrefix", "="),
        ("launcherEmojiPrefix", "e"),
        ("launcherGifPrefix", "g"),
        ("launcherStickerPrefix", "s"),
    )
    used_prefixes: set[str] = set()
    available_fallbacks = [fallback for _, fallback in prefix_defaults]
    for name, fallback in prefix_defaults:
        prefix = re.sub(r"\s+", "", str(merged.get(name, fallback)))
        candidate = prefix[:3] if prefix else fallback
        if candidate.casefold() in used_prefixes:
            candidate = next(
                (value for value in available_fallbacks if value.casefold() not in used_prefixes),
                fallback,
            )
        settings[name] = candidate
        used_prefixes.add(candidate.casefold())

    for name, fallback in (("notificationDndStart", "23:00"), ("notificationDndEnd", "07:00")):
        value = str(merged.get(name, fallback)).strip()
        settings[name] = value if re.fullmatch(r"(?:[01]\d|2[0-3]):[0-5]\d", value) else fallback

    settings["barDensity"] = str(merged.get("barDensity", "comfortable"))
    if settings["barDensity"] not in ("compact", "comfortable", "spacious"):
        settings["barDensity"] = "comfortable"
    settings["launcherCalculatorAngleMode"] = str(
        merged.get("launcherCalculatorAngleMode", "rad")
    ).lower()
    if settings["launcherCalculatorAngleMode"] not in ("deg", "rad"):
        settings["launcherCalculatorAngleMode"] = "rad"
    settings["temperatureUnit"] = str(merged.get("temperatureUnit", "celsius")).lower()
    if settings["temperatureUnit"] not in ("celsius", "fahrenheit"):
        settings["temperatureUnit"] = "celsius"
    settings["wallpaperScalingMode"] = str(merged.get("wallpaperScalingMode", "fill")).lower()
    if settings["wallpaperScalingMode"] not in ("fill", "fit", "stretch"):
        settings["wallpaperScalingMode"] = "fill"
    for name in ("idleSleepAction", "idleBatterySleepAction"):
        settings[name] = str(merged.get(name, "suspend")).lower()
        if settings[name] not in ("none", "suspend", "suspend-then-hibernate", "hibernate"):
            settings[name] = "suspend"
    settings["notificationPosition"] = str(merged.get("notificationPosition", "top"))
    if settings["notificationPosition"] not in ("top", "top-right", "bottom-right"):
        settings["notificationPosition"] = "top"
    settings["notificationLockscreenPrivacy"] = str(merged.get("notificationLockscreenPrivacy", "hidden")).lower()
    if settings["notificationLockscreenPrivacy"] not in ("hidden", "icons", "full"):
        settings["notificationLockscreenPrivacy"] = "hidden"
    settings["notificationShowOnLock"] = settings["notificationLockscreenPrivacy"] != "hidden"
    settings["osdPosition"] = str(merged.get("osdPosition", "bottom"))
    if settings["osdPosition"] not in ("top", "bottom"):
        settings["osdPosition"] = "bottom"
    if settings["captureRecordingCodec"] not in ("h264", "hevc"):
        settings["captureRecordingCodec"] = "hevc"
    if settings["captureRecordingQuality"] not in ("medium", "high", "very_high"):
        settings["captureRecordingQuality"] = "high"
    if settings["captureRecordingMode"] not in ("region", "screen"):
        settings["captureRecordingMode"] = "region"
    if settings["captureScreenshotAction"] not in ("notification", "editor", "copy", "save"):
        settings["captureScreenshotAction"] = "notification"
    if settings["captureScreenshotFormat"] not in ("png", "jpeg", "webp"):
        settings["captureScreenshotFormat"] = "png"
    microphone_source = settings["captureRecordingMicrophoneSource"].replace("\x00", "").strip()
    settings["captureRecordingMicrophoneSource"] = microphone_source[:512] or "default_input"
    filename_template = settings["captureScreenshotFilenameTemplate"].replace("\x00", "").strip()
    filename_template = filename_template.replace("/", "-").replace("\\", "-")
    settings["captureScreenshotFilenameTemplate"] = filename_template[:128] or "{date}_{time}-edited"
    if settings["captureEditorTool"] not in (
        "select", "pen", "line", "rectangle", "ellipse", "arrow", "highlight",
        "blur", "pixelate", "text", "number", "callout", "loupe", "crop", "ocr", "eraser",
    ):
        settings["captureEditorTool"] = "pen"

    try:
        recording_countdown = int(merged.get("captureRecordingCountdown", 0))
    except (TypeError, ValueError):
        recording_countdown = 0
    settings["captureRecordingCountdown"] = recording_countdown if recording_countdown in (0, 3, 5, 10) else 0

    for name, minimum, maximum, fallback in (
        ("barHeight", 40, 72, 50),
        ("caffeineAutoDisableMinutes", 0, 720, 0),
        ("idleBatteryDisplayTimeout", 0, 86400, 300),
        ("idleBatteryLockTimeout", 0, 86400, 300),
        ("idleBatterySuspendTimeout", 0, 86400, 900),
        ("idleDimDuration", 0, 30, 5),
        ("idleDisplayTimeout", 0, 86400, 600),
        ("idleLockedDisplayTimeout", 0, 86400, 60),
        ("idleLockTimeout", 0, 86400, 600),
        ("idleSuspendTimeout", 0, 86400, 0),
        ("lockFaceMaxAttempts", 1, 3, 3),
        ("launcherMaxResults", 5, 50, 20),
        ("notificationCriticalTimeout", 0, 60000, 0),
        ("notificationHistoryLimit", 0, 500, 100),
        ("notificationLowTimeout", 0, 60000, 5000),
        ("notificationMaxVisible", 1, 6, 3),
        ("notificationNormalTimeout", 0, 60000, 5000),
        ("notificationPopupDuration", 1000, 30000, 5000),
        ("osdDuration", 500, 10000, 2000),
        ("wallpaperBatteryFps", 5, 60, 20),
        ("wallpaperEngineFps", 5, 165, 30),
        ("wallpaperTransitionDuration", 0, 2000, 360),
        ("matugenTransitionDuration", 0, 2000, 300),
        ("captureRecordingFps", 5, 165, 60),
        ("captureScreenshotQuality", 1, 100, 90),
        ("captureEditorWidth", 1, 96, 6),
    ):
        try:
            value = int(merged.get(name, fallback))
        except (TypeError, ValueError):
            value = fallback
        settings[name] = max(minimum, min(maximum, value))

    for name, minimum, maximum, fallback in (
        ("audioMaxVolume", 0.5, 1.5, 1.0),
        ("idleDimOpacity", 0.2, 0.9, 0.55),
        ("shellAnimationScale", 0.0, 2.0, 1.0),
        ("shellBlurBarOpacityDark", 0.0, 1.0, 0.24),
        ("shellBlurBarOpacityLight", 0.0, 1.0, 0.86),
        ("shellBlurPanelOpacityDark", 0.0, 1.0, 0.76),
        ("shellBlurPanelOpacityLight", 0.0, 1.0, 0.88),
        ("shellComponentShadowBlur", 0.0, 64.0, 10.0),
        ("shellComponentShadowOffsetX", -32.0, 32.0, 0.0),
        ("shellComponentShadowOffsetY", -32.0, 32.0, 2.0),
        ("shellComponentShadowOpacity", 0.0, 1.0, 0.18),
        ("shellComponentShadowSpread", -32.0, 32.0, 0.0),
        ("shellShadowBlur", 0.0, 64.0, 18.0),
        ("shellShadowOffsetX", -32.0, 32.0, 0.0),
        ("shellShadowOffsetY", -32.0, 32.0, 3.0),
        ("shellShadowOpacity", 0.0, 1.0, 0.28),
        ("shellShadowSpread", -32.0, 32.0, 1.0),
    ):
        try:
            value = float(merged.get(name, fallback))
        except (TypeError, ValueError):
            value = fallback
        settings[name] = max(minimum, min(maximum, value))

    for name, fallback in (
        ("barShowActiveClient", True),
        ("barShowBattery", True),
        ("barShowBluetooth", True),
        ("barShowClock", True),
        ("barShowMedia", True),
        ("barShowMicrophone", True),
        ("barShowNetwork", True),
        ("barShowNotifications", True),
        ("barShowRecording", True),
        ("barShowSysTray", True),
        ("barShowWeather", True),
        ("barShowWorkspaces", True),
        ("cavaEnabled", True),
        ("idleEnabled", True),
        ("idleLockBeforeSleep", True),
        ("idleRespectInhibitors", True),
        ("idleSeparatePowerProfiles", False),
        ("lockFaceRetryOnWake", True),
        ("launcherCalculatorEnabled", True),
        ("launcherClipboardAutoPaste", True),
        ("launcherClipboardEnabled", True),
        ("launcherEmojiEnabled", True),
        ("launcherFilesEnabled", True),
        ("launcherFuzzySearch", True),
        ("launcherGifEnabled", True),
        ("launcherStickerEnabled", True),
        ("notificationDndScheduleEnabled", False),
        ("notificationShowInFullscreen", True),
        ("osdEnabled", True),
        ("osdShowBrightness", True),
        ("osdShowMicrophone", True),
        ("osdShowVolume", True),
        ("shellBlurBarEnabled", True),
        ("shellBlurControlLeftEnabled", True),
        ("shellBlurControlRightEnabled", True),
        ("shellBlurDockEnabled", True),
        ("shellBlurLauncherEnabled", True),
        ("shellBlurNotificationEnabled", True),
        ("shellBlurOsdEnabled", True),
        ("shellBlurSettingsEnabled", True),
        ("shellComponentShadowEnabled", True),
        ("shellLowPowerMode", False),
        ("shellReducedMotion", False),
        ("shellShadowEnabled", True),
        ("wallpaperPauseOnFullscreen", True),
        ("wallpaperPauseOnLock", True),
        ("matugenEnabled", True),
        ("matugenAnimateColors", True),
        ("captureAutoCopyScreenshot", True),
        ("captureAutoCopyRecording", True),
        ("captureRecordingMicrophone", False),
        ("captureRecordingCursor", True),
        ("clock24h", True),
        ("wallhavenShowNsfw", False),
        ("wallpaperWorkshopShowNsfw", False),
        ("greeterRememberLastSession", False),
    ):
        settings[name] = bool(merged.get(name, fallback))

    settings["notificationShowOnLock"] = settings["notificationLockscreenPrivacy"] != "hidden"

    behavior_path = INCLUDE_DIR / "behavior.kdl"
    behavior_original = read(behavior_path)
    screenshot_dir = str(settings["captureScreenshotDirPath"]).rstrip("/") or "~/Pictures/Screenshots"
    screenshot_pattern = screenshot_dir + "/Screenshot from %Y-%m-%d %H-%M-%S.png"
    behavior_updated = replace_once(
        behavior_original,
        r'(?m)^(\s*screenshot-path\s+)"[^"]*"\s*$',
        lambda match: match.group(1) + json.dumps(screenshot_pattern, ensure_ascii=False),
        "Niri screenshot path",
    )
    if behavior_updated != behavior_original:
        result = apply_niri_changes(
            {behavior_path: behavior_updated},
            "SownteeShell Settings and Niri screenshot path saved",
        )
        if not result["ok"]:
            return result

    atomic_write(
        RUNTIME_SETTINGS_PATH,
        json.dumps(settings, ensure_ascii=False, indent=2) + "\n",
    )
    os.chmod(RUNTIME_SETTINGS_PATH, 0o600)
    return {"ok": True, "message": "SownteeShell Settings applied"}


def load_payload(path: str) -> dict[str, object]:
    if path == "-":
        # Accept both the current newline-delimited protocol and older live
        # Quickshell singletons that wrote JSON without closing stdin. Return
        # as soon as one complete object has arrived instead of waiting for EOF.
        payload = ""
        while True:
            character = sys.stdin.read(1)
            if character == "":
                if not payload.strip():
                    raise ValueError("Settings payload was empty")
                return json.loads(payload)
            payload += character
            if character not in "}]":
                continue
            try:
                decoded = json.loads(payload)
            except json.JSONDecodeError:
                continue
            if not isinstance(decoded, dict):
                raise ValueError("Settings payload must be a JSON object")
            return decoded
    payload_path = Path(path)
    try:
        payload_path.chmod(0o600)
        return json.loads(payload_path.read_text(encoding="utf-8"))
    finally:
        # Payloads can contain API keys. They are one-shot IPC files, not state.
        payload_path.unlink(missing_ok=True)


def main() -> int:
    try:
        command = sys.argv[1] if len(sys.argv) > 1 else "snapshot"
        if command == "snapshot":
            result = snapshot()
        elif command == "set-layout":
            result = set_layout(load_payload(sys.argv[2]))
        elif command == "set-keybind":
            result = set_keybind(load_payload(sys.argv[2]))
        elif command == "set-input":
            result = set_input(load_payload(sys.argv[2]))
        elif command == "set-input-enabled":
            result = set_input_enabled(load_payload(sys.argv[2]))
        elif command == "set-input-entry-enabled":
            result = set_input_entry_enabled(load_payload(sys.argv[2]))
        elif command == "set-animation-global":
            result = set_animation_global(load_payload(sys.argv[2]))
        elif command == "set-animation-entry":
            result = set_animation_entry(load_payload(sys.argv[2]))
        elif command == "set-behavior":
            result = set_behavior(load_payload(sys.argv[2]))
        elif command == "set-niri-file":
            result = set_niri_file(load_payload(sys.argv[2]))
        elif command == "set-quickshell":
            result = set_quickshell(load_payload(sys.argv[2]))
        else:
            raise ValueError(f"Unknown command: {command}")
        print(json.dumps(result, ensure_ascii=False))
        return 0 if result.get("ok", True) else 1
    except Exception as error:  # Keep QML error reporting machine-readable.
        print(json.dumps({"ok": False, "message": str(error)}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
