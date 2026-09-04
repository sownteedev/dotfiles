#!/usr/bin/env python3

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys


PACKAGE_NAME = re.compile(r"^[A-Za-z0-9@._+][A-Za-z0-9@._+:-]*$")


def emit(payload: dict, exit_code: int = 0) -> None:
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")))
    raise SystemExit(exit_code)


def data_roots() -> list[Path]:
    roots = [Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))]
    roots.extend(
        Path(path)
        for path in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":")
        if path
    )

    unique: list[Path] = []
    for root in roots:
        if root not in unique:
            unique.append(root)
    return unique


def desktop_id_for(path: Path, applications_dir: Path) -> str:
    relative = path.relative_to(applications_dir).as_posix()
    if relative.endswith(".desktop"):
        relative = relative[:-8]
    return relative.replace("/", "-")


def find_desktop_files(app_id: str) -> list[Path]:
    normalized_id = app_id
    matches: list[Path] = []
    for data_root in data_roots():
        applications_dir = data_root / "applications"
        direct = applications_dir / f"{normalized_id}.desktop"
        if direct.exists():
            matches.append(direct)
            continue
        if not applications_dir.is_dir():
            continue
        try:
            for candidate in applications_dir.rglob("*.desktop"):
                if desktop_id_for(candidate, applications_dir) == normalized_id:
                    matches.append(candidate)
                    break
        except OSError:
            continue
    return matches


def desktop_flatpak_id(desktop_file: Path) -> str:
    try:
        for line in desktop_file.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith("X-Flatpak="):
                return line.partition("=")[2].strip()
    except OSError:
        pass
    return ""


def desktop_executable(desktop_file: Path) -> Path | None:
    command = desktop_command(desktop_file)
    if command and Path(command).is_absolute():
        return Path(command)
    return None


def desktop_command(desktop_file: Path) -> str:
    try:
        for line in desktop_file.read_text(encoding="utf-8", errors="replace").splitlines():
            if not line.startswith("Exec="):
                continue
            arguments = shlex.split(line.partition("=")[2].strip())
            return arguments[0] if arguments else ""
    except (OSError, ValueError):
        pass
    return ""


def flatpak_scope(app_id: str) -> str:
    flatpak = shutil.which("flatpak")
    if not flatpak or not PACKAGE_NAME.fullmatch(app_id):
        return ""
    for scope in ("user", "system"):
        result = subprocess.run(
            [flatpak, "info", f"--{scope}", "--", app_id],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if result.returncode == 0:
            return scope
    return ""


def pacman_owner(desktop_file: Path) -> str:
    pacman = shutil.which("pacman")
    if not pacman:
        return ""
    result = subprocess.run(
        [pacman, "-Qqo", "--", str(desktop_file)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return ""
    package = result.stdout.strip().splitlines()[0] if result.stdout.strip() else ""
    return package if PACKAGE_NAME.fullmatch(package) else ""


def pacman_desktop_ids(package: str) -> list[str]:
    pacman = shutil.which("pacman")
    if not pacman:
        return []
    result = subprocess.run(
        [pacman, "-Qlq", package],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return []

    desktop_ids: list[str] = []
    marker = "/share/applications/"
    for raw_path in result.stdout.splitlines():
        if marker not in raw_path or not raw_path.endswith(".desktop"):
            continue
        relative = raw_path.split(marker, 1)[1][:-8]
        desktop_id = relative.replace("/", "-")
        if desktop_id and desktop_id not in desktop_ids:
            desktop_ids.append(desktop_id)
    return desktop_ids


def pacman_removal_plan(package: str) -> dict:
    pacman = shutil.which("pacman")
    if not pacman:
        return {
            "blockers": [],
            "message": "Pacman is unavailable",
            "removable": False,
            "removal_packages": [],
        }

    environment = os.environ.copy()
    environment["LC_ALL"] = "C"
    result = subprocess.run(
        [pacman, "-Rs", "--print-format", "%n", "--print", "--", package],
        capture_output=True,
        text=True,
        check=False,
        env=environment,
    )
    if result.returncode == 0:
        removal_packages = []
        for line in result.stdout.splitlines():
            candidate = line.strip()
            if PACKAGE_NAME.fullmatch(candidate) and candidate not in removal_packages:
                removal_packages.append(candidate)
        return {
            "blockers": [],
            "message": "",
            "removable": True,
            "removal_packages": removal_packages,
        }

    blockers = []
    for line in result.stdout.splitlines():
        match = re.search(r" required by ([A-Za-z0-9@._+:-]+)$", line.strip())
        if match and match.group(1) not in blockers:
            blockers.append(match.group(1))
    message = f"Required by {', '.join(blockers)}" if blockers else failure_message(result)
    return {
        "blockers": blockers,
        "message": message,
        "removable": False,
        "removal_packages": [],
    }


def resolve_package(app_id: str) -> dict:
    normalized_id = app_id.strip()
    result = {
        "app_id": normalized_id,
        "backend": "",
        "blockers": [],
        "desktop_ids": [normalized_id] if normalized_id else [],
        "managed": False,
        "message": "",
        "package": "",
        "removable": False,
        "removal_packages": [],
        "scope": "",
    }
    if not normalized_id:
        return result

    desktop_files = find_desktop_files(normalized_id)
    if not desktop_files:
        return result
    desktop_file = desktop_files[0]

    flatpak_id = desktop_flatpak_id(desktop_file)
    if flatpak_id:
        scope = flatpak_scope(flatpak_id)
        if scope:
            result.update(
                {
                    "backend": "flatpak",
                    "managed": True,
                    "package": flatpak_id,
                    "removable": True,
                    "scope": scope,
                }
            )
            return result

    package = pacman_owner(desktop_file)
    if not package:
        executable = desktop_executable(desktop_file)
        if executable is not None:
            package = pacman_owner(executable)
    if not package:
        primary_command = Path(desktop_command(desktop_file)).name
        for packaged_desktop in desktop_files[1:]:
            if primary_command == "" or Path(desktop_command(packaged_desktop)).name != primary_command:
                continue
            package = pacman_owner(packaged_desktop)
            if package:
                break
    if package:
        removal_plan = pacman_removal_plan(package)
        result.update(
            {
                "backend": "pacman",
                "desktop_ids": pacman_desktop_ids(package) or [normalized_id],
                "managed": True,
                "package": package,
                "scope": "system",
                **removal_plan,
            }
        )
    return result


def failure_message(result: subprocess.CompletedProcess[str]) -> str:
    output = (result.stdout or result.stderr or "").strip()
    if not output:
        return "Uninstall was cancelled or failed"
    return output.splitlines()[-1][:240]


def uninstall(app_id: str) -> None:
    package = resolve_package(app_id)
    if not package["managed"]:
        emit({**package, "ok": False, "message": "Application is not managed by Pacman or Flatpak"}, 3)
    if not package["removable"]:
        emit({**package, "ok": False, "message": package["message"] or "Application cannot be uninstalled safely"}, 5)

    if package["backend"] == "pacman":
        pkexec = shutil.which("pkexec")
        pacman = shutil.which("pacman")
        if not pkexec or not pacman:
            emit({**package, "ok": False, "message": "Pacman or pkexec is unavailable"}, 4)
        command = [pkexec, pacman, "-Rns", "--noconfirm", "--", package["package"]]
    else:
        flatpak = shutil.which("flatpak")
        if not flatpak:
            emit({**package, "ok": False, "message": "Flatpak is unavailable"}, 4)
        command = [
            flatpak,
            "uninstall",
            f"--{package['scope']}",
            "--app",
            "--assumeyes",
            "--noninteractive",
            "--",
            package["package"],
        ]

    completed = subprocess.run(command, capture_output=True, text=True, check=False)
    if completed.returncode != 0:
        if package["backend"] == "pacman" and completed.returncode in (126, 127):
            emit({**package, "ok": False, "message": "Administrator authorization was cancelled"}, completed.returncode)
        emit({**package, "ok": False, "message": failure_message(completed)}, completed.returncode or 1)
    emit({**package, "ok": True, "message": f"Uninstalled {package['package']}"})


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    for command in ("inspect", "uninstall"):
        action = subparsers.add_parser(command)
        action.add_argument("app_id")
    args = parser.parse_args()

    if args.command == "inspect":
        emit({**resolve_package(args.app_id), "ok": True})
    uninstall(args.app_id)


if __name__ == "__main__":
    try:
        main()
    except (OSError, subprocess.SubprocessError) as error:
        emit({"ok": False, "message": str(error)}, 1)
