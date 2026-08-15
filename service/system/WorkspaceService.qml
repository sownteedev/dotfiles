pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var activeWindowByOutput: ({})
    property string activeWindowId: ""
    property int activeWorkspaceId: -1
    property Timer debounceTimer: Timer {
        interval: 50
        repeat: false

        onTriggered: root.refresh()
    }
    property Process eventStream: Process {
        command: ["niri", "msg", "event-stream"]
        running: true

        stdout: SplitParser {
            onRead: root.debounceTimer.restart()
        }

        Component.onDestruction: running = false
    }
    property var floatingByOutput: ({})
    readonly property string floatingStatePath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/niri-floating-workspaces.json"
    property FileView floatingStateWatcher: FileView {
        path: root.floatingStatePath
        printErrors: false
        watchChanges: true

        onFileChanged: reload()
        onTextChanged: {
            if (loaded)
                root.debounceTimer.restart();
        }
    }
    property string focusedOutputName: ""
    property bool isWorkspaceFloating: false
    property var outputNames: []
    property Process queryData: Process {
        command: ["sh", "-c", "workspaces=$(niri msg --json workspaces) || exit 1; windows=$(niri msg --json windows) || exit 1; floating=$(cat \"$1\" 2>/dev/null || printf '{}'); printf '{\"workspaces\":%s,\"windows\":%s,\"floating\":%s}\\n' \"$workspaces\" \"$windows\" \"$floating\"", "workspace-query", root.floatingStatePath]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                var rawText = text.trim();
                if (rawText !== "")
                    root.parseNiriData(rawText);
            }
        }

        onExited: {
            if (root.refreshPending) {
                root.refreshPending = false;
                Qt.callLater(root.refresh);
            }
        }
    }
    property bool refreshPending: false

    // Process objects survive hot reload. Force a fresh authoritative snapshot
    // after the new engine has restored the singleton and its event stream.
    property Timer reloadRefreshTimer: Timer {
        interval: 120
        running: true

        onTriggered: root.refresh()
    }
    property var workspaces: []

    function compareWindowsByLayout(a, b, floating) {
        var field = floating ? "tile_pos_in_workspace_view" : "pos_in_scrolling_layout";
        var primaryIndex = floating ? 1 : 0;
        var secondaryIndex = floating ? 0 : 1;
        var primaryDifference = windowLayoutCoordinate(a, field, primaryIndex) - windowLayoutCoordinate(b, field, primaryIndex);
        if (primaryDifference !== 0)
            return primaryDifference;
        var secondaryDifference = windowLayoutCoordinate(a, field, secondaryIndex) - windowLayoutCoordinate(b, field, secondaryIndex);
        if (secondaryDifference !== 0)
            return secondaryDifference;
        return Number(a.id || 0) - Number(b.id || 0);
    }
    function focusWorkspace(workspace) {
        var reference = workspaceReference(workspace);
        var output = String(workspace && workspace.output || "");
        if (reference === "")
            return;

        if (output !== "" && output !== focusedOutputName) {
            Quickshell.execDetached(["sh", "-c", "niri msg action focus-monitor \"$1\" && niri msg action focus-workspace \"$2\"", "workspace-focus", output, reference]);
        } else {
            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", reference]);
        }
    }
    function moveWindowToWorkspace(windowId, sourceOutput, workspace, columnIndex) {
        var id = String(windowId || "");
        var fromOutput = String(sourceOutput || "");
        var targetOutput = String(workspace && workspace.output || "");
        var reference = workspaceReference(workspace);
        var targetIndex = Number(columnIndex || 0);
        if (id === "" || reference === "")
            return;

        if (fromOutput !== "" && targetOutput !== "" && fromOutput !== targetOutput) {
            var crossOutputCommand = "niri msg action move-window-to-monitor --id \"$1\" \"$2\" && niri msg action move-window-to-workspace --window-id \"$1\" \"$3\"";
            if (targetIndex > 0)
                crossOutputCommand += " && niri msg action focus-window --id \"$1\" && niri msg action move-column-to-index \"$4\"";
            Quickshell.execDetached(["sh", "-c", crossOutputCommand, "workspace-cross-output", id, targetOutput, reference, String(targetIndex)]);
            return;
        }

        if (targetIndex > 0) {
            Quickshell.execDetached(["sh", "-c", "niri msg action move-window-to-workspace --window-id \"$1\" \"$2\" && niri msg action focus-window --id \"$1\" && niri msg action move-column-to-index \"$3\"", "workspace-move-and-order", id, reference, String(targetIndex)]);
        } else {
            Quickshell.execDetached(["niri", "msg", "action", "move-window-to-workspace", "--window-id", id, reference]);
        }
    }
    function parseNiriData(text) {
        try {
            var data = JSON.parse(text);
            var wsList = data.workspaces || [];
            var winList = data.windows || [];
            var newActiveWindowId = "";
            var newActiveWorkspaceId = -1;
            var newFocusedOutputName = "";
            for (var i = 0; i < winList.length; i++) {
                if (winList[i].is_focused)
                    newActiveWindowId = String(winList[i].id);
            }
            for (var j = 0; j < wsList.length; j++) {
                if (wsList[j].is_focused) {
                    newActiveWorkspaceId = wsList[j].id;
                    newFocusedOutputName = String(wsList[j].output || "");
                }
            }
            var outputSet = {};
            var newOutputNames = [];
            for (var outputIndex = 0; outputIndex < wsList.length; outputIndex++) {
                var outputName = String(wsList[outputIndex].output || "");
                if (outputName !== "" && !outputSet[outputName]) {
                    outputSet[outputName] = true;
                    newOutputNames.push(outputName);
                }
            }
            newOutputNames.sort();
            var floatingData = data.floating || {};
            var floating = false;
            if (newActiveWorkspaceId !== -1 && floatingData[String(newActiveWorkspaceId)])
                floating = true;
            var newFloatingByOutput = {};
            for (var floatingIndex = 0; floatingIndex < wsList.length; floatingIndex++) {
                var floatingWorkspace = wsList[floatingIndex];
                var floatingOutput = String(floatingWorkspace.output || "");
                if (floatingWorkspace.is_active && floatingOutput !== "")
                    newFloatingByOutput[floatingOutput] = floatingData[String(floatingWorkspace.id)] === true;
            }

            var windowsByWorkspace = {};
            for (var k = 0; k < winList.length; k++) {
                var win = winList[k];
                var wsId = win.workspace_id;
                if (!windowsByWorkspace[wsId])
                    windowsByWorkspace[wsId] = [];

                windowsByWorkspace[wsId].push(win);
            }
            for (var wsIdKey in windowsByWorkspace) {
                var workspaceIsFloating = floatingData[String(wsIdKey)] === true;
                windowsByWorkspace[wsIdKey].sort(function (a, b) {
                    return root.compareWindowsByLayout(a, b, workspaceIsFloating);
                });
            }
            var processed = [];
            for (var m = 0; m < wsList.length; m++) {
                var ws = wsList[m];
                var wsWins = windowsByWorkspace[ws.id] || [];
                processed.push({
                    "id": ws.id,
                    "idx": ws.idx,
                    "is_active": ws.is_active,
                    "is_focused": ws.is_focused,
                    "name": String(ws.name || ""),
                    "output": String(ws.output || ""),
                    "windows": wsWins
                });
            }
            processed.sort(function (a, b) {
                if (a.output === b.output)
                    return a.idx - b.idx;
                return a.output < b.output ? -1 : 1;
            });
            var previousActiveWindowByOutput = root.activeWindowByOutput || {};
            var newActiveWindowByOutput = {};
            for (var activeWorkspaceIndex = 0; activeWorkspaceIndex < processed.length; activeWorkspaceIndex++) {
                var activeWorkspace = processed[activeWorkspaceIndex];
                if (!activeWorkspace.is_active || activeWorkspace.output === "")
                    continue;

                var activeCandidate = null;
                if (activeWorkspace.output === newFocusedOutputName && newActiveWindowId !== "") {
                    for (var focusedWindowIndex = 0; focusedWindowIndex < activeWorkspace.windows.length; focusedWindowIndex++) {
                        if (String(activeWorkspace.windows[focusedWindowIndex].id) === newActiveWindowId) {
                            activeCandidate = activeWorkspace.windows[focusedWindowIndex];
                            break;
                        }
                    }
                }
                if (!activeCandidate && previousActiveWindowByOutput[activeWorkspace.output]) {
                    var previousWindowId = String(previousActiveWindowByOutput[activeWorkspace.output].id || "");
                    for (var previousWindowIndex = 0; previousWindowIndex < activeWorkspace.windows.length; previousWindowIndex++) {
                        if (String(activeWorkspace.windows[previousWindowIndex].id) === previousWindowId) {
                            activeCandidate = activeWorkspace.windows[previousWindowIndex];
                            break;
                        }
                    }
                }
                if (!activeCandidate && activeWorkspace.windows.length > 0)
                    activeCandidate = activeWorkspace.windows[0];
                newActiveWindowByOutput[activeWorkspace.output] = root.windowSummary(activeCandidate);
            }
            var needsRebuild = root.workspaces.length !== processed.length;
            if (!needsRebuild) {
                for (var n = 0; n < processed.length && !needsRebuild; n++) {
                    if (root.workspaces[n].id !== processed[n].id || root.workspaces[n].idx !== processed[n].idx || root.workspaces[n].output !== processed[n].output || root.workspaces[n].name !== processed[n].name || root.workspaces[n].windows.length !== processed[n].windows.length) {
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
            if (JSON.stringify(root.activeWindowByOutput) !== JSON.stringify(newActiveWindowByOutput))
                root.activeWindowByOutput = newActiveWindowByOutput;
            root.focusedOutputName = newFocusedOutputName;
            root.outputNames = newOutputNames;
            if (JSON.stringify(root.floatingByOutput) !== JSON.stringify(newFloatingByOutput))
                root.floatingByOutput = newFloatingByOutput;
            if (root.isWorkspaceFloating !== floating)
                root.isWorkspaceFloating = floating;

            if (needsRebuild)
                root.workspaces = processed;
        } catch (error) {
            console.error("Failed to parse workspaces data:", error);
        }
    }
    function refresh() {
        if (queryData.running) {
            refreshPending = true;
            return;
        }
        queryData.running = true;
    }
    function windowLayoutCoordinate(window, field, index) {
        var layout = window && window.layout;
        var position = layout && layout[field];
        if (!position || position.length <= index || position[index] === null || position[index] === undefined)
            return 999999;
        var value = Number(position[index]);
        return isNaN(value) ? 999999 : value;
    }
    function windowMetadataChanged(previous, current) {
        return String(previous.app_id || "") !== String(current.app_id || "") || String(previous.title || "") !== String(current.title || "") || previous.workspace_id !== current.workspace_id;
    }
    function windowSummary(window) {
        if (!window)
            return null;
        return {
            "id": String(window.id || ""),
            "app_id": String(window.app_id || ""),
            "title": String(window.title || "")
        };
    }
    function workspaceReference(workspace) {
        var name = String(workspace && workspace.name || "");
        if (name !== "")
            return name;
        return workspace && workspace.idx !== undefined ? String(workspace.idx) : "";
    }
}
