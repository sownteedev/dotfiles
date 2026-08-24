#!/usr/bin/env python3

import configparser
import json
import os
import re
import shlex
import shutil
from pathlib import Path


SESSION_DIRS = (
    Path("/usr/local/share/wayland-sessions"),
    Path("/usr/share/wayland-sessions"),
)
FIELD_CODE = re.compile(r"%[fFuUdDnNickvm]")


def is_true(value: str) -> bool:
    return value.strip().lower() in {"1", "true", "yes"}


def executable_available(command: list[str], try_exec: str) -> bool:
    candidate = try_exec.strip() or (command[0] if command else "")
    if not candidate:
        return False
    if os.path.isabs(candidate):
        return os.access(candidate, os.X_OK)
    return shutil.which(candidate) is not None


def parse_command(value: str) -> list[str]:
    try:
        tokens = shlex.split(value)
    except ValueError:
        return []

    command: list[str] = []
    for token in tokens:
        if FIELD_CODE.fullmatch(token):
            continue
        token = FIELD_CODE.sub("", token).replace("%%", "%")
        if token:
            command.append(token)
    return command


def read_session(path: Path) -> dict[str, object] | None:
    parser = configparser.RawConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    try:
        with path.open("r", encoding="utf-8-sig") as handle:
            parser.read_file(handle)
    except (OSError, UnicodeError, configparser.Error):
        return None

    section_name = "Desktop Entry"
    if not parser.has_section(section_name):
        return None
    section = parser[section_name]
    if section.get("Type", "Application") != "Application":
        return None
    if is_true(section.get("Hidden", "false")) or is_true(section.get("NoDisplay", "false")):
        return None

    command = parse_command(section.get("Exec", ""))
    if not command or not executable_available(command, section.get("TryExec", "")):
        return None

    session_id = path.stem
    desktop_names = [entry for entry in section.get("DesktopNames", "").split(";") if entry]
    desktop = desktop_names[0] if desktop_names else session_id
    return {
        "id": session_id,
        "name": section.get("Name", session_id),
        "comment": section.get("Comment", ""),
        "desktop": desktop,
        "command": command,
    }


def main() -> None:
    sessions: list[dict[str, object]] = []
    seen: set[str] = set()
    for directory in SESSION_DIRS:
        if not directory.is_dir():
            continue
        for path in sorted(directory.glob("*.desktop")):
            session = read_session(path)
            if session is None or session["id"] in seen:
                continue
            seen.add(str(session["id"]))
            sessions.append(session)

    sessions.sort(key=lambda session: str(session["name"]).casefold())
    print(json.dumps(sessions, ensure_ascii=False, separators=(",", ":")))


if __name__ == "__main__":
    main()

