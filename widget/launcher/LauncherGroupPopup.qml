pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../"
import "../../components"
import "../../service"

FocusScope {
    id: root

    readonly property int columns: 3
    property int currentIndex: 0
    property int currentPage: 0
    property bool dragActive: false
    property var dragEntry: null
    property real dragHotX: 0
    property real dragHotY: 0
    property bool dragOutside: false
    property real dragSourceHeight: 1
    property real dragSourceWidth: 1
    readonly property var groupData: LauncherGroupService.groupById(groupId)
    property string groupId: ""
    readonly property int itemsPerPage: columns * rows
    property bool keyboardNavigationActive: false
    readonly property var memberEntries: {
        var group = root.groupData;
        if (!group)
            return [];

        var available = DesktopEntries.applications.values || [];
        var availableById = {};
        for (var availableIndex = 0; availableIndex < available.length; ++availableIndex)
            availableById[available[availableIndex].id] = available[availableIndex];

        var entries = [];
        for (var appIndex = 0; appIndex < group.appIds.length; ++appIndex) {
            var appId = group.appIds[appIndex];
            var entry = availableById[appId] || DesktopEntries.byId(appId);
            if (entry)
                entries.push(entry);
        }
        return entries;
    }
    property bool opened: false
    readonly property int pageCount: memberEntries.length === 0 ? 0 : Math.ceil(memberEntries.length / itemsPerPage)
    readonly property bool presentationVisible: opened && !dragOutside
    readonly property int rows: 3
    property bool wheelLocked: false

    signal appLaunched
    signal focusSearchRequested

    function activatePreparedDrag() {
        if (!dragEntry)
            return;
        dragOutside = false;
        dragActive = true;
        updateDragOutside();
    }
    function cancelDrag() {
        dragActive = false;
        dragOutside = false;
        dragEntry = null;
    }
    function closeGroup(saveName) {
        if (!opened && !dragActive)
            return;
        if ((saveName === undefined || saveName) && groupData)
            commitName();
        cancelDrag();
        opened = false;
        focusSearchRequested();
    }
    function commitName() {
        if (!groupData)
            return;
        var nextName = nameInput.text.trim();
        if (nextName === "") {
            nameInput.text = groupData.name || qsTr("Apps");
            return;
        }
        LauncherGroupService.renameGroup(groupId, nextName);
    }
    function entriesForPage(pageIndex) {
        var startIndex = pageIndex * itemsPerPage;
        var endIndex = Math.min(startIndex + itemsPerPage, memberEntries.length);
        var entries = [];
        for (var index = startIndex; index < endIndex; ++index) {
            entries.push({
                "entry": memberEntries[index],
                "globalIndex": index
            });
        }
        return entries;
    }
    function finishDrag() {
        if (!dragActive) {
            dragEntry = null;
            return;
        }

        var entry = dragEntry;
        var shouldRemove = dragOutside;
        dragActive = false;
        dragOutside = false;
        dragEntry = null;

        if (!shouldRemove || !entry)
            return;

        commitName();
        var sourceGroupId = groupId;
        opened = false;
        LauncherGroupService.removeApp(sourceGroupId, entry.id);
        focusSearchRequested();
    }
    function launchEntry(entry) {
        if (!entry)
            return;
        closeGroup();
        entry.execute();
        appLaunched();
    }
    function launchSelected() {
        if (currentIndex < 0 || currentIndex >= memberEntries.length)
            return;
        launchEntry(memberEntries[currentIndex]);
    }
    function moveSelection(delta) {
        keyboardNavigationActive = true;
        selectIndex(currentIndex + delta);
    }
    function moveToPage(pageIndex, animated) {
        if (pageCount <= 0 || memberPager.width <= 0)
            return;

        var nextPage = Math.max(0, Math.min(pageIndex, pageCount - 1));
        var nextX = nextPage * memberPager.width;
        currentPage = nextPage;
        pageAnimation.stop();
        if (!animated || Config.animationDuration(220) === 0 || Math.abs(memberPager.contentX - nextX) < 1) {
            memberPager.contentX = nextX;
            return;
        }
        pageAnimation.from = memberPager.contentX;
        pageAnimation.to = nextX;
        pageAnimation.restart();
    }
    function openGroup(targetGroupId, startEditing) {
        var target = LauncherGroupService.groupById(targetGroupId);
        if (!target)
            return;

        cancelDrag();
        groupId = target.id;
        nameInput.text = target.name || qsTr("Apps");
        currentIndex = 0;
        currentPage = 0;
        keyboardNavigationActive = false;
        opened = true;
        Qt.callLater(function () {
            if (!root.opened)
                return;
            memberPager.contentX = 0;
            if (startEditing) {
                nameInput.forceActiveFocus();
                nameInput.selectAll();
            } else {
                root.forceActiveFocus();
            }
        });
    }
    function prepareDrag(entry, sourceItem, hotX, hotY) {
        if (!entry || !sourceItem)
            return;
        var origin = sourceItem.mapToItem(root, 0, 0);
        dragEntry = entry;
        dragHotX = hotX;
        dragHotY = hotY;
        dragSourceHeight = sourceItem.height;
        dragSourceWidth = sourceItem.width;
        dragProxy.x = origin.x;
        dragProxy.y = origin.y;
    }
    function selectIndex(targetIndex) {
        if (memberEntries.length === 0) {
            currentIndex = -1;
            currentPage = 0;
            return;
        }
        currentIndex = Math.max(0, Math.min(targetIndex, memberEntries.length - 1));
        moveToPage(Math.floor(currentIndex / itemsPerPage), true);
    }
    function syncSelection() {
        pageAnimation.stop();
        if (memberEntries.length === 0) {
            currentIndex = -1;
            currentPage = 0;
            memberPager.contentX = 0;
            return;
        }

        currentIndex = Math.max(0, Math.min(currentIndex, memberEntries.length - 1));
        currentPage = Math.max(0, Math.min(Math.floor(currentIndex / itemsPerPage), pageCount - 1));
        memberPager.contentX = currentPage * memberPager.width;
    }
    function updateDragOutside() {
        if (!dragActive)
            return;
        var pointer = folderCard.mapFromItem(root, dragProxy.x + dragHotX, dragProxy.y + dragHotY);
        dragOutside = pointer.x < 0 || pointer.y < 0 || pointer.x > folderCard.width || pointer.y > folderCard.height;
    }

    enabled: opened || dragActive
    focus: opened
    visible: opened || dragActive || scrim.opacity > 0.01 || folderPresentation.opacity > 0.01
    z: 100

    Component.onCompleted: syncSelection()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            closeGroup();
            event.accepted = true;
        } else if (nameInput.activeFocus) {
            return;
        } else if (event.key === Qt.Key_Left) {
            moveSelection(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            moveSelection(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            moveSelection(-columns);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            moveSelection(columns);
            event.accepted = true;
        } else if (event.key === Qt.Key_Home) {
            keyboardNavigationActive = true;
            selectIndex(0);
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            keyboardNavigationActive = true;
            selectIndex(memberEntries.length - 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            keyboardNavigationActive = true;
            selectIndex(currentIndex - itemsPerPage);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageDown) {
            keyboardNavigationActive = true;
            selectIndex(currentIndex + itemsPerPage);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            launchSelected();
            event.accepted = true;
        } else if (event.key === Qt.Key_F2) {
            nameInput.forceActiveFocus();
            nameInput.selectAll();
            event.accepted = true;
        }
    }
    onGroupDataChanged: {
        if ((opened || dragActive) && !groupData) {
            cancelDrag();
            opened = false;
            focusSearchRequested();
        } else if (groupData && !nameInput.activeFocus) {
            nameInput.text = groupData.name || qsTr("Apps");
        }
    }
    onMemberEntriesChanged: Qt.callLater(syncSelection)

    Timer {
        id: wheelUnlockTimer

        interval: 180
        repeat: false

        onTriggered: root.wheelLocked = false
    }
    Rectangle {
        id: scrim

        anchors.fill: parent
        color: Config.alpha(Config.md3.scrim, Config.lightTheme ? 0.32 : 0.52)
        opacity: root.presentationVisible ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animationDuration(root.presentationVisible ? 180 : 130)
                easing.type: root.presentationVisible ? Easing.OutCubic : Easing.InCubic
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.opened && !root.dragActive
        hoverEnabled: true

        onClicked: root.closeGroup()
    }
    Item {
        id: folderPresentation

        readonly property real cardHeight: Math.max(300, Math.min(560, root.height - titlePill.height - 96))

        anchors.centerIn: parent
        height: titlePill.height + 16 + cardHeight
        opacity: root.presentationVisible ? 1 : 0
        scale: root.presentationVisible ? 1 : 0.94
        width: Math.max(300, Math.min(620, root.width - 48))

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animationDuration(root.presentationVisible ? 190 : 130)
                easing.type: root.presentationVisible ? Easing.OutCubic : Easing.InCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Config.animationDuration(root.presentationVisible ? 240 : 150)
                easing.type: root.presentationVisible ? Easing.OutBack : Easing.InCubic
            }
        }

        ShellShadow {
            active: root.presentationVisible
            componentShadow: true
            cornerRadius: titlePill.radius
            target: titlePill
        }
        Rectangle {
            id: titlePill

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            border.color: Config.alpha(nameInput.activeFocus ? Config.md3.primary : Config.md3.outline_variant, nameInput.activeFocus ? 0.52 : 0.3)
            border.width: 1
            color: Config.alpha(Config.md3.surface_container_high, Config.lightTheme ? 0.96 : 0.9)
            height: 66
            radius: height / 2
            width: Math.min(parent.width - 48, 500)

            Text {
                anchors.centerIn: nameInput
                color: Config.alpha(Config.md3.on_surface_variant, 0.52)
                font.family: Config.fontName
                font.pixelSize: 20
                font.weight: Font.DemiBold
                text: qsTr("Apps")
                visible: nameInput.text === ""
            }
            TextInput {
                id: nameInput

                Accessible.name: qsTr("Folder name")
                Accessible.role: Accessible.EditableText
                activeFocusOnTab: true
                anchors.centerIn: parent
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 20
                font.weight: Font.DemiBold
                height: parent.height
                horizontalAlignment: Text.AlignHCenter
                maximumLength: 40
                selectByMouse: true
                selectedTextColor: Config.md3.on_primary
                selectionColor: Config.md3.primary
                verticalAlignment: TextInput.AlignVCenter
                width: parent.width - 116

                Keys.onEscapePressed: event => {
                    root.commitName();
                    root.forceActiveFocus();
                    event.accepted = true;
                }
                onAccepted: {
                    root.commitName();
                    root.forceActiveFocus();
                }
                onActiveFocusChanged: {
                    if (!activeFocus)
                        root.commitName();
                }
            }
            Rectangle {
                id: closeButton

                Accessible.name: qsTr("Close folder")
                Accessible.role: Accessible.Button
                anchors.right: parent.right
                anchors.rightMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                color: closeMouse.pressed ? Config.alpha(Config.md3.on_surface, 0.16) : (closeMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.1) : Config.alpha(Config.md3.on_surface, 0.06))
                height: 48
                radius: height / 2
                scale: closeMouse.pressed ? 0.92 : 1
                width: 48

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animationDuration(100)
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Config.animationDuration(120)
                        easing.type: Easing.OutBack
                    }
                }

                Accessible.onPressAction: root.closeGroup()

                Text {
                    anchors.centerIn: parent
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 28
                    font.weight: Font.Medium
                    text: "×"
                    y: -1
                }
                MouseArea {
                    id: closeMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.closeGroup()
                }
            }
        }
        ShellShadow {
            active: root.presentationVisible
            componentShadow: true
            cornerRadius: folderCard.radius
            target: folderCard
        }
        Rectangle {
            id: folderCard

            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            border.color: Config.alpha(Config.md3.outline_variant, Config.lightTheme ? 0.38 : 0.26)
            border.width: 1
            color: Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.95 : 0.88)
            height: parent.cardHeight
            radius: 40
            width: parent.width

            MouseArea {
                anchors.fill: parent
            }
            ListView {
                id: memberPager

                anchors.bottom: pageIndicator.visible ? pageIndicator.top : parent.bottom
                anchors.bottomMargin: pageIndicator.visible ? 12 : 24
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.right: parent.right
                anchors.rightMargin: 24
                anchors.top: parent.top
                anchors.topMargin: 24
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                flickDeceleration: 4200
                interactive: !root.dragActive
                maximumFlickVelocity: width * 2.5
                model: root.pageCount
                orientation: ListView.Horizontal
                reuseItems: true
                snapMode: ListView.SnapOneItem

                delegate: Item {
                    id: pageRoot

                    required property int index

                    height: memberPager.height
                    width: memberPager.width

                    Grid {
                        id: pageGrid

                        anchors.fill: parent
                        columns: root.columns
                        rows: root.rows

                        Repeater {
                            model: root.entriesForPage(pageRoot.index)

                            delegate: Item {
                                id: memberDelegate

                                readonly property bool dragging: root.dragActive && root.dragEntry !== null && root.dragEntry.id === modelData.entry.id
                                readonly property real iconSize: Math.max(52, Math.min(86, Math.min(width, height) * 0.56))
                                required property var modelData
                                readonly property bool selected: modelData.globalIndex === root.currentIndex
                                property bool wasDragged: false

                                height: pageGrid.height / root.rows
                                width: pageGrid.width / root.columns

                                Item {
                                    id: memberSurface

                                    Accessible.name: memberDelegate.modelData.entry.name
                                    Accessible.role: Accessible.Button
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    opacity: memberDelegate.dragging ? 0.12 : 1
                                    scale: memberMouse.pressed && !memberDelegate.wasDragged ? 0.95 : 1

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Config.animationDuration(100)
                                        }
                                    }
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: Config.animationDuration(140)
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Accessible.onPressAction: root.launchEntry(memberDelegate.modelData.entry)

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 9
                                        width: parent.width - 8

                                        Item {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.preferredHeight: memberDelegate.iconSize + 14
                                            Layout.preferredWidth: Layout.preferredHeight

                                            Rectangle {
                                                anchors.fill: parent
                                                color: memberMouse.pressed ? Config.alpha(Config.md3.on_surface, 0.12) : (memberMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.07) : (memberDelegate.selected && root.keyboardNavigationActive ? Config.alpha(Config.md3.primary, 0.1) : "transparent"))
                                                radius: 24

                                                Behavior on color {
                                                    ColorAnimation {
                                                        duration: Config.animationDuration(110)
                                                    }
                                                }
                                            }
                                            LauncherAppIcon {
                                                anchors.centerIn: parent
                                                entry: memberDelegate.modelData.entry
                                                height: memberDelegate.iconSize
                                                requestedSourceSize: 96
                                                scale: memberMouse.pressed ? 0.94 : (memberMouse.containsMouse ? 1.04 : 1)
                                                width: memberDelegate.iconSize

                                                Behavior on scale {
                                                    NumberAnimation {
                                                        duration: Config.animationDuration(140)
                                                        easing.type: Easing.OutCubic
                                                    }
                                                }
                                            }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            color: memberDelegate.selected && root.keyboardNavigationActive ? Config.md3.primary : Config.md3.on_surface
                                            elide: Text.ElideRight
                                            font.family: Config.fontName
                                            font.pixelSize: 15
                                            font.weight: Font.DemiBold
                                            horizontalAlignment: Text.AlignHCenter
                                            maximumLineCount: 1
                                            text: memberDelegate.modelData.entry.name

                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: Config.animationDuration(110)
                                                }
                                            }
                                        }
                                    }
                                }
                                MouseArea {
                                    id: memberMouse

                                    acceptedButtons: Qt.LeftButton
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    drag.axis: Drag.XAndYAxis
                                    drag.smoothed: false
                                    drag.target: dragProxy
                                    drag.threshold: 10
                                    hoverEnabled: true
                                    preventStealing: true

                                    drag.onActiveChanged: {
                                        if (drag.active) {
                                            memberDelegate.wasDragged = true;
                                            root.activatePreparedDrag();
                                        }
                                    }
                                    onCanceled: {
                                        memberDelegate.wasDragged = false;
                                        root.cancelDrag();
                                    }
                                    onClicked: {
                                        if (!memberDelegate.wasDragged)
                                            root.launchEntry(memberDelegate.modelData.entry);
                                    }
                                    onEntered: {
                                        root.keyboardNavigationActive = false;
                                        root.currentIndex = memberDelegate.modelData.globalIndex;
                                    }
                                    onPressed: mouse => {
                                        root.currentIndex = memberDelegate.modelData.globalIndex;
                                        memberDelegate.wasDragged = false;
                                        root.prepareDrag(memberDelegate.modelData.entry, memberDelegate, mouse.x, mouse.y);
                                    }
                                    onReleased: {
                                        if (memberDelegate.wasDragged)
                                            root.finishDrag();
                                        else
                                            root.dragEntry = null;
                                    }
                                }
                            }
                        }
                    }
                }

                onMovementEnded: root.currentPage = Math.max(0, Math.min(Math.round(contentX / Math.max(1, width)), root.pageCount - 1))
            }
            NumberAnimation {
                id: pageAnimation

                duration: Config.animationDuration(220)
                easing.type: Easing.OutCubic
                property: "contentX"
                target: memberPager
            }
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                blocking: true
                enabled: root.pageCount > 1 && !root.dragActive
                target: null

                onWheel: event => {
                    if (root.wheelLocked)
                        return;
                    var delta = Math.abs(event.pixelDelta.x) > Math.abs(event.pixelDelta.y) ? event.pixelDelta.x : event.pixelDelta.y;
                    if (delta === 0)
                        delta = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) ? event.angleDelta.x : event.angleDelta.y;
                    if (delta === 0)
                        return;
                    root.wheelLocked = true;
                    wheelUnlockTimer.restart();
                    root.moveToPage(root.currentPage + (delta < 0 ? 1 : -1), true);
                    event.accepted = true;
                }
            }
            Row {
                id: pageIndicator

                anchors.bottom: parent.bottom
                anchors.bottomMargin: 18
                anchors.horizontalCenter: parent.horizontalCenter
                height: 24
                spacing: 8
                visible: root.pageCount > 1

                Repeater {
                    model: root.pageCount

                    delegate: Item {
                        id: pageDotTarget

                        required property int index

                        height: 24
                        width: 24

                        Rectangle {
                            anchors.centerIn: parent
                            color: pageDotTarget.index === root.currentPage ? Config.md3.primary : Config.alpha(Config.md3.on_surface_variant, 0.34)
                            height: 8
                            radius: 4
                            scale: pageDotTarget.index === root.currentPage ? 1.18 : 1
                            width: 8

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animationDuration(120)
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: Config.animationDuration(150)
                                    easing.type: Easing.OutBack
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                var firstIndex = pageDotTarget.index * root.itemsPerPage;
                                root.currentIndex = Math.min(firstIndex, root.memberEntries.length - 1);
                                root.moveToPage(pageDotTarget.index, true);
                            }
                        }
                    }
                }
            }
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                visible: root.memberEntries.length === 0

                IconImage {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: 48
                    Layout.preferredWidth: 48
                    opacity: 0.56
                    source: Quickshell.iconPath("folder-symbolic", "folder")
                }
                Text {
                    color: Config.md3.on_surface_variant
                    font.family: Config.fontName
                    font.pixelSize: 16
                    text: qsTr("No apps available")
                }
            }
        }
    }
    Item {
        id: dragProxy

        height: root.dragSourceHeight
        visible: root.dragActive && root.dragEntry !== null
        width: root.dragSourceWidth
        z: 500

        onXChanged: root.updateDragOutside()
        onYChanged: root.updateDragOutside()

        Item {
            anchors.fill: parent
            scale: 1.06

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 9
                width: parent.width - 8

                LauncherAppIcon {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: Math.max(52, Math.min(86, Math.min(dragProxy.width, dragProxy.height) * 0.56))
                    Layout.preferredWidth: Layout.preferredHeight
                    entry: root.dragEntry
                    requestedSourceSize: 96
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    text: root.dragEntry ? root.dragEntry.name : ""
                }
            }
        }
    }
}
