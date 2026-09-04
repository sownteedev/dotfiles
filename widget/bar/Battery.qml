pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import QtQuick.Window
import Quickshell.Services.UPower
import Quickshell.Widgets
import "../../"

Item {
    id: root

    readonly property bool activelyCharging: {
        if (!UPower.displayDevice)
            return false;

        const state = UPower.displayDevice.state;
        // UPower reports a full battery as FullyCharged while AC remains connected.
        return state === UPowerDeviceState.Charging || state === UPowerDeviceState.PendingCharge || (state === UPowerDeviceState.FullyCharged && !UPower.onBattery);
    }
    readonly property bool animationActive: onScreen && externalPower && !Config.shellLowPowerMode
    property int animationElapsed: 0
    readonly property color batteryColor: externalPower ? Config.md3.secondary : boundedPercentage <= 33 ? "#e05c5c" : boundedPercentage <= 66 ? "#e0a040" : '#91f08b'
    readonly property int batteryPercentage: UPower.displayDevice ? Math.round(UPower.displayDevice.percentage * 100) : 0
    readonly property int boundedPercentage: Math.max(0, Math.min(100, batteryPercentage))
    readonly property color bubbleColor: Qt.lighter(batteryColor, 1.38)
    readonly property bool externalPower: UPower.displayDevice && (!UPower.onBattery || activelyCharging || UPower.displayDevice.state === UPowerDeviceState.FullyCharged)
    readonly property color fillForeground: externalPower ? Config.md3.on_secondary : "#ffffff"
    readonly property bool onScreen: visible && (Window.window?.visible ?? false)
    readonly property color outlineColor: Config.alpha(batteryColor, 0.92)
    property bool showReadout: true
    readonly property bool waveAnimationActive: onScreen && boundedPercentage > 0 && boundedPercentage < 100 && !Config.shellLowPowerMode

    Accessible.name: activelyCharging ? qsTr("Battery at %1%, charging").arg(boundedPercentage) : externalPower ? qsTr("Battery at %1%, plugged in").arg(boundedPercentage) : qsTr("Battery at %1%").arg(boundedPercentage)
    Accessible.role: Accessible.StaticText
    implicitHeight: visible ? 30 : 0
    implicitWidth: visible ? 45 : 0
    visible: UPower.displayDevice ? UPower.displayDevice.isLaptopBattery : false

    Timer {
        readonly property int frameInterval: root.externalPower ? 40 : 80

        interval: frameInterval
        repeat: true
        running: root.waveAnimationActive || root.animationActive

        onTriggered: root.animationElapsed = (root.animationElapsed + frameInterval) % 86400000
    }
    ClippingRectangle {
        id: liquidClip

        readonly property real fillWidth: width * root.boundedPercentage / 100

        Accessible.ignored: true
        color: "transparent"
        height: batteryBody.height - 4
        radius: batteryBody.radius - 2
        width: batteryBody.width - 4
        x: batteryBody.x + 2
        y: batteryBody.y + 2

        Shape {
            id: liquidFill

            readonly property real edgeCenter: Math.max(0, width - waveAmplitude)
            readonly property real edgeInner: Math.max(0, width - waveAmplitude * 2)
            readonly property real waveAmplitude: root.waveAnimationActive ? Math.min(root.externalPower ? 2.2 : 1.15, width / 3) : 0

            height: parent.height + 24
            visible: width > 0
            width: liquidClip.fillWidth
            y: {
                const duration = root.externalPower ? 480 : 960;
                return -12 + (root.animationElapsed % duration) / duration * 12;
            }

            ShapePath {
                fillColor: Config.alpha(root.batteryColor, root.externalPower ? 0.8 : 0.66)
                startX: 0
                startY: 0
                strokeColor: "transparent"
                strokeWidth: -1

                PathLine {
                    x: liquidFill.edgeCenter
                    y: 0
                }
                PathCubic {
                    control1X: liquidFill.edgeCenter + liquidFill.waveAmplitude * 0.55
                    control1Y: 0
                    control2X: liquidFill.width
                    control2Y: 1.65
                    x: liquidFill.width
                    y: 3
                }
                PathCubic {
                    control1X: liquidFill.width
                    control1Y: 4.35
                    control2X: liquidFill.edgeCenter + liquidFill.waveAmplitude * 0.55
                    control2Y: 6
                    x: liquidFill.edgeCenter
                    y: 6
                }
                PathCubic {
                    control1X: liquidFill.edgeCenter - liquidFill.waveAmplitude * 0.55
                    control1Y: 6
                    control2X: liquidFill.edgeInner
                    control2Y: 7.65
                    x: liquidFill.edgeInner
                    y: 9
                }
                PathCubic {
                    control1X: liquidFill.edgeInner
                    control1Y: 10.35
                    control2X: liquidFill.edgeCenter - liquidFill.waveAmplitude * 0.55
                    control2Y: 12
                    x: liquidFill.edgeCenter
                    y: 12
                }
                PathCubic {
                    control1X: liquidFill.edgeCenter + liquidFill.waveAmplitude * 0.55
                    control1Y: 12
                    control2X: liquidFill.width
                    control2Y: 13.65
                    x: liquidFill.width
                    y: 15
                }
                PathCubic {
                    control1X: liquidFill.width
                    control1Y: 16.35
                    control2X: liquidFill.edgeCenter + liquidFill.waveAmplitude * 0.55
                    control2Y: 18
                    x: liquidFill.edgeCenter
                    y: 18
                }
                PathCubic {
                    control1X: liquidFill.edgeCenter - liquidFill.waveAmplitude * 0.55
                    control1Y: 18
                    control2X: liquidFill.edgeInner
                    control2Y: 19.65
                    x: liquidFill.edgeInner
                    y: 21
                }
                PathCubic {
                    control1X: liquidFill.edgeInner
                    control1Y: 22.35
                    control2X: liquidFill.edgeCenter - liquidFill.waveAmplitude * 0.55
                    control2Y: 24
                    x: liquidFill.edgeCenter
                    y: 24
                }
                PathCubic {
                    control1X: liquidFill.edgeCenter + liquidFill.waveAmplitude * 0.55
                    control1Y: 24
                    control2X: liquidFill.width
                    control2Y: 25.65
                    x: liquidFill.width
                    y: 27
                }
                PathCubic {
                    control1X: liquidFill.width
                    control1Y: 28.35
                    control2X: liquidFill.edgeCenter + liquidFill.waveAmplitude * 0.55
                    control2Y: 30
                    x: liquidFill.edgeCenter
                    y: 30
                }
                PathCubic {
                    control1X: liquidFill.edgeCenter - liquidFill.waveAmplitude * 0.55
                    control1Y: 30
                    control2X: liquidFill.edgeInner
                    control2Y: 31.65
                    x: liquidFill.edgeInner
                    y: 33
                }
                PathCubic {
                    control1X: liquidFill.edgeInner
                    control1Y: 34.35
                    control2X: liquidFill.edgeCenter - liquidFill.waveAmplitude * 0.55
                    control2Y: 36
                    x: liquidFill.edgeCenter
                    y: 36
                }
                PathLine {
                    x: 0
                    y: 36
                }
                PathLine {
                    x: 0
                    y: 0
                }
            }
        }
    }
    Repeater {
        model: [
            {
                "delay": 0,
                "duration": 820,
                "endX": 7,
                "endY": 9,
                "size": 4.6
            },
            {
                "delay": 240,
                "duration": 720,
                "endX": 16,
                "endY": 17,
                "size": 3.2
            },
            {
                "delay": 470,
                "duration": 900,
                "endX": 25,
                "endY": 12,
                "size": 4
            },
            {
                "delay": 690,
                "duration": 780,
                "endX": 32,
                "endY": 18,
                "size": 2.8
            }
        ]

        delegate: Rectangle {
            id: bubble

            readonly property real cycleDuration: modelData.delay + travelDuration
            readonly property real endX: modelData.endX
            readonly property real endY: modelData.endY
            readonly property real fixedStartX: 47
            readonly property real localTime: root.animationActive ? root.animationElapsed % cycleDuration : 0
            required property var modelData
            readonly property real progress: Math.max(0, Math.min(1, (localTime - modelData.delay) / travelDuration))
            readonly property real startY: 15 - height / 2
            readonly property int travelDuration: modelData.duration

            Accessible.ignored: true
            border.color: Config.alpha(root.bubbleColor, 0.96)
            border.width: 1
            color: Config.alpha(root.bubbleColor, 0.34)
            height: modelData.size
            opacity: {
                if (!root.animationActive || localTime < modelData.delay)
                    return 0;
                if (progress < 100 / travelDuration)
                    return progress * travelDuration / 100 * 0.94;
                if (progress > (travelDuration - 130) / travelDuration)
                    return Math.max(0, (1 - progress) * travelDuration / 130 * 0.94);
                return 0.94;
            }
            radius: width / 2
            scale: 0.72 + (1.08 - 0.72) * (1 - Math.pow(1 - progress, 3))
            visible: root.animationActive
            width: modelData.size
            x: fixedStartX + (endX - fixedStartX) * (0.5 - Math.cos(progress * Math.PI) / 2)
            y: startY + (endY - startY) * (0.5 - Math.cos(progress * Math.PI) / 2)

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 1
                anchors.top: parent.top
                anchors.topMargin: 1
                color: Config.alpha(Config.md3.on_secondary, 0.82)
                height: Math.max(1, parent.height * 0.24)
                radius: width / 2
                width: height
            }
        }
    }
    Rectangle {
        id: batteryTerminal

        Accessible.ignored: true
        border.color: root.outlineColor
        border.width: 1
        color: "transparent"
        height: 8
        radius: 2
        width: 6
        x: 39
        y: 11

        Behavior on border.color {
            ColorAnimation {
                duration: 180
            }
        }
    }
    Rectangle {
        id: batteryBody

        Accessible.ignored: true
        border.color: root.outlineColor
        border.width: 1
        color: "transparent"
        height: 21
        radius: 6
        width: 40
        x: 0
        y: 4.5

        Behavior on border.color {
            ColorAnimation {
                duration: 180
            }
        }
    }
    BatteryReadout {
        foreground: Config.md3.on_surface
        height: batteryBody.height
        visible: root.showReadout
        width: batteryBody.width
        x: batteryBody.x
        y: batteryBody.y
    }
    Item {
        id: filledReadoutClip

        clip: true
        height: liquidClip.height
        visible: root.showReadout && width > 0
        width: liquidClip.fillWidth
        x: liquidClip.x
        y: liquidClip.y

        BatteryReadout {
            foreground: root.fillForeground
            height: batteryBody.height
            width: batteryBody.width
            x: batteryBody.x - filledReadoutClip.x
            y: batteryBody.y - filledReadoutClip.y
        }
    }

    component BatteryReadout: Text {
        required property color foreground

        Accessible.ignored: true
        color: foreground
        font.family: Config.fontName
        font.pixelSize: 9
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        renderType: Text.NativeRendering
        text: (root.activelyCharging ? "⚡" : "") + root.boundedPercentage.toString()
        verticalAlignment: Text.AlignVCenter
    }
}
