import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "../../"

MouseArea {
    id: rootButton

    property string iconName: ""
    property int index: 0

    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true
    implicitHeight: 70
    implicitWidth: 70
    opacity: powerWindow.menuOpen ? 1.0 : 0.0

    Behavior on opacity {
        NumberAnimation {
            duration: 300 + rootButton.index * 50
        }
    }

    // Stagger animation based on index
    transform: Translate {
        y: powerWindow.menuOpen ? 0 : 20

        Behavior on y {
            NumberAnimation {
                duration: 400 + rootButton.index * 50
                easing.type: Easing.OutBack
            }
        }
    }

    onClicked: {
        powerWindow.executeAction(index);
    }
    onContainsMouseChanged: {
        if (containsMouse) {
            contentRoot.activeIndex = index;
        }
    }

    Rectangle {
        id: bgRect

        property bool isActive: contentRoot.activeIndex === rootButton.index

        anchors.fill: parent
        border.color: isActive ? Config.alpha(Config.md3.surface_container_high, 0.8) : Config.alpha(Config.md3.surface, 0.8)
        border.width: 1
        color: isActive ? Config.alpha(Config.md3.surface_container, 0.8) : Config.alpha(Config.md3.background, 0.8)
        layer.enabled: isActive
        radius: width / 2
        scale: isActive ? 1.15 : 1.0

        Behavior on border.color {
            ColorAnimation {
                duration: 150
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
        layer.effect: DropShadow {
            color: "#80000000"
            radius: 12
            samples: 25
            transparentBorder: true
        }
        Behavior on scale {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutBack
            }
        }

        IconImage {
            id: iconImg

            property color overlayColor: bgRect.isActive ? Config.md3.on_surface : Config.md3.on_surface

            anchors.centerIn: parent
            height: 35
            layer.enabled: true
            scale: bgRect.isActive ? 1.1 : 1.0
            source: Quickshell.iconPath(rootButton.iconName)
            width: 35

            layer.effect: ColorOverlay {
                color: iconImg.overlayColor
            }
            Behavior on overlayColor {
                ColorAnimation {
                    duration: 150
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutBack
                }
            }
        }
    }
}
