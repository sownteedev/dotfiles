import "../../"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    property bool active: false
    property bool compact: false
    property bool dense: false
    property bool expanded: false
    property bool expandable: false
    property bool indented: false
    property color iconColor: Config.md3.primary
    property string iconName: ""
    property string text: ""

    signal clicked()

    color: active ? Config.alpha(root.iconColor, 0.17) : (mouse.containsMouse ? Config.alpha(root.iconColor, 0.08) : "transparent")
    implicitHeight: dense ? 44 : 50
    radius: 14

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.compact ? (root.width - 22) / 2 : (root.indented ? 28 : 16)
        anchors.rightMargin: root.compact ? 0 : 14
        spacing: root.indented ? 11 : 13

        IconImage {
            Layout.preferredHeight: root.indented ? 18 : 22
            Layout.preferredWidth: root.indented ? 18 : 22
            height: 22
            layer.enabled: true
            layer.effect: ColorOverlay {
                color: root.active ? root.iconColor : Config.alpha(root.iconColor, root.indented ? 0.66 : 0.82)
            }
            source: Quickshell.iconPath(root.iconName)
            visible: root.iconName !== ""
            width: 22
        }

        Text {
            Layout.fillWidth: true
            color: root.active ? root.iconColor : Config.md3.on_surface
            font.family: Config.fontName
            font.pixelSize: root.dense ? 15 : 17
            font.weight: root.active ? Font.DemiBold : Font.Medium
            text: root.text
            visible: !root.compact
        }

        Text {
            color: root.active ? root.iconColor : Config.alpha(root.iconColor, 0.7)
            font.family: Config.fontName
            font.pixelSize: 16
            text: root.expanded ? "⌄" : "›"
            visible: root.expandable && !root.compact
        }

    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: root.clicked()
    }

    Behavior on color {
        ColorAnimation {
            duration: 140
        }

    }

}
