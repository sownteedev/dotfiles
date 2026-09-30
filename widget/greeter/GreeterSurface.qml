pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Networking
import Quickshell.Services.UPower

Item {
    id: root

    readonly property var activeNetwork: {
        var values = wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : [];
        for (var i = 0; i < values.length; ++i) {
            if (values[i] && values[i].connected)
                return values[i];
        }
        return null;
    }
    readonly property bool batteryCharging: batteryDevice && (batteryDevice.state === UPowerDeviceState.Charging || batteryDevice.state === UPowerDeviceState.PendingCharge || (batteryDevice.state === UPowerDeviceState.FullyCharged && !UPower.onBattery))
    readonly property var batteryDevice: UPower.displayDevice
    readonly property bool batteryExternalPower: batteryDevice && (!UPower.onBattery || batteryCharging || batteryDevice.state === UPowerDeviceState.FullyCharged)
    readonly property int batteryPercentage: batteryDevice ? Math.round(batteryDevice.percentage * 100) : 0
    readonly property var devices: Networking.devices ? Networking.devices.values : []
    readonly property bool hasBattery: batteryDevice && batteryDevice.ready && batteryDevice.isLaptopBattery
    property bool interactive: true
    readonly property real leftMargin: Math.max(48, Math.min(112, root.width * 0.055))
    readonly property bool networkConnected: wiredDevice || activeNetwork !== null
    readonly property string networkIcon: wiredDevice ? "󰈀" : activeNetwork ? (activeNetwork.signalStrength > 0.7 ? "󰤨" : activeNetwork.signalStrength > 0.4 ? "󰤥" : "󰤟") : "󰤭"
    readonly property string networkLabel: wiredDevice ? qsTr("Wired") : activeNetwork ? (activeNetwork.name || qsTr("Connected")) : qsTr("Offline")
    property date now: new Date()
    readonly property real scaleFactor: Math.max(0.8, Math.min(1.4, Math.min(width / 1600, height / 900)))
    readonly property var wifiDevice: {
        for (var i = 0; i < devices.length; ++i) {
            if (devices[i].type === DeviceType.Wifi)
                return devices[i];
        }
        return null;
    }
    readonly property var wiredDevice: {
        for (var i = 0; i < devices.length; ++i) {
            if (devices[i].type === DeviceType.Wired && devices[i].connected)
                return devices[i];
        }
        return null;
    }

    Timer {
        interval: 1000
        repeat: true
        running: true

        onTriggered: root.now = new Date()
    }
    Rectangle {
        anchors.fill: parent
        color: GreeterTheme.background

        gradient: Gradient {
            GradientStop {
                color: GreeterTheme.surfaceContainerLowest
                position: 0
            }
            GradientStop {
                color: GreeterTheme.background
                position: 0.52
            }
            GradientStop {
                color: GreeterTheme.surfaceContainerLow
                position: 1
            }
        }
    }
    GreeterBackground {
        id: greeterBackground

        anchors.fill: parent
    }
    Rectangle {
        anchors.fill: parent
        color: GreeterTheme.withAlpha(GreeterTheme.scrim, GreeterTheme.isDark ? 0.22 : 0.14)
        visible: greeterBackground.hasBackground
    }
    Rectangle {
        id: leftVeil

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.top: parent.top
        width: Math.min(root.width, Math.max(680, root.width * 0.52))

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                color: GreeterTheme.withAlpha(GreeterTheme.surfaceContainerLowest, GreeterTheme.isDark ? 0.94 : 0.88)
                position: 0.0
            }
            GradientStop {
                color: GreeterTheme.withAlpha(GreeterTheme.surfaceContainerLowest, GreeterTheme.isDark ? 0.76 : 0.62)
                position: 0.62
            }
            GradientStop {
                color: "transparent"
                position: 1.0
            }
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.min(root.height * 0.45, 520)

        gradient: Gradient {
            GradientStop {
                color: "transparent"
                position: 0.0
            }
            GradientStop {
                color: GreeterTheme.withAlpha(GreeterTheme.surfaceContainerLowest, GreeterTheme.isDark ? 0.42 : 0.28)
                position: 0.65
            }
            GradientStop {
                color: GreeterTheme.withAlpha(GreeterTheme.surfaceContainerLowest, GreeterTheme.isDark ? 0.88 : 0.68)
                position: 1.0
            }
        }
    }
    Item {
        id: decorativeRight

        anchors.bottom: parent.bottom
        anchors.left: parent.horizontalCenter
        anchors.right: parent.right
        anchors.top: parent.top
        clip: true

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: -width * 0.15
            anchors.top: parent.top
            anchors.topMargin: -height * 0.1
            color: GreeterTheme.withAlpha(GreeterTheme.primary, GreeterTheme.isDark ? 0.08 : 0.12)
            height: Math.min(600, root.height * 0.6)
            radius: width / 2
            width: height
        }
        Shape {
            anchors.fill: parent
            asynchronous: true
            layer.enabled: true
            layer.samples: 4
            scale: Math.min(1.2, Math.max(0.6, root.scaleFactor))
            transformOrigin: Item.TopRight

            ShapePath {
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                strokeColor: GreeterTheme.withAlpha(GreeterTheme.primary, GreeterTheme.isDark ? 0.16 : 0.22)
                strokeWidth: 3.5

                PathSvg {
                    path: "M200 240 C520 60 1000 160 1055 480 C1104 770 790 990 520 890 C250 790 262 520 525 458 C804 392 1078 568 1220 840"
                }
            }
            ShapePath {
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                strokeColor: GreeterTheme.withAlpha(GreeterTheme.tertiary, GreeterTheme.isDark ? 0.12 : 0.16)
                strokeWidth: 2

                PathSvg {
                    path: "M290 270 C560 130 930 205 982 480 C1020 690 800 840 590 785"
                }
            }
        }
    }
    Row {
        id: identityHeader

        anchors.left: parent.left
        anchors.leftMargin: root.leftMargin
        anchors.top: parent.top
        anchors.topMargin: Math.max(42, Math.min(88, root.height * 0.06))
        spacing: Math.round(14 * root.scaleFactor)

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            border.color: GreeterTheme.withAlpha(GreeterTheme.primary, 0.45)
            border.width: 1.5
            color: GreeterTheme.withAlpha(GreeterTheme.primary, 0.14)
            height: Math.round(42 * root.scaleFactor)
            radius: height / 2
            width: height

            Text {
                anchors.centerIn: parent
                color: GreeterTheme.primary
                font.family: "Inter Variable"
                font.pixelSize: Math.round(20 * root.scaleFactor)
                font.weight: Font.Black
                text: "S"
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: GreeterTheme.backgroundText
            font.family: "Inter Variable"
            font.letterSpacing: 2
            font.pixelSize: Math.round(17 * root.scaleFactor)
            font.weight: Font.Bold
            text: "Sowntee Shell"
        }
    }
    Column {
        id: clockBlock

        anchors.left: parent.left
        anchors.leftMargin: root.leftMargin
        anchors.top: identityHeader.bottom
        anchors.topMargin: Math.max(30, Math.min(64, root.height * 0.045))
        spacing: Math.round(8 * root.scaleFactor)

        Text {
            color: GreeterTheme.backgroundText
            font.family: "Inter Variable"
            font.letterSpacing: -4
            font.pixelSize: Math.round(Math.min(180, Math.max(108, root.height * 0.125)))
            font.weight: Font.Black
            style: Text.Raised
            styleColor: GreeterTheme.withAlpha(GreeterTheme.shadow, 0.35)
            text: root.now.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
        }
        Text {
            color: GreeterTheme.surfaceVariantText
            font.capitalization: Font.Capitalize
            font.family: "Inter Variable"
            font.pixelSize: Math.round(Math.min(32, Math.max(20, root.height * 0.024)))
            font.weight: Font.DemiBold
            style: Text.Raised
            styleColor: GreeterTheme.withAlpha(GreeterTheme.shadow, 0.25)
            text: root.now.toLocaleDateString(Qt.locale(), Locale.LongFormat)
        }
        Rectangle {
            color: GreeterTheme.primary
            height: 4
            radius: 2
            width: Math.round(Math.min(140, Math.max(90, root.width * 0.06)))
        }
    }
    LoginCard {
        id: loginCard

        anchors.left: parent.left
        anchors.leftMargin: root.leftMargin
        anchors.top: clockBlock.bottom
        anchors.topMargin: Math.max(28, Math.min(56, root.height * 0.04))
        defaultUser: GreeterSession.configuredUser
        visible: root.interactive
        width: Math.min(520, Math.max(420, root.width * 0.32))
    }
    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: Math.max(28, 40 * root.scaleFactor)
        anchors.top: parent.top
        anchors.topMargin: Math.max(28, 40 * root.scaleFactor)
        spacing: Math.round(12 * root.scaleFactor)

        StatusPill {
            accentColor: root.networkConnected ? GreeterTheme.primary : GreeterTheme.surfaceVariantText
            icon: root.networkIcon
            scaleFactor: root.scaleFactor
            text: root.networkLabel
        }
        Rectangle {
            border.color: GreeterTheme.withAlpha(GreeterTheme.outlineVariant, 0.4)
            border.width: 1
            color: GreeterTheme.withAlpha(GreeterTheme.surfaceContainerHigh, 0.78)
            implicitHeight: Math.round(36 * root.scaleFactor)
            implicitWidth: batteryRow.implicitWidth + Math.round(20 * root.scaleFactor)
            radius: implicitHeight / 2
            visible: root.hasBattery

            Row {
                id: batteryRow

                anchors.centerIn: parent
                spacing: Math.round(8 * root.scaleFactor)

                GreeterBatteryIcon {
                    accentColor: root.batteryExternalPower ? GreeterTheme.secondary : root.batteryPercentage <= 20 ? GreeterTheme.error : root.batteryPercentage <= 50 ? GreeterTheme.tertiary : GreeterTheme.primary
                    anchors.verticalCenter: parent.verticalCenter
                    charging: root.batteryCharging
                    externalPower: root.batteryExternalPower
                    percentage: root.batteryPercentage
                    scaleFactor: root.scaleFactor * 0.88
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: GreeterTheme.surfaceText
                    font.family: "Inter Variable"
                    font.pixelSize: Math.round(12 * root.scaleFactor)
                    font.weight: Font.Medium
                    text: root.batteryPercentage + "%"
                }
            }
        }
    }
    Row {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.max(28, 40 * root.scaleFactor)
        anchors.right: parent.right
        anchors.rightMargin: Math.max(28, 40 * root.scaleFactor)
        spacing: Math.round(14 * root.scaleFactor)
        visible: root.interactive

        MdIconButton {
            accessibleName: qsTr("Restart")
            iconGlyph: "󰜉"
            pill: true
            scaleFactor: root.scaleFactor

            onClicked: GreeterSession.reboot()
        }
        MdIconButton {
            accessibleName: qsTr("Power off")
            destructive: true
            iconGlyph: "󰐥"
            pill: true
            scaleFactor: root.scaleFactor

            onClicked: GreeterSession.powerOff()
        }
    }
    Rectangle {
        anchors.fill: parent
        color: GreeterTheme.scrim
        opacity: GreeterSession.launching ? 1 : 0
        visible: opacity > 0
        z: 100

        Behavior on opacity {
            NumberAnimation {
                duration: 240
                easing.type: Easing.InOutCubic
            }
        }
    }
}
