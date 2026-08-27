#!/usr/bin/env python3

import argparse
import hashlib
import json
import os
import subprocess
import tempfile
import time
from pathlib import Path


class WifiQrError(RuntimeError):
    pass


def emit(ok: bool, **values: object) -> None:
    print(json.dumps({"ok": ok, **values}, ensure_ascii=False), flush=True)


def escape_wifi_value(value: str) -> str:
    escaped = value.replace("\\", "\\\\")
    for character in (";", ",", ":", '"'):
        escaped = escaped.replace(character, "\\" + character)
    return escaped


def wifi_payload(security: str, ssid: str, password: str = "") -> str:
    payload = f"WIFI:T:{security};S:{escape_wifi_value(ssid)};"
    if security.lower() != "nopass":
        payload += f"P:{escape_wifi_value(password)};"
    return payload + ";"


def private_directory() -> Path:
    directory = Path(tempfile.gettempdir()) / f"sowntee-wifi-qr-{os.getuid()}"
    if directory.exists():
        if directory.is_symlink() or not directory.is_dir() or directory.stat().st_uid != os.getuid():
            raise WifiQrError("The private QR directory is not safe to use.")
    else:
        directory.mkdir(mode=0o700)
    directory.chmod(0o700)
    return directory


def remove_stale_files(directory: Path) -> None:
    for path in directory.glob("wifi-*.png*"):
        try:
            path.unlink()
        except FileNotFoundError:
            pass


def nmcli_value(field: str, profile: str, preserve_whitespace: bool = False) -> str:
    try:
        result = subprocess.run(
            [
                "nmcli",
                "--show-secrets",
                "--escape",
                "no",
                "--get-values",
                field,
                "connection",
                "show",
                profile,
            ],
            capture_output=True,
            check=False,
            text=True,
            timeout=10,
        )
    except FileNotFoundError as error:
        raise WifiQrError("NetworkManager tools are not installed.") from error
    except subprocess.TimeoutExpired as error:
        raise WifiQrError("Reading the saved Wi-Fi credentials timed out.") from error

    if result.returncode != 0:
        raise WifiQrError("Could not read the saved Wi-Fi credentials.")

    value = result.stdout
    if value.endswith("\n"):
        value = value[:-1]
    return value if preserve_whitespace else value.strip()


def saved_wifi_payload(ssid: str, profile: str) -> str:
    key_management = nmcli_value("802-11-wireless-security.key-mgmt", profile).lower()
    if key_management not in {"wpa-psk", "sae", "wpa-psk-sae"}:
        raise WifiQrError("Only WPA/WPA2/WPA3 personal networks can be shared by QR code.")

    password = nmcli_value("802-11-wireless-security.psk", profile, preserve_whitespace=True)
    if password == "":
        raise WifiQrError("The saved password could not be retrieved.")
    return wifi_payload("WPA", ssid, password)


def generate_qr(ssid: str, profile: str, open_network: bool) -> Path:
    if ssid == "":
        raise WifiQrError("The Wi-Fi name is empty.")
    if not open_network and profile == "":
        raise WifiQrError("The saved NetworkManager profile could not be found.")

    payload = wifi_payload("nopass", ssid) if open_network else saved_wifi_payload(ssid, profile)
    directory = private_directory()
    remove_stale_files(directory)
    digest = hashlib.sha256(ssid.encode("utf-8")).hexdigest()[:12]
    output_path = directory / f"wifi-{digest}-{time.time_ns()}.png"
    temporary_path = output_path.with_suffix(".tmp.png")

    try:
        result = subprocess.run(
            ["qrencode", "-8", "-l", "M", "-m", "4", "-s", "8", "-t", "PNG", "-o", str(temporary_path)],
            capture_output=True,
            check=False,
            input=payload,
            text=True,
            timeout=10,
        )
    except FileNotFoundError as error:
        raise WifiQrError("The qrencode package is not installed.") from error
    except subprocess.TimeoutExpired as error:
        raise WifiQrError("Creating the Wi-Fi QR code timed out.") from error

    if result.returncode != 0 or not temporary_path.is_file() or temporary_path.stat().st_size == 0:
        temporary_path.unlink(missing_ok=True)
        raise WifiQrError("Could not create the Wi-Fi QR code.")

    temporary_path.chmod(0o600)
    os.replace(temporary_path, output_path)
    return output_path


def delete_qr(path_value: str) -> None:
    directory = private_directory().resolve()
    path = Path(path_value).resolve()
    if path.parent != directory or not path.name.startswith("wifi-") or path.suffix != ".png":
        raise WifiQrError("Refusing to remove a file outside the private QR directory.")
    path.unlink(missing_ok=True)


def cleanup_qr_files() -> None:
    remove_stale_files(private_directory())


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate temporary Wi-Fi QR codes for SownteeShell.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    generate = subparsers.add_parser("generate")
    generate.add_argument("--ssid", required=True)
    source = generate.add_mutually_exclusive_group(required=True)
    source.add_argument("--profile", default="")
    source.add_argument("--open", action="store_true", dest="open_network")

    delete = subparsers.add_parser("delete")
    delete.add_argument("--path", required=True)
    subparsers.add_parser("cleanup")
    return parser.parse_args()


def main() -> int:
    os.umask(0o077)
    args = parse_args()
    try:
        if args.command == "generate":
            path = generate_qr(args.ssid, args.profile, args.open_network)
            emit(True, path=str(path), ssid=args.ssid)
        elif args.command == "delete":
            delete_qr(args.path)
            emit(True)
        else:
            cleanup_qr_files()
            emit(True)
        return 0
    except WifiQrError as error:
        emit(False, error=str(error))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
