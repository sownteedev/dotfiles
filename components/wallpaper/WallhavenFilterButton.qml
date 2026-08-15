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
    activeFocusOnTab: true
    border.color: activeFocus ? Config.alpha(Config.md3.primary, 0.72) : "transparent"
    border.width: 1
    color: mouse.pressed ? Config.alpha(Config.md3.on_surface, 0.14) : (active || expanded ? accentColor : (mouse.containsMouse || activeFocus ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent"))
    implicitHeight: 34
    implicitWidth: content.implicitWidth + 18
    radius: 9

    Behavior on color {
        ColorAnimation {
            duration: 120
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
                    duration: 150
                    easing.type: Easing.OutCubic
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
