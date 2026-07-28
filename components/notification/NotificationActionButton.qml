import QtQuick
import "../../"

Rectangle {
    id: root

    property var action: null
    property real cornerRadius: 11
    property real horizontalPadding: 14
    property color hoverBorderColor: Config.alpha(Config.md3.on_surface, 0.22)
    property color hoverColor: Config.alpha(Config.md3.on_surface, 0.15)
    property string label: action && action.text ? action.text : (action && action.identifier ? action.identifier : "Action")
    property int labelPixelSize: 12
    property int labelWeight: Font.DemiBold
    property real minimumWidth: 80
    property color normalBorderColor: Config.alpha(Config.md3.on_surface, 0.12)
    property color normalColor: Config.alpha(Config.md3.on_surface, 0.09)
    property color pressedColor: Config.alpha(Config.md3.on_surface, 0.20)

    signal clicked

    border.color: pointer.containsMouse ? hoverBorderColor : normalBorderColor
    border.width: 1
    color: pointer.pressed ? pressedColor : (pointer.containsMouse ? hoverColor : normalColor)
    implicitHeight: 36
    implicitWidth: Math.max(minimumWidth, actionLabel.implicitWidth + horizontalPadding * 2)
    radius: Math.min(height / 2, cornerRadius)
    scale: pointer.pressed ? 0.96 : 1

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
    Behavior on scale {
        NumberAnimation {
            duration: 80
        }
    }

    Text {
        id: actionLabel

        anchors.centerIn: parent
        color: Config.md3.on_surface
        elide: Text.ElideRight
        font.family: Config.fontName
        font.pixelSize: root.labelPixelSize
        font.weight: root.labelWeight
        text: root.label
        width: Math.min(implicitWidth, root.width - root.horizontalPadding * 2)
    }
    MouseArea {
        id: pointer

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        onClicked: root.clicked()
    }
}
