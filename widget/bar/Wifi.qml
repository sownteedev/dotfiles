import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "../../"
import "../../service"

MouseArea {
    id: root

    readonly property bool connected: WifiService.connected
    readonly property color iconColor: WifiService.connectivityIssue ? WifiService.connectivityColor : Config.md3.on_surface
    readonly property string iconName: WifiService.iconName
    property bool showName: false
    readonly property string ssid: WifiService.connectivityIssue ? WifiService.connectivityText : WifiService.connectionName

    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true
    implicitHeight: 30
    implicitWidth: layout.implicitWidth

    onClicked: StateManager.showControlPanel(1)
    onEntered: showName = true
    onExited: showName = false

    RowLayout {
        id: layout

        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -1
        spacing: root.showName && root.ssid !== "" ? 10 : 0

        Behavior on spacing {
            NumberAnimation {
                duration: 250
                easing.type: Easing.InOutQuad
            }
        }

        Item {
            implicitHeight: 25
            implicitWidth: 25
            opacity: root.connected ? 1 : 0.4

            IconImage {
                id: icon

                anchors.fill: parent
                source: Quickshell.iconPath(root.iconName)
                visible: false
            }
            ColorOverlay {
                anchors.fill: icon
                color: root.iconColor
                source: icon

                Behavior on color {
                    ColorAnimation {
                        duration: 180
                    }
                }
            }
        }
        Item {
            clip: true
            implicitHeight: ssidText.implicitHeight
            implicitWidth: root.showName && root.ssid !== "" ? ssidText.implicitWidth : 0

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.InOutQuad
                }
            }

            Text {
                id: ssidText

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: WifiService.connectivityIssue ? WifiService.connectivityColor : Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.Medium
                opacity: parent.implicitWidth > 0 ? 1 : 0
                text: root.ssid

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }
        }
    }
}
