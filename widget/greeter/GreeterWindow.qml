import QtQuick
import Quickshell

FloatingWindow {
    id: root

    property bool primary: false

    color: GreeterTheme.background
    fullscreen: true
    title: qsTr("Login")
    visible: true

    Shortcut {
        enabled: root.primary && !GreeterSession.greetdAvailable
        sequences: [StandardKey.Cancel]

        onActivated: Qt.quit()
    }
    GreeterSurface {
        anchors.fill: parent
        interactive: root.primary
    }
}
