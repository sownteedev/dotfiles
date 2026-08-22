import "../../"
import QtQuick
import Quickshell
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root

    property string iconName: ""
    property bool iconOnly: false
    property bool primary: false
    property string text: ""

    signal clicked

    Accessible.name: text
    Accessible.role: Accessible.Button
    activeFocusOnTab: enabled
    border.color: activeFocus ? Config.alpha(primary ? Config.md3.on_primary : Config.md3.primary, 0.72) : "transparent"
    border.width: 1
    color: primary ? (mouse.containsMouse ? Config.alpha(Config.md3.primary, 0.86) : Config.md3.primary) : (mouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.09) : Config.alpha(Config.md3.on_surface, 0.055))
    implicitHeight: 44
    implicitWidth: iconOnly ? implicitHeight : content.implicitWidth + 34
    opacity: enabled ? 1 : 0.42
    radius: 13
    z: mouse.containsMouse ? 1 : 0

    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: 120
        }
    }

    Accessible.onPressAction: {
        if (root.enabled)
            root.clicked();
    }
    Keys.onReturnPressed: event => {
        root.clicked();
        event.accepted = true;
    }
    Keys.onSpacePressed: event => {
        root.clicked();
        event.accepted = true;
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: 10

        IconImage {
            anchors.verticalCenter: parent.verticalCenter
            height: 19
            layer.enabled: visible
            source: root.iconName === "" ? "" : Quickshell.iconPath(root.iconName)
            visible: root.iconName !== ""
            width: 19

            layer.effect: ColorOverlay {
                color: root.primary ? Config.md3.on_primary : Config.md3.on_surface
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: root.primary ? Config.md3.on_primary : Config.md3.on_surface
            font.family: Config.fontName
            font.pixelSize: 15
            font.weight: Font.DemiBold
            text: root.text
            visible: !root.iconOnly && text !== ""
        }
    }
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 7
        color: Config.md3.surface_container_high
        height: 30
        radius: 9
        visible: root.iconOnly && mouse.containsMouse && root.text !== ""
        width: tooltipText.implicitWidth + 18
        z: 20

        Text {
            id: tooltipText

            anchors.centerIn: parent
            color: Config.md3.on_surface
            font.family: Config.fontName
            font.pixelSize: 12
            font.weight: Font.Medium
            text: root.text
        }
    }
    MouseArea {
        id: mouse

        anchors.fill: parent
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled
        hoverEnabled: true

        onClicked: {
            root.forceActiveFocus();
            root.clicked();
        }
    }
}
