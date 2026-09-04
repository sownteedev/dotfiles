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
    readonly property int appCount: pinnedAppCount + runningAppCount
    property bool autoHidden: false
    readonly property real desiredAppListWidth: appCount > 0 ? appCount * 54 - 6 + (runningAppCount > 0 ? 7 : 0) : 0
    readonly property real desiredSurfaceWidth: 20 + (appCount > 0 ? desiredAppListWidth + 6 : 0) + (showAllAppsSeparator ? 8 : 0) + 50
    readonly property var desktopApplications: DesktopEntries.applications.values || []
    readonly property int dockBandHeight: 94
    readonly property bool dockObstructed: {
        for (var i = 0; i < activeWindows.length; ++i) {
            if (windowOverlapsDock(activeWindows[i]))
                return true;
        }
        return false;
    }
    property bool dragActive: false
    property string hoveredEntryId: ""
    property bool modelSyncPending: false
    property string pinActionEntryId: ""
    property int pinnedAppCount: 0
    property real previewAnchorCenterX: width / 2
    property string previewAppName: ""
    property string previewEntryId: ""
    property string previewIconName: "application-x-executable"
    property bool previewShown: false
    readonly property var previewWindows: windowsForEntry(previewEntryId, previewAppName)
    readonly property bool revealRequested: dockHover.hovered || revealHover.hovered || dragActive || pinActionEntryId !== "" || previewShown || previewShowTimer.running || windowPreview.hovered
    property int runningAppCount: 0
    readonly property bool showAllAppsSeparator: pinnedAppCount > 0 && runningAppCount === 0
    property real surfaceBottomMargin: autoHidden ? -74 : 12
    readonly property bool themeReady: ThemeService.hasAppliedTheme || (ThemeService.themeFileResolved && !Config.matugenEnabled)

    signal launcherRequested

    function cancelWindowPreview(entryId) {
        if (hoveredEntryId === String(entryId || ""))
            hoveredEntryId = "";
        previewShowTimer.stop();
        previewHideTimer.restart();
    }
    function closePreviewWindow(windowId) {
        var id = String(windowId || "");
        if (id === "")
            return;
        if (previewWindows.length <= 1) {
            previewShown = false;
            hoveredEntryId = "";
        }
        Quickshell.execDetached(["niri", "msg", "action", "close-window", "--id", id]);
    }
    function commitDockOrder() {
        var ids = [];
        for (var i = 0; i < dockModel.count; ++i) {
            var item = dockModel.get(i);
            if (item.kind === "app" && item.pinned)
                ids.push(item.entryId);
        }
        DockService.setPinnedOrder(ids);
    }
    function desktopEntryForWindow(windowData, availableById) {
        var appId = String(windowData && windowData.app_id || "").trim();
        if (appId === "")
            return null;

        var entry = availableById[appId] || availableById[appId.toLowerCase()] || DesktopEntries.byId(appId);
        if (!entry && appId.toLowerCase().endsWith(".desktop"))
            entry = DesktopEntries.byId(appId.slice(0, -8));
        return entry || DesktopEntries.heuristicLookup(appId);
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
    function focusPreviewWindow(windowId) {
        var id = String(windowId || "");
        if (id === "")
            return;
        previewShown = false;
        hoveredEntryId = "";
        Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", id]);
    }
    function isQuickshellAppId(appId) {
        var normalized = normalizedAppId(appId);
        var shellAppId = normalizedAppId(Quickshell.appId || "org.quickshell");
        return normalized === shellAppId || normalized === "org.quickshell" || normalized === "quickshell";
    }
    function isShellWindowEntryId(entryId) {
        var normalized = normalizedAppId(entryId);
        return normalized === "sownteeshell-settings" || normalized === "sownteeshell-calendar";
    }
    function modelIndexForId(entryId) {
        var id = String(entryId || "");
        for (var i = 0; i < dockModel.count; ++i) {
            if (dockModel.get(i).kind === "app" && dockModel.get(i).entryId === id)
                return i;
        }
        return -1;
    }
    function modelIndexForKey(modelKey) {
        var key = String(modelKey || "");
        for (var i = 0; i < dockModel.count; ++i) {
            if (dockModel.get(i).modelKey === key)
                return i;
        }
        return -1;
    }
    function modelKeyForEntry(entryId) {
        return "app:" + String(entryId || "").toLowerCase();
    }
    function normalizedAppId(appId) {
        var normalized = String(appId || "").trim().toLowerCase();
        return normalized.endsWith(".desktop") ? normalized.slice(0, -8) : normalized;
    }
    function reorderModel(entryId, targetIndex) {
        var sourceIndex = modelIndexForId(entryId);
        var target = Math.max(0, Math.min(targetIndex, dockModel.count - 1));
        if (sourceIndex === -1 || sourceIndex === target)
            return;
        dockModel.move(sourceIndex, target, 1);
    }
    function requestWindowPreview(entryId, appName, iconName, anchorItem) {
        var id = String(entryId || "");
        var matchingWindows = windowsForEntry(id, appName);
        if (id === "" || !anchorItem || matchingWindows.length === 0) {
            cancelWindowPreview(id);
            return;
        }

        hoveredEntryId = id;
        previewEntryId = id;
        previewAppName = String(appName || id);
        previewIconName = String(iconName || "application-x-executable");
        var anchorPosition = anchorItem.mapToItem(dockSurface.parent, 0, 0);
        previewAnchorCenterX = anchorPosition.x + anchorItem.width / 2;
        previewHideTimer.stop();
        if (previewShown)
            previewShowTimer.stop();
        else
            previewShowTimer.restart();
    }
    function runningEntries() {
        var availableById = {};
        for (var availableIndex = 0; availableIndex < desktopApplications.length; ++availableIndex) {
            var availableEntry = desktopApplications[availableIndex];
            var availableId = String(availableEntry.id || "");
            if (availableId === "")
                continue;
            availableById[availableId] = availableEntry;
            availableById[availableId.toLowerCase()] = availableEntry;
        }

        var pinned = visiblePinnedEntries();
        var pinnedKeys = [];
        for (var pinnedIndex = 0; pinnedIndex < pinned.length; ++pinnedIndex)
            pinnedKeys.push(NotificationHistory.appKeys(pinned[pinnedIndex].id, pinned[pinnedIndex].name));

        var entries = [];
        var seen = {};
        var workspaces = WorkspaceService.workspaces || [];
        for (var workspaceIndex = 0; workspaceIndex < workspaces.length; ++workspaceIndex) {
            var windows = workspaces[workspaceIndex].windows || [];
            for (var windowIndex = 0; windowIndex < windows.length; ++windowIndex) {
                var windowData = windows[windowIndex];
                var appId = String(windowData.app_id || "").trim();
                var shellEntryId = WorkspaceService.shellWindowEntryId(windowData);
                if ((appId === "" && shellEntryId === "") || !WorkspaceService.showInWorkspaceAndDock(windowData))
                    continue;

                var windowKeys = NotificationHistory.windowKeys(windowData);
                var pinnedMatch = false;
                for (var pinnedKeyIndex = 0; pinnedKeyIndex < pinnedKeys.length; ++pinnedKeyIndex) {
                    if (NotificationHistory.keysIntersect(windowKeys, pinnedKeys[pinnedKeyIndex])) {
                        pinnedMatch = true;
                        break;
                    }
                }
                if (pinnedMatch)
                    continue;

                var entry = shellEntryId === "" ? desktopEntryForWindow(windowData, availableById) : null;
                var entryId = shellEntryId !== "" ? shellEntryId : String(entry ? entry.id : appId);
                var modelKey = modelKeyForEntry(entryId);
                if (seen[modelKey])
                    continue;
                seen[modelKey] = true;

                var iconName = WorkspaceService.shellWindowIconName(windowData);
                if (iconName === "")
                    iconName = String(entry && entry.icon || "");
                if (iconName === "" && Quickshell.iconPath(appId, true) !== "")
                    iconName = appId;
                if (iconName === "" && Quickshell.iconPath(appId.toLowerCase(), true) !== "")
                    iconName = appId.toLowerCase();
                var shellName = WorkspaceService.shellWindowDisplayName(windowData);
                entries.push({
                    "appName": shellName !== "" ? shellName : String(entry && entry.name || appId || windowData.title || qsTr("Application")),
                    "entryId": entryId,
                    "iconName": iconName !== "" ? iconName : "application-x-executable",
                    "kind": "app",
                    "launchable": shellEntryId === "" && !!entry,
                    "modelKey": modelKey,
                    "pinned": false
                });
            }
        }
        return entries;
    }
    function syncDockModel() {
        if (dragActive) {
            modelSyncPending = true;
            return;
        }
        modelSyncPending = false;
        var pinned = visiblePinnedEntries();
        var discoveredRunning = runningEntries();
        var runningByKey = {};
        for (var discoveredIndex = 0; discoveredIndex < discoveredRunning.length; ++discoveredIndex)
            runningByKey[discoveredRunning[discoveredIndex].modelKey] = discoveredRunning[discoveredIndex];

        var stableRunning = [];
        var includedRunning = {};
        for (var currentRunningIndex = 0; currentRunningIndex < dockModel.count; ++currentRunningIndex) {
            var currentRunning = dockModel.get(currentRunningIndex);
            if (currentRunning.kind !== "app" || currentRunning.pinned || !runningByKey[currentRunning.modelKey])
                continue;
            stableRunning.push(runningByKey[currentRunning.modelKey]);
            includedRunning[currentRunning.modelKey] = true;
        }
        for (var appendIndex = 0; appendIndex < discoveredRunning.length; ++appendIndex) {
            var discoveredEntry = discoveredRunning[appendIndex];
            if (!includedRunning[discoveredEntry.modelKey])
                stableRunning.push(discoveredEntry);
        }

        var desired = [];
        for (var pinnedIndex = 0; pinnedIndex < pinned.length; ++pinnedIndex) {
            var pinnedEntry = pinned[pinnedIndex];
            var pinnedId = String(pinnedEntry.id || "");
            desired.push({
                "appName": String(pinnedEntry.name || pinnedId),
                "entryId": pinnedId,
                "iconName": String(pinnedEntry.icon || "application-x-executable"),
                "kind": "app",
                "launchable": true,
                "modelKey": modelKeyForEntry(pinnedId),
                "pinned": true
            });
        }
        if (stableRunning.length > 0) {
            desired.push({
                "appName": "",
                "entryId": "",
                "iconName": "",
                "kind": "separator",
                "launchable": false,
                "modelKey": "running-separator",
                "pinned": false
            });
            for (var stableIndex = 0; stableIndex < stableRunning.length; ++stableIndex)
                desired.push(stableRunning[stableIndex]);
        }

        var desiredKeys = {};
        for (var desiredIndex = 0; desiredIndex < desired.length; ++desiredIndex)
            desiredKeys[desired[desiredIndex].modelKey] = true;
        if (pinActionEntryId !== "" && !desiredKeys[modelKeyForEntry(pinActionEntryId)]) {
            pinActionDismissTimer.stop();
            pinActionEntryId = "";
        }

        for (var removeIndex = dockModel.count - 1; removeIndex >= 0; --removeIndex) {
            if (!desiredKeys[dockModel.get(removeIndex).modelKey])
                dockModel.remove(removeIndex);
        }
        for (var targetIndex = 0; targetIndex < desired.length; ++targetIndex) {
            var entry = desired[targetIndex];
            var currentIndex = modelIndexForKey(entry.modelKey);
            if (currentIndex === -1) {
                dockModel.insert(targetIndex, entry);
            } else {
                if (currentIndex !== targetIndex)
                    dockModel.move(currentIndex, targetIndex, 1);
                dockModel.setProperty(targetIndex, "appName", entry.appName);
                dockModel.setProperty(targetIndex, "entryId", entry.entryId);
                dockModel.setProperty(targetIndex, "iconName", entry.iconName);
                dockModel.setProperty(targetIndex, "kind", entry.kind);
                dockModel.setProperty(targetIndex, "launchable", entry.launchable);
                dockModel.setProperty(targetIndex, "pinned", entry.pinned);
            }
        }
        pinnedAppCount = pinned.length;
        runningAppCount = stableRunning.length;
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
    function visiblePinnedEntries() {
        var pinned = DockService.pinnedEntries || [];
        var visibleEntries = [];
        for (var index = 0; index < pinned.length; ++index) {
            if (!isQuickshellAppId(pinned[index].id))
                visibleEntries.push(pinned[index]);
        }
        return visibleEntries;
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
    function windowsForEntry(entryId, appName) {
        var entryKeys = NotificationHistory.appKeys(entryId, appName);
        var shellEntry = normalizedAppId(entryId);
        var matchShellWindow = isShellWindowEntryId(shellEntry);
        if (!matchShellWindow && entryKeys.length === 0)
            return [];

        var result = [];
        var workspaces = WorkspaceService.workspaces || [];
        for (var workspaceIndex = 0; workspaceIndex < workspaces.length; ++workspaceIndex) {
            var workspace = workspaces[workspaceIndex];
            var windows = workspace.windows || [];
            for (var windowIndex = 0; windowIndex < windows.length; ++windowIndex) {
                var windowData = windows[windowIndex];
                var matchesWindow = matchShellWindow ? normalizedAppId(WorkspaceService.shellWindowEntryId(windowData)) === shellEntry : NotificationHistory.keysIntersect(entryKeys, NotificationHistory.windowKeys(windowData));
                if (!matchesWindow)
                    continue;
                result.push({
                    "id": String(windowData.id || ""),
                    "isFocused": String(windowData.id || "") === String(WorkspaceService.activeWindowId || ""),
                    "output": String(workspace.output || ""),
                    "title": String(windowData.title || appName || entryId),
                    "workspaceId": workspace.id,
                    "workspaceLabel": String(workspace.name || "") !== "" ? String(workspace.name) : qsTr("Workspace %1").arg(workspace.idx)
                });
            }
        }
        return result;
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
            item: Config.shellBlurDockEnabled && dockWindow.themeReady ? dockSurface : null
            radius: dockSurface.radius
        }
        Region {
            item: Config.shellBlurDockEnabled && windowPreview.shown ? windowPreview.regionItem : null
            radius: windowPreview.cornerRadius
        }
    }
    mask: Region {
        Region {
            item: dockWindow.themeReady ? dockSurface : null
            radius: dockSurface.radius
        }
        Region {
            item: windowPreview.visible ? windowPreview.regionItem : null
            radius: windowPreview.cornerRadius
        }
        Region {
            item: revealEdge
        }
    }
    Behavior on surfaceBottomMargin {
        NumberAnimation {
            duration: dockWindow.themeReady ? Config.animationDuration(dockWindow.autoHidden ? 210 : 260) : 0
            easing.type: dockWindow.autoHidden ? Easing.InCubic : Easing.OutBack
        }
    }

    Component.onCompleted: {
        syncDockModel();
        updateAutoHide();
    }
    onDesktopApplicationsChanged: Qt.callLater(syncDockModel)
    onDockObstructedChanged: updateAutoHide()
    onPreviewWindowsChanged: {
        if (previewWindows.length === 0)
            previewShown = false;
    }
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
    Connections {
        function onWorkspacesChanged() {
            Qt.callLater(dockWindow.syncDockModel);
        }

        target: WorkspaceService
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
        id: pinActionDismissTimer

        interval: 900
        repeat: false

        onTriggered: dockWindow.pinActionEntryId = ""
    }
    Timer {
        id: previewShowTimer

        interval: 180
        repeat: false

        onTriggered: {
            if (dockWindow.hoveredEntryId === dockWindow.previewEntryId && dockWindow.previewWindows.length > 0)
                dockWindow.previewShown = true;
        }
    }
    Timer {
        id: previewHideTimer

        interval: 170
        repeat: false

        onTriggered: {
            if (dockWindow.hoveredEntryId === "" && !windowPreview.hovered)
                dockWindow.previewShown = false;
        }
    }
    ShellShadow {
        active: dockWindow.visible && dockWindow.themeReady
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
        visible: dockWindow.themeReady
        width: Math.min(dockWindow.width - 32, dockWindow.desiredSurfaceWidth)

        Behavior on width {
            NumberAnimation {
                duration: dockWindow.themeReady ? Config.animationDuration(220) : 0
                easing.type: Easing.OutCubic
            }
        }

        HoverHandler {
            id: dockHover

            onHoveredChanged: {
                if (hovered)
                    pinActionDismissTimer.stop();
                else if (dockWindow.pinActionEntryId !== "")
                    pinActionDismissTimer.restart();
            }
        }
        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 6

            ListView {
                id: dockAppList

                Layout.fillHeight: true
                Layout.preferredWidth: Math.min(dockWindow.desiredAppListWidth, Math.max(0, dockSurface.width - 76))
                boundsBehavior: Flickable.StopAtBounds
                clip: contentWidth > width
                interactive: contentWidth > width && !dockWindow.dragActive
                model: dockModel
                orientation: ListView.Horizontal
                spacing: 6
                visible: dockWindow.appCount > 0

                delegate: Item {
                    id: appButton

                    required property string appName
                    readonly property var appWindows: isSeparator ? [] : dockWindow.windowsForEntry(entryId, appName)
                    property bool draggedDuringPress: false
                    required property string entryId
                    required property string iconName
                    required property int index
                    readonly property bool isSeparator: kind === "separator"
                    required property string kind
                    required property bool launchable
                    required property string modelKey
                    required property bool pinned
                    readonly property bool settingsWindowEntry: dockWindow.normalizedAppId(entryId) === "sownteeshell-settings"
                    readonly property bool shellWindowEntry: dockWindow.isShellWindowEntryId(entryId)
                    readonly property int unreadCount: isSeparator ? 0 : NotificationHistory.unreadCountForEntry(entryId, appName)
                    readonly property int windowCount: appWindows.length

                    Accessible.ignored: isSeparator
                    Accessible.name: appName
                    Accessible.role: Accessible.Button
                    height: 50
                    width: isSeparator ? 1 : 48
                    z: appMouse.drag.active ? 100 : 0

                    Rectangle {
                        anchors.centerIn: parent
                        color: Config.alpha(Config.md3.outline_variant, Config.lightTheme ? 0.62 : 0.48)
                        height: 32
                        radius: width / 2
                        visible: appButton.isSeparator
                        width: 1
                    }
                    DropArea {
                        anchors.fill: parent
                        enabled: appButton.pinned && !appButton.isSeparator
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
                        visible: !appButton.isSeparator
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
                            height: appButton.settingsWindowEntry ? 35 : 40
                            layer.enabled: appButton.shellWindowEntry
                            mipmap: true
                            smooth: true
                            source: Quickshell.iconPath(appButton.iconName || "application-x-executable")
                            width: height

                            layer.effect: ColorOverlay {
                                color: Config.md3.on_surface
                            }
                        }
                    }
                    Row {
                        id: runningIndicator

                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 4
                        spacing: 3
                        visible: !appButton.isSeparator && appButton.windowCount > 0 && !appMouse.drag.active
                        z: 160

                        Repeater {
                            model: Math.min(appButton.windowCount, 4)

                            delegate: Rectangle {
                                required property int index

                                color: appButton.appWindows[index].isFocused ? Config.md3.primary : Config.alpha(Config.md3.on_surface_variant, 0.72)
                                height: 4
                                radius: height / 2
                                width: appButton.appWindows[index].isFocused ? 12 : 4

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Config.animationDuration(120)
                                    }
                                }
                                Behavior on width {
                                    NumberAnimation {
                                        duration: Config.animationDuration(140)
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }
                    MouseArea {
                        id: appMouse

                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        anchors.fill: parent
                        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        drag.axis: Drag.XAxis
                        drag.smoothed: false
                        drag.target: appButton.pinned && (pressedButtons & Qt.LeftButton) ? dragProxy : null
                        enabled: !appButton.isSeparator
                        hoverEnabled: true
                        preventStealing: true

                        drag.onActiveChanged: {
                            if (drag.active) {
                                pinActionDismissTimer.stop();
                                dockWindow.pinActionEntryId = "";
                                dockWindow.previewShown = false;
                                dockWindow.cancelWindowPreview(appButton.entryId);
                                appButton.draggedDuringPress = true;
                                dockWindow.dragActive = true;
                            }
                        }
                        onCanceled: dockWindow.finishReorder(dragProxy)
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                if (!appButton.pinned && !appButton.launchable)
                                    return;
                                dockWindow.previewShown = false;
                                dockWindow.cancelWindowPreview(appButton.entryId);
                                dockWindow.pinActionEntryId = dockWindow.pinActionEntryId === appButton.entryId ? "" : appButton.entryId;
                                pinActionDismissTimer.stop();
                            } else if (!appButton.draggedDuringPress) {
                                pinActionDismissTimer.stop();
                                dockWindow.pinActionEntryId = "";
                                dockWindow.previewShown = false;
                                dockWindow.cancelWindowPreview(appButton.entryId);
                                if (appButton.launchable)
                                    DockService.launch(appButton.entryId);
                                else if (appButton.windowCount > 0)
                                    dockWindow.focusPreviewWindow(appButton.appWindows[0].id);
                            }
                        }
                        onEntered: {
                            if (!drag.active && appButton.windowCount > 0)
                                dockWindow.requestWindowPreview(appButton.entryId, appButton.appName, appButton.iconName, appButton);
                        }
                        onExited: dockWindow.cancelWindowPreview(appButton.entryId)
                        onPressed: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                appButton.draggedDuringPress = false;
                            }
                        }
                        onReleased: mouse => {
                            if (mouse.button === Qt.LeftButton && appButton.pinned)
                                dockWindow.finishReorder(dragProxy);
                        }
                    }
                    Rectangle {
                        id: pinActionBadge

                        Accessible.name: appButton.pinned ? qsTr("Unpin from Dock") : qsTr("Pin to Dock")
                        Accessible.role: Accessible.Button
                        anchors.left: appVisual.left
                        anchors.leftMargin: -4
                        anchors.top: appVisual.top
                        anchors.topMargin: -4
                        border.color: Config.alpha(appButton.pinned ? Config.md3.on_error : Config.md3.on_primary, 0.5)
                        border.width: 1
                        color: pinActionMouse.pressed ? (appButton.pinned ? Config.md3.error_container : Config.md3.primary_container) : (appButton.pinned ? Config.md3.error : Config.md3.primary)
                        height: 20
                        radius: 10
                        scale: pinActionMouse.pressed ? 0.9 : pinActionMouse.containsMouse ? 1.08 : 1
                        visible: !appButton.isSeparator && dockWindow.pinActionEntryId === appButton.entryId && !appMouse.drag.active
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
                            color: pinActionMouse.pressed ? (appButton.pinned ? Config.md3.on_error_container : Config.md3.on_primary_container) : (appButton.pinned ? Config.md3.on_error : Config.md3.on_primary)
                            font.family: Config.fontName
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            text: appButton.pinned ? "−" : "+"
                        }
                        MouseArea {
                            id: pinActionMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            preventStealing: true

                            onClicked: {
                                pinActionDismissTimer.stop();
                                dockWindow.pinActionEntryId = "";
                                if (appButton.pinned)
                                    DockService.unpin(appButton.entryId);
                                else
                                    DockService.pin(appButton.entryId);
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
                color: Config.alpha(Config.md3.outline_variant, Config.lightTheme ? 0.62 : 0.48)
                visible: dockWindow.showAllAppsSeparator
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
                        pinActionDismissTimer.stop();
                        dockWindow.pinActionEntryId = "";
                        dockWindow.launcherRequested();
                    }
                }
            }
        }
    }
    DockWindowPreview {
        id: windowPreview

        anchors.bottom: dockSurface.top
        anchors.bottomMargin: 12
        height: implicitHeight
        iconName: dockWindow.previewIconName
        shown: dockWindow.previewShown && dockWindow.previewWindows.length > 0
        width: implicitWidth
        windows: dockWindow.previewWindows
        x: Math.max(16, Math.min(dockWindow.previewAnchorCenterX - width / 2, dockWindow.width - width - 16))
        z: 300

        onHoveredChanged: {
            if (hovered) {
                previewHideTimer.stop();
            } else if (dockWindow.hoveredEntryId === "") {
                previewHideTimer.restart();
            }
        }
        onWindowActivated: windowId => dockWindow.focusPreviewWindow(windowId)
        onWindowCloseRequested: windowId => dockWindow.closePreviewWindow(windowId)
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
