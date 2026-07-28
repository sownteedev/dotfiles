import QtQuick
import Quickshell.Services.UPower
import "../../"

Item {
    id: root

    readonly property color batteryColor: charging ? Config.md3.secondary : batteryPercentage <= 20 ? Config.md3.error : batteryPercentage <= 50 ? Config.md3.tertiary : Config.md3.secondary
    readonly property int batteryPercentage: UPower.displayDevice ? Math.round(UPower.displayDevice.percentage * 100) : 0
    readonly property bool charging: UPower.displayDevice && (UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.FullyCharged)

    implicitHeight: visible ? 30 : 0
    implicitWidth: visible ? 38 : 0
    visible: UPower.displayDevice ? UPower.displayDevice.isLaptopBattery : false

    Item {
        anchors.centerIn: parent
        height: 22
        width: 36

        Text {
            color: Config.md3.on_surface
            font.family: Config.fontName
            font.pixelSize: 9
            font.weight: Font.ExtraBold
            height: 12
            horizontalAlignment: Text.AlignHCenter
            text: root.batteryPercentage.toString()
            verticalAlignment: Text.AlignVCenter
            width: 25
            x: 4
            y: 5
        }
        Item {
            id: batteryFillClip

            clip: true
            height: 12
            width: 25 * Math.max(0, Math.min(100, root.batteryPercentage)) / 100
            x: 4
            y: 5

            Behavior on width {
                NumberAnimation {
                    duration: 350
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Config.alpha(root.batteryColor, 0.78)
                radius: 2

                Behavior on color {
                    ColorAnimation {
                        duration: 220
                    }
                }
            }
            Text {
                color: Config.md3.background
                font.family: Config.fontName
                font.pixelSize: 10
                font.weight: Font.ExtraBold
                height: 12
                horizontalAlignment: Text.AlignHCenter
                text: root.batteryPercentage.toString()
                verticalAlignment: Text.AlignVCenter
                width: 25
                x: 0
                y: 0
            }
        }
        Rectangle {
            border.color: Config.alpha(Config.md3.on_surface, 0.6)
            border.width: 1.5
            color: Config.alpha(Config.md3.on_surface, 0.06)
            height: 18
            radius: 4
            width: 31
            x: 1
            y: 2

            Behavior on border.color {
                ColorAnimation {
                    duration: 220
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 220
                }
            }
        }
        Rectangle {
            color: Config.alpha(Config.md3.on_surface, 0.6)
            height: 6
            radius: 1
            width: 3
            x: 33
            y: 8

            Behavior on color {
                ColorAnimation {
                    duration: 220
                }
            }
        }
    }
}
