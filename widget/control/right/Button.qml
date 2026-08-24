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
    property string iconFontFamily: "Material Design Icons Desktop"
    property string iconGlyph: ""
    property string iconName: ""

    signal clicked

    height: 54
    width: 54

    ShellShadow {
        componentShadow: true
        cornerRadius: btnRect.radius
        scale: btnRect.scale
        target: btnRect
    }
    Rectangle {
        id: btnRect

        anchors.fill: parent
        color: buttonRoot.active ? "transparent" : (mouseArea.pressed ? Config.alpha(Config.md3.on_surface, 0.2) : (mouseArea.containsMouse ? Config.alpha(Config.md3.on_surface, 0.14) : Config.alpha(Config.md3.on_surface, 0.09)))
        radius: buttonRoot.active ? 16 : 27
        scale: mouseArea.pressed ? 0.93 : 1.0

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

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
            AnimatedLiquid {
                active: buttonRoot.active
                anchors.fill: parent
                color: mouseArea.pressed ? Config.alpha(buttonRoot.activeColor, 0.85) : Config.alpha(buttonRoot.activeColor, 1.0)
            }
        }
        Rectangle {
            id: maskRect

            anchors.fill: parent
            color: "black"
            radius: btnRect.radius
            visible: false
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
            visible: buttonRoot.iconGlyph === ""
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
        Text {
            anchors.centerIn: parent
            color: buttonRoot.active ? Config.md3.on_primary : Config.md3.on_surface
            font.family: buttonRoot.iconFontFamily
            font.pixelSize: 25
            renderType: Text.NativeRendering
            scale: buttonRoot.active ? 1.05 : 0.9
            text: buttonRoot.iconGlyph
            visible: buttonRoot.iconGlyph !== ""

            Behavior on color {
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
        MouseArea {
            id: mouseArea

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: buttonRoot.clicked()
        }
    }
}
