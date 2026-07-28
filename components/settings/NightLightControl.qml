import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "../../"
import ".."

Rectangle {
    id: root

    property bool dragging: false
    readonly property int maximumTemperature: 6500
    readonly property int minimumTemperature: 2500
    property bool nightLightEnabled: false
    property int temperature: 4000
    property real visualWarmth: warmth
    readonly property real warmth: Math.max(0, Math.min(1, (maximumTemperature - temperature) / (maximumTemperature - minimumTemperature)))

    signal temperatureRequested(int temperature)
    signal toggleRequested(bool enabled)

    border.color: Config.alpha(Config.md3.on_surface, 0.06)
    border.width: 1
    clip: true
    color: Config.md3.surface_container
    implicitHeight: nightLightEnabled ? 154 : 68
    radius: 14

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    onTemperatureChanged: {
        if (!dragging)
            visualWarmth = warmth;
    }

    Item {
        id: header

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 68

        Rectangle {
            id: iconBackground

            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: Config.alpha(nightLightEnabled ? "#ffad42" : Config.md3.on_surface, 0.16)
            height: 40
            radius: 20
            width: 40

            IconImage {
                anchors.centerIn: parent
                height: 22
                layer.enabled: true
                source: Quickshell.iconPath("night-light-symbolic")
                width: 22

                layer.effect: ColorOverlay {
                    color: root.nightLightEnabled ? "#ffad42" : Config.md3.on_surface_variant
                }
            }
        }
        Column {
            anchors.left: iconBackground.right
            anchors.leftMargin: 12
            anchors.right: nightSwitch.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 16
                font.weight: Font.Bold
                renderType: Text.NativeRendering
                text: "Night Light"
                width: parent.width
            }
            Text {
                color: Config.md3.on_surface_variant
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 13
                font.weight: Font.Medium
                renderType: Text.NativeRendering
                text: root.nightLightEnabled ? root.temperature + "K · " + Math.round(root.warmth * 100) + "% warmth" : "Warm colors to reduce eye strain"
                width: parent.width
            }
        }
        ToggleSwitch {
            id: nightSwitch

            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            checked: root.nightLightEnabled
            checkedColor: "#ffad42"
            height: 26
            thumbCheckedColor: Config.md3.surface_container
            thumbMargin: 3
            thumbUncheckedColor: Config.md3.on_surface
            width: 48

            onToggled: checked => root.toggleRequested(checked)
        }
    }
    Item {
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.top: header.bottom
        enabled: root.nightLightEnabled
        height: 78
        opacity: root.nightLightEnabled ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 140
            }
        }

        Rectangle {
            id: warmthTrack

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 10
            height: 24
            radius: 12

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    color: "#3448d8"
                    position: 0.0
                }
                GradientStop {
                    color: "#f2a064"
                    position: 0.48
                }
                GradientStop {
                    color: "#ff9f1a"
                    position: 1.0
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                border.color: Config.alpha(Config.md3.background, 0.28)
                border.width: 1
                color: Config.md3.on_surface
                height: parent.height + 12
                radius: 3
                width: 6
                x: root.visualWarmth * (parent.width - width)

                Behavior on x {
                    NumberAnimation {
                        duration: root.dragging ? 0 : 90
                        easing.type: Easing.OutQuad
                    }
                }
            }
            MouseArea {
                function updateTemperature(mouse) {
                    var ratio = Math.max(0, Math.min(1, mouse.x / width));
                    root.visualWarmth = ratio;
                    var value = root.maximumTemperature - ratio * (root.maximumTemperature - root.minimumTemperature);
                    root.temperatureRequested(Math.round(value / 50) * 50);
                }

                anchors.bottomMargin: -8
                anchors.fill: parent
                anchors.topMargin: -8
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                preventStealing: true

                onCanceled: {
                    root.dragging = false;
                    root.visualWarmth = root.warmth;
                }
                onPositionChanged: mouse => {
                    if (pressed)
                        updateTemperature(mouse);
                }
                onPressed: mouse => {
                    root.dragging = true;
                    updateTemperature(mouse);
                }
                onReleased: {
                    root.dragging = false;
                    root.visualWarmth = root.warmth;
                }
            }
        }
        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: warmthTrack.bottom
            anchors.topMargin: 10

            Text {
                color: Config.md3.on_surface_variant
                font.family: Config.fontName
                font.pixelSize: 12
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
                text: "Cool"
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                color: "#ffad42"
                font.family: Config.fontName
                font.pixelSize: 12
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
                text: "Warm"
            }
        }
    }
}
