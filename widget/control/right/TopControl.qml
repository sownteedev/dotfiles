import "../../../" // Config
import "../../../service"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../../../components"

RowLayout {
    id: root

    readonly property color pillBackground: Config.alpha(Config.md3.on_surface, 0.04)
    readonly property color pillBorder: Config.alpha(Config.md3.on_surface, 0.07)
    readonly property color pillIconBackground: Config.alpha(Config.md3.primary, 0.16)

    // Left: compact system uptime badge
    Rectangle {
        Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
        Layout.preferredHeight: 42
        Layout.preferredWidth: uptimeContent.implicitWidth + 22
        border.color: root.pillBorder
        border.width: 1
        color: root.pillBackground
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
                color: root.pillIconBackground
                radius: 9

                Md3Icon {
                    anchors.centerIn: parent
                    color: Config.md3.primary
                    filled: true
                    name: "preferences-system-time-symbolic"
                    size: 16
                }
            }
            ColumnLayout {
                spacing: 0

                Text {
                    color: Config.md3.on_surface_variant
                    font.capitalization: Font.AllUppercase
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.labelSmall.letterSpacing
                    font.pixelSize: Md3.typeScale.labelSmall.size
                    font.weight: Md3.typeScale.labelSmall.weight
                    lineHeight: Md3.typeScale.labelSmall.lineHeight
                    lineHeightMode: Text.FixedHeight
                    text: "System uptime"
                }
                Text {
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                    font.pixelSize: Md3.typeScale.titleMedium.size
                    font.weight: Font.DemiBold
                    lineHeight: Md3.typeScale.titleMedium.lineHeight
                    lineHeightMode: Text.FixedHeight
                    text: SysStats.uptimeText.replace(/^Uptime\s*/, "")
                }
            }
        }
    }
    Item {
        Layout.fillWidth: true
    }

    // Right: package update status
    Rectangle {
        id: updateButton

        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        Layout.preferredHeight: 42
        Layout.preferredWidth: UpdateService.busy ? 42 : updateContent.implicitWidth + 22
        border.color: root.pillBorder
        border.width: 1
        clip: true
        color: {
            if (updateMouse.pressed)
                return Config.alpha(Config.md3.primary, 0.14);
            if (updateMouse.containsMouse)
                return Config.alpha(Config.md3.on_surface, 0.075);
            return root.pillBackground;
        }
        radius: 13

        Behavior on Layout.preferredWidth {
            NumberAnimation {
                duration: Config.animationDuration(220)
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Config.animationDuration(160)
            }
        }

        RowLayout {
            id: updateContent

            anchors.fill: parent
            anchors.leftMargin: 7
            anchors.rightMargin: UpdateService.busy ? 7 : 12
            spacing: 9

            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: 28
                color: UpdateService.error !== "" || !UpdateService.available ? Config.alpha(Config.md3.error, 0.14) : root.pillIconBackground
                radius: 9

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animationDuration(160)
                    }
                }

                Md3Icon {
                    anchors.centerIn: parent
                    color: UpdateService.error !== "" || !UpdateService.available ? Config.md3.error : Config.md3.primary
                    filled: UpdateService.updateCount <= 0 || !UpdateService.available
                    name: UpdateService.available ? UpdateService.updateCount > 0 ? "software-update-available-symbolic" : "emblem-ok-symbolic" : "dialog-warning-symbolic"
                    size: 16
                    visible: !UpdateService.busy
                }
                AnimatedSpinner {
                    anchors.centerIn: parent
                    color: Config.md3.primary
                    height: 17
                    lineWidth: 2
                    running: UpdateService.busy && visible
                    visible: UpdateService.busy
                    width: 17
                }
            }
            ColumnLayout {
                spacing: 0
                visible: !UpdateService.busy

                Text {
                    color: Config.md3.on_surface_variant
                    font.capitalization: Font.AllUppercase
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.labelSmall.letterSpacing
                    font.pixelSize: Md3.typeScale.labelSmall.size
                    font.weight: Md3.typeScale.labelSmall.weight
                    lineHeight: Md3.typeScale.labelSmall.lineHeight
                    lineHeightMode: Text.FixedHeight
                    text: "Package updates"
                }
                Text {
                    color: UpdateService.error !== "" || !UpdateService.available ? Config.md3.error : Config.md3.on_surface
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                    font.pixelSize: Md3.typeScale.titleMedium.size
                    font.weight: Font.DemiBold
                    lineHeight: Md3.typeScale.titleMedium.lineHeight
                    lineHeightMode: Text.FixedHeight
                    text: UpdateService.statusText
                }
            }
        }
        MouseArea {
            id: updateMouse

            acceptedButtons: Qt.LeftButton | Qt.RightButton
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: mouse => {
                if (mouse.button === Qt.RightButton || UpdateService.updateCount === 0 || !UpdateService.available || UpdateService.error !== "")
                    UpdateService.refresh(true);
                else
                    UpdateService.upgrade();
            }
        }
    }
}
