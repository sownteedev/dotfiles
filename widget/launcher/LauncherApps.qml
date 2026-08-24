import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../"
import "../../components"
import "../../service"

GridView {
    id: appsGrid

    readonly property int columns: Responsive.columnsFor(width, 210, 8, width < 300 ? 1 : 2, 0)
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

        var finalItems = apps.map(function (e) {
            return {
                "name": e.name,
                "entry": e
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
    readonly property real iconSize: Responsive.clamp(normalizedCellWidth * 0.38, 72, 96)
    readonly property int normalizedCellWidth: Math.floor(width / columns)
    property string query: ""

    signal appLaunched

    function launchSelected() {
        if (currentIndex < 0 || currentIndex >= gridItems.length)
            return;
        gridItems[currentIndex].entry.execute();
        appLaunched();
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
            return;
        }
        currentIndex = Math.max(0, Math.min(targetIndex, gridItems.length - 1));
        positionViewAtIndex(currentIndex, GridView.Contain);
    }
    function selectLast() {
        selectIndex(gridItems.length - 1);
    }
    function selectLeft() {
        selectIndex(currentIndex - 1);
    }
    function selectNextPage() {
        var visibleRows = Math.max(1, Math.floor(height / cellHeight));
        selectIndex(currentIndex + visibleRows * columns);
    }
    function selectPreviousPage() {
        var visibleRows = Math.max(1, Math.floor(height / cellHeight));
        selectIndex(currentIndex - visibleRows * columns);
    }
    function selectRight() {
        selectIndex(currentIndex + 1);
    }
    function selectUp() {
        selectIndex(currentIndex - columns);
    }
    function syncSelection() {
        if (gridItems.length === 0) {
            currentIndex = -1;
            return;
        }
        selectIndex(currentIndex < 0 ? 0 : Math.min(currentIndex, gridItems.length - 1));
    }

    Layout.fillHeight: true
    Layout.fillWidth: true
    bottomMargin: 16
    boundsBehavior: Flickable.StopAtBounds
    cellHeight: Responsive.clamp(iconSize + 92, 164, 196)
    cellWidth: normalizedCellWidth
    clip: true
    leftMargin: Math.floor((width - (normalizedCellWidth * columns)) / 2)
    model: gridItems
    rightMargin: leftMargin
    topMargin: 16

    Behavior on contentY {
        enabled: !appsGrid.dragging && !appsGrid.flicking

        NumberAnimation {
            duration: 250
            easing.type: Easing.OutQuad
        }
    }
    delegate: Item {
        id: delegateRoot

        readonly property bool entranceReady: appsGrid.entranceReady
        readonly property bool isSelected: index === appsGrid.currentIndex

        function resetEntrance() {
            entryTimer.stop();
            entryAnim.stop();
            opacity = 0;
            scale = 0.8;
            entryTranslate.y = 30;
        }
        function scheduleEntrance() {
            resetEntrance();
            var col = index % appsGrid.columns;
            var row = Math.floor(index / appsGrid.columns);
            entryTimer.interval = Math.min(col + row, appsGrid.columns + 3) * 20;
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
                duration: 250
                easing.type: Easing.OutQuad
                property: "opacity"
                target: delegateRoot
                to: 1.0
            }
            NumberAnimation {
                duration: 350
                easing.type: Easing.OutBack
                property: "scale"
                target: delegateRoot
                to: 1.0
            }
            NumberAnimation {
                duration: 350
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

            // Multiply delegateRoot scale/opacity with hover effects
            scale: gridMouse.pressed ? 0.95 : (gridMouse.containsMouse ? 1.02 : 1.0)

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 150
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
                        source: Quickshell.iconPath(modelData.entry.icon || "application-x-executable")
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
                    text: modelData.name
                    wrapMode: Text.WordWrap

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
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
                    appsGrid.currentIndex = index;
                    if (mouse.button === Qt.RightButton) {
                        appActionPopup.openFor(modelData.entry, modelData.name, appCell, mouse.x, mouse.y);
                    } else {
                        modelData.entry.execute();
                        appsGrid.appLaunched();
                    }
                }
                onEntered: appsGrid.currentIndex = index
                onPressed: appsGrid.currentIndex = index
            }
        }
    }
    displaced: Transition {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutQuad
            properties: "x,y"
        }
    }

    // Smooth exit and displacement animations for real-time search filtering
    // Removed 'add' transition because we handle entry animation natively in the delegate for staggered fly-in wave
    remove: Transition {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutQuad
            properties: "opacity,scale"
            to: 0.0
        }
    }

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

    AppActionPopup {
        id: appActionPopup

        onAppLaunched: appsGrid.appLaunched()
    }
    Timer {
        id: entranceWaveTimer

        interval: Math.max(450, (appsGrid.columns + Math.ceil(appsGrid.height / appsGrid.cellHeight)) * 25 + 350)
        repeat: false

        onTriggered: appsGrid.entranceWaveActive = false
    }

    // Empty state message when search returns no matching apps
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
