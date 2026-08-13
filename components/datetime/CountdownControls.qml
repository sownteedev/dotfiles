pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "../../"

Item {
    id: root

    readonly property color actionColor: completed ? Config.md3.secondary : running ? Config.md3.tertiary : Config.md3.primary
    property bool completed: false
    property bool hasStarted: false
    property bool running: false

    signal resetRequested
    signal toggleRequested

    implicitHeight: 52
    implicitWidth: 232

    Rectangle {
        anchors.fill: parent
        border.color: Config.alpha(Config.md3.on_surface, 0.07)
        border.width: 1
        color: Config.alpha(Config.md3.surface_container_high, 0.46)
        radius: height / 2
    }
    RowLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 4

        Rectangle {
            id: resetButton

            readonly property bool available: root.hasStarted || root.completed

            Accessible.name: qsTr("Reset timer")
            Accessible.role: Accessible.Button
            Layout.fillHeight: true
            Layout.preferredWidth: 44
            activeFocusOnTab: available
            border.color: activeFocus ? Config.alpha(Config.md3.primary, 0.65) : Config.alpha(Config.md3.on_surface, resetArea.containsMouse && available ? 0.14 : 0.055)
            border.width: 1
            color: Config.alpha(Config.md3.on_surface, resetArea.pressed && available ? 0.12 : resetArea.containsMouse && available ? 0.075 : 0.025)
            enabled: available
            opacity: available ? 1 : 0.34
            radius: height / 2
            scale: resetArea.pressed && available ? 0.92 : 1

            Behavior on color {
                ColorAnimation {
                    duration: 130
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 140
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 110
                    easing.type: Easing.OutCubic
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    root.resetRequested();
                    event.accepted = true;
                }
            }

            IconImage {
                anchors.centerIn: parent
                height: 18
                layer.enabled: true
                source: Quickshell.iconPath("view-refresh-symbolic")
                width: 18

                layer.effect: ColorOverlay {
                    color: Config.alpha(Config.md3.on_surface, 0.78)
                }
            }
            MouseArea {
                id: resetArea

                anchors.fill: parent
                cursorShape: resetButton.available ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: resetButton.available
                hoverEnabled: true

                onClicked: {
                    resetButton.forceActiveFocus();
                    root.resetRequested();
                }
            }
        }
        Rectangle {
            Layout.preferredHeight: 20
            Layout.preferredWidth: 1
            color: Config.alpha(Config.md3.on_surface, 0.075)
        }
        Rectangle {
            id: actionButton

            Accessible.name: root.running ? qsTr("Pause timer") : root.hasStarted ? qsTr("Resume timer") : root.completed ? qsTr("Restart timer") : qsTr("Start timer")
            Accessible.role: Accessible.Button
            Layout.fillHeight: true
            Layout.fillWidth: true
            activeFocusOnTab: true
            border.color: activeFocus ? Config.alpha(root.actionColor, 0.72) : Config.alpha(root.actionColor, actionArea.containsMouse ? 0.38 : 0.24)
            border.width: 1
            color: Config.alpha(root.actionColor, actionArea.pressed ? 0.28 : actionArea.containsMouse ? 0.21 : 0.14)
            radius: height / 2
            scale: actionArea.pressed ? 0.97 : 1

            Behavior on border.color {
                ColorAnimation {
                    duration: 140
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 110
                    easing.type: Easing.OutCubic
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    root.toggleRequested();
                    event.accepted = true;
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: 9

                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 17
                    layer.enabled: true
                    source: Quickshell.iconPath(root.completed ? "view-refresh-symbolic" : root.running ? "media-playback-pause-symbolic" : "media-playback-start-symbolic")
                    width: 17

                    layer.effect: ColorOverlay {
                        color: root.actionColor
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.actionColor
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    renderType: Text.NativeRendering
                    text: root.running ? qsTr("Pause") : root.hasStarted ? qsTr("Resume") : root.completed ? qsTr("Restart") : qsTr("Start")
                }
            }
            MouseArea {
                id: actionArea

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onClicked: {
                    actionButton.forceActiveFocus();
                    root.toggleRequested();
                }
            }
        }
    }
}
