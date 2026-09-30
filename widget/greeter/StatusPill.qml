pragma ComponentBehavior: Bound

import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    property color accentColor: GreeterTheme.surfaceVariantText
    property string icon: ""
    property string iconName: ""
    property real scaleFactor: 1
    property string text: ""

    Accessible.ignored: true
    border.color: GreeterTheme.withAlpha(GreeterTheme.outlineVariant, 0.35)
    border.width: 1
    color: GreeterTheme.withAlpha(GreeterTheme.surfaceContainerHigh, 0.78)
    implicitHeight: Math.round(36 * root.scaleFactor)
    implicitWidth: contentRow.implicitWidth + Math.round(24 * root.scaleFactor)
    radius: height / 2

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: Math.round(7 * root.scaleFactor)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: root.accentColor
            font.family: "Symbols Nerd Font"
            font.pixelSize: Math.round(15 * root.scaleFactor)
            text: root.icon
            visible: root.icon !== "" && root.iconName === ""
        }
        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            height: Math.round(15 * root.scaleFactor)
            layer.enabled: visible
            source: root.iconName === "" ? "" : Quickshell.iconPath(root.iconName)
            visible: root.iconName !== ""
            width: height

            layer.effect: ColorOverlay {
                color: root.accentColor
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: GreeterTheme.surfaceText
            font.family: "Inter Variable"
            font.pixelSize: Math.round(12 * root.scaleFactor)
            font.weight: Font.Medium
            text: root.text
            visible: root.text !== ""
        }
    }
}
