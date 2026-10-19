#!/usr/bin/env python3

import json
import os
import socket
import sys


class Niri:
    def __enter__(self):
        self.connection = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.connection.settimeout(3)
        self.connection.connect(os.environ["NIRI_SOCKET"])
        self.stream = self.connection.makefile("rwb")
        return self

    def __exit__(self, *_):
        self.stream.close()
        self.connection.close()

    def read_reply(self):
        reply = json.loads(self.stream.readline())
        if "Err" in reply:
            raise RuntimeError(reply["Err"])
        return reply["Ok"]

    def request(self, request):
        self.stream.write((json.dumps(request) + "\n").encode())
        self.stream.flush()
        return self.read_reply()

    def actions(self, actions):
        self.stream.write(b"".join(
            (json.dumps({"Action": action}) + "\n").encode()
            for action in actions
        ))
        self.stream.flush()
        for _ in actions:
            self.read_reply()


def find_window(windows, window_id):
    return next((window for window in windows if window["id"] == window_id), None)


def column_of(window):
    position = (window.get("layout") or {}).get("pos_in_scrolling_layout")
    return position[0] if position else None


def resolve_workspace(workspaces, requested):
    if requested.get("id") is not None:
        return next((workspace for workspace in workspaces if workspace["id"] == int(requested["id"])), None)
    return next((workspace for workspace in workspaces
                 if (not requested.get("output") or workspace["output"] == requested["output"])
                 and (workspace["name"] == requested["name"] if requested.get("name")
                      else workspace["idx"] == int(requested.get("idx", 0)))), None)


def reorder_window(niri, window_id, target_column):
    windows = niri.request("Windows")["Windows"]
    window = find_window(windows, window_id)
    if not window or window["is_floating"] or window.get("is_fullscreen", False) or column_of(window) is None:
        return
    workspace_id = window["workspace_id"]
    width = int(window["layout"]["window_size"][0])
    peers = [peer for peer in windows if peer["workspace_id"] == workspace_id and not peer["is_floating"]]
    target_column = max(1, min(target_column, max(column_of(peer) or 1 for peer in peers)))
    for _ in range(len(peers) + 1):
        windows = niri.request("Windows")["Windows"]
        window = find_window(windows, window_id)
        if not window or window["workspace_id"] != workspace_id or window["is_floating"] or window.get("is_fullscreen", False):
            return
        current_column = column_of(window)
        if current_column is None or current_column == target_column:
            return
        peers = [peer for peer in windows if peer["workspace_id"] == workspace_id and not peer["is_floating"]]
        direction = -1 if current_column > target_column else 1
        if any(peer.get("is_fullscreen", False) and column_of(peer) == current_column + direction for peer in peers):
            return
        single_window = sum(column_of(peer) == current_column for peer in peers) == 1
        focused = next((peer for peer in peers if peer["is_focused"]), None)
        if single_window and focused:
            focused_column = column_of(focused)
            if focused_column == current_column:
                niri.actions([{"MoveColumnToIndex": {"index": target_column}}])
                return
            if focused_column == current_column + direction:
                niri.actions([{"MoveColumnToIndex": {"index": current_column}}])
                continue
        action = "ConsumeOrExpelWindowLeft" if direction < 0 else "ConsumeOrExpelWindowRight"
        steps = [{action: {"id": window_id}}] * (2 if single_window else 1)
        neighbor = next((peer for peer in peers if column_of(peer) == current_column + direction), None)
        if single_window and neighbor and neighbor["layout"]["tile_size"][0] != window["layout"]["tile_size"][0]:
            steps.append({"SetWindowWidth": {"id": window_id, "change": {"SetFixed": width}}})
        niri.actions(steps)
    raise RuntimeError("Window position did not settle")


def move_window(niri, request):
    window_id = int(request["window_id"])
    windows = niri.request("Windows")["Windows"]
    window = find_window(windows, window_id)
    if window is None:
        return
    target_id = int(request.get("target_window_id") or 0)
    target = find_window(windows, target_id)
    workspace = None
    if request.get("workspace") is not None:
        workspace = resolve_workspace(niri.request("Workspaces")["Workspaces"], request["workspace"])
        if workspace is None:
            raise RuntimeError("Destination workspace is no longer available")
    destination_id = workspace["id"] if workspace else window["workspace_id"]
    target_column = column_of(target) if target and target["id"] != window_id and target["workspace_id"] == destination_id and not target["is_floating"] else None
    if workspace and window["workspace_id"] != destination_id:
        niri.actions([{"MoveWindowToWorkspace": {
            "window_id": window_id,
            "reference": {"Id": destination_id},
            "focus": True,
        }}])
    if target_column is not None:
        reorder_window(niri, window_id, target_column)


def main():
    try:
        request = json.loads(sys.argv[1])
        with Niri() as niri:
            move_window(niri, request)
    except (OSError, ValueError, KeyError, IndexError, TypeError, RuntimeError) as error:
        print(f"Workspace move failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
