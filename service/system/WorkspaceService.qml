pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

QtObject {
    id: root

    property var activeWindowByOutput: ({})
    property string activeWindowId: ""
    property var activeWindowsByOutput: ({})
    property int activeWorkspaceId: -1
    property var activeWorkspaceIdByOutput: ({})
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
    property bool windowDragActive: false
    property Process windowMoveProcess: Process {
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    console.warn("[Workspaces]", text.trim());
            }
        }

        onExited: {
            root.refresh();
            Qt.callLater(root.startNextWindowMove);
        }
    }
    property var windowMoveQueue: []
    property var workspaceIdByWindow: ({})
    property var workspaces: []

    function applyFocusedWindow(windowId, rememberOverviewSelection) {
        var id = String(windowId || "");
        if (id === "")
            return false;

        if (rememberOverviewSelection)
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
                    var activeWorkspaceByOutput = Object.assign({}, root.activeWorkspaceIdByOutput || {});
                    activeWorkspaceByOutput[workspace.output] = workspace.id;
                    root.activeWorkspaceIdByOutput = activeWorkspaceByOutput;
                    root.focusedOutputName = workspace.output;
                }
                return true;
            }
        }
        return false;
    }
    function compareWindowsByLayout(a, b, workspaceIsFloating) {
        var aFloating = Boolean(a && (a.is_floating === true || workspaceIsFloating));
        var bFloating = Boolean(b && (b.is_floating === true || workspaceIsFloating));

        if (!aFloating && bFloating)
            return -1;
        if (aFloating && !bFloating)
            return 1;

        if (aFloating && bFloating) {
            var aX = windowLayoutCoordinate(a, "tile_pos_in_workspace_view", 0);
            var bX = windowLayoutCoordinate(b, "tile_pos_in_workspace_view", 0);
            if (aX !== bX)
                return aX - bX;

            var aY = windowLayoutCoordinate(a, "tile_pos_in_workspace_view", 1);
            var bY = windowLayoutCoordinate(b, "tile_pos_in_workspace_view", 1);
            if (aY !== bY)
                return aY - bY;

            return Number(a.id || 0) - Number(b.id || 0);
        }

        var aCol = windowLayoutCoordinate(a, "pos_in_scrolling_layout", 0);
        var bCol = windowLayoutCoordinate(b, "pos_in_scrolling_layout", 0);
        if (aCol !== bCol)
            return aCol - bCol;

        var aRow = windowLayoutCoordinate(a, "pos_in_scrolling_layout", 1);
        var bRow = windowLayoutCoordinate(b, "pos_in_scrolling_layout", 1);
        if (aRow !== bRow)
            return aRow - bRow;

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
            } else if (event.WorkspaceActivated) {
                var activatedId = Number(event.WorkspaceActivated.id);
                var activatedOutput = root.workspaceOutputForId(activatedId);
                if (!isNaN(activatedId) && activatedOutput !== "") {
                    var activeIds = Object.assign({}, root.activeWorkspaceIdByOutput || {});
                    activeIds[activatedOutput] = activatedId;
                    root.activeWorkspaceIdByOutput = activeIds;
                    if (event.WorkspaceActivated.focused === true) {
                        root.activeWorkspaceId = activatedId;
                        root.focusedOutputName = activatedOutput;
                    }
                }
            } else if (event.WindowFocusChanged && event.WindowFocusChanged.id !== null && event.WindowFocusChanged.id !== undefined) {
                root.applyFocusedWindow(event.WindowFocusChanged.id, root.overviewOpen);
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
    function isQuickshellWindow(windowData) {
        var appId = String(windowData && windowData.app_id || "").trim().toLowerCase();
        var shellAppId = String(Quickshell.appId || "org.quickshell").trim().toLowerCase();
        return appId === shellAppId || appId === "org.quickshell" || appId === "quickshell";
    }
    function layoutPositionIsValid(position) {
        if (!position || position.length < 2 || position[0] === null || position[0] === undefined || position[1] === null || position[1] === undefined)
            return false;
        return !isNaN(Number(position[0])) && !isNaN(Number(position[1]));
    }
    function moveWindowToColumn(windowId, targetWindowId) {
        var id = String(windowId || "");
        var targetId = String(targetWindowId || "");
        if (id === "" || targetId === "" || id === targetId)
            return;
        queueWindowMove({
            "window_id": id,
            "target_window_id": targetId
        });
    }
    function moveWindowToWorkspace(windowId, workspace, targetWindowId) {
        var id = String(windowId || "");
        if (id === "" || !workspace)
            return;
        queueWindowMove({
            "window_id": id,
            "target_window_id": String(targetWindowId || ""),
            "workspace": {
                "id": workspace.id,
                "idx": workspace.idx,
                "name": String(workspace.name || ""),
                "output": String(workspace.output || "")
            }
        });
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
            var newActiveWorkspaceIdByOutput = {};
            for (var outputIndex = 0; outputIndex < wsList.length; outputIndex++) {
                var outputName = String(wsList[outputIndex].output || "");
                if (outputName !== "" && !outputSet[outputName]) {
                    outputSet[outputName] = true;
                    newOutputNames.push(outputName);
                }
                if (outputName !== "" && wsList[outputIndex].is_active)
                    newActiveWorkspaceIdByOutput[outputName] = wsList[outputIndex].id;
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
            var previousActiveWindows = root.activeWindowsByOutput || {};
            for (var previousOutput in previousActiveWindows) {
                var outputWindows = previousActiveWindows[previousOutput] || [];
                for (var outputWindowIndex = 0; outputWindowIndex < outputWindows.length; ++outputWindowIndex) {
                    var latestWindow = outputWindows[outputWindowIndex];
                    previousWindowById[String(latestWindow.id || "")] = latestWindow;
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
            if (JSON.stringify(root.activeWorkspaceIdByOutput) !== JSON.stringify(newActiveWorkspaceIdByOutput))
                root.activeWorkspaceIdByOutput = newActiveWorkspaceIdByOutput;
            if (JSON.stringify(root.activeWindowByOutput) !== JSON.stringify(newActiveWindowByOutput))
                root.activeWindowByOutput = newActiveWindowByOutput;
            if (JSON.stringify(root.activeWindowsByOutput) !== JSON.stringify(newActiveWindowsByOutput))
                root.activeWindowsByOutput = newActiveWindowsByOutput;
            root.focusedOutputName = newFocusedOutputName;
            if (root.isWorkspaceFloating !== floating)
                root.isWorkspaceFloating = floating;
            root.outputNames = newOutputNames;
            if (JSON.stringify(root.floatingByOutput) !== JSON.stringify(newFloatingByOutput))
                root.floatingByOutput = newFloatingByOutput;

            if (needsRebuild)
                root.workspaces = processed;
        } catch (error) {
            console.error("Failed to parse workspaces data:", error);
        }
    }
    function queueWindowMove(request) {
        root.windowMoveQueue = root.windowMoveQueue.concat([request]);
        root.startNextWindowMove();
    }
    function refresh() {
        if (queryData.running) {
            refreshPending = true;
            return;
        }
        queryData.running = true;
    }
    function selectOverviewWindow(windowId) {
        root.applyFocusedWindow(windowId, true);
    }
    function shellWindowDisplayName(windowData) {
        if (String(windowData && windowData.app_id || "").trim().toLowerCase() === "sownteeshell-connect")
            return "SownteeShell Connect";
        var kind = shellWindowKind(windowData);
        if (kind === "settings")
            return qsTr("SownteeShell Settings");
        if (kind === "calendar")
            return qsTr("SownteeShell Calendar");
        return "";
    }
    function shellWindowEntryId(windowData) {
        var kind = shellWindowKind(windowData);
        return kind === "" ? "" : "sownteeshell-" + kind;
    }
    function shellWindowIconName(windowData) {
        if (String(windowData && windowData.app_id || "").trim().toLowerCase() === "sownteeshell-connect")
            return Config.sownteeshellDir + "/assets/icons/sownteeshell-connect.svg";
        var kind = shellWindowKind(windowData);
        if (kind === "settings")
            return "sownteeshell-settings";
        if (kind === "calendar")
            return "sownteeshell-calendar";
        return "";
    }
    function shellWindowKind(windowData) {
        if (String(windowData && windowData.app_id || "").trim().toLowerCase() === "sownteeshell-connect")
            return "connect";
        var title = String(windowData && windowData.title || "").trim().toLowerCase();
        if (title === "sownteeshell settings")
            return "settings";
        if (title === "sownteeshell calendar")
            return "calendar";
        return "";
    }
    function showInWorkspaceAndDock(windowData) {
        return !isQuickshellWindow(windowData) || shellWindowKind(windowData) !== "";
    }
    function startNextWindowMove() {
        if (root.windowMoveProcess.running || root.windowMoveQueue.length === 0)
            return;
        var request = root.windowMoveQueue[0];
        root.windowMoveQueue = root.windowMoveQueue.slice(1);
        root.windowMoveProcess.command = ["python3", Config.sownteeshellDir + "/backend/python/workspace/move_window.py", JSON.stringify(request)];
        root.windowMoveProcess.running = true;
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
        return String(previous.app_id || "") !== String(current.app_id || "") || String(previous.title || "") !== String(current.title || "") || previous.workspace_id !== current.workspace_id || previous.is_floating !== current.is_floating;
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
    function workspaceOutputForId(workspaceId) {
        var source = root.workspaces || [];
        for (var index = 0; index < source.length; index++) {
            if (Number(source[index].id) === Number(workspaceId))
                return String(source[index].output || "");
        }
        return "";
    }
    function workspaceReference(workspace) {
        var name = String(workspace && workspace.name || "");
        if (name !== "")
            return name;
        return workspace && workspace.idx !== undefined ? String(workspace.idx) : "";
    }
}
