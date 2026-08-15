import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../../"
import "../../service"

RowLayout {
    id: root

    readonly property var activeWindow: WorkspaceService.activeWindowByOutput[root.outputName] || null
    readonly property string activeWindowId: activeWindow ? String(activeWindow.id || "") : WorkspaceService.activeWindowId
    readonly property int activeWorkspaceId: WorkspaceService.activeWorkspaceId
    property bool compact: false
    property int desktopEntriesRevision: 0
    property bool isDragging: false
    readonly property int maxWorkspaceIdx: {
        var max = 0;
        var targetOutput = outputName || WorkspaceService.focusedOutputName;
        for (var i = 0; i < workspaces.length; i++) {
            if (workspaces[i].output === targetOutput && workspaces[i].windows.length > 0 && workspaces[i].idx > max)
                max = workspaces[i].idx;
        }
        return max;
    }
    readonly property bool multipleOutputs: WorkspaceService.outputNames.length > 1
    property string outputName: ""
    readonly property real workspaceGap: compact ? 10 : 18
    readonly property var workspaces: WorkspaceService.workspaces

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
        var source = root.workspaces || [];
        var sourceIds = {};
        for (var sourceIndex = 0; sourceIndex < source.length; sourceIndex++)
            sourceIds[String(source[sourceIndex].id)] = true;

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
                workspaceModel.setProperty(targetIndex, "workspaceData", targetWorkspace);
                workspaceModel.setProperty(targetIndex, "pendingRemoval", false);
            }
        }
    }

    spacing: 0

    Component.onCompleted: syncWorkspaceModel()

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

            property bool expanded: false
            property real expansionProgress: expanded ? 1 : 0
            readonly property bool hasWindows: workspaceData.windows.length > 0
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
                color: dropArea.containsDrag ? Config.alpha(Config.md3.surface_container_high, Config.lightTheme ? 0.8 : 0.6) : (wsButton.workspaceId === root.activeWorkspaceId ? Config.alpha(Config.md3.surface_container_highest, Config.lightTheme ? 0.7 : 0.5) : Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.7 : 0.5))
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
                keys: ["niri-window"]

                onDropped: drop => {
                    var windowId = drop.source.windowId;
                    console.log("Dropped window:", windowId, "to workspace:", wsButton.workspaceIdx, "on", wsButton.workspaceOutput);
                    WorkspaceService.moveWindowToWorkspace(windowId, drop.source.workspaceOutput, wsButton.workspaceData);
                }
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
                    font.pixelSize: root.compact ? 11 : root.multipleOutputs ? 12 : 14
                    font.weight: Font.Black
                    text: root.multipleOutputs ? wsButton.workspaceOutput + " · " + wsButton.workspaceIdx : String(wsButton.workspaceIdx)
                }

                // Window list inside workspace (flat, no inner pills)
                RowLayout {
                    spacing: root.compact ? 6 : 10
                    visible: wsButton.hasWindows

                    Repeater {
                        model: wsButton.workspaceData.windows

                        delegate: Item {
                            id: winIconItem

                            implicitHeight: 22
                            implicitWidth: winIconLayout.implicitWidth
                            z: winIconMouseArea.drag.active ? 9999 : 1

                            DropArea {
                                id: iconDropArea

                                anchors.fill: parent
                                keys: ["niri-window"]

                                onDropped: drop => {
                                    var draggedWinId = drop.source.windowId;
                                    var draggedFromWorkspaceId = drop.source.workspaceId;
                                    var draggedFromOutput = drop.source.workspaceOutput;
                                    var targetWinId = modelData.id;
                                    var targetPos = index + 1;

                                    if (draggedWinId === targetWinId)
                                        return;

                                    if (draggedFromWorkspaceId === wsButton.workspaceId) {
                                        var cmd = "niri msg action focus-window --id " + draggedWinId + " && niri msg action move-column-to-index " + targetPos;
                                        Quickshell.execDetached(["sh", "-c", cmd]);
                                    } else {
                                        WorkspaceService.moveWindowToWorkspace(draggedWinId, draggedFromOutput, wsButton.workspaceData, targetPos);
                                    }
                                }
                            }
                            Item {
                                id: dragProxy

                                property string windowId: String(modelData.id)
                                property int workspaceId: wsButton.workspaceId
                                property int workspaceIdx: wsButton.workspaceIdx
                                property string workspaceOutput: wsButton.workspaceOutput

                                Drag.active: winIconMouseArea.drag.active
                                Drag.hotSpot.x: 12
                                Drag.hotSpot.y: 12
                                Drag.keys: ["niri-window"]
                                height: 25
                                opacity: 0
                                visible: true
                                width: 25
                            }
                            MouseArea {
                                id: winIconMouseArea

                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                drag.target: dragProxy
                                hoverEnabled: true

                                drag.onActiveChanged: {
                                    root.isDragging = drag.active;
                                }
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        Quickshell.execDetached(["niri", "msg", "action", "close-window", "--id", String(modelData.id)]);
                                    } else {
                                        Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(modelData.id)]);
                                    }
                                }
                                onPressed: {
                                    root.isDragging = false;
                                }
                                onReleased: {
                                    root.isDragging = false;
                                    if (dragProxy.Drag.active) {
                                        dragProxy.Drag.drop();
                                        dragProxy.x = 0;
                                        dragProxy.y = 0;
                                    }
                                }
                            }
                            RowLayout {
                                id: winIconLayout

                                anchors.verticalCenter: winIconMouseArea.drag.active ? undefined : parent.verticalCenter
                                opacity: winIconMouseArea.drag.active ? 0.75 : 1.0
                                rotation: winIconMouseArea.drag.active ? 6 : 0
                                scale: winIconMouseArea.drag.active ? 1.25 : (iconDropArea.containsDrag ? 0.85 : 1.0)
                                spacing: 0
                                x: dragProxy.x
                                y: winIconMouseArea.drag.active ? dragProxy.y : (winIconMouseArea.containsMouse ? -5 : 0)

                                Behavior on opacity {
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
                                    height: root.compact ? 22 : 25
                                    scale: (winIconMouseArea.containsMouse && !winIconMouseArea.drag.active) ? 1.15 : 1.0
                                    source: {
                                        root.desktopEntriesRevision;
                                        return root.getAppIcon(modelData.app_id);
                                    }
                                    width: root.compact ? 22 : 25

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 150
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                }
                                Item {
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: String(modelData.id) === root.activeWindowId ? Math.min(titleText.implicitWidth, root.compact ? 86 : 150) + 7 : 0
                                    clip: true

                                    Behavior on Layout.preferredWidth {
                                        NumberAnimation {
                                            duration: 250
                                            easing.type: Easing.OutCubic
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
                                            return modelData.app_id ? root.getAppName(modelData.app_id) : "";
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
        opacity: root.isDragging ? 1.0 : 0.0
        visible: root.isDragging

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
                keys: ["niri-window"]

                onDropped: drop => {
                    var windowId = drop.source.windowId;
                    var newIdx = root.maxWorkspaceIdx + 1;
                    var targetOutput = root.outputName || WorkspaceService.focusedOutputName;
                    console.log("[Workspaces] Moving window", windowId, "to new workspace", newIdx, "on", targetOutput);
                    WorkspaceService.moveWindowToWorkspace(windowId, drop.source.workspaceOutput, {
                        "idx": newIdx,
                        "name": "",
                        "output": targetOutput
                    });
                }
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
