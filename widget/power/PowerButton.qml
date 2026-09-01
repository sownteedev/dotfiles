pragma ComponentBehavior: Bound

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
    height: 70
    hoverEnabled: true
    opacity: menuOpen ? 1 : 0
    scale: pressed ? 0.95 : 1
    width: height

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

    onClicked: triggered()

    IconImage {
        id: icon

        anchors.centerIn: parent
        height: 36
        layer.enabled: true
        opacity: rootButton.active ? 1 : (rootButton.containsMouse ? 0.96 : 0.68)
        source: Quickshell.iconPath(rootButton.iconName)
        width: 36

        layer.effect: ColorOverlay {
            color: rootButton.active ? rootButton.accent : Config.md3.on_surface_variant

            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Config.animationDuration(140)
            }
        }
    }
}
