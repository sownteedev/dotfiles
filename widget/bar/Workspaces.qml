import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../../"
import "../../service"

RowLayout {
    id: root

    readonly property string activeWindowId: WorkspaceService.activeWindowId
    readonly property int activeWorkspaceId: WorkspaceService.activeWorkspaceId
    property int desktopEntriesRevision: 0
    property bool isDragging: false
    readonly property int maxWorkspaceIdx: {
        var max = 0;
        for (var i = 0; i < workspaces.length; i++)
            if (workspaces[i].idx > max)
                max = workspaces[i].idx;
        return max;
    }
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

    // Helper to resolve friendly application name
    function getAppName(appId) {
        if (!appId)
            return "";
        var entry = DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId);
        return entry ? entry.name : appId;
    }

    spacing: 18

    Connections {
        function onApplicationsChanged() {
            root.desktopEntriesRevision++;
        }

        target: DesktopEntries
    }
    Repeater {
        model: root.workspaces

        delegate: Rectangle {
            id: wsButton

            readonly property int workspaceIdx: modelData.idx

            border.color: dropArea.containsDrag ? Config.md3.surface_container_highest : "transparent"
            border.width: 1
            color: dropArea.containsDrag ? Config.alpha(Config.md3.surface_container_high, Config.lightTheme ? 0.8 : 0.6) : (modelData.id === root.activeWorkspaceId ? Config.alpha(Config.md3.surface_container_highest, Config.lightTheme ? 0.7 : 0.5) : Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.7 : 0.5))
            implicitHeight: 38
            implicitWidth: wsLayout.implicitWidth + 30
            radius: 7
            scale: dropArea.containsDrag ? 1.05 : 1.0

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

            DropArea {
                id: dropArea

                anchors.fill: parent
                keys: ["niri-window"]

                onDropped: drop => {
                    var windowId = drop.source.windowId;
                    var destWorkspace = modelData.idx;
                    console.log("Dropped window:", windowId, "to workspace:", destWorkspace);
                    Quickshell.execDetached(["niri", "msg", "action", "move-window-to-workspace", "--window-id", String(windowId), String(destWorkspace)]);
                }
            }
            MouseArea {
                anchors.fill: parent

                onClicked: {
                    Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(modelData.idx)]);
                }
            }
            RowLayout {
                id: wsLayout

                anchors.centerIn: parent
                spacing: 12

                // Workspace ID/Index
                Text {
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.Black
                    text: String(modelData.idx)
                }

                // Window list inside workspace (flat, no inner pills)
                RowLayout {
                    spacing: 10
                    visible: modelData.windows.length > 0

                    Repeater {
                        model: modelData.windows

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
                                    var draggedFromWS = drop.source.workspaceIdx;
                                    var targetWinId = modelData.id;
                                    var targetWS = wsButton.workspaceIdx;
                                    var targetPos = index + 1;

                                    if (draggedWinId === targetWinId)
                                        return;

                                    if (draggedFromWS === targetWS) {
                                        var cmd = "niri msg action focus-window --id " + draggedWinId + " && niri msg action move-column-to-index " + targetPos;
                                        Quickshell.execDetached(["sh", "-c", cmd]);
                                    } else {
                                        var cmd = "niri msg action move-window-to-workspace --window-id " + draggedWinId + " " + targetWS + " && sleep 0.05 && niri msg action focus-window --id " + draggedWinId + " && niri msg action move-column-to-index " + targetPos;
                                        Quickshell.execDetached(["sh", "-c", cmd]);
                                    }
                                }
                            }
                            Item {
                                id: dragProxy

                                property string windowId: String(modelData.id)
                                property int workspaceIdx: wsButton.workspaceIdx

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
                                    height: 25
                                    scale: (winIconMouseArea.containsMouse && !winIconMouseArea.drag.active) ? 1.15 : 1.0
                                    source: {
                                        root.desktopEntriesRevision;
                                        return root.getAppIcon(modelData.app_id);
                                    }
                                    width: 25

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 150
                                            easing.type: Easing.OutBack
                                        }
                                    }
                                }
                                Item {
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: (String(modelData.id) === root.activeWindowId) ? (titleText.implicitWidth + 7) : 0
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
                                        font.family: Config.fontName
                                        font.pixelSize: 15
                                        font.weight: Font.Medium
                                        text: {
                                            root.desktopEntriesRevision;
                                            return modelData.app_id ? root.getAppName(modelData.app_id) : "";
                                        }
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
                    console.log("[Workspaces] Moving window", windowId, "to new workspace", newIdx);
                    Quickshell.execDetached(["niri", "msg", "action", "move-window-to-workspace", "--window-id", String(windowId), String(newIdx)]);
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
