pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Widgets
import "../../"
import "../../service"

MouseArea {
    id: root

    readonly property bool connecting: QuickSettingsService.tailscaleTransitionPending && QuickSettingsService.tailscaleTargetEnabled
    readonly property int onlinePeerCount: QuickSettingsService.tailscaleOnlinePeerCount
    readonly property bool showStatus: containsMouse
    readonly property string statusText: connecting ? qsTr("Connecting…") : qsTr("%1 online").arg(onlinePeerCount)

    Accessible.name: qsTr("Tailscale, %1").arg(statusText)
    Accessible.role: Accessible.StaticText
    acceptedButtons: Qt.NoButton
    hoverEnabled: true
    implicitHeight: 30
    implicitWidth: layout.implicitWidth
    visible: QuickSettingsService.tailscaleEnabled

    Component.onCompleted: QuickSettingsService.registerTailscaleStatusConsumer()
    Component.onDestruction: QuickSettingsService.unregisterTailscaleStatusConsumer()
    onEntered: QuickSettingsService.refreshStates()

    RowLayout {
        id: layout

        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -1
        spacing: root.showStatus ? 8 : 0

        Behavior on spacing {
            NumberAnimation {
                duration: Config.animationDuration(180)
                easing.type: Easing.InOutCubic
            }
        }

        Item {
            implicitHeight: 22
            implicitWidth: 22

            IconImage {
                id: tailscaleIcon

                anchors.centerIn: parent
                implicitHeight: 22
                implicitWidth: 22
                source: "file://" + Config.quickshellDir + "/assets/icons/tailscale.svg"
                visible: false
            }
            ColorOverlay {
                anchors.fill: tailscaleIcon
                color: root.connecting ? Config.md3.tertiary : Config.md3.primary
                source: tailscaleIcon

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animationDuration(140)
                    }
                }
            }
        }
        Item {
            clip: true
            implicitHeight: statusLabel.implicitHeight
            implicitWidth: root.showStatus ? statusLabel.implicitWidth : 0

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Config.animationDuration(180)
                    easing.type: Easing.InOutCubic
                }
            }

            Text {
                id: statusLabel

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.DemiBold
                opacity: parent.implicitWidth > 0 ? 1 : 0
                text: root.statusText

                Behavior on opacity {
                    OpacityAnimator {
                        duration: Config.animationDuration(120)
                    }
                }
            }
        }
    }
}
