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
                duration: 220
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 160
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
                        duration: 160
                    }
                }

                IconImage {
                    id: updateIcon

                    anchors.centerIn: parent
                    height: 16
                    layer.enabled: true
                    source: Quickshell.iconPath(UpdateService.available ? UpdateService.updateCount > 0 ? "software-update-available-symbolic" : "emblem-ok-symbolic" : "dialog-warning-symbolic")
                    visible: !UpdateService.busy
                    width: 16

                    layer.effect: ColorOverlay {
                        color: UpdateService.error !== "" || !UpdateService.available ? Config.md3.error : Config.md3.primary
                    }
                }
                Canvas {
                    id: updateSpinner

                    anchors.centerIn: parent
                    height: 17
                    renderTarget: Canvas.FramebufferObject
                    visible: UpdateService.busy
                    width: 17

                    RotationAnimator on rotation {
                        duration: 680
                        from: 0
                        loops: Animation.Infinite
                        running: UpdateService.busy
                        to: 360

                        onRunningChanged: {
                            if (!running)
                                updateSpinner.rotation = 0;
                        }
                    }

                    onPaint: {
                        var context = getContext("2d");
                        context.reset();
                        context.beginPath();
                        context.lineCap = "round";
                        context.lineWidth = 2;
                        context.strokeStyle = Config.md3.primary;
                        context.arc(width / 2, height / 2, 6, -Math.PI * 0.15, Math.PI * 1.35);
                        context.stroke();
                    }
                }
            }
            ColumnLayout {
                spacing: 0
                visible: !UpdateService.busy

                Text {
                    color: Config.alpha(Config.md3.on_surface, 0.42)
                    font.capitalization: Font.AllUppercase
                    font.family: Config.fontName
                    font.letterSpacing: 0.7
                    font.pixelSize: 8
                    font.weight: Font.DemiBold
                    text: "Package updates"
                }
                Text {
                    color: UpdateService.error !== "" || !UpdateService.available ? Config.md3.error : Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
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
