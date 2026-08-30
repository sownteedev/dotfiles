pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "../../"

Item {
    id: root

    readonly property color actionBackground: preparing ? Config.md3.primary_container : completed ? Config.md3.secondary_container : running ? Config.md3.tertiary_container : hasStarted ? Config.md3.primary_container : Config.md3.primary
    readonly property color actionForeground: preparing ? Config.md3.on_primary_container : completed ? Config.md3.on_secondary_container : running ? Config.md3.on_tertiary_container : hasStarted ? Config.md3.on_primary_container : Config.md3.on_primary
    property bool completed: false
    property bool hasStarted: false
    property bool preparing: false
    property bool running: false

    signal resetRequested
    signal toggleRequested

    implicitHeight: 50
    implicitWidth: 244

    RowLayout {
        anchors.fill: parent
        spacing: 8

        Rectangle {
            id: resetButton

            readonly property bool available: root.preparing || root.hasStarted || root.completed

            Accessible.name: qsTr("Reset timer")
            Accessible.role: Accessible.Button
            Layout.fillHeight: true
            Layout.preferredWidth: 50
            activeFocusOnTab: available
            border.color: activeFocus ? Config.alpha(Config.md3.primary, 0.72) : "transparent"
            border.width: 1
            color: resetArea.pressed && available ? Config.md3.surface_container_highest : resetArea.containsMouse && available ? Config.md3.surface_container_high : Config.md3.surface_container
            enabled: available
            opacity: available ? 1 : 0.38
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
                height: 19
                layer.enabled: true
                source: Quickshell.iconPath("view-refresh-symbolic")
                width: 19

                layer.effect: ColorOverlay {
                    color: Config.md3.on_surface_variant
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
            id: actionButton

            Accessible.name: root.preparing ? qsTr("Starting timer") : root.running ? qsTr("Pause timer") : root.hasStarted ? qsTr("Resume timer") : root.completed ? qsTr("Restart timer") : qsTr("Start timer")
            Accessible.role: Accessible.Button
            Layout.fillHeight: true
            Layout.fillWidth: true
            activeFocusOnTab: !root.preparing
            border.color: activeFocus ? Config.alpha(root.actionForeground, 0.72) : "transparent"
            border.width: 1
            color: root.actionBackground
            enabled: !root.preparing
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
                if (actionButton.enabled && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
                    root.toggleRequested();
                    event.accepted = true;
                }
            }

            Rectangle {
                anchors.fill: parent
                color: actionArea.pressed ? Config.alpha(root.actionForeground, 0.12) : actionArea.containsMouse ? Config.alpha(root.actionForeground, 0.07) : "transparent"
                radius: parent.radius

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
            }
            Row {
                anchors.centerIn: parent
                spacing: 9

                IconImage {
                    anchors.verticalCenter: parent.verticalCenter
                    height: 17
                    layer.enabled: true
                    source: Quickshell.iconPath(root.preparing ? "preferences-system-time-symbolic" : root.completed ? "view-refresh-symbolic" : root.running ? "media-playback-pause-symbolic" : "media-playback-start-symbolic")
                    width: 17

                    layer.effect: ColorOverlay {
                        color: root.actionForeground
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.actionForeground
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    text: root.preparing ? qsTr("Starting…") : root.running ? qsTr("Pause") : root.hasStarted ? qsTr("Resume") : root.completed ? qsTr("Restart") : qsTr("Start")
                }
            }
            MouseArea {
                id: actionArea

                anchors.fill: parent
                cursorShape: actionButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: actionButton.enabled
                hoverEnabled: true

                onClicked: {
                    actionButton.forceActiveFocus();
                    root.toggleRequested();
                }
            }
        }
    }
}
