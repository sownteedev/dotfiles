import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../../"
import "../../service"

RowLayout {
    id: root

    readonly property var activeWindow: WorkspaceService.activeWindowByOutput[root.outputName] || null
    readonly property string activeWindowId: activeWindow ? String(activeWindow.id || "") : WorkspaceService.activeWindowId
    property bool compact: false
    property int desktopEntriesRevision: 0
    readonly property int maxWorkspaceIdx: {
        var max = 0;
        var targetOutput = outputName || WorkspaceService.focusedOutputName;
        for (var i = 0; i < workspaces.length; i++) {
            if (workspaces[i].output === targetOutput && workspaces[i].windows.length > 0 && workspaces[i].idx > max)
                max = workspaces[i].idx;
        }
        return max;
    }
    property string outputName: ""
    readonly property string windowDragMimeType: "application/x-sownteeshell-window"
    readonly property real workspaceGap: compact ? 10 : 18
    readonly property var workspaces: WorkspaceService.workspaces

    function acceptWindowDrag(drag) {
        if (!windowDragData(drag)) {
            drag.accepted = false;
            return;
        }
        drag.accept(Qt.MoveAction);
    }

    // Helper to resolve application icon path
    function getAppIcon(appId) {
        if (!appId)
            return Quickshell.iconPath("application-x-executable");
        var entry = DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId);
        if (entry && entry.icon) {
            var iconPath = Quickshell.iconPath(entry.icon, true);
            if (iconPath)
                return iconPath;
        }
        var path = Quickshell.iconPath(appId, true);
        if (!path) {
            path = Quickshell.iconPath(appId.toLowerCase(), true);
        }
        return path ? path : Quickshell.iconPath("application-x-executable");
    }
    function getAppName(appId) {
        if (!appId)
            return "";
        var entry = DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId);
        return entry ? entry.name : appId;
    }
    function getWindowIcon(windowData) {
        var shellIcon = WorkspaceService.shellWindowIconName(windowData);
        return shellIcon !== "" ? Quickshell.iconPath(shellIcon) : getAppIcon(windowData && windowData.app_id);
    }
    function getWindowName(windowData) {
        var shellName = WorkspaceService.shellWindowDisplayName(windowData);
        return shellName !== "" ? shellName : getAppName(windowData && windowData.app_id);
    }
    function removeWorkspaceModelEntry(workspaceId) {
        for (var index = 0; index < workspaceModel.count; index++) {
            var entry = workspaceModel.get(index);
            if (entry.workspaceId === workspaceId && entry.pendingRemoval) {
                workspaceModel.remove(index);
                return;
            }
        }
    }
    function syncWorkspaceModel() {
        var allWorkspaces = root.workspaces || [];
        var source = [];
        var targetOutput = root.outputName || WorkspaceService.focusedOutputName;
        for (var sourceIndex = 0; sourceIndex < allWorkspaces.length; sourceIndex++) {
            if (targetOutput === "" || String(allWorkspaces[sourceIndex].output || "") === targetOutput)
                source.push(allWorkspaces[sourceIndex]);
        }
        var sourceIds = {};
        for (var idIndex = 0; idIndex < source.length; idIndex++)
            sourceIds[String(source[idIndex].id)] = true;

        for (var removeIndex = workspaceModel.count - 1; removeIndex >= 0; removeIndex--) {
            var removedEntry = workspaceModel.get(removeIndex);
            if (!sourceIds[String(removedEntry.workspaceId)]) {
                if (removedEntry.workspaceData.windows.length > 0 && !removedEntry.pendingRemoval) {
                    var closingWorkspace = Object.assign({}, removedEntry.workspaceData);
                    closingWorkspace.windows = [];
                    workspaceModel.setProperty(removeIndex, "workspaceData", closingWorkspace);
                    workspaceModel.setProperty(removeIndex, "pendingRemoval", true);
                } else if (!removedEntry.pendingRemoval) {
                    workspaceModel.remove(removeIndex);
                }
            }
        }

        for (var targetIndex = 0; targetIndex < source.length; targetIndex++) {
            var targetWorkspace = source[targetIndex];
            var currentIndex = -1;
            for (var modelIndex = 0; modelIndex < workspaceModel.count; modelIndex++) {
                if (workspaceModel.get(modelIndex).workspaceId === targetWorkspace.id) {
                    currentIndex = modelIndex;
                    break;
                }
            }

            if (currentIndex === -1) {
                workspaceModel.insert(targetIndex, {
                    "pendingRemoval": false,
                    "workspaceId": targetWorkspace.id,
                    "workspaceData": targetWorkspace
                });
            } else {
                if (currentIndex !== targetIndex)
                    workspaceModel.move(currentIndex, targetIndex, 1);
                var currentEntry = workspaceModel.get(targetIndex);
                if (!workspaceDataMatches(currentEntry.workspaceData, targetWorkspace))
                    workspaceModel.setProperty(targetIndex, "workspaceData", targetWorkspace);
                if (currentEntry.pendingRemoval)
                    workspaceModel.setProperty(targetIndex, "pendingRemoval", false);
            }
        }
    }
    function windowDragData(drop) {
        if (!drop)
            return null;

        var encoded = "";
        if (drop.formats && drop.formats.indexOf(root.windowDragMimeType) !== -1)
            encoded = String(drop.getDataAsString(root.windowDragMimeType) || "");
        if (encoded !== "") {
            try {
                var payload = JSON.parse(encoded);
                if (payload && String(payload.windowId || "") !== "")
                    return payload;
            } catch (error) {
                console.warn("[Workspaces] Invalid window drag payload:", error);
            }
        }

        var source = drop.source;
        if (!source || String(source.windowId || "") === "")
            return null;
        return {
            "windowId": String(source.windowId),
            "workspaceId": Number(source.workspaceId),
            "workspaceIdx": Number(source.workspaceIdx),
            "workspaceOutput": String(source.workspaceOutput || "")
        };
    }
    function workspaceDataMatches(previous, current) {
        if (!previous || !current)
            return false;
        if (Number(previous.id) !== Number(current.id) || Number(previous.idx) !== Number(current.idx) || String(previous.output || "") !== String(current.output || "") || String(previous.name || "") !== String(current.name || "") || String(previous.active_window_id || "") !== String(current.active_window_id || "") || !!previous.is_active !== !!current.is_active || !!previous.is_focused !== !!current.is_focused)
            return false;

        var previousWindows = previous.windows || [];
        var currentWindows = current.windows || [];
        if (previousWindows.length !== currentWindows.length)
            return false;
        for (var index = 0; index < currentWindows.length; index++) {
            if (String(previousWindows[index].id || "") !== String(currentWindows[index].id || "") || WorkspaceService.windowMetadataChanged(previousWindows[index], currentWindows[index]))
                return false;
        }
        return true;
    }
    function workspaceDisplayWindows(windows) {
        var source = windows || [];
        var visibleWindows = [];
        for (var index = 0; index < source.length; index++) {
            if (WorkspaceService.showInWorkspaceAndDock(source[index]))
                visibleWindows.push(source[index]);
        }
        return visibleWindows;
    }
    function workspaceWindowPosition(windows, windowId) {
        var source = windows || [];
        for (var index = 0; index < source.length; index++) {
            if (String(source[index].id) === String(windowId))
                return index + 1;
        }
        return 1;
    }

    spacing: 0

    Component.onCompleted: syncWorkspaceModel()
    onOutputNameChanged: syncWorkspaceModel()

    ListModel {
        id: workspaceModel

        dynamicRoles: true
    }
    Connections {
        function onApplicationsChanged() {
            root.desktopEntriesRevision++;
        }

        target: DesktopEntries
    }
    Connections {
        function onWorkspacesChanged() {
            root.syncWorkspaceModel();
        }

        target: WorkspaceService
    }
    Repeater {
        model: workspaceModel

        delegate: Rectangle {
            id: wsButton

            readonly property var displayWindows: root.workspaceDisplayWindows(workspaceData.windows)
            property bool expanded: false
            property real expansionProgress: expanded ? 1 : 0
            readonly property bool hasWindows: displayWindows.length > 0
            property bool inLayout: false
            required property bool pendingRemoval
            required property var workspaceData
            readonly property int workspaceId: workspaceData.id
            readonly property int workspaceIdx: workspaceData.idx
            readonly property string workspaceOutput: workspaceData.output

            border.width: 0
            color: "transparent"
            implicitHeight: 38
            implicitWidth: (wsLayout.implicitWidth + 30 + root.workspaceGap) * expansionProgress
            opacity: expanded ? 1 : 0
            scale: expanded ? 1 : 0.82
            visible: inLayout

            Behavior on expansionProgress {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutBack
                }
            }

            Component.onCompleted: {
                if (hasWindows) {
                    inLayout = true;
                    Qt.callLater(function () {
                        if (wsButton.hasWindows)
                            wsButton.expanded = true;
                    });
                }
            }
            onHasWindowsChanged: {
                if (hasWindows) {
                    collapseTimer.stop();
                    inLayout = true;
                    Qt.callLater(function () {
                        if (wsButton.hasWindows)
                            wsButton.expanded = true;
                    });
                } else {
                    expanded = false;
                    collapseTimer.restart();
                }
            }

            Timer {
                id: collapseTimer

                interval: 270

                onTriggered: {
                    if (!wsButton.hasWindows) {
                        wsButton.inLayout = false;
                        if (wsButton.pendingRemoval)
                            root.removeWorkspaceModelEntry(wsButton.workspaceId);
                    }
                }
            }
            Rectangle {
                id: workspaceSurface

                border.color: dropArea.containsDrag ? Config.md3.surface_container_highest : "transparent"
                border.width: 1
                color: dropArea.containsDrag ? Config.alpha(Config.md3.surface_container_high, Config.lightTheme ? 0.8 : 0.6) : (wsButton.workspaceData.is_active ? Config.alpha(Config.md3.surface_container_highest, Config.lightTheme ? 0.7 : 0.5) : Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.7 : 0.5))
                height: 38
                radius: 7
                scale: dropArea.containsDrag ? 1.05 : 1.0
                width: Math.max(0, wsButton.width - root.workspaceGap)
                x: root.workspaceGap / 2

                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutQuad
                    }
                }
            }
            DropArea {
                id: dropArea

                anchors.fill: workspaceSurface

                onDropped: drop => {
                    var payload = root.windowDragData(drop);
                    if (!payload) {
                        drop.accepted = false;
                        return;
                    }
                    console.log("Dropped window:", payload.windowId, "to workspace:", wsButton.workspaceIdx, "on", wsButton.workspaceOutput);
                    WorkspaceService.moveWindowToWorkspace(payload.windowId, payload.workspaceOutput, wsButton.workspaceData);
                    drop.accept(Qt.MoveAction);
                }
                onEntered: drag => root.acceptWindowDrag(drag)
            }
            MouseArea {
                anchors.fill: workspaceSurface

                onClicked: {
                    WorkspaceService.focusWorkspace(wsButton.workspaceData);
                }
            }
            RowLayout {
                id: wsLayout

                anchors.centerIn: workspaceSurface
                spacing: root.compact ? 8 : 12

                // Workspace ID/Index
                Text {
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: root.compact ? 11 : 14
                    font.weight: Font.Black
                    text: String(wsButton.workspaceIdx)
                }

                // Window list inside workspace (flat, no inner pills)
                RowLayout {
                    spacing: root.compact ? 6 : 10
                    visible: wsButton.displayWindows.length > 0

                    Repeater {
                        model: wsButton.displayWindows

                        delegate: Item {
                            id: winIconItem

                            readonly property bool shellWindow: shellWindowKind !== ""
                            readonly property string shellWindowKind: WorkspaceService.shellWindowKind(modelData)

                            implicitHeight: 22
                            implicitWidth: winIconLayout.implicitWidth
                            z: winIconMouseArea.drag.active ? 9999 : 1

                            DropArea {
                                id: iconDropArea

                                anchors.fill: parent

                                onDropped: drop => {
                                    var payload = root.windowDragData(drop);
                                    if (!payload) {
                                        drop.accepted = false;
                                        return;
                                    }
                                    var draggedWinId = payload.windowId;
                                    var draggedFromWorkspaceId = payload.workspaceId;
                                    var draggedFromOutput = payload.workspaceOutput;
                                    var targetWinId = modelData.id;
                                    var targetPos = root.workspaceWindowPosition(wsButton.workspaceData.windows, targetWinId);

                                    if (String(draggedWinId) === String(targetWinId)) {
                                        drop.accepted = false;
                                        return;
                                    }

                                    if (draggedFromWorkspaceId === wsButton.workspaceId) {
                                        // Moving within the same workspace: re-order column position
                                        WorkspaceService.moveWindowToColumn(draggedWinId, targetPos, String(draggedWinId) !== root.activeWindowId);
                                    } else {
                                        WorkspaceService.moveWindowToWorkspace(draggedWinId, draggedFromOutput, wsButton.workspaceData, targetPos);
                                    }
                                    drop.accept(Qt.MoveAction);
                                }
                                onEntered: drag => root.acceptWindowDrag(drag)
                            }
                            Item {
                                id: dragProxy

                                property bool acceptedDropPending: false
                                property bool iconGrabPending: false
                                property real returnOpacity: 1.0
                                property real returnScale: 1.0
                                property bool returningToSource: false
                                property bool sourceHidden: false
                                property string windowId: String(modelData.id)
                                property int workspaceId: wsButton.workspaceId
                                property int workspaceIdx: wsButton.workspaceIdx
                                property string workspaceOutput: wsButton.workspaceOutput

                                function beginPlatformDrag() {
                                    if (dragProxy.Drag.active || iconGrabPending)
                                        return;

                                    acceptedDropReset.stop();
                                    acceptedDropPending = false;
                                    iconGrabPending = true;
                                    var grabStarted = windowIcon.grabToImage(function (result) {
                                        iconGrabPending = false;
                                        if (!winIconMouseArea.drag.active) {
                                            WorkspaceService.windowDragActive = false;
                                            return;
                                        }

                                        var previewPath = "/tmp/sownteeshell-workspace-drag-" + dragProxy.windowId + ".png";
                                        dragProxy.Drag.imageSource = result.saveToFile(previewPath) ? "file://" + previewPath : "";
                                        dragProxy.sourceHidden = true;
                                        dragProxy.Drag.active = true;
                                    }, Qt.size(32, 32));
                                    if (!grabStarted) {
                                        iconGrabPending = false;
                                        dragProxy.Drag.imageSource = "";
                                        dragProxy.sourceHidden = true;
                                        dragProxy.Drag.active = true;
                                    }
                                }
                                function finishPlatformDrag(dropAction) {
                                    dragProxy.Drag.active = false;
                                    WorkspaceService.windowDragActive = false;

                                    if (dropAction === Qt.MoveAction) {
                                        acceptedDropPending = true;
                                        returningToSource = false;
                                        returnOpacity = 1.0;
                                        returnScale = 1.0;
                                        dragProxy.x = 0;
                                        dragProxy.y = 0;
                                        acceptedDropReset.restart();
                                        return;
                                    }

                                    acceptedDropPending = false;
                                    sourceHidden = true;
                                    returningToSource = true;
                                    returnOpacity = 0.0;
                                    returnScale = 0.72;
                                    dragProxy.x = 0;
                                    dragProxy.y = 0;
                                    returnRevealTimer.restart();
                                }

                                Drag.dragType: Drag.Automatic
                                Drag.hotSpot.x: 12
                                Drag.hotSpot.y: 12
                                Drag.imageSourceSize: Qt.size(32, 32)
                                Drag.mimeData: {
                                    var data = {};
                                    data[root.windowDragMimeType] = JSON.stringify({
                                        "windowId": dragProxy.windowId,
                                        "workspaceId": dragProxy.workspaceId,
                                        "workspaceIdx": dragProxy.workspaceIdx,
                                        "workspaceOutput": dragProxy.workspaceOutput
                                    });
                                    return data;
                                }
                                Drag.proposedAction: Qt.MoveAction
                                Drag.supportedActions: Qt.MoveAction
                                height: 25
                                opacity: 0
                                visible: true
                                width: 25

                                Drag.onDragFinished: dropAction => dragProxy.finishPlatformDrag(dropAction)

                                Timer {
                                    id: acceptedDropReset

                                    interval: 260
                                    repeat: false

                                    onTriggered: {
                                        dragProxy.acceptedDropPending = false;
                                        dragProxy.sourceHidden = false;
                                    }
                                }
                                Timer {
                                    id: returnRevealTimer

                                    interval: 35
                                    repeat: false

                                    onTriggered: {
                                        dragProxy.sourceHidden = false;
                                        returnAnimation.restart();
                                    }
                                }
                                ParallelAnimation {
                                    id: returnAnimation

                                    onFinished: {
                                        dragProxy.x = 0;
                                        dragProxy.y = 0;
                                        dragProxy.returnOpacity = 1.0;
                                        dragProxy.returnScale = 1.0;
                                        dragProxy.returningToSource = false;
                                        dragProxy.acceptedDropPending = false;
                                    }

                                    NumberAnimation {
                                        duration: 120
                                        easing.type: Easing.OutQuad
                                        property: "returnOpacity"
                                        target: dragProxy
                                        to: 1.0
                                    }
                                    NumberAnimation {
                                        duration: 210
                                        easing.type: Easing.OutBack
                                        property: "returnScale"
                                        target: dragProxy
                                        to: 1.0
                                    }
                                }
                            }
                            MouseArea {
                                id: winIconMouseArea

                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                drag.target: dragProxy
                                hoverEnabled: true

                                drag.onActiveChanged: {
                                    if (drag.active) {
                                        WorkspaceService.windowDragActive = true;
                                        dragProxy.beginPlatformDrag();
                                    }
                                }
                                onCanceled: {
                                    if (!dragProxy.Drag.active) {
                                        WorkspaceService.windowDragActive = false;
                                        if (!dragProxy.returningToSource && !dragProxy.acceptedDropPending) {
                                            dragProxy.sourceHidden = false;
                                            dragProxy.x = 0;
                                            dragProxy.y = 0;
                                        }
                                    }
                                }
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        Quickshell.execDetached(["niri", "msg", "action", "close-window", "--id", String(modelData.id)]);
                                    } else {
                                        Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(modelData.id)]);
                                    }
                                }
                                onReleased: {
                                    if (!dragProxy.Drag.active && !dragProxy.iconGrabPending && !dragProxy.returningToSource && !dragProxy.acceptedDropPending) {
                                        dragProxy.sourceHidden = false;
                                        dragProxy.x = 0;
                                        dragProxy.y = 0;
                                    }
                                }
                            }
                            RowLayout {
                                id: winIconLayout

                                anchors.verticalCenter: (winIconMouseArea.drag.active || dragProxy.returningToSource) ? undefined : parent.verticalCenter
                                opacity: dragProxy.returningToSource ? dragProxy.returnOpacity : (winIconMouseArea.drag.active ? 0.75 : 1.0)
                                rotation: winIconMouseArea.drag.active ? 6 : 0
                                scale: dragProxy.returningToSource ? dragProxy.returnScale : (winIconMouseArea.drag.active ? 1.25 : (iconDropArea.containsDrag ? 0.85 : 1.0))
                                spacing: 0
                                visible: !dragProxy.sourceHidden
                                x: dragProxy.x
                                y: (winIconMouseArea.drag.active || dragProxy.returningToSource) ? dragProxy.y : (winIconMouseArea.containsMouse ? -5 : 0)

                                Behavior on opacity {
                                    enabled: !dragProxy.returningToSource

                                    NumberAnimation {
                                        duration: 150
                                    }
                                }
                                Behavior on rotation {
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutQuad
                                    }
                                }
                                Behavior on scale {
                                    enabled: !dragProxy.returningToSource

                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutQuad
                                    }
                                }
                                Behavior on y {
                                    enabled: !winIconMouseArea.drag.active

                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutQuad
                                    }
                                }

                                IconImage {
                                    id: windowIcon

                                    height: winIconItem.shellWindowKind === "settings" ? (root.compact ? 19 : 21) : (root.compact ? 22 : 25)
                                    layer.enabled: winIconItem.shellWindow
                                    scale: (winIconMouseArea.containsMouse && !winIconMouseArea.drag.active) ? 1.15 : 1.0
                                    source: {
                                        root.desktopEntriesRevision;
                                        return root.getWindowIcon(modelData);
                                    }
                                    width: height

                                    layer.effect: ColorOverlay {
                                        color: Config.md3.on_surface
                                    }
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 150
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                }
                                Item {
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: !winIconMouseArea.drag.active && String(modelData.id) === root.activeWindowId ? Math.min(titleText.implicitWidth, root.compact ? 86 : 150) + 7 : 0
                                    clip: true
                                    opacity: !winIconMouseArea.drag.active && String(modelData.id) === root.activeWindowId ? 1 : 0

                                    Behavior on Layout.preferredWidth {
                                        NumberAnimation {
                                            duration: 250
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: 150
                                        }
                                    }

                                    Text {
                                        id: titleText

                                        anchors.left: parent.left
                                        anchors.leftMargin: 7
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: Config.md3.on_surface
                                        elide: Text.ElideRight
                                        font.family: Config.fontName
                                        font.pixelSize: root.compact ? 13 : 15
                                        font.weight: Font.Medium
                                        text: {
                                            root.desktopEntriesRevision;
                                            return root.getWindowName(modelData);
                                        }
                                        width: Math.min(implicitWidth, root.compact ? 86 : 150)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // "New workspace" drop zone — appears only while dragging
    Item {
        implicitHeight: newWsRect.implicitHeight
        implicitWidth: newWsRect.implicitWidth
        opacity: WorkspaceService.windowDragActive ? 1.0 : 0.0
        visible: WorkspaceService.windowDragActive

        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutQuad
            }
        }

        Rectangle {
            id: newWsRect

            border.color: dropNewArea.containsDrag ? Config.md3.primary : Config.md3.surface_container_highest
            border.width: 1
            color: dropNewArea.containsDrag ? Config.alpha(Config.md3.primary, 0.35) : Config.alpha(Config.md3.surface, Config.lightTheme ? 0.7 : 0.5)
            implicitHeight: 38
            implicitWidth: 38
            radius: 7
            scale: dropNewArea.containsDrag ? 1.08 : 1.0

            Behavior on border.color {
                ColorAnimation {
                    duration: 150
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutBack
                }
            }

            DropArea {
                id: dropNewArea

                anchors.fill: parent

                onDropped: drop => {
                    var payload = root.windowDragData(drop);
                    if (!payload) {
                        drop.accepted = false;
                        return;
                    }
                    var newIdx = root.maxWorkspaceIdx + 1;
                    var targetOutput = root.outputName || WorkspaceService.focusedOutputName;
                    console.log("[Workspaces] Moving window", payload.windowId, "to new workspace", newIdx, "on", targetOutput);
                    WorkspaceService.moveWindowToWorkspace(payload.windowId, payload.workspaceOutput, {
                        "idx": newIdx,
                        "name": "",
                        "output": targetOutput
                    });
                    drop.accept(Qt.MoveAction);
                }
                onEntered: drag => root.acceptWindowDrag(drag)
            }

            // "+" label
            Text {
                anchors.centerIn: parent
                color: dropNewArea.containsDrag ? Config.md3.primary : Config.alpha(Config.md3.on_surface, 0.55)
                font.family: Config.fontName
                font.pixelSize: 18
                font.weight: Font.Bold
                text: "+"

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
        }
    }
}
