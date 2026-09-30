pragma ComponentBehavior: Bound

import QtQuick
import "../../"
import "../../components"

MouseArea {
    id: rootButton

    required property color accent
    required property int actionIndex
    required property bool active
    required property string iconName
    required property string label
    required property bool menuOpen

    signal triggered

    Accessible.name: label
    Accessible.role: Accessible.Button
    cursorShape: Qt.PointingHandCursor
    height: 70
    hoverEnabled: true
    opacity: menuOpen ? 1 : 0
    scale: pressed ? 0.95 : 1
    width: height

    Behavior on opacity {
        SequentialAnimation {
            PauseAnimation {
                duration: Config.animationDuration(rootButton.menuOpen ? rootButton.actionIndex * 20 : 0)
            }
            Md3NumberAnimation {
                role: rootButton.menuOpen ? "enter" : "exit"
            }
        }
    }
    Behavior on scale {
        Md3NumberAnimation {
            role: rootButton.pressed ? "state" : "spatial"
        }
    }
    transform: Translate {
        y: rootButton.menuOpen ? 0 : 14

        Behavior on y {
            SequentialAnimation {
                PauseAnimation {
                    duration: Config.animationDuration(rootButton.menuOpen ? rootButton.actionIndex * 20 : 0)
                }
                Md3NumberAnimation {
                    role: rootButton.menuOpen ? "spatial" : "exit"
                }
            }
        }
    }

    Accessible.onPressAction: {
        if (rootButton.enabled && rootButton.menuOpen)
            rootButton.triggered();
    }
    onClicked: triggered()

    Md3Icon {
        id: icon

        anchors.centerIn: parent
        color: rootButton.active ? rootButton.accent : Config.md3.on_surface_variant
        filled: rootButton.active
        name: rootButton.iconName
        opacity: rootButton.active ? 1 : (rootButton.containsMouse ? 0.96 : 0.68)
        size: 38

        Behavior on color {
            Md3ColorAnimation {
                role: "state"
            }
        }
        Behavior on opacity {
            Md3NumberAnimation {
                role: "state"
            }
        }
    }
}
