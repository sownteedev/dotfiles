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

    readonly property bool actuallyPaired: device && device.bonded
    readonly property int batteryPercent: hasBattery ? Math.round(device.battery * 100) : -1
    readonly property bool busy: connecting || disconnecting || commandPending || (device && device.pairing)
    readonly property bool commandPending: device && BluetoothService.pendingAddress === BluetoothService.normalizeAddress(device.address)
    readonly property bool connected: device && device.connected
    readonly property bool connecting: device && device.state === BluetoothDeviceState.Connecting
    readonly property var detailedBattery: BluetoothService.airpodsBattery || ({})
    required property var device
    readonly property string deviceName: device ? (device.name || device.deviceName || "Bluetooth device") : "Bluetooth device"
    readonly property bool disconnecting: device && device.state === BluetoothDeviceState.Disconnecting
    readonly property bool hasBattery: device && device.batteryAvailable
    readonly property bool hasDetailedBattery: connected && isAirpods && BluetoothService.airpodsBatteryAvailable && detailedBattery.accurate === true && BluetoothService.normalizeAddress(detailedBattery.address) === BluetoothService.normalizeAddress(device.address)
    readonly property bool isAirpods: deviceName.toLowerCase().indexOf("airpods") !== -1
    property bool pairPending: false
    property bool pairedDevice: false
    readonly property bool remembered: pairedDevice || savedDevice
    property bool savedDevice: false
    readonly property bool showStatus: !hasDetailedBattery && (remembered || connected || busy || BluetoothService.lastErrorAddress === BluetoothService.normalizeAddress(device.address))
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
    border.color: root.connected ? Config.alpha(Config.md3.primary, 0.42) : root.remembered ? Config.alpha(Config.md3.on_surface, Config.lightTheme ? 0.12 : 0.09) : "transparent"
    border.width: 1
    color: root.connected ? Config.alpha(Config.md3.primary, 0.12) : root.remembered ? Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.64 : 0.30) : Config.alpha(Config.md3.on_surface, 0.055)
    implicitHeight: contentRow.implicitHeight + (root.hasDetailedBattery ? 22 : root.remembered ? 26 : 22)
    radius: 16

    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }
    Behavior on implicitHeight {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
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
        id: contentRow

        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Rectangle {
            Layout.preferredHeight: root.remembered ? 42 : 38
            Layout.preferredWidth: root.remembered ? 42 : 38
            border.color: Config.alpha(Config.md3.primary, 0.35)
            border.width: root.connected ? 1 : 0
            color: root.connected ? Config.alpha(Config.md3.primary, 0.16) : root.remembered ? Config.alpha(Config.md3.on_surface, 0.11) : Config.alpha(Config.md3.primary, 0.09)
            radius: root.remembered ? 13 : 19

            IconImage {
                id: deviceIcon

                anchors.centerIn: parent
                implicitHeight: root.remembered ? 24 : 22
                implicitWidth: root.remembered ? 24 : 22
                source: Quickshell.iconPath(((root.device && root.device.icon) || "bluetooth") + "-symbolic", "bluetooth-symbolic")
                visible: false
            }
            ColorOverlay {
                anchors.fill: deviceIcon
                color: root.connected ? Config.md3.primary : root.remembered ? Config.md3.on_surface : Config.md3.on_surface_variant
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
            spacing: root.hasDetailedBattery ? 3 : 4

            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: root.connected ? Font.Bold : Font.DemiBold
                text: root.deviceName
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: root.showStatus

                Rectangle {
                    Layout.preferredHeight: 6
                    Layout.preferredWidth: 6
                    color: root.statusColor
                    opacity: root.connected ? 1 : 0.58
                    radius: 3
                }
                Text {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    color: root.statusColor
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 11
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
                    x: 0

                    Repeater {
                        model: root.hasDetailedBattery ? [
                            {
                                "label": "L",
                                "type": "left",
                                "value": root.detailedBattery.left,
                                "charging": root.detailedBattery.leftCharging === true
                            },
                            {
                                "label": "R",
                                "type": "right",
                                "value": root.detailedBattery.right,
                                "charging": root.detailedBattery.rightCharging === true
                            },
                            {
                                "label": "Case",
                                "type": "case",
                                "value": root.detailedBattery.case,
                                "charging": root.detailedBattery.caseCharging === true
                            }
                        ] : []

                        Rectangle {
                            id: batteryChip

                            readonly property color levelColor: root.batteryColor(modelData.value)
                            required property var modelData
                            readonly property bool valueAvailable: modelData.value !== null && modelData.value !== undefined && modelData.value >= 0 && modelData.value <= 100

                            border.color: Config.alpha(levelColor, 0.35)
                            border.width: 1
                            clip: true
                            color: Config.alpha(levelColor, 0.12)
                            height: 25
                            radius: 7
                            width: detailContent.implicitWidth + 14

                            RowLayout {
                                id: detailContent

                                anchors.centerIn: parent
                                spacing: 4.5

                                Item {
                                    id: iconHolder

                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredHeight: 14
                                    Layout.preferredWidth: modelData.type === "case" ? 12 : 9

                                    // Left Earbud: Head on left, stem on right
                                    Item {
                                        anchors.fill: parent
                                        visible: modelData.type === "left"

                                        Rectangle {
                                            color: batteryChip.levelColor
                                            height: 6
                                            radius: 3
                                            width: 6
                                            x: 3
                                            y: 1
                                        }
                                        Rectangle {
                                            color: batteryChip.levelColor
                                            height: 8.5
                                            radius: 1
                                            width: 2.2
                                            x: 2.3
                                            y: 4.5
                                        }
                                    }

                                    // Right Earbud: Head on right, stem on left
                                    Item {
                                        anchors.fill: parent
                                        visible: modelData.type === "right"

                                        Rectangle {
                                            color: batteryChip.levelColor
                                            height: 6
                                            radius: 3
                                            width: 6
                                            x: 0
                                            y: 1
                                        }
                                        Rectangle {
                                            color: batteryChip.levelColor
                                            height: 8.5
                                            radius: 1
                                            width: 2.2
                                            x: 4.5
                                            y: 4.5
                                        }
                                    }

                                    // Case: Rounded container with lid line & LED
                                    Rectangle {
                                        anchors.centerIn: parent
                                        border.color: batteryChip.levelColor
                                        border.width: 1.2
                                        color: "transparent"
                                        height: 13
                                        radius: 3.5
                                        visible: modelData.type === "case"
                                        width: 11

                                        // Lid seam line
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.top: parent.top
                                            anchors.topMargin: 4
                                            color: batteryChip.levelColor
                                            height: 1
                                        }

                                        // LED dot
                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.top: parent.top
                                            anchors.topMargin: 7
                                            color: batteryChip.levelColor
                                            height: 2
                                            radius: 1
                                            width: 2
                                        }
                                    }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.pixelSize: 11
                                    font.weight: Font.ExtraBold
                                    text: batteryChip.valueAvailable ? modelData.value + "%" : "—"
                                }
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    color: Config.md3.tertiary
                                    font.family: Config.fontName
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    text: "⚡"
                                    visible: batteryChip.valueAvailable && modelData.charging === true
                                }
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
            Layout.preferredHeight: 36
            Layout.preferredWidth: Math.min(Layout.maximumWidth, Math.max(66, primaryLabel.implicitWidth + 20))
            border.color: root.connected ? Config.alpha(Config.md3.on_surface, 0.15) : "transparent"
            border.width: 1
            color: root.busy ? Config.alpha(Config.md3.tertiary, 0.16) : root.connected ? Config.alpha(Config.md3.on_surface, primaryMouse.containsMouse ? 0.16 : 0.1) : (primaryMouse.containsMouse ? Config.md3.primary_container : Config.md3.primary)
            opacity: root.busy ? 0.72 : 1
            radius: 12

            Text {
                id: primaryLabel

                anchors.centerIn: parent
                color: root.connected ? Config.md3.on_surface : primaryMouse.containsMouse ? Config.md3.on_primary_container : Config.md3.on_primary
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 12
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                text: primaryAction.label
                width: parent.width - 12
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
            border.color: Config.alpha(Config.md3.error, 0.14)
            border.width: 1
            color: forgetMouse.containsMouse ? Config.alpha(Config.md3.error, 0.18) : Config.alpha(Config.md3.error, 0.06)
            radius: 12
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
