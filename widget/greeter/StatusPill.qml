import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    property color accentColor: GreeterTheme.primary
    property string icon: ""
    property string iconName: ""
    property real scaleFactor: 1

    implicitHeight: 32 * root.scaleFactor
    implicitWidth: 32 * root.scaleFactor

    Text {
        anchors.centerIn: parent
        color: root.accentColor
        font.family: "Symbols Nerd Font"
        font.pixelSize: 23 * root.scaleFactor
        text: root.icon
        visible: root.iconName === ""
    }
    IconImage {
        anchors.centerIn: parent
        height: 23 * root.scaleFactor
        layer.enabled: visible
        source: root.iconName === "" ? "" : Quickshell.iconPath(root.iconName)
        visible: root.iconName !== ""
        width: height

        layer.effect: ColorOverlay {
            color: root.accentColor
        }
    }
}
