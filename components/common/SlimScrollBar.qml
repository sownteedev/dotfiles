import "../../"
import QtQuick
import QtQuick.Controls

ScrollBar {
    id: root

    property color accentColor: Config.md3.primary

    implicitHeight: orientation === Qt.Horizontal ? 8 : 0
    implicitWidth: orientation === Qt.Vertical ? 8 : 0
    minimumSize: 0.06
    opacity: size < 1 ? (active || hovered ? 1 : 0.58) : 0
    padding: 2
    policy: ScrollBar.AsNeeded

    background: Rectangle {
        color: Config.alpha(root.accentColor, root.hovered ? 0.08 : 0.035)
        implicitHeight: root.orientation === Qt.Horizontal ? 4 : 0
        implicitWidth: root.orientation === Qt.Vertical ? 4 : 0
        radius: 2
    }
    contentItem: Rectangle {
        color: root.pressed ? root.accentColor : Config.alpha(root.accentColor, root.hovered ? 0.78 : 0.48)
        implicitHeight: root.orientation === Qt.Horizontal ? 4 : 24
        implicitWidth: root.orientation === Qt.Vertical ? 4 : 24
        radius: 2

        Behavior on color {
            ColorAnimation {
                duration: 130
            }
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: 160
        }
    }
}
