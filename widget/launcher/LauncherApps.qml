import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../"
import "../../components"
import "../../service"

Item {
    id: appsGrid

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

        if (query.trim() !== "") {
            var q = query.toLowerCase().trim();
            apps = apps.filter(function (entry) {
                var nameMatch = entry.name && entry.name.toLowerCase().indexOf(q) !== -1;
                var commentMatch = entry.comment && entry.comment.toLowerCase().indexOf(q) !== -1;
                var idMatch = entry.id && entry.id.toLowerCase().indexOf(q) !== -1;
                return nameMatch || commentMatch || idMatch;
            });
        }

        var finalItems = apps.map(function (entry) {
            return {
                "name": entry.name,
                "entry": entry
            };
        });

        finalItems.sort(function (a, b) {
            return a.name.localeCompare(b.name, undefined, {
                sensitivity: "base",
                numeric: true
            });
        });

        return finalItems;
    }
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
                "name": sourceItem.name,
                "entry": sourceItem.entry,
                "globalIndex": index,
                "localIndex": index - startIndex
            });
        }
        return pageItems;
    }
    function launchSelected() {
        if (currentIndex < 0 || currentIndex >= gridItems.length)
            return;
        gridItems[currentIndex].entry.execute();
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

                        readonly property bool entranceReady: appsGrid.entranceReady
                        readonly property bool isSelected: modelData.globalIndex === appsGrid.currentIndex
                        required property var modelData

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
                        Rectangle {
                            id: appCell

                            anchors.fill: parent
                            anchors.margins: 10
                            color: delegateRoot.isSelected ? Config.alpha(Config.md3.on_surface, gridMouse.pressed ? 0.2 : 0.13) : (gridMouse.pressed ? Config.alpha(Config.md3.on_surface, 0.16) : (gridMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.08) : "transparent"))
                            radius: 18
                            scale: gridMouse.pressed ? 0.95 : (gridMouse.containsMouse ? 1.02 : 1)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animationDuration(120)
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Config.animationDuration(150)
                                    easing.type: Easing.OutQuad
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
                                        source: Quickshell.iconPath(delegateRoot.modelData.entry.icon || "application-x-executable")
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    color: delegateRoot.isSelected || gridMouse.containsMouse ? Config.md3.on_surface : Config.alpha(Config.md3.on_surface, 0.85)
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
                            MouseArea {
                                id: gridMouse

                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true

                                onClicked: mouse => {
                                    appsGrid.currentIndex = delegateRoot.modelData.globalIndex;
                                    if (mouse.button === Qt.RightButton) {
                                        appActionPopup.openFor(delegateRoot.modelData.entry, delegateRoot.modelData.name, appCell, mouse.x, mouse.y);
                                    } else {
                                        delegateRoot.modelData.entry.execute();
                                        appsGrid.appLaunched();
                                    }
                                }
                                onEntered: appsGrid.currentIndex = delegateRoot.modelData.globalIndex
                                onPressed: appsGrid.currentIndex = delegateRoot.modelData.globalIndex
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

        enabled: appsGrid.pageCount > 1
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
