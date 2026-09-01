import "../../"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    property bool active: false
    property bool compact: false
    property bool dense: false
    property bool expandable: false
    property bool expanded: false
    property color iconColor: Config.md3.primary
    property string iconName: ""
    readonly property real iconSize: indented ? 18 : 22
    readonly property real iconViewportSize: iconSize + 4
    property bool indented: false
    property real selectionProgress: active ? 1 : 0
    property string text: ""

    signal clicked

    color: mouse.containsMouse && !active ? Config.alpha(root.iconColor, 0.075) : "transparent"
    implicitHeight: compact ? 40 : dense ? 44 : 50
    radius: 14
    scale: mouse.pressed ? 0.985 : 1

    Behavior on color {
        ColorAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
        }
    }
    Behavior on selectionProgress {
        NumberAnimation {
            duration: 240
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Config.alpha(root.iconColor, 0.17)
        opacity: root.selectionProgress
        radius: root.radius
        scale: 0.9 + root.selectionProgress * 0.1
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.compact ? (root.width - root.iconViewportSize) / 2 : (root.indented ? 26 : 14)
        anchors.rightMargin: root.compact ? 0 : 14
        spacing: root.indented ? 11 : 13

        transform: Translate {
            x: root.compact ? 0 : root.selectionProgress * 3
        }

        Item {
            Layout.preferredHeight: root.iconViewportSize
            Layout.preferredWidth: root.iconViewportSize
            layer.enabled: visible
            visible: root.iconName !== ""

            layer.effect: ColorOverlay {
                color: root.active ? root.iconColor : Config.alpha(root.iconColor, root.indented ? 0.66 : 0.82)
            }

            IconImage {
                anchors.centerIn: parent
                height: root.iconSize
                source: Quickshell.iconPath(root.iconName)
                width: root.iconSize
            }
        }
        Text {
            Layout.fillWidth: true
            color: root.active ? root.iconColor : Config.md3.on_surface
            font.family: Config.fontName
            font.pixelSize: root.dense ? 14 : 16
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
    ToolTip {
        id: compactToolTip

        bottomPadding: 7
        delay: 320
        leftPadding: 10
        rightPadding: 10
        text: root.text
        timeout: 2400
        topPadding: 7
        visible: root.compact && mouse.containsMouse && root.text !== ""
        x: root.width + 8
        y: (root.height - height) / 2

        background: Rectangle {
            border.color: Config.alpha(Config.md3.outline, 0.18)
            border.width: 1
            color: Config.md3.surface_container_highest
            radius: 10
        }
        contentItem: Text {
            color: Config.md3.on_surface
            font.family: Config.fontName
            font.pixelSize: 12
            font.weight: Font.Medium
            text: compactToolTip.text
        }
    }
}
