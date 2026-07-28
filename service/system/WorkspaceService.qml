pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string activeWindowId: ""
    property int activeWorkspaceId: -1
    property Timer debounceTimer

    debounceTimer: Timer {
        interval: 50
        repeat: false
        onTriggered: root.refresh()
    }

    property Process eventStream

    eventStream: Process {
        command: ["niri", "msg", "event-stream"]
        running: true
        Component.onDestruction: running = false

        stdout: SplitParser {
            onRead: root.debounceTimer.restart()
        }

    }

    readonly property string floatingStatePath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/niri-floating-workspaces.json"
    property bool isWorkspaceFloating: false
    property Process queryData

    queryData: Process {
        command: ["sh", "-c", "workspaces=$(niri msg --json workspaces) || exit 1; windows=$(niri msg --json windows) || exit 1; floating=$(cat \"$1\" 2>/dev/null || printf '{}'); printf '{\"workspaces\":%s,\"windows\":%s,\"floating\":%s}\\n' \"$workspaces\" \"$windows\" \"$floating\"", "workspace-query", root.floatingStatePath]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var rawText = text.trim();
                if (rawText !== "")
                    root.parseNiriData(rawText);

            }
        }

    }

    // Process objects survive hot reload. Force a fresh authoritative snapshot
    // after the new engine has restored the singleton and its event stream.
    property Timer reloadRefreshTimer

    reloadRefreshTimer: Timer {
        interval: 120
        running: true
        onTriggered: root.refresh()
    }

    property var workspaces: []

    function parseNiriData(text) {
        try {
            var data = JSON.parse(text);
            var wsList = data.workspaces || [];
            var winList = data.windows || [];
            var newActiveWindowId = "";
            var newActiveWorkspaceId = -1;
            for (var i = 0; i < winList.length; i++) {
                if (winList[i].is_focused)
                    newActiveWindowId = String(winList[i].id);

            }
            for (var j = 0; j < wsList.length; j++) {
                if (wsList[j].is_focused)
                    newActiveWorkspaceId = wsList[j].id;

            }
            var floatingData = data.floating || {
            };
            var floating = false;
            if (newActiveWorkspaceId !== -1 && floatingData[String(newActiveWorkspaceId)])
                floating = true;

            var windowsByWorkspace = {
            };
            for (var k = 0; k < winList.length; k++) {
                var win = winList[k];
                var wsId = win.workspace_id;
                if (!windowsByWorkspace[wsId])
                    windowsByWorkspace[wsId] = [];

                windowsByWorkspace[wsId].push(win);
            }
            for (var wsIdKey in windowsByWorkspace) {
                windowsByWorkspace[wsIdKey].sort(function(a, b) {
                    var posA = a.layout && a.layout.pos_in_scrolling_layout ? a.layout.pos_in_scrolling_layout[0] : 999999;
                    var posB = b.layout && b.layout.pos_in_scrolling_layout ? b.layout.pos_in_scrolling_layout[0] : 999999;
                    return posA - posB;
                });
            }
            var processed = [];
            for (var m = 0; m < wsList.length; m++) {
                var ws = wsList[m];
                var wsWins = windowsByWorkspace[ws.id] || [];
                if (wsWins.length > 0)
                    processed.push({
                        "id": ws.id,
                        "idx": ws.idx,
                        "is_active": ws.is_active,
                        "windows": wsWins
                    });

            }
            processed.sort(function(a, b) {
                return a.idx - b.idx;
            });
            var needsRebuild = root.workspaces.length !== processed.length;
            if (!needsRebuild) {
                for (var n = 0; n < processed.length && !needsRebuild; n++) {
                    if (root.workspaces[n].id !== processed[n].id || root.workspaces[n].idx !== processed[n].idx || root.workspaces[n].windows.length !== processed[n].windows.length) {
                        needsRebuild = true;
                        break;
                    }
                    for (var p = 0; p < processed[n].windows.length; p++) {
                        if (root.workspaces[n].windows[p].id !== processed[n].windows[p].id || root.windowMetadataChanged(root.workspaces[n].windows[p], processed[n].windows[p])) {
                            needsRebuild = true;
                            break;
                        }
                    }
                }
            }
            root.activeWindowId = newActiveWindowId;
            root.activeWorkspaceId = newActiveWorkspaceId;
            if (root.isWorkspaceFloating !== floating)
                root.isWorkspaceFloating = floating;

            if (needsRebuild)
                root.workspaces = processed;

        } catch (error) {
            console.error("Failed to parse workspaces data:", error);
        }
    }

    function refresh() {
        queryData.running = false;
        queryData.running = true;
    }

    function windowMetadataChanged(previous, current) {
        return String(previous.app_id || "") !== String(current.app_id || "") || String(previous.title || "") !== String(current.title || "") || previous.workspace_id !== current.workspace_id;
    }

}
