import "../../"
import QtQuick
import Quickshell
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root

    property string iconName: ""
    property bool primary: false
    property string text: ""

    signal clicked

    color: primary ? (mouse.containsMouse ? Config.alpha(Config.md3.primary, 0.86) : Config.md3.primary) : (mouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.09) : Config.alpha(Config.md3.on_surface, 0.055))
    implicitHeight: 44
    implicitWidth: content.implicitWidth + 34
    radius: 13

    Behavior on color {
        ColorAnimation {
            duration: 140
        }
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
