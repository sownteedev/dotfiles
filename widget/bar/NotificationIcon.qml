import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects
import "../../"
import "../../service"

MouseArea {
    id: root

    property var targetScreen: null

    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true
    implicitHeight: 30
    implicitWidth: 25

    onClicked: StateManager.toggleControlPanel(0, targetScreen)

    Item {
        anchors.centerIn: parent
        height: 23
        width: 23

        IconImage {
            id: icon

            anchors.fill: parent
            source: Quickshell.iconPath("bell-outline-symbolic")
            visible: false
        }
        ColorOverlay {
            anchors.fill: icon
            color: root.containsMouse ? Config.md3.error : Config.md3.on_surface
            source: icon

            Behavior on color {
                ColorAnimation {
                    duration: 150
                }
            }
        }

        // Notification Badge (number of notifications)
        Rectangle {
            id: badge

            readonly property bool dndActive: QuickSettingsService.dndActive

            anchors.bottom: parent.bottom
            anchors.bottomMargin: -4

            // Position at the bottom right of the icon
            anchors.right: parent.right
            anchors.rightMargin: -6
            border.color: Config.md3.background // outline to distinguish from bar background
            border.width: 1.5
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
