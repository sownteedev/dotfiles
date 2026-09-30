import "../../"
import QtQuick

Rectangle {
    id: root

    property color accentColor: Config.md3.secondary_container
    property bool external: false
    property real fontPixelSize: 12
    required property string label
    property bool selected: false
    property color selectedTextColor: Config.md3.on_secondary_container

    signal clicked

    Accessible.name: label
    Accessible.role: Accessible.Button
    activeFocusOnTab: false
    border.color: "transparent"
    border.width: 0
    color: mouse.pressed ? Config.alpha(Config.md3.on_surface, Md3.state.pressed) : (selected ? accentColor : (mouse.containsMouse ? Config.alpha(Config.md3.on_surface, Md3.state.hover) : "transparent"))
    implicitHeight: 32
    implicitWidth: content.implicitWidth + 20
    opacity: enabled ? 1 : 0.38
    radius: Md3.shape.small

    Behavior on color {
        ColorAnimation {
            duration: Config.animationDuration(Md3.motion.short2)
        }
    }

    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Row {
        id: content

        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: root.selected ? root.selectedTextColor : Config.md3.on_surface_variant
            font.family: Config.fontName
            font.letterSpacing: Md3.typeScale.labelMedium.letterSpacing
            font.pixelSize: root.fontPixelSize
            font.weight: root.selected ? Font.DemiBold : Font.Medium
            text: root.label
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: Config.md3.on_surface_variant
            font.family: Config.fontName
            font.pixelSize: 12
            text: "↗"
            visible: root.external
        }
    }
    MouseArea {
        id: mouse

        anchors.fill: parent
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled
        hoverEnabled: true

        onClicked: root.clicked()
    }
}
