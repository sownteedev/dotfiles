import "../../../" // Config
import "../../../service"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets

RowLayout {
    id: root

    // Left: compact system uptime badge
    Rectangle {
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredHeight: 42
        Layout.preferredWidth: uptimeContent.implicitWidth + 22
        border.color: Config.alpha(Config.md3.on_surface, 0.07)
        border.width: 1
        color: Config.alpha(Config.md3.on_surface, 0.04)
        radius: 13

        RowLayout {
            id: uptimeContent

            anchors.fill: parent
            anchors.leftMargin: 7
            anchors.rightMargin: 12
            spacing: 9

            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: 28
                color: Config.alpha(Config.md3.primary, 0.16)
                radius: 9

                IconImage {
                    anchors.centerIn: parent
                    height: 16
                    layer.enabled: true
                    source: Quickshell.iconPath("preferences-system-time-symbolic")
                    width: 16

                    layer.effect: ColorOverlay {
                        color: Config.md3.primary
                    }
                }
            }
            ColumnLayout {
                spacing: 0

                Text {
                    color: Config.alpha(Config.md3.on_surface, 0.42)
                    font.capitalization: Font.AllUppercase
                    font.family: Config.fontName
                    font.letterSpacing: 0.7
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    text: "System uptime"
                }
                Text {
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    text: SysStats.uptimeText.replace(/^Uptime\s*/, "")
                }
            }
        }
    }
    Item {
        Layout.fillWidth: true
    }

    // Right: Profile Avatar
    Rectangle {
        id: avatarContainer

        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        color: "transparent"
        height: 35
        layer.enabled: true
        radius: 20
        width: 35

        layer.effect: DropShadow {
            color: "#80000000"
            horizontalOffset: 0
            radius: 5
            samples: 10
            verticalOffset: 0
        }

        Rectangle {
            id: avatarClip

            anchors.fill: parent
            clip: true
            color: "transparent"
            radius: 20

            Image {
                anchors.fill: parent
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                source: "file://" + Config.profileImage
                sourceSize: Qt.size(avatarClip.width * 2, avatarClip.height * 2)
            }
        }
    }
}
