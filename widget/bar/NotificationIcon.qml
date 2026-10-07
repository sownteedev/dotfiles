import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects
import "../../"
import "../../components" as Components
import "../../service"

MouseArea {
    id: root

    property var targetScreen: null

    Accessible.name: qsTr("Notifications")
    Accessible.role: Accessible.Button
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true
    implicitHeight: 36
    implicitWidth: 36

    onClicked: StateManager.toggleControlPanel(0, targetScreen)

    Rectangle {
        anchors.fill: parent
        color: Config.md3.on_surface
        opacity: root.pressed ? 0.12 : root.containsMouse ? 0.08 : 0
        radius: height / 2

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animationDuration(Md3.motion.short3)
            }
        }
    }
    Item {
        anchors.centerIn: parent
        height: 28
        width: 28

        Components.Md3Icon {
            anchors.fill: parent
            color: Config.md3.on_surface
            filled: NotificationHistory.notifications.count > 0
            name: "bell-outline-symbolic"
            size: 28

            Behavior on color {
                ColorAnimation {
                    duration: Config.animationDuration(Md3.motion.short3)
                }
            }
        }

        // Notification Badge (number of notifications)
        Rectangle {
            id: badge

            readonly property bool dndActive: QuickSettingsService.dndActive

            anchors.bottom: parent.bottom
            anchors.bottomMargin: -2
            anchors.right: parent.right
            anchors.rightMargin: -2
            color: dndActive ? Config.md3.tertiary : Config.md3.error
            height: dndActive ? 13 : 16
            radius: height / 2
            visible: NotificationHistory.notifications.count > 0
            width: dndActive ? 13 : (countText.text.length > 1 ? countText.implicitWidth + 8 : 16)

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                id: countText

                anchors.centerIn: parent
                color: Config.md3.on_error
                font.family: Config.fontName
                font.pixelSize: 9
                font.weight: Font.Bold
                text: NotificationHistory.notifications.count > 9 ? "9+" : NotificationHistory.notifications.count.toString()
                visible: !badge.dndActive
            }
        }
    }
}
