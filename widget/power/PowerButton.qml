import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "../../"

MouseArea {
    id: rootButton

    required property color accent
    required property int actionIndex
    required property bool active
    required property string iconName
    required property string label
    required property bool menuOpen

    signal triggered

    cursorShape: Qt.PointingHandCursor
    height: 64
    hoverEnabled: true
    opacity: menuOpen ? 1 : 0
    scale: pressed ? 0.95 : 1
    width: active ? 148 : 62

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation {
                duration: rootButton.menuOpen ? rootButton.actionIndex * 20 : 0
            }
            NumberAnimation {
                duration: rootButton.menuOpen ? 190 : 90
                easing.type: Easing.OutCubic
            }
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: rootButton.pressed ? 65 : 170
            easing.type: rootButton.pressed ? Easing.OutQuad : Easing.OutCubic
        }
    }
    transform: Translate {
        y: rootButton.menuOpen ? 0 : 14

        Behavior on y {
            SequentialAnimation {
                PauseAnimation {
                    duration: rootButton.menuOpen ? rootButton.actionIndex * 20 : 0
                }
                NumberAnimation {
                    duration: rootButton.menuOpen ? 280 : 120
                    easing.overshoot: 1.08
                    easing.type: rootButton.menuOpen ? Easing.OutBack : Easing.InCubic
                }
            }
        }
    }
    Behavior on width {
        NumberAnimation {
            duration: 260
            easing.type: Easing.InOutCubic
        }
    }

    onClicked: triggered()

    Rectangle {
        id: selectionSurface

        anchors.fill: parent
        border.color: Config.alpha(rootButton.accent, rootButton.active ? 0.62 : 0)
        border.width: 1
        color: Config.alpha(rootButton.accent, rootButton.active ? 0.24 : 0)
        layer.enabled: true
        radius: height / 2

        Behavior on border.color {
            ColorAnimation {
                duration: 210
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 210
            }
        }
        layer.effect: DropShadow {
            color: Config.alpha(rootButton.accent, rootButton.active ? 0.28 : 0)
            horizontalOffset: 0
            radius: 13
            samples: 17
            transparentBorder: true
            verticalOffset: 2
        }
    }
    Row {
        anchors.centerIn: parent
        spacing: 10

        IconImage {
            id: icon

            anchors.verticalCenter: parent.verticalCenter
            height: width
            layer.enabled: true
            opacity: rootButton.active ? 1 : (rootButton.containsMouse ? 0.96 : 0.68)
            source: Quickshell.iconPath(rootButton.iconName)
            width: rootButton.active ? 29 : 27

            layer.effect: ColorOverlay {
                color: rootButton.active ? rootButton.accent : Config.md3.on_surface_variant
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: 210
                    easing.type: Easing.OutCubic
                }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            color: Config.md3.on_surface
            font.family: Config.fontFamily
            font.pixelSize: 16
            font.weight: Font.DemiBold
            opacity: rootButton.active ? 1 : 0
            text: rootButton.label
            width: rootButton.active ? implicitWidth : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: rootButton.active ? 170 : 70
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: 230
                    easing.type: Easing.InOutCubic
                }
            }
        }
    }
}
