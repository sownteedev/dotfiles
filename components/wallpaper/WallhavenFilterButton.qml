import "../../"
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    property color accentColor: Config.md3.secondary_container
    property bool active: false
    property bool expanded: false
    property real fontPixelSize: 12
    readonly property bool hasSwatch: swatchColor.a > 0
    property string iconName: ""
    required property string label
    property color swatchColor: "transparent"

    signal clicked

    Accessible.name: label
    Accessible.role: Accessible.Button
    activeFocusOnTab: false
    border.color: "transparent"
    border.width: 0
    color: mouse.pressed ? Config.alpha(Config.md3.on_surface, Md3.state.pressed) : (active || expanded ? accentColor : (mouse.containsMouse ? Config.alpha(Config.md3.on_surface, Md3.state.hover) : "transparent"))
    implicitHeight: 34
    implicitWidth: content.implicitWidth + 18
    radius: Md3.shape.full

    Behavior on color {
        ColorAnimation {
            duration: Config.animationDuration(Md3.motion.short2)
        }
    }

    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Row {
        id: content

        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            border.color: Config.alpha(Config.md3.on_surface, 0.2)
            border.width: 1
            color: root.swatchColor
            height: 12
            radius: 4
            visible: root.hasSwatch
            width: 12
        }
        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            height: 14
            layer.enabled: true
            source: Quickshell.iconPath(root.iconName)
            visible: root.iconName !== ""
            width: 14

            layer.effect: ColorOverlay {
                color: root.active || root.expanded ? Config.md3.on_secondary_container : Config.md3.on_surface_variant
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: root.active || root.expanded ? Config.md3.on_secondary_container : Config.md3.on_surface_variant
            font.family: Config.fontName
            font.pixelSize: root.fontPixelSize
            font.weight: Font.DemiBold
            text: root.label
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: root.active || root.expanded ? Config.md3.on_secondary_container : Config.md3.on_surface_variant
            font.family: Config.fontName
            font.pixelSize: 12
            rotation: root.expanded ? 180 : 0
            text: "⌄"
            visible: root.expanded || root.iconName === ""

            Behavior on rotation {
                RotationAnimator {
                    duration: Config.animationDuration(Md3.motion.short3)
                    easing.type: Md3.motion.emphasizedDecelerate
                }
            }
        }
    }
    MouseArea {
        id: mouse

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        onClicked: root.clicked()
    }
}
