import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import "../../"
import "../../service"

PanelWindow {
    id: bar

    readonly property real s: 1.0

    WlrLayershell.namespace: "blur-bar"
    anchors.left: true
    anchors.right: true
    anchors.top: true
    color: Config.alpha(Config.md3.background, 0.2)
    implicitHeight: 50

    SystemClock {
        id: systemClock
    }
    IdleInhibitor {
        enabled: QuickSettingsService.caffeineEnabled
        window: bar
    }
    Item {
        anchors.fill: parent

        // Left side: Active Window + currently playing media
        RowLayout {
            anchors.left: parent.left
            anchors.leftMargin: 25
            anchors.verticalCenter: parent.verticalCenter
            spacing: 50

            ActiveClient {
            }
            Media {
            }
        }

        // Center: Workspaces list
        RowLayout {
            anchors.centerIn: parent
            anchors.verticalCenter: parent.verticalCenter

            Workspaces {
            }
        }

        // Right side: SysTray + connectivity + Battery + DateTime
        RowLayout {
            anchors.right: parent.right
            anchors.rightMargin: 30
            anchors.verticalCenter: parent.verticalCenter
            spacing: 25

            RecordingIndicator {
                parentWindow: bar
            }
            SysTray {
                parentWindow: bar
            }
            MicrophonePrivacy {
                parentWindow: bar
            }
            Wifi {
            }
            BluetoothStatus {
            }
            Battery {
            }
            MouseArea {
                cursorShape: Qt.PointingHandCursor
                implicitHeight: 22
                implicitWidth: 22
                visible: QuickSettingsService.caffeineEnabled

                onClicked: QuickSettingsService.setCaffeineEnabled(false)

                IconImage {
                    anchors.fill: parent
                    layer.enabled: true
                    source: Quickshell.iconPath("caffeine-cup-full-symbolic")

                    layer.effect: ColorOverlay {
                        color: Config.md3.primary
                    }
                }
            }
            NotificationIcon {
            }
            Text {
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 18
                font.weight: Font.DemiBold
                text: "│"
            }
            MouseArea {
                id: clockArea

                hoverEnabled: true
                implicitHeight: 30
                implicitWidth: clockLayout.implicitWidth

                ColumnLayout {
                    id: clockLayout

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        Layout.alignment: Qt.AlignRight
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 16
                        font.weight: Font.ExtraBold
                        text: systemClock.date ? Qt.formatDateTime(systemClock.date, Config.clock24h ? "HH : mm" : "hh : mm A") : ""
                    }
                    Text {
                        Layout.alignment: Qt.AlignRight
                        color: Config.md3.on_surface_variant
                        font.family: Config.fontName
                        font.pixelSize: 15
                        font.weight: Font.Medium
                        text: systemClock.date ? Qt.formatDateTime(systemClock.date, "ddd, dd MMM yyyy") : ""
                    }
                }
            }
        }
    }
}
