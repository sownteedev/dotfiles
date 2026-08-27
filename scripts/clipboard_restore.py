#!/usr/bin/env python3

import argparse
import shutil
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import unquote, urlsplit


def decode_entry(entry_id: str) -> bytes | None:
    result = subprocess.run(
        ["cliphist", "decode", entry_id],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.stdout if result.returncode == 0 else None


def normalize_uri_list(data: bytes) -> bytes | None:
    try:
        lines = data.decode("utf-8").splitlines()
    except UnicodeDecodeError:
        return None

    values = [line.strip() for line in lines if line.strip()]
    if values and values[0].lower() in {"copy", "cut"}:
        values = values[1:]

    uris: list[str] = []
    for value in values:
        if value.startswith("#"):
            continue

        if value.lower().startswith("file://"):
            parsed = urlsplit(value)
            if parsed.scheme.lower() != "file" or parsed.netloc not in {"", "localhost"}:
                return None
            path = Path(unquote(parsed.path))
        else:
            path = Path(value).expanduser()

        try:
            is_local_entry = path.is_absolute() and path.exists()
        except (OSError, ValueError):
            return None
        if not is_local_entry:
            return None
        uris.append(path.absolute().as_uri())

    if not uris:
        return None
    return ("\r\n".join(uris) + "\r\n").encode("utf-8")


def copy_data(data: bytes, mime_type: str = "") -> bool:
    command = ["wl-copy"]
    if mime_type:
        command.extend(["--type", mime_type])
    result = subprocess.run(command, input=data, stderr=subprocess.DEVNULL, check=False)
    return result.returncode == 0


def auto_paste() -> None:
    if not shutil.which("wtype"):
        return
    time.sleep(0.4)
    subprocess.run(
        ["wtype", "-M", "ctrl", "-k", "v", "-m", "ctrl"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("entry_id")
    parser.add_argument("--auto-paste", action="store_true")
    args = parser.parse_args()

    decoded = decode_entry(args.entry_id)
    if decoded is None:
        return 1

    uri_data = normalize_uri_list(decoded)
    clipboard_data = uri_data if uri_data is not None else decoded
    mime_type = "text/uri-list" if uri_data is not None else ""

    if not copy_data(clipboard_data, mime_type):
        return 1
    if args.auto_paste:
        auto_paste()
    return 0


if __name__ == "__main__":
    sys.exit(main())
