import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Widgets
import "../../"
import "../../service"

Rectangle {
    id: root

    readonly property int batteryPercent: hasBattery ? Math.round(device.battery * 100) : -1
    readonly property bool busy: connecting || disconnecting || commandPending || (device && device.pairing)
    readonly property bool commandPending: device && BluetoothService.pendingAddress === BluetoothService.normalizeAddress(device.address)
    readonly property bool connected: device && device.connected
    readonly property bool connecting: device && device.state === BluetoothDeviceState.Connecting
    required property var device
    readonly property string deviceName: device ? (device.name || device.deviceName || "Bluetooth device") : "Bluetooth device"
    readonly property bool disconnecting: device && device.state === BluetoothDeviceState.Disconnecting
    readonly property bool hasBattery: device && device.batteryAvailable
    property bool pairPending: false
    property bool pairedDevice: false
    readonly property color statusColor: BluetoothService.lastErrorAddress === BluetoothService.normalizeAddress(device.address) ? Config.md3.error : busy ? Config.md3.tertiary : connected ? Config.md3.primary : Config.md3.on_surface_variant
    readonly property string statusText: {
        if (!device)
            return "Unavailable";
        if (BluetoothService.lastErrorAddress === BluetoothService.normalizeAddress(device.address))
            return BluetoothService.lastError;
        if (commandPending)
            return BluetoothService.statusText;
        if (device.pairing)
            return "Pairing…";
        if (connecting)
            return "Connecting…";
        if (disconnecting)
            return "Disconnecting…";
        if (connected)
            return hasBattery ? "Connected · " + batteryPercent + "%" : "Connected";
        return pairedDevice ? "Disconnected" : "Ready to pair";
    }

    signal pairingStarted

    function activate() {
        if (!device || busy)
            return;
        if (pairedDevice) {
            if (connected)
                BluetoothService.disconnect(device);
            else
                BluetoothService.connect(device);
        } else {
            pairPending = true;
            pairingStarted();
            BluetoothService.pair(device);
        }
    }

    Layout.fillWidth: true
    border.color: root.connected ? Config.alpha(Config.md3.primary, 0.35) : Config.alpha(Config.md3.on_surface, 0.055)
    border.width: 1
    color: Config.md3.surface_container
    implicitHeight: 76
    radius: 14

    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }

    Component.onCompleted: {
        if (pairedDevice && device && (device.paired || device.bonded) && !device.trusted)
            device.trusted = true;
    }

    Connections {
        function onPairedChanged() {
            if (!root.pairPending || !root.device.paired)
                return;
            root.device.trusted = true;
            root.pairPending = false;
        }
        function onPairingChanged() {
            if (!root.device.pairing && !root.device.paired)
                root.pairPending = false;
        }

        target: root.device
    }
    Connections {
        function onPendingAddressChanged() {
            if (root.pairPending && root.device && BluetoothService.pendingAddress !== BluetoothService.normalizeAddress(root.device.address) && !root.device.pairing && !root.device.paired)
                root.pairPending = false;
        }

        target: BluetoothService
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        spacing: 13

        Rectangle {
            Layout.preferredHeight: 46
            Layout.preferredWidth: 46
            border.color: Config.alpha(Config.md3.primary, 0.35)
            border.width: root.connected ? 1 : 0
            color: root.connected ? Config.alpha(Config.md3.primary, 0.18) : Config.md3.surface_container
            radius: 12

            IconImage {
                id: deviceIcon

                anchors.centerIn: parent
                implicitHeight: 25
                implicitWidth: 25
                source: Quickshell.iconPath(((root.device && root.device.icon) || "bluetooth") + "-symbolic", "bluetooth-symbolic")
                visible: false
            }
            ColorOverlay {
                anchors.fill: deviceIcon
                color: root.connected ? Config.md3.primary : Config.md3.on_surface
                source: deviceIcon
            }
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -3
                anchors.right: parent.right
                anchors.rightMargin: -4
                color: root.batteryPercent <= 20 ? Config.md3.error : root.batteryPercent <= 50 ? Config.md3.tertiary : Config.md3.secondary
                height: 17
                radius: 8
                visible: root.hasBattery
                width: batteryText.implicitWidth + 8

                Text {
                    id: batteryText

                    anchors.centerIn: parent
                    color: Config.md3.background
                    font.family: Config.fontName
                    font.pixelSize: 9
                    font.weight: Font.ExtraBold
                    text: root.batteryPercent + "%"
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 16
                font.weight: root.connected ? Font.Bold : Font.DemiBold
                text: root.deviceName
            }
            Text {
                Layout.fillWidth: true
                color: root.statusColor
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.Medium
                text: root.statusText
            }
        }
        Rectangle {
            id: primaryAction

            readonly property string label: root.commandPending ? BluetoothService.statusText : root.busy ? (root.device && root.device.pairing ? "Pairing…" : root.connecting ? "Connecting…" : "Disconnecting…") : root.pairedDevice ? (root.connected ? "Disconnect" : "Connect") : "Pair"

            Layout.preferredHeight: 36
            Layout.preferredWidth: Math.max(74, primaryLabel.implicitWidth + 24)
            border.color: Config.alpha(root.connected ? Config.md3.on_surface : Config.md3.primary, 0.24)
            border.width: 1
            color: primaryMouse.containsMouse && !root.busy ? Config.alpha(root.connected ? Config.md3.on_surface : Config.md3.primary, 0.24) : Config.alpha(root.connected ? Config.md3.on_surface : Config.md3.primary, 0.13)
            opacity: root.busy ? 0.72 : 1
            radius: 11

            Text {
                id: primaryLabel

                anchors.centerIn: parent
                color: root.connected ? Config.md3.on_surface : Config.md3.primary
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.Bold
                text: primaryAction.label
            }
            MouseArea {
                id: primaryMouse

                anchors.fill: parent
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: !root.busy
                hoverEnabled: true

                onClicked: root.activate()
            }
        }
        Rectangle {
            Layout.preferredHeight: 36
            Layout.preferredWidth: 36
            border.color: Config.alpha(Config.md3.error, 0.18)
            border.width: 1
            color: forgetMouse.containsMouse ? Config.alpha(Config.md3.error, 0.20) : Config.alpha(Config.md3.error, 0.08)
            radius: 11
            visible: root.pairedDevice && !root.busy

            IconImage {
                id: forgetIcon

                anchors.centerIn: parent
                implicitHeight: 17
                implicitWidth: 17
                source: Quickshell.iconPath("user-trash-symbolic")
                visible: false
            }
            ColorOverlay {
                anchors.fill: forgetIcon
                color: Config.md3.error
                source: forgetIcon
            }
            MouseArea {
                id: forgetMouse

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onClicked: BluetoothService.forget(root.device)
            }
        }
    }
}
