pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var activeWindowByOutput: ({})
    property string activeWindowId: ""
    property var activeWindowsByOutput: ({})
    property int activeWorkspaceId: -1
    property Timer debounceTimer: Timer {
        interval: 50
        repeat: false

        onTriggered: root.refresh()
    }
    property Process eventStream: Process {
        command: ["niri", "msg", "--json", "event-stream"]
        running: true

        stdout: SplitParser {
            onRead: line => {
                root.handleNiriEvent(line);
                root.debounceTimer.restart();
            }
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
    property bool overviewOpen: false
    property string overviewWindowId: ""
    property Process queryData: Process {
        command: ["sh", "-c", "workspaces=$(niri msg --json workspaces) || exit 1; windows=$(niri msg --json windows) || exit 1; overview=$(niri msg --json overview-state 2>/dev/null || printf '{\"is_open\":false}'); floating=$(cat \"$1\" 2>/dev/null || printf '{}'); printf '{\"workspaces\":%s,\"windows\":%s,\"overview\":%s,\"floating\":%s}\\n' \"$workspaces\" \"$windows\" \"$overview\" \"$floating\"", "workspace-query", root.floatingStatePath]
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

        onTriggered: {
            root.eventStream.running = false;
            Qt.callLater(function () {
                root.eventStream.running = true;
                root.refresh();
            });
        }
    }
    property var workspaceIdByWindow: ({})
    property var workspaces: []

    function compareWindowsByLayout(a, b, floating) {
        var field = floating ? "tile_pos_in_workspace_view" : "pos_in_scrolling_layout";
        var primaryIndex = 0;
        var secondaryIndex = 1;
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
    function handleNiriEvent(line) {
        var text = String(line || "").trim();
        if (text === "")
            return;

        try {
            var event = JSON.parse(text);
            if (event.OverviewOpenedOrClosed) {
                root.overviewOpen = event.OverviewOpenedOrClosed.is_open === true;
                if (!root.overviewOpen)
                    root.overviewWindowId = "";
            } else if (root.overviewOpen && event.WindowFocusChanged && event.WindowFocusChanged.id !== null && event.WindowFocusChanged.id !== undefined) {
                root.selectOverviewWindow(event.WindowFocusChanged.id);
            } else if (root.overviewOpen && event.WindowOpenedOrChanged && event.WindowOpenedOrChanged.window) {
                var changedWindow = event.WindowOpenedOrChanged.window;
                if (changedWindow.is_focused || changedWindow.workspace_id === null)
                    root.selectOverviewWindow(changedWindow.id);
            }
            return;
        } catch (error) {}

        if (text.indexOf("Overview toggled: ") === 0) {
            root.overviewOpen = text.slice(18).trim() === "true";
            if (!root.overviewOpen)
                root.overviewWindowId = "";
        } else if (root.overviewOpen && text.indexOf("Window focus changed: ") === 0) {
            var focusedId = text.slice(22).trim();
            var focusedMatch = focusedId.match(/^Some\((\d+)\)$/);
            if (focusedMatch)
                root.selectOverviewWindow(focusedMatch[1]);
            else if (/^\d+$/.test(focusedId))
                root.selectOverviewWindow(focusedId);
        } else if (root.overviewOpen && text.indexOf("Window opened or changed: Window {") === 0) {
            var movedWindowMatch = text.match(/^Window opened or changed: Window \{ id: (\d+),.*workspace_id: None,/);
            if (movedWindowMatch)
                root.selectOverviewWindow(movedWindowMatch[1]);
        }
    }
    function layoutPositionIsValid(position) {
        if (!position || position.length < 2 || position[0] === null || position[0] === undefined || position[1] === null || position[1] === undefined)
            return false;
        return !isNaN(Number(position[0])) && !isNaN(Number(position[1]));
    }
    function moveWindowToColumn(windowId, columnIndex, restoreFocus) {
        var id = String(windowId || "");
        var targetColumn = Math.round(Number(columnIndex));
        if (id === "" || isNaN(targetColumn) || targetColumn < 1)
            return;

        if (restoreFocus) {
            Quickshell.execDetached(["sh", "-c", "if niri msg action focus-window --id \"$1\"; then niri msg action move-column-to-index \"$2\"; niri msg action focus-window-previous; fi", "workspace-reorder", id, String(targetColumn)]);
            return;
        }
        Quickshell.execDetached(["sh", "-c", "niri msg action focus-window --id \"$1\" && niri msg action move-column-to-index \"$2\"", "workspace-reorder-focused", id, String(targetColumn)]);
    }
    function moveWindowToWorkspace(windowId, sourceOutput, workspace, columnIndex) {
        var id = String(windowId || "");
        var fromOutput = String(sourceOutput || "");
        var targetOutput = String(workspace && workspace.output || "");
        var reference = workspaceReference(workspace);
        var targetColumn = Number(columnIndex);
        if (isNaN(targetColumn) || targetColumn < 1)
            targetColumn = 0;
        else
            targetColumn = Math.round(targetColumn);
        if (id === "" || reference === "")
            return;

        if (fromOutput !== "" && targetOutput !== "" && fromOutput !== targetOutput) {
            if (targetColumn > 0) {
                Quickshell.execDetached(["sh", "-c", "niri msg action move-window-to-monitor --id \"$1\" \"$2\" && niri msg action move-window-to-workspace --window-id \"$1\" --focus false \"$3\" || exit 1; if niri msg action focus-window --id \"$1\"; then niri msg action move-column-to-index \"$4\"; niri msg action focus-window-previous; fi", "workspace-cross-output-positioned", id, targetOutput, reference, String(targetColumn)]);
                return;
            }
            Quickshell.execDetached(["sh", "-c", "niri msg action move-window-to-monitor --id \"$1\" \"$2\" && niri msg action move-window-to-workspace --window-id \"$1\" --focus false \"$3\"", "workspace-cross-output", id, targetOutput, reference]);
            return;
        }

        if (targetColumn > 0) {
            Quickshell.execDetached(["sh", "-c", "niri msg action move-window-to-workspace --window-id \"$1\" --focus false \"$2\" || exit 1; if niri msg action focus-window --id \"$1\"; then niri msg action move-column-to-index \"$3\"; niri msg action focus-window-previous; fi", "workspace-positioned", id, reference, String(targetColumn)]);
            return;
        }
        Quickshell.execDetached(["niri", "msg", "action", "move-window-to-workspace", "--window-id", id, "--focus", "false", reference]);
    }
    function parseNiriData(text) {
        try {
            var data = JSON.parse(text);
            var wsList = data.workspaces || [];
            var winList = data.windows || [];
            var overviewOpen = data.overview && data.overview.is_open === true;
            root.overviewOpen = overviewOpen;
            if (!overviewOpen)
                root.overviewWindowId = "";
            var focusedWindow = null;
            var newActiveWindowId = "";
            var newActiveWorkspaceId = -1;
            var newFocusedOutputName = "";
            for (var i = 0; i < winList.length; i++) {
                if (winList[i].is_focused) {
                    focusedWindow = winList[i];
                    newActiveWindowId = String(winList[i].id);
                    break;
                }
            }
            for (var j = 0; j < wsList.length; j++) {
                if (wsList[j].is_focused) {
                    newActiveWorkspaceId = wsList[j].id;
                    newFocusedOutputName = String(wsList[j].output || "");
                    if ((overviewOpen || newActiveWindowId === "") && wsList[j].active_window_id !== null && wsList[j].active_window_id !== undefined)
                        newActiveWindowId = String(wsList[j].active_window_id);
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

            var previousWorkspaceIdByWindow = root.workspaceIdByWindow || {};
            var previousWindowById = {};
            var previousWorkspaces = root.workspaces || [];
            for (var previousWorkspaceIndex = 0; previousWorkspaceIndex < previousWorkspaces.length; previousWorkspaceIndex++) {
                var previousWindows = previousWorkspaces[previousWorkspaceIndex].windows || [];
                for (var cachedWindowIndex = 0; cachedWindowIndex < previousWindows.length; cachedWindowIndex++) {
                    var cachedWindow = previousWindows[cachedWindowIndex];
                    previousWindowById[String(cachedWindow.id || "")] = cachedWindow;
                }
            }
            var newWorkspaceIdByWindow = {};
            var windowsByWorkspace = {};
            for (var k = 0; k < winList.length; k++) {
                var win = winList[k];
                var windowId = String(win.id || "");
                var wsId = win.workspace_id;
                if ((wsId === null || wsId === undefined) && windowId !== "" && previousWorkspaceIdByWindow[windowId] !== undefined)
                    wsId = previousWorkspaceIdByWindow[windowId];
                if (wsId === null || wsId === undefined)
                    continue;

                var resolvedWindow = win;
                var previousWindow = previousWindowById[windowId];
                var currentLayout = win.layout || {};
                var previousLayout = previousWindow && previousWindow.layout ? previousWindow.layout : {};
                var preserveScrollingPosition = !root.layoutPositionIsValid(currentLayout.pos_in_scrolling_layout) && root.layoutPositionIsValid(previousLayout.pos_in_scrolling_layout);
                var preserveFloatingPosition = !root.layoutPositionIsValid(currentLayout.tile_pos_in_workspace_view) && root.layoutPositionIsValid(previousLayout.tile_pos_in_workspace_view);
                if (win.workspace_id !== wsId || preserveScrollingPosition || preserveFloatingPosition) {
                    resolvedWindow = Object.assign({}, win);
                    resolvedWindow.workspace_id = wsId;
                    if (preserveScrollingPosition || preserveFloatingPosition) {
                        resolvedWindow.layout = Object.assign({}, currentLayout);
                        if (preserveScrollingPosition)
                            resolvedWindow.layout.pos_in_scrolling_layout = previousLayout.pos_in_scrolling_layout;
                        if (preserveFloatingPosition)
                            resolvedWindow.layout.tile_pos_in_workspace_view = previousLayout.tile_pos_in_workspace_view;
                    }
                }
                if (windowId !== "")
                    newWorkspaceIdByWindow[windowId] = wsId;
                if (!windowsByWorkspace[wsId])
                    windowsByWorkspace[wsId] = [];

                windowsByWorkspace[wsId].push(resolvedWindow);
            }
            root.workspaceIdByWindow = newWorkspaceIdByWindow;
            var overviewWindowWorkspaceId = overviewOpen && root.overviewWindowId !== "" ? newWorkspaceIdByWindow[root.overviewWindowId] : undefined;
            if (overviewWindowWorkspaceId !== undefined && String(overviewWindowWorkspaceId) === String(newActiveWorkspaceId))
                newActiveWindowId = root.overviewWindowId;
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
                    "active_window_id": ws.active_window_id === undefined ? null : ws.active_window_id,
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
            var newActiveWindowsByOutput = {};
            for (var activeWorkspaceIndex = 0; activeWorkspaceIndex < processed.length; activeWorkspaceIndex++) {
                var activeWorkspace = processed[activeWorkspaceIndex];
                if (!activeWorkspace.is_active || activeWorkspace.output === "")
                    continue;

                newActiveWindowsByOutput[activeWorkspace.output] = activeWorkspace.windows;
                var activeCandidate = null;
                var activeCandidateId = activeWorkspace.active_window_id;
                var focusedWindowWorkspaceId = focusedWindow ? newWorkspaceIdByWindow[String(focusedWindow.id || "")] : undefined;
                if (overviewOpen && root.overviewWindowId !== "" && String(overviewWindowWorkspaceId) === String(activeWorkspace.id))
                    activeCandidateId = root.overviewWindowId;
                else if (!overviewOpen && focusedWindow && activeWorkspace.output === newFocusedOutputName && String(focusedWindowWorkspaceId) === String(activeWorkspace.id))
                    activeCandidateId = focusedWindow.id;
                else if ((activeCandidateId === null || activeCandidateId === undefined) && activeWorkspace.output === newFocusedOutputName && newActiveWindowId !== "")
                    activeCandidateId = newActiveWindowId;
                if (activeCandidateId !== null && activeCandidateId !== undefined && String(activeCandidateId) !== "") {
                    for (var focusedWindowIndex = 0; focusedWindowIndex < activeWorkspace.windows.length; focusedWindowIndex++) {
                        if (String(activeWorkspace.windows[focusedWindowIndex].id) === String(activeCandidateId)) {
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
                    if (root.workspaces[n].id !== processed[n].id || root.workspaces[n].idx !== processed[n].idx || root.workspaces[n].active_window_id !== processed[n].active_window_id || root.workspaces[n].output !== processed[n].output || root.workspaces[n].name !== processed[n].name || root.workspaces[n].windows.length !== processed[n].windows.length) {
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
            if (JSON.stringify(root.activeWindowsByOutput) !== JSON.stringify(newActiveWindowsByOutput))
                root.activeWindowsByOutput = newActiveWindowsByOutput;
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
    function selectOverviewWindow(windowId) {
        var id = String(windowId || "");
        if (id === "")
            return;

        root.overviewWindowId = id;
        var source = root.workspaces || [];
        for (var workspaceIndex = 0; workspaceIndex < source.length; workspaceIndex++) {
            var workspace = source[workspaceIndex];
            var windows = workspace.windows || [];
            for (var windowIndex = 0; windowIndex < windows.length; windowIndex++) {
                var window = windows[windowIndex];
                if (String(window.id) !== id)
                    continue;

                root.activeWindowId = id;
                root.activeWorkspaceId = workspace.id;
                if (workspace.output !== "") {
                    var activeByOutput = Object.assign({}, root.activeWindowByOutput || {});
                    activeByOutput[workspace.output] = root.windowSummary(window);
                    root.activeWindowByOutput = activeByOutput;
                    root.focusedOutputName = workspace.output;
                }
                return;
            }
        }
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
