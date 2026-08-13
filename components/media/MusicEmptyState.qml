import "../../"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

Item {
    id: root

    readonly property bool animationActive: visible && opacity > 0

    implicitHeight: 440
    implicitWidth: 410

    ColumnLayout {
        anchors.centerIn: parent
        height: 410
        spacing: 22
        width: Math.min(380, Math.max(0, root.width - 32))

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 196
            Layout.preferredWidth: 196

            Rectangle {
                anchors.centerIn: parent
                color: Config.alpha(Config.md3.primary, 0.055)
                height: 196
                radius: 98
                width: 196

                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    running: root.animationActive

                    NumberAnimation {
                        duration: 1800
                        easing.type: Easing.InOutSine
                        to: 1.045
                    }
                    NumberAnimation {
                        duration: 1800
                        easing.type: Easing.InOutSine
                        to: 1
                    }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                border.color: Config.alpha(Config.md3.primary, 0.34)
                border.width: 1
                color: Config.alpha(Config.md3.surface_container_lowest, 0.74)
                height: 162
                radius: 81
                width: 162

                Rectangle {
                    anchors.centerIn: parent
                    border.color: Config.alpha(Config.md3.on_surface, 0.1)
                    border.width: 1
                    color: "transparent"
                    height: 128
                    radius: 64
                    width: 128
                }
                Rectangle {
                    anchors.centerIn: parent
                    border.color: Config.alpha(Config.md3.on_surface, 0.08)
                    border.width: 1
                    color: "transparent"
                    height: 94
                    radius: 47
                    width: 94
                }
                Rectangle {
                    anchors.centerIn: parent
                    color: Config.alpha(Config.md3.primary, 0.16)
                    height: 62
                    radius: 31
                    width: 62

                    IconImage {
                        anchors.centerIn: parent
                        implicitHeight: 31
                        implicitWidth: 31
                        layer.enabled: true
                        source: Quickshell.iconPath("multimedia-audio-player-symbolic")

                        layer.effect: ColorOverlay {
                            color: Config.md3.primary
                        }
                    }
                }
            }
            Row {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                anchors.horizontalCenter: parent.horizontalCenter
                height: 36
                spacing: 5

                Repeater {
                    model: [16, 28, 21, 34, 23, 29, 15]

                    Rectangle {
                        required property int index
                        required property int modelData

                        anchors.bottom: parent.bottom
                        color: index % 2 === 0 ? Config.md3.primary : Config.md3.tertiary
                        height: 7
                        radius: 2.5
                        width: 5

                        SequentialAnimation on height {
                            loops: Animation.Infinite
                            running: root.animationActive

                            NumberAnimation {
                                duration: 600 + index * 55
                                easing.type: Easing.InOutSine
                                to: modelData
                            }
                            NumberAnimation {
                                duration: 680 + index * 45
                                easing.type: Easing.InOutSine
                                to: 7
                            }
                        }
                    }
                }
            }
        }
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 22
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                renderType: Text.NativeRendering
                text: "Your music will appear here"
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 330
                color: Config.md3.on_surface_variant
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.3
                renderType: Text.NativeRendering
                text: "Play something in Spotify, a browser,\nor any MPRIS-compatible app"
            }
        }
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 34
            Layout.preferredWidth: statusRow.implicitWidth + 28
            border.color: Config.alpha(Config.md3.primary, 0.18)
            border.width: 1
            color: Config.alpha(Config.md3.primary, 0.08)
            radius: 17

            Row {
                id: statusRow

                anchors.centerIn: parent
                spacing: 8

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Config.md3.primary
                    height: 10
                    radius: 5
                    width: 10

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: root.animationActive

                        NumberAnimation {
                            duration: 900
                            easing.type: Easing.InOutSine
                            to: 0.3
                        }
                        NumberAnimation {
                            duration: 900
                            easing.type: Easing.InOutSine
                            to: 1
                        }
                    }
                }
                Text {
                    color: Config.md3.primary
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                    text: "Waiting for a player"
                }
            }
        }
    }
}
