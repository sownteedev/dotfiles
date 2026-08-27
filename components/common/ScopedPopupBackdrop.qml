import QtQuick
import "../.."

Item {
    id: root

    property bool active: false
    property real cornerRadius: 0
    property Item host: null

    signal dismissed

    anchors.fill: parent
    enabled: active
    opacity: active ? 1 : 0
    parent: host
    visible: host !== null && (active || opacity > 0)
    z: 1000

    Behavior on opacity {
        NumberAnimation {
            duration: Config.shellReducedMotion ? 0 : 140
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Config.alpha(Config.md3.scrim, Config.lightTheme ? 0.1 : 0.15)
        radius: root.cornerRadius
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.active

        onClicked: root.dismissed()
    }
}
