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
    readonly property var detailedBattery: BluetoothService.airpodsBattery || ({})
    readonly property bool busy: connecting || disconnecting || commandPending || (device && device.pairing)
    readonly property bool commandPending: device && BluetoothService.pendingAddress === BluetoothService.normalizeAddress(device.address)
    readonly property bool connected: device && device.connected
    readonly property bool connecting: device && device.state === BluetoothDeviceState.Connecting
    required property var device
    readonly property string deviceName: device ? (device.name || device.deviceName || "Bluetooth device") : "Bluetooth device"
    readonly property bool disconnecting: device && device.state === BluetoothDeviceState.Disconnecting
    readonly property bool hasBattery: device && device.batteryAvailable
    readonly property bool isAirpods: deviceName.toLowerCase().indexOf("airpods") !== -1
    readonly property bool actuallyPaired: device && device.bonded
    readonly property bool hasDetailedBattery: connected && isAirpods && BluetoothService.airpodsBatteryAvailable && detailedBattery.accurate === true && BluetoothService.normalizeAddress(detailedBattery.address) === BluetoothService.normalizeAddress(device.address)
    property bool pairPending: false
    property bool pairedDevice: false
    property bool savedDevice: false
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
        if (connected && isAirpods) {
            if (hasDetailedBattery)
                return "Connected";
            return BluetoothService.airpodsBatteryScanning ? "Connected · Reading L/R/Case…" : "Connected · Waiting for L/R/Case";
        }
        if (connected)
            return hasBattery ? "Connected · " + batteryPercent + "%" : "Connected";
        if (savedDevice && !actuallyPaired)
            return "Disconnected";
        return actuallyPaired ? "Disconnected" : "Ready to pair";
    }

    signal pairingStarted

    function activate() {
        if (!device || busy)
            return;
        if (connected) {
            BluetoothService.disconnect(device);
        } else if (actuallyPaired || savedDevice) {
            BluetoothService.connect(device);
        } else {
            pairPending = true;
            pairingStarted();
            BluetoothService.pair(device);
        }
    }
    function batteryColor(value) {
        if (value === null || value === undefined || value < 0)
            return Config.md3.outline;
        if (value <= 20)
            return Config.md3.error;
        if (value <= 50)
            return Config.md3.tertiary;
        return Config.md3.secondary;
    }

    Layout.fillWidth: true
    border.color: root.connected ? Config.alpha(Config.md3.primary, 0.35) : Config.alpha(Config.md3.on_surface, 0.055)
    border.width: 1
    color: Config.md3.surface_container
    implicitHeight: hasDetailedBattery ? 108 : 76
    radius: 14

    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }

    Component.onCompleted: {
        if (pairedDevice && device && device.bonded && !device.trusted)
            device.trusted = true;
    }

    Connections {
        function onBondedChanged() {
            if (!root.pairPending || !root.device.bonded)
                return;
            root.device.trusted = true;
            root.pairPending = false;
        }
        function onPairingChanged() {
            if (!root.device.pairing && !root.device.bonded && BluetoothService.pendingAddress !== BluetoothService.normalizeAddress(root.device.address))
                root.pairPending = false;
        }

        target: root.device
    }
    Connections {
        function onPendingAddressChanged() {
            if (root.pairPending && root.device && BluetoothService.pendingAddress !== BluetoothService.normalizeAddress(root.device.address) && !root.device.pairing && !root.device.bonded)
                root.pairPending = false;
        }

        target: BluetoothService
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 10
        spacing: 9

        Rectangle {
            Layout.preferredHeight: 44
            Layout.preferredWidth: 44
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
                visible: root.connected && root.hasBattery && !root.isAirpods
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
            Layout.minimumWidth: 0
            spacing: root.hasDetailedBattery ? 4 : 6

            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 16
                font.weight: root.connected ? Font.Bold : Font.DemiBold
                text: root.deviceName
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    Layout.preferredHeight: 7
                    Layout.preferredWidth: 7
                    color: root.statusColor
                    opacity: root.connected ? 1 : 0.58
                    radius: 4
                }

                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    color: root.statusColor
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    text: root.statusText
                }
            }
            Flickable {
                id: batteryDetailViewport

                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 24 : 0
                boundsBehavior: Flickable.StopAtBounds
                clip: contentWidth > width
                contentHeight: height
                contentWidth: Math.max(width, batteryDetailRow.implicitWidth)
                flickableDirection: Flickable.HorizontalFlick
                interactive: contentWidth > width
                visible: root.hasDetailedBattery

                Row {
                    id: batteryDetailRow

                    height: parent.height
                    spacing: 6
                    x: implicitWidth <= batteryDetailViewport.width ? (batteryDetailViewport.width - implicitWidth) / 2 : 0

                    Repeater {
                        model: root.hasDetailedBattery ? [
                            { "label": "L", "value": root.detailedBattery.left, "charging": root.detailedBattery.leftCharging === true },
                            { "label": "R", "value": root.detailedBattery.right, "charging": root.detailedBattery.rightCharging === true },
                            { "label": "Case", "value": root.detailedBattery.case, "charging": root.detailedBattery.caseCharging === true }
                        ] : []

                        Rectangle {
                            id: batteryChip

                            required property var modelData

                            readonly property bool valueAvailable: modelData.value !== null && modelData.value !== undefined && modelData.value >= 0 && modelData.value <= 100
                            readonly property color levelColor: root.batteryColor(modelData.value)

                            border.color: Config.alpha(levelColor, 0.32)
                            border.width: 1
                            clip: true
                            color: Config.alpha(levelColor, 0.10)
                            height: 24
                            radius: 8
                            width: detailContent.implicitWidth + 14

                            RowLayout {
                                id: detailContent

                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -1
                                spacing: 5

                                Text {
                                    color: Config.alpha(batteryChip.levelColor, 0.88)
                                    font.family: Config.fontName
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    text: modelData.label
                                }
                                Text {
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.pixelSize: 11
                                    font.weight: Font.ExtraBold
                                    text: batteryChip.valueAvailable ? modelData.value + "%" : "—"
                                }
                                Text {
                                    color: Config.md3.tertiary
                                    font.family: Config.fontName
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    text: "⚡"
                                    visible: batteryChip.valueAvailable && modelData.charging === true
                                }
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 2
                                anchors.left: parent.left
                                anchors.leftMargin: 3
                                color: batteryChip.levelColor
                                height: 2
                                opacity: batteryChip.valueAvailable ? 0.72 : 0
                                radius: 1
                                width: (batteryChip.width - 6) * Math.max(0, Math.min(100, modelData.value || 0)) / 100
                            }
                        }
                    }
                }
            }
        }
        Rectangle {
            id: primaryAction

            readonly property string label: root.commandPending ? BluetoothService.statusText : root.busy ? (root.device && root.device.pairing ? "Pairing…" : root.connecting ? "Connecting…" : "Disconnecting…") : root.connected ? "Disconnect" : (root.actuallyPaired || root.savedDevice) ? "Connect" : "Pair"

            Layout.maximumWidth: 104
            Layout.preferredHeight: 34
            Layout.preferredWidth: Math.min(Layout.maximumWidth, Math.max(68, primaryLabel.implicitWidth + 18))
            border.color: Config.alpha(root.connected ? Config.md3.on_surface : Config.md3.primary, 0.24)
            border.width: 1
            color: primaryMouse.containsMouse && !root.busy ? Config.alpha(root.connected ? Config.md3.on_surface : Config.md3.primary, 0.24) : Config.alpha(root.connected ? Config.md3.on_surface : Config.md3.primary, 0.13)
            opacity: root.busy ? 0.72 : 1
            radius: 10

            Text {
                id: primaryLabel

                anchors.centerIn: parent
                color: root.connected ? Config.md3.on_surface : Config.md3.primary
                font.family: Config.fontName
                font.pixelSize: 13
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                text: primaryAction.label
                width: parent.width - 12
                elide: Text.ElideRight
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
            Layout.preferredHeight: 34
            Layout.preferredWidth: 34
            border.color: Config.alpha(Config.md3.error, 0.18)
            border.width: 1
            color: forgetMouse.containsMouse ? Config.alpha(Config.md3.error, 0.20) : Config.alpha(Config.md3.error, 0.08)
            radius: 10
            visible: (root.pairedDevice || root.savedDevice) && !root.busy

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
