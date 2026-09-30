import "../../../" // for Config
import "../../../components"
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: buttonRoot

    property string accessibleName: ""
    property bool active: false
    property color activeColor: Config.md3.primary
    property string iconFontFamily: "Material Design Icons Desktop"
    property string iconGlyph: ""
    property string iconName: ""

    signal clicked

    Accessible.checkable: true
    Accessible.checked: active
    Accessible.name: accessibleName
    Accessible.role: Accessible.Button
    height: 54
    width: 54

    Accessible.onPressAction: {
        if (buttonRoot.enabled)
            buttonRoot.clicked();
    }

    ShellShadow {
        componentShadow: true
        cornerRadius: btnRect.radius
        scale: btnRect.scale
        target: btnRect
    }
    Rectangle {
        id: btnRect

        anchors.fill: parent
        color: buttonRoot.active ? "transparent" : Config.md3.surface_container_high
        radius: Math.min(width / 2, height / 2, buttonRoot.active ? Md3.shape.large : Md3.shape.full)
        scale: mouseArea.pressed ? 0.93 : 1.0

        Behavior on color {
            Md3ColorAnimation {
                role: "state"
            }
        }
        Behavior on radius {
            Md3NumberAnimation {
                role: "transform"
            }
        }
        Behavior on scale {
            Md3NumberAnimation {
                role: "microSpatial"
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Config.alpha(Config.md3.on_surface, mouseArea.pressed ? Md3.state.pressed : mouseArea.containsMouse ? Md3.state.hover : 0)
            radius: parent.radius
            visible: !buttonRoot.active
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
                    Md3ColorAnimation {
                        role: "state"
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
        Md3Icon {
            id: iconImg

            anchors.centerIn: parent
            color: buttonRoot.active ? Config.md3.on_primary : Config.md3.on_surface
            filled: buttonRoot.active
            name: buttonRoot.iconName
            size: 26
            visible: buttonRoot.iconGlyph === ""

            Behavior on color {
                Md3ColorAnimation {
                    role: "state"
                }
            }
        }
        Text {
            anchors.centerIn: parent
            color: buttonRoot.active ? Config.md3.on_primary : Config.md3.on_surface
            font.family: buttonRoot.iconFontFamily
            font.pixelSize: 25
            renderType: Text.NativeRendering
            text: buttonRoot.iconGlyph
            visible: buttonRoot.iconGlyph !== ""

            Behavior on color {
                Md3ColorAnimation {
                    role: "state"
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
