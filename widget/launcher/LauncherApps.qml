import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../"

GridView {
    id: appsGrid

    readonly property int columns: Responsive.columnsFor(width, 150, 5, width < 300 ? 1 : 2, 0)
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
    readonly property int normalizedCellWidth: Math.floor(width / columns)
    property string query: ""

    signal appLaunched

    Layout.fillHeight: true
    Layout.fillWidth: true
    boundsBehavior: Flickable.StopAtBounds
    cellHeight: width < 620 ? 142 : 158
    cellWidth: normalizedCellWidth
    clip: true
    leftMargin: Math.floor((width - (normalizedCellWidth * columns)) / 2)
    model: gridItems
    rightMargin: leftMargin

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
            // Staggered delay: 25ms per column/row step
            entryTimer.interval = Math.min(col + row, appsGrid.columns + 3) * 25 + 10;
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
            anchors.margins: 6
            border.color: gridMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.08) : "transparent"
            border.width: 1
            color: gridMouse.pressed ? Config.md3.surface_container_highest : (gridMouse.containsMouse ? Config.md3.surface_container : "transparent")
            opacity: gridMouse.pressed ? 0.8 : 1.0
            radius: 18

            // Multiply delegateRoot scale/opacity with hover effects
            scale: gridMouse.pressed ? 0.95 : (gridMouse.containsMouse ? 1.02 : 1.0)

            Behavior on border.color {
                ColorAnimation {
                    duration: 120
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 100
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
                spacing: 10
                width: parent.width - 16

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    height: appsGrid.width < 620 ? 60 : 70
                    width: height

                    IconImage {
                        anchors.fill: parent
                        mipmap: true
                        smooth: true
                        source: Quickshell.iconPath(modelData.entry.icon || "application-x-executable")
                    }
                }
                Text {
                    Layout.fillWidth: true
                    color: gridMouse.containsMouse ? Config.md3.on_surface : Config.alpha(Config.md3.on_surface, 0.85)
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 14
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

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onClicked: {
                    modelData.entry.execute();
                    appsGrid.appLaunched();
                }
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

    onEntranceReadyChanged: {
        entranceWaveTimer.stop();
        entranceWaveActive = entranceReady;
        if (entranceReady)
            entranceWaveTimer.restart();
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
        text: "No matching applications"
        visible: appsGrid.gridItems.length === 0
    }
}
