import "../../../" // for Config
import "../../../components"
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: buttonRoot

    property bool active: false
    property color activeColor: Config.md3.primary
    property string iconName: ""

    signal clicked

    height: 54
    width: 54

    // Smooth shadow that transitions in radius, offset, and color
    DropShadow {
        id: shadow

        anchors.fill: btnRect
        color: mouseArea.pressed ? (buttonRoot.active ? Config.alpha(buttonRoot.activeColor, 0.2) : "#60000000") : (buttonRoot.active ? Config.alpha(buttonRoot.activeColor, 0.45) : "#90000000")
        horizontalOffset: 0
        radius: mouseArea.pressed ? 3 : (buttonRoot.active ? 12 : 6)
        samples: 25
        source: btnRect
        verticalOffset: mouseArea.pressed ? 1 : (buttonRoot.active ? 4 : 2)

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
        Behavior on radius {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }
        Behavior on verticalOffset {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }
    }
    Rectangle {
        id: btnRect

        anchors.fill: parent
        color: buttonRoot.active ? "transparent" : (mouseArea.pressed ? Config.md3.surface_container_highest : (mouseArea.containsMouse ? Config.md3.surface_container_high : Config.md3.surface_container))
        
        radius: buttonRoot.active ? 16 : 27
        scale: mouseArea.pressed ? 0.93 : 1.0
        
        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: maskRect
            }
            
            // Background tint when active (behind the liquid)
            Rectangle {
                anchors.fill: parent
                color: buttonRoot.active ? (mouseArea.pressed ? Config.alpha(buttonRoot.activeColor, 0.2) : (mouseArea.containsMouse ? Config.alpha(buttonRoot.activeColor, 0.15) : Config.alpha(buttonRoot.activeColor, 0.1))) : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            AnimatedLiquid {
                anchors.fill: parent
                active: buttonRoot.active
                color: mouseArea.pressed ? Config.alpha(buttonRoot.activeColor, 0.85) : Config.alpha(buttonRoot.activeColor, 1.0)
            }
        }
        
        Rectangle {
            id: maskRect
            anchors.fill: parent
            radius: btnRect.radius
            color: "black"
            visible: false
        }

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
        Behavior on radius {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutBack
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutQuad
            }
        }

        IconImage {
            id: iconImg

            anchors.centerIn: parent
            height: 24
            layer.enabled: true
            // Bounce scale when active
            scale: buttonRoot.active ? 1.05 : 0.9
            source: {
                var n = buttonRoot.iconName;
                if (!n)
                    return "";

                if (n.startsWith("file://") || n.startsWith("/"))
                    return n;

                var p = Quickshell.iconPath(n);
                return p !== "" ? p : "";
            }
            width: 24

            layer.effect: ColorOverlay {
                color: buttonRoot.active ? Config.md3.on_primary : Config.md3.on_surface

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutBack
                }
            }
        }
        MouseArea {
            id: mouseArea

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: buttonRoot.clicked()
        }
    }
}
