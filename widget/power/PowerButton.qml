import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
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

    cursorShape: Qt.PointingHandCursor
    height: 64
    hoverEnabled: true
    opacity: menuOpen ? 1 : 0
    scale: pressed ? 0.95 : 1
    width: active ? Math.max(62, 28 + (labelItem.implicitWidth > 0 ? 10 + labelItem.implicitWidth : 0) + 36) : 62

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

    ShellShadow {
        active: rootButton.active
        componentShadow: true
        cornerRadius: selectionSurface.radius
        target: selectionSurface
    }
    Rectangle {
        id: selectionSurface

        anchors.fill: parent
        border.color: Config.alpha(rootButton.accent, rootButton.active ? 0.62 : 0)
        border.width: 1
        color: Config.alpha(rootButton.accent, rootButton.active ? 0.24 : 0)
        radius: height / 2

        Behavior on border.color {
            ColorAnimation {
                duration: 180
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 180
            }
        }
    }
    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: 10

        IconImage {
            id: icon

            anchors.verticalCenter: parent.verticalCenter
            height: 28
            layer.enabled: true
            opacity: rootButton.active ? 1 : (rootButton.containsMouse ? 0.96 : 0.68)
            source: Quickshell.iconPath(rootButton.iconName)
            width: 28

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
                    duration: 160
                }
            }
        }
        Item {
            id: labelItem

            anchors.verticalCenter: parent.verticalCenter
            clip: true
            height: buttonLabel.implicitHeight
            implicitWidth: buttonLabel.implicitWidth
            opacity: rootButton.active ? 1 : 0
            width: rootButton.active ? buttonLabel.implicitWidth : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: rootButton.active ? 200 : 70
                    easing.type: Easing.InOutCubic
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.InOutCubic
                }
            }

            Text {
                id: buttonLabel

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 16
                font.weight: Font.DemiBold
                text: rootButton.label
            }
        }
    }
}
