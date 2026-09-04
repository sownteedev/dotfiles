import "../../"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Widgets

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
    ToolTip {
        id: actionToolTip

        bottomPadding: 8
        delay: 320
        leftPadding: 11
        margins: 8
        popupType: Popup.Item
        rightPadding: 11
        text: root.text
        timeout: 3200
        topPadding: 8
        visible: root.iconOnly && mouse.containsMouse && root.text !== ""
        x: Math.round((root.width - width) / 2)
        y: root.height + 7

        background: Rectangle {
            color: Config.md3.surface_container_highest
            radius: 10
        }
        contentItem: Text {
            color: Config.md3.on_surface
            font.family: Config.fontName
            font.pixelSize: 12
            font.weight: Font.Medium
            text: actionToolTip.text
        }
    }
}
