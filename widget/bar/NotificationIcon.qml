import QtQuick
import "../../"
import "../../components" as Components
import "../../service"

MouseArea {
    id: root

    readonly property bool dndActive: QuickSettingsService.dndActive
    readonly property int notificationCount: NotificationHistory.notifications.count
    property var targetScreen: null

    Accessible.name: dndActive ? qsTr("Notifications: %1, Do Not Disturb enabled").arg(notificationCount) : qsTr("Notifications: %1").arg(notificationCount)
    Accessible.role: Accessible.Button
    activeFocusOnTab: true
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true
    implicitHeight: 36
    implicitWidth: 36

    Accessible.onPressAction: StateManager.toggleControlPanel(0, root.targetScreen)
    Keys.onReturnPressed: StateManager.toggleControlPanel(0, root.targetScreen)
    Keys.onSpacePressed: StateManager.toggleControlPanel(0, root.targetScreen)
    onClicked: StateManager.toggleControlPanel(0, targetScreen)

    Rectangle {
        anchors.fill: parent
        color: Config.md3.on_surface
        opacity: root.pressed ? Md3.state.pressed : root.containsMouse || root.activeFocus ? Md3.state.hover : 0
        radius: height / 2

        Behavior on opacity {
            NumberAnimation {
                duration: Config.animationDuration(Md3.motion.short3)
            }
        }
    }
    Components.Md3Icon {
        anchors.centerIn: parent
        color: root.dndActive ? Config.md3.tertiary : Config.md3.on_surface
        filled: true
        name: root.dndActive ? "notifications-disabled-symbolic" : "bell-outline-symbolic"
        size: Md3.barIconSize

        Behavior on color {
            ColorAnimation {
                duration: Config.animationDuration(Md3.motion.short3)
            }
        }
    }
    Rectangle {
        id: badge

        anchors.right: parent.right
        anchors.top: parent.top
        color: root.dndActive ? Config.md3.tertiary : Config.md3.error
        height: 18
        radius: height / 2
        visible: root.notificationCount > 0
        width: Math.max(height, countText.implicitWidth + 10)

        Behavior on color {
            ColorAnimation {
                duration: Config.animationDuration(Md3.motion.short2)
            }
        }

        Text {
            id: countText

            anchors.centerIn: parent
            color: root.dndActive ? Config.md3.on_tertiary : Config.md3.on_error
            font.family: Config.fontName
            font.pixelSize: 10
            font.weight: Font.DemiBold
            text: root.notificationCount > 9 ? "9+" : String(root.notificationCount)
        }
    }
}
