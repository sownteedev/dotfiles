import QtQuick
import QtQuick.Layouts
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
    readonly property string networkIcon: wiredDevice ? "󰈀" : activeNetwork ? (activeNetwork.signalStrength > 0.7 ? "󰤨" : activeNetwork.signalStrength > 0.4 ? "󰤥" : "󰤟") : "󰤭"
    property date now: new Date()
    readonly property real scaleFactor: Math.max(0.76, Math.min(1.3, Math.min(width / 1600, height / 900)))
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
        color: GreeterTheme.withAlpha(GreeterTheme.scrim, GreeterTheme.isDark ? 0.26 : 0.18)
        visible: greeterBackground.hasBackground
    }
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: -width * 0.28
        anchors.top: parent.top
        anchors.topMargin: -height * 0.32
        color: GreeterTheme.withAlpha(GreeterTheme.primary, GreeterTheme.isDark ? 0.11 : 0.16)
        height: width
        radius: width / 2
        width: Math.max(440, Math.min(760, root.width * 0.48))
    }
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -height * 0.38
        anchors.left: parent.left
        anchors.leftMargin: -width * 0.22
        color: GreeterTheme.withAlpha(GreeterTheme.tertiary, GreeterTheme.isDark ? 0.07 : 0.11)
        height: width
        radius: width / 2
        width: Math.max(380, Math.min(680, root.width * 0.42))
    }
    Rectangle {
        anchors.centerIn: parent
        border.color: GreeterTheme.withAlpha(GreeterTheme.primary, GreeterTheme.isDark ? 0.07 : 0.1)
        border.width: Math.max(1, 2 * root.scaleFactor)
        color: "transparent"
        height: width
        radius: width / 2
        width: Math.min(root.width * 0.74, root.height * 1.12)
    }
    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 28 * root.scaleFactor
        anchors.top: parent.top
        anchors.topMargin: 24 * root.scaleFactor
        spacing: 14 * root.scaleFactor

        StatusPill {
            accentColor: GreeterTheme.surfaceVariantText
            icon: root.networkIcon
            scaleFactor: root.scaleFactor
        }
        GreeterBatteryIcon {
            accentColor: root.batteryExternalPower ? GreeterTheme.secondary : root.batteryPercentage <= 33 ? "#e05c5c" : root.batteryPercentage <= 66 ? "#e0a040" : "#91f08b"
            charging: root.batteryCharging
            externalPower: root.batteryExternalPower
            percentage: root.batteryPercentage
            scaleFactor: root.scaleFactor
            visible: root.hasBattery
        }
    }
    Column {
        id: clockBlock

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.max(100, 112 * root.scaleFactor)
        spacing: -6 * root.scaleFactor

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: GreeterTheme.backgroundText
            font.family: "Inter Variable"
            font.pixelSize: 120 * root.scaleFactor
            font.weight: Font.Black
            style: Text.Raised
            styleColor: GreeterTheme.withAlpha(GreeterTheme.shadow, 0.34)
            text: root.now.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: GreeterTheme.surfaceVariantText
            font.capitalization: Font.Capitalize
            font.family: "Inter Variable"
            font.pixelSize: 25 * root.scaleFactor
            font.weight: Font.Bold
            style: Text.Raised
            styleColor: GreeterTheme.withAlpha(GreeterTheme.shadow, 0.28)
            text: root.now.toLocaleDateString(Qt.locale(), Locale.LongFormat)
        }
    }
    LoginCard {
        id: loginCard

        anchors.centerIn: parent
        anchors.verticalCenterOffset: Math.min(140 * root.scaleFactor, Math.max(72 * root.scaleFactor, root.height * 0.1))
        defaultUser: GreeterSession.configuredUser
        height: Math.min(implicitHeight, Math.max(350, root.height - clockBlock.height - 132))
        visible: root.interactive
        width: Math.min(loginCard.implicitWidth, parent.width - 40)
    }
    Row {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24 * root.scaleFactor
        anchors.right: parent.right
        anchors.rightMargin: 28 * root.scaleFactor
        spacing: 10
        visible: root.interactive

        MdIconButton {
            accessibleName: qsTr("Restart")
            iconGlyph: "󰜉"

            onClicked: GreeterSession.reboot()
        }
        MdIconButton {
            accessibleName: qsTr("Power off")
            destructive: true
            iconGlyph: "󰐥"

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
