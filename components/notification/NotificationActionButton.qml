import QtQuick
import "../../"

Rectangle {
    id: root

    property var action: null
    property real cornerRadius: Md3.shape.full
    property real horizontalPadding: 14
    property color hoverBorderColor: Config.alpha(Config.md3.on_surface, 0.22)
    property color hoverColor: Config.alpha(Config.md3.on_surface, 0.15)
    property string label: action && action.text ? action.text : (action && action.identifier ? action.identifier : qsTr("Action"))
    property int labelPixelSize: Md3.typeScale.labelLarge.size
    property int labelWeight: Md3.typeScale.labelLarge.weight
    property real minimumWidth: 80
    property color normalBorderColor: Config.alpha(Config.md3.on_surface, 0.12)
    property color normalColor: Config.alpha(Config.md3.on_surface, 0.09)
    property color pressedColor: Config.alpha(Config.md3.on_surface, 0.20)

    signal clicked

    Accessible.name: root.label
    Accessible.role: Accessible.Button
    activeFocusOnTab: false
    border.color: pointer.containsMouse ? hoverBorderColor : normalBorderColor
    border.width: 1
    color: pointer.pressed ? pressedColor : (pointer.containsMouse ? hoverColor : normalColor)
    implicitHeight: 36
    implicitWidth: Math.max(minimumWidth, actionLabel.implicitWidth + horizontalPadding * 2)
    radius: Math.min(height / 2, Math.max(cornerRadius, Md3.shape.small))
    scale: pointer.pressed ? 0.96 : 1

    Behavior on border.color {
        ColorAnimation {
            duration: Config.animationDuration(Md3.motion.short2)
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: Config.animationDuration(Md3.motion.short2)
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Config.animationDuration(Md3.motion.short1)
        }
    }

    Accessible.onPressAction: {
        if (root.enabled)
            root.clicked();
    }
    Keys.onReturnPressed: event => {
        if (root.enabled)
            root.clicked();
        event.accepted = true;
    }
    Keys.onSpacePressed: event => {
        if (root.enabled)
            root.clicked();
        event.accepted = true;
    }

    Text {
        id: actionLabel

        anchors.centerIn: parent
        color: root.enabled ? Config.md3.on_surface : Config.alpha(Config.md3.on_surface, Md3.state.disabledContent)
        elide: Text.ElideRight
        font.family: Config.fontName
        font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
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
