#!/usr/bin/env python3
"""Open the desktop portal file chooser and emit one JSON response."""

from __future__ import annotations

import argparse
import json
import os
import shlex
import signal
import sys
import uuid
from pathlib import Path
from typing import Any

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

PORTAL_BUS_NAME = "org.freedesktop.portal.Desktop"
PORTAL_OBJECT_PATH = "/org/freedesktop/portal/desktop"
FILE_CHOOSER_INTERFACE = "org.freedesktop.portal.FileChooser"
REQUEST_INTERFACE = "org.freedesktop.portal.Request"


class PortalError(Exception):
    pass


def emit(payload: dict[str, Any]) -> None:
    print(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), flush=True)


def normalize_current_folder(value: str) -> str:
    text = str(value or "").strip()
    if not text:
        return ""

    if text.startswith("file:"):
        path = Gio.File.new_for_uri(text).get_path()
        if not path:
            raise PortalError("The selected starting folder is not a local path")
    else:
        path = os.path.expanduser(text)

    candidate = Path(path).resolve(strict=False)
    if candidate.is_file():
        candidate = candidate.parent
    while not candidate.is_dir() and candidate != candidate.parent:
        candidate = candidate.parent
    return str(candidate) if candidate.is_dir() else ""


def parse_filter_string(value: str) -> tuple[str, list[tuple[int, str]]] | None:
    text = str(value or "").strip()
    if not text:
        return None

    if "|" in text:
        name, raw_conditions = text.split("|", 1)
    else:
        name, raw_conditions = "Files", text

    conditions: list[tuple[int, str]] = []
    for condition in shlex.split(raw_conditions.strip()):
        if "/" in condition and not any(character in condition for character in "*?["):
            conditions.append((1, condition))
        else:
            conditions.append((0, condition))
    if not conditions:
        return None
    return (name.strip() or "Files", conditions)


def parse_filters(value: Any) -> list[tuple[str, list[tuple[int, str]]]]:
    if value is None:
        return []
    if isinstance(value, str):
        value = [value]
    if not isinstance(value, list):
        raise PortalError("File filters must be a JSON array")

    parsed: list[tuple[str, list[tuple[int, str]]]] = []
    for entry in value:
        if isinstance(entry, str):
            item = parse_filter_string(entry)
            if item:
                parsed.append(item)
            continue
        if not isinstance(entry, dict):
            raise PortalError("Each file filter must be a string or object")

        name = str(entry.get("name") or entry.get("label") or "Files").strip() or "Files"
        conditions: list[tuple[int, str]] = []
        patterns = entry.get("patterns", entry.get("globs", []))
        mime_types = entry.get("mimeTypes", entry.get("mimes", []))
        if isinstance(patterns, str):
            patterns = shlex.split(patterns)
        if isinstance(mime_types, str):
            mime_types = shlex.split(mime_types)
        for pattern in patterns or []:
            if str(pattern).strip():
                conditions.append((0, str(pattern).strip()))
        for mime_type in mime_types or []:
            if str(mime_type).strip():
                conditions.append((1, str(mime_type).strip()))
        if conditions:
            parsed.append((name, conditions))
    return parsed


def build_options(arguments: argparse.Namespace, token: str) -> dict[str, GLib.Variant]:
    options: dict[str, GLib.Variant] = {
        "handle_token": GLib.Variant("s", token),
        "modal": GLib.Variant("b", True),
        "multiple": GLib.Variant("b", bool(arguments.multiple)),
        "directory": GLib.Variant("b", bool(arguments.directory)),
    }
    current_folder = normalize_current_folder(arguments.current)
    if current_folder:
        options["current_folder"] = GLib.Variant("ay", os.fsencode(current_folder) + b"\0")
    filters = parse_filters(json.loads(arguments.filters_json))
    if filters:
        options["filters"] = GLib.Variant("a(sa(us))", filters)
    return options


def request_path_for(connection: Gio.DBusConnection, token: str) -> str:
    unique_name = connection.get_unique_name()
    if not unique_name:
        raise PortalError("Could not determine the session bus connection name")
    sender = unique_name.removeprefix(":").replace(".", "_")
    return f"/org/freedesktop/portal/desktop/request/{sender}/{token}"


def unpack_result(value: Any) -> Any:
    return value.unpack() if isinstance(value, GLib.Variant) else value


def response_payload(response_code: int, results: dict[str, Any]) -> dict[str, Any]:
    if response_code == 1:
        return {"ok": True, "canceled": True, "paths": [], "uris": []}
    if response_code != 0:
        return {
            "ok": False,
            "canceled": False,
            "message": "The desktop portal could not complete the file selection",
        }

    uris = [str(uri) for uri in unpack_result(results.get("uris", [])) or []]
    if not uris:
        return {
            "ok": False,
            "canceled": False,
            "message": "The desktop portal returned no selected files",
        }
    paths: list[str] = []
    for uri in uris:
        path = Gio.File.new_for_uri(uri).get_path()
        if path:
            paths.append(path)
    if len(paths) != len(uris):
        return {
            "ok": False,
            "canceled": False,
            "message": "The selected item is not available as a local file",
        }
    return {"ok": True, "canceled": False, "paths": paths, "uris": uris}


class PortalFilePicker:
    def __init__(self, arguments: argparse.Namespace) -> None:
        self.arguments = arguments
        self.connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.loop = GLib.MainLoop()
        self.request_path = ""
        self.response: dict[str, Any] | None = None
        self.subscription_id = 0
        self.cancel_requested = False

    def subscribe(self, request_path: str) -> None:
        if self.subscription_id:
            self.connection.signal_unsubscribe(self.subscription_id)
        self.subscription_id = self.connection.signal_subscribe(
            PORTAL_BUS_NAME,
            REQUEST_INTERFACE,
            "Response",
            request_path,
            None,
            Gio.DBusSignalFlags.NONE,
            self.on_response,
        )

    def on_response(
        self,
        connection: Gio.DBusConnection,
        sender_name: str,
        object_path: str,
        interface_name: str,
        signal_name: str,
        parameters: GLib.Variant,
    ) -> None:
        response_code, raw_results = parameters.unpack()
        results = {str(key): unpack_result(value) for key, value in raw_results.items()}
        self.response = response_payload(int(response_code), results)
        self.loop.quit()

    def request_cancel(self, signum: int, frame: Any) -> None:
        if self.cancel_requested:
            return
        self.cancel_requested = True
        GLib.idle_add(self.close_request)

    def close_request(self) -> bool:
        if self.request_path:
            try:
                self.connection.call_sync(
                    PORTAL_BUS_NAME,
                    self.request_path,
                    REQUEST_INTERFACE,
                    "Close",
                    None,
                    None,
                    Gio.DBusCallFlags.NONE,
                    1000,
                    None,
                )
            except GLib.Error:
                pass
        self.response = {"ok": True, "canceled": True, "paths": [], "uris": []}
        self.loop.quit()
        return GLib.SOURCE_REMOVE

    def run(self) -> dict[str, Any]:
        token = "sowntee_" + uuid.uuid4().hex
        self.request_path = request_path_for(self.connection, token)
        self.subscribe(self.request_path)
        signal.signal(signal.SIGINT, self.request_cancel)
        signal.signal(signal.SIGTERM, self.request_cancel)

        options = build_options(self.arguments, token)
        parameters = GLib.Variant(
            "(ssa{sv})",
            (self.arguments.parent_window, self.arguments.title, options),
        )
        result = self.connection.call_sync(
            PORTAL_BUS_NAME,
            PORTAL_OBJECT_PATH,
            FILE_CHOOSER_INTERFACE,
            "OpenFile",
            parameters,
            GLib.VariantType.new("(o)"),
            Gio.DBusCallFlags.NONE,
            -1,
            None,
        )
        returned_path = str(result.unpack()[0])
        if returned_path != self.request_path:
            self.request_path = returned_path
            self.subscribe(returned_path)
        if self.cancel_requested:
            self.close_request()
        elif self.response is None:
            self.loop.run()

        if self.subscription_id:
            self.connection.signal_unsubscribe(self.subscription_id)
            self.subscription_id = 0
        return self.response or {
            "ok": False,
            "canceled": False,
            "message": "The desktop portal closed without a response",
        }


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Open a file chooser through xdg-desktop-portal")
    parser.add_argument("--title", default="Select file")
    parser.add_argument("--current", default="")
    parser.add_argument("--directory", action="store_true")
    parser.add_argument("--multiple", action="store_true")
    parser.add_argument("--filters-json", default="[]")
    parser.add_argument("--parent-window", default="")
    return parser.parse_args()


def main() -> int:
    try:
        payload = PortalFilePicker(parse_arguments()).run()
    except (GLib.Error, OSError, PortalError, TypeError, ValueError) as error:
        emit({"ok": False, "canceled": False, "message": str(error)})
        return 1
    emit(payload)
    return 0 if payload.get("ok") else 1


if __name__ == "__main__":
    sys.exit(main())
