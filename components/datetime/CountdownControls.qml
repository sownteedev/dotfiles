import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "../../"

RowLayout {
    id: root

    property bool completed: false
    property bool hasStarted: false
    property bool running: false

    signal resetRequested
    signal toggleRequested

    spacing: 10

    Rectangle {
        Layout.preferredHeight: 50
        Layout.preferredWidth: 50
        border.color: Config.alpha(Config.md3.on_surface, resetArea.containsMouse ? 0.14 : 0.07)
        border.width: 1
        color: Config.alpha(Config.md3.on_surface, resetArea.pressed ? 0.12 : (resetArea.containsMouse ? 0.085 : 0.045))
        radius: 25
        scale: resetArea.pressed ? 0.94 : 1

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

        IconImage {
            anchors.centerIn: parent
            height: 19
            layer.enabled: true
            source: Quickshell.iconPath("view-refresh-symbolic")
            width: 19

            layer.effect: ColorOverlay {
                color: Config.alpha(Config.md3.on_surface, 0.8)
            }
        }
        MouseArea {
            id: resetArea

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: root.resetRequested()
        }
    }
    Rectangle {
        Layout.preferredHeight: 50
        Layout.preferredWidth: 154
        border.color: Config.alpha(Config.md3.on_surface, startArea.containsMouse ? 0.32 : 0.16)
        border.width: 1
        color: startArea.pressed ? Qt.darker(Config.md3.primary, 1.12) : (startArea.containsMouse ? Qt.lighter(Config.md3.primary, 1.05) : Config.md3.primary)
        radius: 25
        scale: startArea.pressed ? 0.97 : 1

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

        Row {
            anchors.centerIn: parent
            spacing: 10

            IconImage {
                height: 19
                layer.enabled: true
                source: Quickshell.iconPath(root.running ? "media-playback-pause-symbolic" : "media-playback-start-symbolic")
                width: 19

                layer.effect: ColorOverlay {
                    color: Config.md3.background
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Config.md3.background
                font.family: Config.fontName
                font.pixelSize: 15
                font.weight: Font.Bold
                renderType: Text.NativeRendering
                text: root.running ? "Pause" : (root.hasStarted ? "Resume" : (root.completed ? "Restart" : "Start"))
            }
        }
        MouseArea {
            id: startArea

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: root.toggleRequested()
        }
    }
    Item {
        Layout.preferredHeight: 50
        Layout.preferredWidth: 50
    }
}
