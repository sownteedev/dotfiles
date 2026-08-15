import "../../"
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    property string fallbackIconName: ""
    required property string iconName
    required property string label

    signal clicked

    Accessible.name: label
    Accessible.role: Accessible.Button
    activeFocusOnTab: true
    border.color: activeFocus ? Config.alpha(Config.md3.primary, 0.7) : Config.alpha(Config.md3.on_surface, 0.12)
    border.width: 1
    color: sourceMouse.pressed ? Config.md3.primary_container : (sourceMouse.containsMouse || activeFocus ? Config.alpha(Config.md3.primary_container, 0.72) : Config.alpha(Config.md3.surface, 0.88))
    implicitHeight: 44
    implicitWidth: Math.max(112, content.implicitWidth + 28)
    radius: height / 2

    Behavior on border.color {
        ColorAnimation {
            duration: 120
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    Keys.onEnterPressed: root.clicked()
    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Row {
        id: content

        anchors.centerIn: parent
        spacing: 7

        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            height: 17
            layer.enabled: true
            source: Quickshell.iconPath(root.iconName, root.fallbackIconName)
            width: 17

            layer.effect: ColorOverlay {
                color: sourceMouse.containsMouse || root.activeFocus ? Config.md3.on_primary_container : Config.md3.on_surface_variant
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: sourceMouse.containsMouse || root.activeFocus ? Config.md3.on_primary_container : Config.md3.on_surface_variant
            font.family: Config.fontName
            font.pixelSize: 11
            font.weight: Font.DemiBold
            text: root.label
        }
    }
    MouseArea {
        id: sourceMouse

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        onClicked: root.clicked()
    }
}
