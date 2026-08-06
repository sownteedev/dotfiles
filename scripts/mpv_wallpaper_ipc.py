#!/usr/bin/env python3
"""Small MPV IPC client used by the live wallpaper service."""

import json
import os
import socket
import sys
import time


def request(socket_path, command, timeout=0.8):
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.settimeout(timeout)
    request_id = time.monotonic_ns()
    try:
        client.connect(socket_path)
        client.sendall((json.dumps({"command": command, "request_id": request_id}) + "\n").encode())
        data = b""
        while True:
            chunk = client.recv(65536)
            if not chunk:
                return None
            data += chunk
            while b"\n" in data:
                line, data = data.split(b"\n", 1)
                response = json.loads(line)
                if response.get("request_id") == request_id:
                    return response
    finally:
        client.close()


def wait_for_file(path, deadline):
    previous_size = -1
    stable_reads = 0
    while time.monotonic() < deadline:
        try:
            size = os.path.getsize(path)
            if size > 0 and size == previous_size:
                stable_reads += 1
                if stable_reads >= 2:
                    return True
            else:
                stable_reads = 0
            previous_size = size
        except OSError:
            previous_size = -1
            stable_reads = 0
        time.sleep(0.08)
    return False


def wait_ready(socket_path, timeout, screenshot_path=""):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            response = request(socket_path, ["get_property", "video-params"])
            if response and response.get("error") == "success" and response.get("data"):
                if screenshot_path:
                    screenshot = request(
                        socket_path,
                        ["screenshot-to-file", screenshot_path, "video"],
                        timeout=1.5,
                    )
                    if not screenshot or screenshot.get("error") != "success":
                        return 1
                    return 0 if wait_for_file(screenshot_path, deadline + 1.0) else 1
                return 0
        except (FileNotFoundError, ConnectionRefusedError, socket.timeout, OSError, json.JSONDecodeError):
            pass
        time.sleep(0.08)
    return 1


def configure(socket_path, paused, fps):
    try:
        pause_result = request(socket_path, ["set_property", "pause", paused])
        fps_result = request(socket_path, ["vf", "set", f"fps={max(1, int(fps))}"])
        return 0 if pause_result and fps_result else 1
    except (FileNotFoundError, ConnectionRefusedError, socket.timeout, OSError, json.JSONDecodeError):
        return 1


def main():
    if len(sys.argv) < 3:
        return 2
    mode, socket_path = sys.argv[1:3]
    if mode == "wait-ready":
        return wait_ready(
            socket_path,
            float(sys.argv[3]) if len(sys.argv) > 3 else 2.0,
            sys.argv[4] if len(sys.argv) > 4 else "",
        )
    if mode == "configure" and len(sys.argv) >= 5:
        return configure(socket_path, sys.argv[3].lower() == "true", int(sys.argv[4]))
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
