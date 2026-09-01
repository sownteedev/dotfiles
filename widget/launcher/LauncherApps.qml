pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../"
import "../../components"
import "../../service"

Item {
    id: appsGrid

    property bool appDragActive: false
    readonly property int cellHeight: Math.max(1, Math.floor(pageContentHeight / rows))
    readonly property int cellWidth: Math.max(1, Math.floor(width / columns))
    readonly property int columns: Responsive.columnsFor(width, 210, 8, width < 300 ? 1 : 2, 0)
    property int currentIndex: -1
    property int currentPage: 0
    property bool entranceReady: false
    property bool entranceWaveActive: false
    readonly property var gridItems: {
        var apps = DesktopEntries.applications.values;
        if (!apps)
            return [];

        apps = apps.filter(function (entry) {
            return !entry.noDisplay && !entry.runInTerminal && entry.name && entry.name !== "";
        });

        var normalizedQuery = query.toLowerCase().trim();
        if (normalizedQuery !== "") {
            apps = apps.filter(function (entry) {
                var nameMatch = entry.name && entry.name.toLowerCase().indexOf(normalizedQuery) !== -1;
                var commentMatch = entry.comment && entry.comment.toLowerCase().indexOf(normalizedQuery) !== -1;
                var idMatch = entry.id && entry.id.toLowerCase().indexOf(normalizedQuery) !== -1;
                return nameMatch || commentMatch || idMatch;
            });

            var searchItems = apps.map(function (entry) {
                return {
                    "entries": [],
                    "entry": entry,
                    "groupId": "",
                    "kind": "app",
                    "name": entry.name
                };
            });
            searchItems.sort(function (a, b) {
                return a.name.localeCompare(b.name, undefined, {
                    sensitivity: "base",
                    numeric: true
                });
            });
            return searchItems;
        }

        var availableById = {};
        for (var availableIndex = 0; availableIndex < apps.length; ++availableIndex)
            availableById[apps[availableIndex].id] = apps[availableIndex];

        var groupedAppIds = {};
        var finalItems = [];
        var groups = LauncherGroupService.groups || [];
        for (var groupIndex = 0; groupIndex < groups.length; ++groupIndex) {
            var group = groups[groupIndex];
            var groupEntries = [];
            var resolvedIds = {};
            for (var appIndex = 0; appIndex < group.appIds.length; ++appIndex) {
                var appId = group.appIds[appIndex];
                var entry = availableById[appId] || DesktopEntries.byId(appId);
                if (!entry || entry.noDisplay || entry.runInTerminal || !entry.name || entry.name === "" || resolvedIds[entry.id])
                    continue;
                resolvedIds[entry.id] = true;
                groupEntries.push(entry);
            }

            if (groupEntries.length < 2)
                continue;

            for (var groupedIndex = 0; groupedIndex < groupEntries.length; ++groupedIndex)
                groupedAppIds[groupEntries[groupedIndex].id] = true;
            finalItems.push({
                "entries": groupEntries,
                "entry": null,
                "groupId": group.id,
                "kind": "group",
                "name": group.name
            });
        }

        for (var entryIndex = 0; entryIndex < apps.length; ++entryIndex) {
            var appEntry = apps[entryIndex];
            if (groupedAppIds[appEntry.id])
                continue;
            finalItems.push({
                "entries": [],
                "entry": appEntry,
                "groupId": "",
                "kind": "app",
                "name": appEntry.name
            });
        }

        finalItems.sort(function (a, b) {
            return a.name.localeCompare(b.name, undefined, {
                sensitivity: "base",
                numeric: true
            });
        });

        return finalItems;
    }
    property bool groupPopupOpened: false
    readonly property real iconSize: Responsive.clamp(cellWidth * 0.38, 72, 96)
    readonly property int indicatorAreaHeight: 38
    readonly property int itemsPerPage: Math.max(1, columns * rows)
    readonly property int pageContentHeight: Math.max(1, height - indicatorAreaHeight)
    readonly property int pageCount: gridItems.length === 0 ? 0 : Math.ceil(gridItems.length / itemsPerPage)
    readonly property int preferredCellHeight: Responsive.clamp(iconSize + 92, 164, 196)
    property string query: ""
    readonly property int rows: Math.max(1, Math.floor(pageContentHeight / preferredCellHeight))
    property bool touchpadGestureActive: false
    property real touchpadGestureDelta: 0
    property int touchpadGesturePage: 0
    property real touchpadGestureStartX: 0
    readonly property int visiblePage: pageCount === 0 || pager.width <= 0 ? 0 : Math.max(0, Math.min(Math.round(pager.contentX / pager.width), pageCount - 1))

    signal appLaunched
    signal groupOpenRequested(string groupId, bool editName)

    function beginTouchpadGesture() {
        if (pageCount <= 1 || pager.width <= 0)
            return;

        pageAnimation.stop();
        pager.cancelFlick();
        appActionPopup.close();
        touchpadGesturePage = visiblePage;
        touchpadGestureStartX = touchpadGesturePage * pager.width;
        touchpadGestureDelta = 0;
        touchpadGestureActive = true;
        pager.contentX = touchpadGestureStartX;
    }
    function finishTouchpadGesture(useDragThreshold) {
        touchpadGestureTimer.stop();
        if (!touchpadGestureActive)
            return;

        var movement = pager.contentX - touchpadGestureStartX;
        var threshold = useDragThreshold ? Math.min(pager.width * 0.18, 90) : Math.min(pager.width * 0.06, 56);
        var targetPage = touchpadGesturePage;
        if (Math.abs(movement) >= threshold)
            targetPage += movement > 0 ? 1 : -1;

        touchpadGestureActive = false;
        targetPage = Math.max(0, Math.min(targetPage, pageCount - 1));
        syncPageSelection(targetPage);
        moveToPage(targetPage, true);
    }
    function itemsForPage(pageIndex) {
        var startIndex = pageIndex * itemsPerPage;
        var endIndex = Math.min(startIndex + itemsPerPage, gridItems.length);
        var pageItems = [];
        for (var index = startIndex; index < endIndex; ++index) {
            var sourceItem = gridItems[index];
            pageItems.push({
                "entries": sourceItem.entries,
                "entry": sourceItem.entry,
                "globalIndex": index,
                "groupId": sourceItem.groupId,
                "kind": sourceItem.kind,
                "localIndex": index - startIndex,
                "name": sourceItem.name
            });
        }
        return pageItems;
    }
    function launchSelected() {
        if (currentIndex < 0 || currentIndex >= gridItems.length)
            return;
        var selectedItem = gridItems[currentIndex];
        if (selectedItem.kind === "group") {
            appActionPopup.close();
            groupOpenRequested(selectedItem.groupId, false);
            return;
        }
        selectedItem.entry.execute();
        appLaunched();
    }
    function moveToPage(targetPage, animated) {
        if (pageCount <= 0 || pager.width <= 0)
            return;

        touchpadGestureTimer.stop();
        touchpadGestureActive = false;
        var clampedPage = Math.max(0, Math.min(targetPage, pageCount - 1));
        var targetX = clampedPage * pager.width;
        currentPage = clampedPage;
        appActionPopup.close();
        pageAnimation.stop();

        if (!animated || Config.animationDuration(240) === 0 || Math.abs(pager.contentX - targetX) < 1) {
            pager.contentX = targetX;
            return;
        }

        pageAnimation.to = targetX;
        pageAnimation.restart();
    }
    function selectDown() {
        selectIndex(currentIndex + columns);
    }
    function selectFirst() {
        selectIndex(0);
    }
    function selectIndex(targetIndex) {
        if (gridItems.length === 0) {
            currentIndex = -1;
            currentPage = 0;
            return;
        }

        currentIndex = Math.max(0, Math.min(targetIndex, gridItems.length - 1));
        moveToPage(Math.floor(currentIndex / itemsPerPage), true);
    }
    function selectLast() {
        selectIndex(gridItems.length - 1);
    }
    function selectLeft() {
        selectIndex(currentIndex - 1);
    }
    function selectNextPage() {
        selectIndex(currentIndex + itemsPerPage);
    }
    function selectPage(pageIndex) {
        if (pageCount <= 0)
            return;

        var clampedPage = Math.max(0, Math.min(pageIndex, pageCount - 1));
        currentIndex = Math.min(clampedPage * itemsPerPage, gridItems.length - 1);
        moveToPage(clampedPage, true);
    }
    function selectPreviousPage() {
        selectIndex(currentIndex - itemsPerPage);
    }
    function selectRight() {
        selectIndex(currentIndex + 1);
    }
    function selectUp() {
        selectIndex(currentIndex - columns);
    }
    function setSwipeOffset(offset) {
        if (!touchpadGestureActive)
            return;

        touchpadGestureDelta = Math.max(-pager.width, Math.min(offset, pager.width));
        var lastPageX = (pageCount - 1) * pager.width;
        pager.contentX = Math.max(0, Math.min(touchpadGestureStartX - touchpadGestureDelta, lastPageX));
    }
    function syncPageSelection(pageIndex) {
        if (gridItems.length === 0)
            return;

        var firstIndex = pageIndex * itemsPerPage;
        var lastIndex = Math.min(firstIndex + itemsPerPage, gridItems.length) - 1;
        if (currentIndex < firstIndex || currentIndex > lastIndex)
            currentIndex = firstIndex;
    }
    function syncSelection() {
        pageAnimation.stop();
        if (gridItems.length === 0) {
            currentIndex = -1;
            currentPage = 0;
            pager.contentX = 0;
            return;
        }

        currentIndex = currentIndex < 0 ? 0 : Math.min(currentIndex, gridItems.length - 1);
        currentPage = Math.max(0, Math.min(Math.floor(currentIndex / itemsPerPage), pageCount - 1));
        pager.contentX = currentPage * pager.width;
    }
    function updateTouchpadGesture(delta) {
        if (pageCount <= 1 || delta === 0)
            return;
        if (!touchpadGestureActive)
            beginTouchpadGesture();
        if (!touchpadGestureActive)
            return;

        setSwipeOffset(touchpadGestureDelta + delta);
        touchpadGestureTimer.restart();
    }

    Layout.fillHeight: true
    Layout.fillWidth: true
    clip: true

    Component.onCompleted: syncSelection()
    onEntranceReadyChanged: {
        entranceWaveTimer.stop();
        entranceWaveActive = entranceReady;
        if (entranceReady)
            entranceWaveTimer.restart();
    }
    onGridItemsChanged: {
        appActionPopup.close();
        Qt.callLater(syncSelection);
    }
    onItemsPerPageChanged: Qt.callLater(syncSelection)
    onWidthChanged: Qt.callLater(syncSelection)

    ListView {
        id: pager

        acceptedButtons: Qt.LeftButton
        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: width
        clip: true
        flickDeceleration: 4000
        interactive: false
        maximumFlickVelocity: width * 3
        model: appsGrid.pageCount
        orientation: ListView.Horizontal
        reuseItems: true
        snapMode: ListView.SnapOneItem

        delegate: Item {
            id: pageRoot

            required property int index

            height: pager.height
            width: pager.width

            Grid {
                id: pageGrid

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                columns: appsGrid.columns
                height: appsGrid.pageContentHeight
                rows: appsGrid.rows
                spacing: 0
                width: appsGrid.cellWidth * appsGrid.columns

                Repeater {
                    model: appsGrid.itemsForPage(pageRoot.index)

                    delegate: Item {
                        id: delegateRoot

                        property real dragHotX: 0
                        property real dragHotY: 0
                        property bool draggedDuringPress: false
                        readonly property bool entranceReady: appsGrid.entranceReady
                        readonly property bool isGroup: modelData.kind === "group"
                        readonly property bool isSelected: modelData.globalIndex === appsGrid.currentIndex
                        required property var modelData

                        function activateItem() {
                            appsGrid.currentIndex = modelData.globalIndex;
                            if (isGroup) {
                                appActionPopup.close();
                                appsGrid.groupOpenRequested(modelData.groupId, false);
                            } else {
                                modelData.entry.execute();
                                appsGrid.appLaunched();
                            }
                        }
                        function resetEntrance() {
                            entryTimer.stop();
                            entryAnim.stop();
                            opacity = 0;
                            scale = 0.8;
                            entryTranslate.y = 30;
                        }
                        function scheduleEntrance() {
                            resetEntrance();
                            var column = modelData.localIndex % appsGrid.columns;
                            var row = Math.floor(modelData.localIndex / appsGrid.columns);
                            entryTimer.interval = Math.min(column + row, appsGrid.columns + 3) * 20;
                            entryTimer.start();
                        }
                        function showEntranceFinal() {
                            entryTimer.stop();
                            entryAnim.stop();
                            opacity = 1;
                            scale = 1;
                            entryTranslate.y = 0;
                        }

                        height: appsGrid.cellHeight
                        opacity: 0
                        scale: 0.8
                        width: appsGrid.cellWidth
                        z: gridMouse.drag.active ? 50 : 0

                        transform: Translate {
                            id: entryTranslate

                            y: 30
                        }

                        Component.onCompleted: {
                            if (appsGrid.entranceReady && appsGrid.entranceWaveActive)
                                delegateRoot.scheduleEntrance();
                            else if (appsGrid.entranceReady)
                                delegateRoot.showEntranceFinal();
                            else
                                delegateRoot.resetEntrance();
                        }
                        onEntranceReadyChanged: {
                            if (entranceReady && appsGrid.entranceWaveActive)
                                delegateRoot.scheduleEntrance();
                            else if (entranceReady)
                                delegateRoot.showEntranceFinal();
                            else
                                delegateRoot.resetEntrance();
                        }

                        Timer {
                            id: entryTimer

                            repeat: false

                            onTriggered: entryAnim.start()
                        }
                        ParallelAnimation {
                            id: entryAnim

                            NumberAnimation {
                                duration: Config.animationDuration(250)
                                easing.type: Easing.OutQuad
                                property: "opacity"
                                target: delegateRoot
                                to: 1
                            }
                            NumberAnimation {
                                duration: Config.animationDuration(350)
                                easing.type: Easing.OutBack
                                property: "scale"
                                target: delegateRoot
                                to: 1
                            }
                            NumberAnimation {
                                duration: Config.animationDuration(350)
                                easing.type: Easing.OutBack
                                property: "y"
                                target: entryTranslate
                                to: 0
                            }
                        }
                        Item {
                            id: dragProxy

                            Drag.active: gridMouse.drag.active
                            Drag.hotSpot.x: delegateRoot.dragHotX
                            Drag.hotSpot.y: delegateRoot.dragHotY
                            Drag.keys: ["launcher-app"]
                            Drag.supportedActions: Qt.MoveAction
                            height: Math.max(1, delegateRoot.height - 20)
                            objectName: delegateRoot.isGroup || !delegateRoot.modelData.entry ? "" : delegateRoot.modelData.entry.id
                            opacity: 0
                            width: Math.max(1, delegateRoot.width - 20)
                            x: 10
                            y: 10
                        }
                        Rectangle {
                            id: appCell

                            Accessible.name: delegateRoot.modelData.name
                            Accessible.role: Accessible.Button
                            anchors.fill: parent
                            anchors.margins: 10
                            color: dropTarget.containsDrag ? Config.alpha(Config.md3.primary_container, Config.lightTheme ? 0.86 : 0.72) : (delegateRoot.isSelected ? Config.alpha(Config.md3.on_surface, gridMouse.pressed ? 0.2 : 0.13) : (gridMouse.pressed ? Config.alpha(Config.md3.on_surface, 0.16) : (gridMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.08) : "transparent")))
                            opacity: gridMouse.drag.active ? 0.94 : 1
                            radius: 18
                            scale: gridMouse.drag.active ? 1.08 : (dropTarget.containsDrag ? 1.04 : (gridMouse.pressed ? 0.95 : (gridMouse.containsMouse ? 1.02 : 1)))

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animationDuration(120)
                                }
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Config.animationDuration(100)
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Config.animationDuration(150)
                                    easing.type: Easing.OutQuad
                                }
                            }
                            transform: Translate {
                                x: gridMouse.drag.active ? dragProxy.x - 10 : 0
                                y: gridMouse.drag.active ? dragProxy.y - 10 : 0
                            }

                            Accessible.onPressAction: delegateRoot.activateItem()

                            DropArea {
                                id: dropTarget

                                anchors.fill: parent
                                enabled: appsGrid.query.trim() === ""
                                keys: ["launcher-app"]

                                onDropped: drop => {
                                    var sourceAppId = String(drop.source ? drop.source.objectName || "" : "");
                                    if (sourceAppId === "")
                                        return;

                                    if (delegateRoot.isGroup) {
                                        if (!LauncherGroupService.addApp(delegateRoot.modelData.groupId, sourceAppId))
                                            return;
                                    } else {
                                        var createdGroupId = LauncherGroupService.createGroup(sourceAppId, delegateRoot.modelData.entry.id);
                                        if (createdGroupId === "")
                                            return;
                                    }
                                    drop.acceptProposedAction();
                                }
                                onEntered: drag => {
                                    var sourceAppId = String(drag.source ? drag.source.objectName || "" : "");
                                    if (sourceAppId === "" || (!delegateRoot.isGroup && sourceAppId === delegateRoot.modelData.entry.id))
                                        drag.accepted = false;
                                }
                            }
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 14
                                width: parent.width - 24

                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.preferredHeight: appsGrid.iconSize
                                    Layout.preferredWidth: appsGrid.iconSize

                                    IconImage {
                                        anchors.fill: parent
                                        mipmap: true
                                        smooth: true
                                        source: visible ? Quickshell.iconPath(delegateRoot.modelData.entry.icon || "application-x-executable") : ""
                                        visible: !delegateRoot.isGroup
                                    }
                                    LauncherGroupIcon {
                                        anchors.fill: parent
                                        dropActive: dropTarget.containsDrag
                                        entries: delegateRoot.modelData.entries
                                        visible: delegateRoot.isGroup
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    color: dropTarget.containsDrag ? Config.md3.on_primary_container : (delegateRoot.isSelected || gridMouse.containsMouse ? Config.md3.on_surface : Config.alpha(Config.md3.on_surface, 0.85))
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignHCenter
                                    maximumLineCount: 2
                                    text: delegateRoot.modelData.name
                                    wrapMode: Text.WordWrap

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Config.animationDuration(120)
                                        }
                                    }
                                }
                            }
                        }
                        MouseArea {
                            id: gridMouse

                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            anchors.fill: parent
                            anchors.margins: 10
                            cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                            drag.axis: Drag.XAndYAxis
                            drag.smoothed: false
                            drag.target: !delegateRoot.isGroup && appsGrid.query.trim() === "" && (pressedButtons & Qt.LeftButton) ? dragProxy : null
                            hoverEnabled: true
                            preventStealing: !delegateRoot.isGroup && appsGrid.query.trim() === ""

                            drag.onActiveChanged: {
                                if (drag.active) {
                                    delegateRoot.draggedDuringPress = true;
                                    appsGrid.appDragActive = true;
                                    pageAnimation.stop();
                                    appActionPopup.close();
                                } else {
                                    appsGrid.appDragActive = false;
                                    dragProxy.x = 10;
                                    dragProxy.y = 10;
                                }
                            }
                            onCanceled: {
                                appsGrid.appDragActive = false;
                                if (dragProxy.Drag.active)
                                    dragProxy.Drag.cancel();
                            }
                            onClicked: mouse => {
                                if (delegateRoot.draggedDuringPress)
                                    return;
                                appsGrid.currentIndex = delegateRoot.modelData.globalIndex;
                                if (mouse.button === Qt.RightButton) {
                                    if (!delegateRoot.isGroup)
                                        appActionPopup.openFor(delegateRoot.modelData.entry, delegateRoot.modelData.name, appCell, mouse.x, mouse.y);
                                } else {
                                    delegateRoot.activateItem();
                                }
                            }
                            onEntered: appsGrid.currentIndex = delegateRoot.modelData.globalIndex
                            onPressed: mouse => {
                                appsGrid.currentIndex = delegateRoot.modelData.globalIndex;
                                if (mouse.button === Qt.LeftButton) {
                                    delegateRoot.draggedDuringPress = false;
                                    delegateRoot.dragHotX = mouse.x;
                                    delegateRoot.dragHotY = mouse.y;
                                }
                            }
                            onReleased: mouse => {
                                if (mouse.button === Qt.LeftButton && dragProxy.Drag.active) {
                                    appsGrid.appDragActive = false;
                                    dragProxy.Drag.drop();
                                }
                            }
                        }
                    }
                }
            }
        }

        onMovementEnded: {
            appsGrid.currentPage = appsGrid.visiblePage;
            appsGrid.syncPageSelection(appsGrid.currentPage);
        }
        onMovementStarted: {
            pageAnimation.stop();
            appActionPopup.close();
        }
    }
    DragHandler {
        id: pageDrag

        enabled: appsGrid.pageCount > 1 && !appsGrid.appDragActive && !appsGrid.groupPopupOpened
        target: null
        xAxis.enabled: true
        yAxis.enabled: false

        onActiveChanged: {
            if (active) {
                appsGrid.beginTouchpadGesture();
            } else {
                appsGrid.finishTouchpadGesture(true);
            }
        }
        onTranslationChanged: {
            if (!active)
                return;
            touchpadGestureTimer.stop();
            appsGrid.setSwipeOffset(translation.x);
        }
    }
    WheelHandler {
        id: horizontalPageWheel

        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        blocking: true
        enabled: !appsGrid.appDragActive && !appsGrid.groupPopupOpened
        orientation: Qt.Horizontal
        target: null

        onWheel: event => {
            var horizontalDelta = event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x * 0.5;
            if (horizontalDelta === 0)
                return;
            if (event.phase === Qt.ScrollBegin)
                appsGrid.beginTouchpadGesture();
            appsGrid.updateTouchpadGesture(horizontalDelta * 1.25);
            if (event.phase === Qt.ScrollEnd)
                appsGrid.finishTouchpadGesture(false);
            event.accepted = true;
        }
    }
    NumberAnimation {
        id: pageAnimation

        duration: Config.animationDuration(240)
        easing.type: Easing.OutCubic
        property: "contentX"
        target: pager
    }
    Timer {
        id: touchpadGestureTimer

        interval: 120
        repeat: false

        onTriggered: appsGrid.finishTouchpadGesture(false)
    }
    Timer {
        id: entranceWaveTimer

        interval: Math.max(450, (appsGrid.columns + appsGrid.rows) * 25 + 350)
        repeat: false

        onTriggered: appsGrid.entranceWaveActive = false
    }
    Row {
        id: pageIndicator

        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        height: 12
        spacing: 8
        visible: appsGrid.pageCount > 1
        z: 2

        Repeater {
            model: appsGrid.pageCount

            delegate: Item {
                id: dotHitArea

                required property int index

                height: 20
                width: dot.width + 8

                Rectangle {
                    id: dot

                    anchors.centerIn: parent
                    color: dotHitArea.index === appsGrid.visiblePage ? Config.md3.primary : Config.alpha(Config.md3.on_surface_variant, 0.38)
                    height: 8
                    radius: height / 2
                    width: dotHitArea.index === appsGrid.visiblePage ? 24 : 8

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animationDuration(160)
                        }
                    }
                    Behavior on width {
                        NumberAnimation {
                            duration: Config.animationDuration(180)
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    onClicked: appsGrid.selectPage(dotHitArea.index)
                }
            }
        }
    }
    AppActionPopup {
        id: appActionPopup

        onAppLaunched: appsGrid.appLaunched()
    }
    Text {
        anchors.centerIn: parent
        color: Config.alpha(Config.md3.on_surface, 0.35)
        font.family: Config.fontName
        font.pixelSize: 16
        font.weight: Font.Medium
        text: qsTr("No matching applications")
        visible: appsGrid.gridItems.length === 0
    }
}
