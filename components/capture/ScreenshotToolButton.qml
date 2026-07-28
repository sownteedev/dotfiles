import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "../../"

Rectangle {
    id: root

    required property string selectedTool
    required property var toolData

    signal selected(string tool)

    color: selectedTool === toolData.tool ? Config.md3.tertiary : pointer.containsMouse ? Config.md3.surface_container_high : Config.md3.surface_container
    implicitHeight: 42
    implicitWidth: 48
    radius: 11

    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    Text {
        anchors.centerIn: parent
        color: root.selectedTool === root.toolData.tool ? Config.md3.background : Config.md3.on_surface
        font.family: Config.fontName
        font.pixelSize: root.toolData.fontSize || 22
        font.weight: Font.Bold
        text: root.toolData.glyph || ""
        visible: !root.toolData.iconName
    }
    IconImage {
        anchors.centerIn: parent
        height: 23
        layer.enabled: visible
        source: visible ? Quickshell.iconPath(root.toolData.iconName, "edit-clear-symbolic") : ""
        visible: !!root.toolData.iconName
        width: 23

        layer.effect: ColorOverlay {
            color: root.selectedTool === root.toolData.tool ? Config.md3.background : Config.md3.on_surface
        }
    }
    MouseArea {
        id: pointer

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        onClicked: root.selected(root.toolData.tool)
    }
}
