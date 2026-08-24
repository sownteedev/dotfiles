pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import "../../"
import "../../components"
import "../../service"

PanelWindow {
    id: dockWindow

    readonly property var activeWindows: WorkspaceService.activeWindowsByOutput[screen ? screen.name : ""] || []
    readonly property int appCount: dockModel.count
    property bool autoHidden: false
    readonly property real desiredPinnedWidth: appCount > 0 ? appCount * 54 - 6 : 0
    readonly property real desiredSurfaceWidth: 20 + desiredPinnedWidth + (appCount > 0 ? 13 : 0) + 52
    readonly property int dockBandHeight: 94
    readonly property bool dockObstructed: {
        for (var i = 0; i < activeWindows.length; ++i) {
            if (windowOverlapsDock(activeWindows[i]))
                return true;
        }
        return false;
    }
    property bool dragActive: false
    property bool modelSyncPending: false
    readonly property bool revealRequested: dockHover.hovered || revealHover.hovered || dragActive || unpinEntryId !== ""
    property real surfaceBottomMargin: autoHidden ? -74 : 12
    property string unpinEntryId: ""

    signal launcherRequested

    function commitDockOrder() {
        var ids = [];
        for (var i = 0; i < dockModel.count; ++i)
            ids.push(dockModel.get(i).entryId);
        DockService.setPinnedOrder(ids);
    }
    function finishReorder(proxy) {
        if (proxy && proxy.Drag.active)
            proxy.Drag.drop();
        commitDockOrder();
        dragActive = false;
        if (proxy) {
            proxy.x = 0;
            proxy.y = 0;
        }
        if (modelSyncPending)
            Qt.callLater(syncDockModel);
        updateAutoHide();
    }
    function modelIndexForId(entryId) {
        var id = String(entryId || "");
        for (var i = 0; i < dockModel.count; ++i) {
            if (dockModel.get(i).entryId === id)
                return i;
        }
        return -1;
    }
    function reorderModel(entryId, targetIndex) {
        var sourceIndex = modelIndexForId(entryId);
        var target = Math.max(0, Math.min(targetIndex, dockModel.count - 1));
        if (sourceIndex === -1 || sourceIndex === target)
            return;
        dockModel.move(sourceIndex, target, 1);
    }
    function syncDockModel() {
        if (dragActive) {
            modelSyncPending = true;
            return;
        }
        modelSyncPending = false;
        var desired = DockService.pinnedEntries || [];
        var desiredIds = {};
        for (var desiredIndex = 0; desiredIndex < desired.length; ++desiredIndex)
            desiredIds[String(desired[desiredIndex].id || "")] = true;
        if (unpinEntryId !== "" && !desiredIds[unpinEntryId]) {
            unpinDismissTimer.stop();
            unpinEntryId = "";
        }

        for (var removeIndex = dockModel.count - 1; removeIndex >= 0; --removeIndex) {
            if (!desiredIds[dockModel.get(removeIndex).entryId])
                dockModel.remove(removeIndex);
        }
        for (var targetIndex = 0; targetIndex < desired.length; ++targetIndex) {
            var entry = desired[targetIndex];
            var entryId = String(entry.id || "");
            var currentIndex = modelIndexForId(entryId);
            if (currentIndex === -1) {
                dockModel.insert(targetIndex, {
                    "appName": String(entry.name || entryId),
                    "entryId": entryId,
                    "iconName": String(entry.icon || "application-x-executable")
                });
            } else {
                if (currentIndex !== targetIndex)
                    dockModel.move(currentIndex, targetIndex, 1);
                dockModel.setProperty(targetIndex, "appName", String(entry.name || entryId));
                dockModel.setProperty(targetIndex, "iconName", String(entry.icon || "application-x-executable"));
            }
        }
    }
    function updateAutoHide() {
        if (!dockObstructed || revealRequested) {
            hideTimer.stop();
            autoHidden = false;
        } else {
            hideTimer.restart();
        }
    }
    function validLayoutPair(value) {
        return value && value.length >= 2 && value[0] !== null && value[0] !== undefined && value[1] !== null && value[1] !== undefined && !isNaN(Number(value[0])) && !isNaN(Number(value[1]));
    }
    function windowOverlapsDock(windowData) {
        if (!windowData)
            return false;
        if (windowData.is_fullscreen === true)
            return true;

        var outputName = screen ? screen.name : "";
        var workspaceFloating = WorkspaceService.floatingByOutput[outputName] === true;
        var isFloating = windowData.is_floating === true || workspaceFloating;
        var layout = windowData.layout || {};
        var position = layout.tile_pos_in_workspace_view;
        var size = layout.tile_size || layout.window_size;
        if (!validLayoutPair(position) || !validLayoutPair(size) || !screen)
            return !isFloating;

        var windowLeft = Number(position[0]);
        var windowTop = Number(position[1]);
        var windowRight = windowLeft + Number(size[0]);
        var windowBottom = windowTop + Number(size[1]);
        var workAreaHeight = Math.max(0, screen.height - Config.barHeight);
        var dockLeft = (screen.width - dockSurface.width) / 2;
        var dockRight = dockLeft + dockSurface.width;
        var dockTop = workAreaHeight - dockWindow.dockBandHeight + 12;
        var dockBottom = workAreaHeight - 8;
        return windowRight > dockLeft && windowLeft < dockRight && windowBottom > dockTop && windowTop < dockBottom;
    }

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell-dock"
    aboveWindows: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    anchors.top: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    focusable: false

    BackgroundEffect.blurRegion: Region {
        Region {
            item: Config.shellBlurDockEnabled ? dockSurface : null
            radius: dockSurface.radius
        }
    }
    mask: Region {
        Region {
            item: dockSurface
            radius: dockSurface.radius
        }
        Region {
            item: revealEdge
        }
    }
    Behavior on surfaceBottomMargin {
        NumberAnimation {
            duration: Config.animationDuration(dockWindow.autoHidden ? 210 : 260)
            easing.type: dockWindow.autoHidden ? Easing.InCubic : Easing.OutBack
        }
    }

    Component.onCompleted: {
        syncDockModel();
        updateAutoHide();
    }
    onDockObstructedChanged: updateAutoHide()
    onRevealRequestedChanged: updateAutoHide()

    Connections {
        function onPinnedEntriesChanged() {
            Qt.callLater(dockWindow.syncDockModel);
        }
        function onPinnedIdsChanged() {
            Qt.callLater(dockWindow.syncDockModel);
        }

        target: DockService
    }
    ListModel {
        id: dockModel
    }
    Timer {
        id: hideTimer

        interval: 100
        repeat: false

        onTriggered: {
            if (dockWindow.dockObstructed && !dockWindow.revealRequested)
                dockWindow.autoHidden = true;
        }
    }
    Timer {
        id: unpinDismissTimer

        interval: 900
        repeat: false

        onTriggered: dockWindow.unpinEntryId = ""
    }
    ShellShadow {
        active: dockWindow.visible
        cornerRadius: dockSurface.radius
        target: dockSurface
    }
    Rectangle {
        id: dockSurface

        anchors.bottom: parent.bottom
        anchors.bottomMargin: dockWindow.surfaceBottomMargin
        anchors.horizontalCenter: parent.horizontalCenter
        border.color: Config.alpha(Config.md3.outline_variant, Config.lightTheme ? 0.42 : 0.26)
        border.width: 1
        color: Config.shellBlurDockEnabled ? Config.alpha(Config.md3.surface_container, Config.lightTheme ? Config.shellBlurPanelOpacityLight : Config.shellBlurPanelOpacityDark) : Config.md3.surface_container
        height: 70
        radius: 20
        width: Math.min(dockWindow.width - 32, dockWindow.desiredSurfaceWidth)

        Behavior on width {
            NumberAnimation {
                duration: Config.animationDuration(220)
                easing.type: Easing.OutCubic
            }
        }

        HoverHandler {
            id: dockHover

            onHoveredChanged: {
                if (hovered)
                    unpinDismissTimer.stop();
                else if (dockWindow.unpinEntryId !== "")
                    unpinDismissTimer.restart();
            }
        }
        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            ListView {
                id: pinnedList

                Layout.fillHeight: true
                Layout.preferredWidth: Math.min(dockWindow.desiredPinnedWidth, Math.max(0, dockSurface.width - 85))
                boundsBehavior: Flickable.StopAtBounds
                clip: contentWidth > width
                interactive: contentWidth > width && !dockWindow.dragActive
                model: dockModel
                orientation: ListView.Horizontal
                spacing: 6

                delegate: Item {
                    id: appButton

                    required property string appName
                    property bool draggedDuringPress: false
                    required property string entryId
                    required property string iconName
                    required property int index
                    readonly property int unreadCount: NotificationHistory.unreadCountForEntry(entryId, appName)

                    Accessible.name: appName
                    Accessible.role: Accessible.Button
                    height: 50
                    width: 48
                    z: appMouse.drag.active ? 100 : 0

                    DropArea {
                        anchors.fill: parent
                        keys: ["dock-app"]

                        onEntered: drag => {
                            if (drag.source && drag.source.entryId !== appButton.entryId)
                                dockWindow.reorderModel(drag.source.entryId, appButton.index);
                        }
                    }
                    Item {
                        id: dragProxy

                        property string entryId: appButton.entryId

                        Drag.active: appMouse.drag.active
                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: height / 2
                        Drag.keys: ["dock-app"]
                        Drag.supportedActions: Qt.MoveAction
                        height: 48
                        opacity: 0
                        width: 48
                    }
                    Rectangle {
                        id: appVisual

                        color: appMouse.pressed ? Config.alpha(Config.md3.on_surface, 0.16) : appMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent"
                        height: 48
                        radius: 15
                        rotation: appMouse.drag.active ? 5 : 0
                        scale: appMouse.drag.active ? 1.13 : appMouse.pressed ? 0.92 : appMouse.containsMouse ? 1.08 : 1
                        width: 48
                        x: appMouse.drag.active ? dragProxy.x : 0
                        y: appMouse.drag.active ? dragProxy.y : 1

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(100)
                            }
                        }
                        Behavior on rotation {
                            NumberAnimation {
                                duration: Config.animationDuration(130)
                                easing.type: Easing.OutCubic
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: Config.animationDuration(150)
                                easing.type: Easing.OutBack
                            }
                        }

                        IconImage {
                            anchors.centerIn: parent
                            height: 40
                            mipmap: true
                            smooth: true
                            source: Quickshell.iconPath(appButton.iconName || "application-x-executable")
                            width: 40
                        }
                    }
                    MouseArea {
                        id: appMouse

                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        anchors.fill: parent
                        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        drag.axis: Drag.XAxis
                        drag.smoothed: false
                        drag.target: (pressedButtons & Qt.LeftButton) ? dragProxy : null
                        hoverEnabled: true
                        preventStealing: true

                        drag.onActiveChanged: {
                            if (drag.active) {
                                unpinDismissTimer.stop();
                                dockWindow.unpinEntryId = "";
                                appButton.draggedDuringPress = true;
                                dockWindow.dragActive = true;
                            }
                        }
                        onCanceled: dockWindow.finishReorder(dragProxy)
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                dockWindow.unpinEntryId = dockWindow.unpinEntryId === appButton.entryId ? "" : appButton.entryId;
                                unpinDismissTimer.stop();
                            } else if (!appButton.draggedDuringPress) {
                                unpinDismissTimer.stop();
                                dockWindow.unpinEntryId = "";
                                DockService.launch(appButton.entryId);
                            }
                        }
                        onPressed: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                appButton.draggedDuringPress = false;
                            }
                        }
                        onReleased: mouse => {
                            if (mouse.button === Qt.LeftButton)
                                dockWindow.finishReorder(dragProxy);
                        }
                    }
                    Rectangle {
                        id: unpinBadge

                        Accessible.name: qsTr("Unpin from Dock")
                        Accessible.role: Accessible.Button
                        anchors.left: appVisual.left
                        anchors.leftMargin: -4
                        anchors.top: appVisual.top
                        anchors.topMargin: -4
                        border.color: Config.alpha(Config.md3.on_error, 0.5)
                        border.width: 1
                        color: unpinMouse.pressed ? Config.md3.error_container : Config.md3.error
                        height: 20
                        radius: 10
                        scale: unpinMouse.pressed ? 0.9 : unpinMouse.containsMouse ? 1.08 : 1
                        visible: dockWindow.unpinEntryId === appButton.entryId && !appMouse.drag.active
                        width: 20
                        z: 200

                        Behavior on scale {
                            NumberAnimation {
                                duration: Config.animationDuration(120)
                                easing.type: Easing.OutBack
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            color: unpinMouse.pressed ? Config.md3.on_error_container : Config.md3.on_error
                            font.family: Config.fontName
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            renderType: Text.NativeRendering
                            text: "−"
                        }
                        MouseArea {
                            id: unpinMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            preventStealing: true

                            onClicked: {
                                unpinDismissTimer.stop();
                                DockService.unpin(appButton.entryId);
                                dockWindow.unpinEntryId = "";
                            }
                        }
                    }
                    Rectangle {
                        id: notificationBadge

                        Accessible.name: qsTr("%1 unread notifications").arg(appButton.unreadCount)
                        Accessible.role: Accessible.StaticText
                        anchors.right: appVisual.right
                        anchors.rightMargin: -4
                        anchors.top: appVisual.top
                        anchors.topMargin: -4
                        color: Config.md3.error
                        height: 20
                        radius: 10
                        visible: appButton.unreadCount > 0 && !appMouse.drag.active
                        width: Math.max(20, notificationCountText.implicitWidth + 8)
                        z: 190

                        Text {
                            id: notificationCountText

                            anchors.centerIn: parent
                            color: Config.md3.on_error
                            font.family: Config.fontName
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            renderType: Text.NativeRendering
                            text: appButton.unreadCount > 99 ? "99+" : String(appButton.unreadCount)
                        }
                    }
                }
                displaced: Transition {
                    NumberAnimation {
                        duration: Config.animationDuration(180)
                        easing.type: Easing.OutCubic
                        properties: "x,y"
                    }
                }
            }
            Rectangle {
                Layout.fillHeight: true
                Layout.leftMargin: 1
                Layout.preferredWidth: 1
                color: Config.alpha(Config.md3.outline_variant, 0.42)
                visible: dockWindow.appCount > 0
            }
            Rectangle {
                id: allAppsButton

                Accessible.name: qsTr("All applications")
                Accessible.role: Accessible.Button
                Layout.preferredHeight: 50
                Layout.preferredWidth: 50
                color: allAppsMouse.pressed ? Config.alpha(Config.md3.primary, 0.22) : allAppsMouse.containsMouse ? Config.alpha(Config.md3.primary, 0.14) : "transparent"
                radius: 15
                scale: allAppsMouse.pressed ? 0.92 : allAppsMouse.containsMouse ? 1.06 : 1

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animationDuration(100)
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Config.animationDuration(150)
                        easing.type: Easing.OutBack
                    }
                }

                Grid {
                    anchors.centerIn: parent
                    columns: 3
                    spacing: 4

                    Repeater {
                        model: 9

                        Rectangle {
                            color: allAppsMouse.containsMouse ? Config.md3.primary : Config.md3.on_surface_variant
                            height: 5
                            radius: 2
                            width: 5

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animationDuration(100)
                                }
                            }
                        }
                    }
                }
                MouseArea {
                    id: allAppsMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: {
                        unpinDismissTimer.stop();
                        dockWindow.unpinEntryId = "";
                        dockWindow.launcherRequested();
                    }
                }
            }
        }
    }
    Item {
        id: revealEdge

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        height: 6
        width: Math.min(parent.width, Math.max(240, dockSurface.width + 160))

        HoverHandler {
            id: revealHover
        }
    }
}
