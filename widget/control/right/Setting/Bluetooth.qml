import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Widgets
import "../../../../"
import "../../../../components"
import "../../../../service"

Item {
    id: root

    property bool manualScanActive: false
    property bool ownsDiscovery: false
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var availableDevices: {
        var nearbyRevision = BluetoothService.nearbyRevision;
        var result = [];
        for (var i = 0; i < devices.length; ++i) {
            if (!isRememberedDevice(devices[i]) && BluetoothService.isNearby(devices[i].address))
                result.push(devices[i]);
        }
        return result;
    }
    readonly property var devices: adapter ? adapter.devices.values : []
    readonly property string connectedAirpodsAddress: {
        for (var i = 0; i < pairedDevices.length; ++i) {
            var name = String(pairedDevices[i].name || pairedDevices[i].deviceName || "").toLowerCase();
            if (name.indexOf("airpods") !== -1 && pairedDevices[i].connected)
                return String(pairedDevices[i].address || "");
        }
        return "";
    }
    onConnectedAirpodsAddressChanged: syncAirpodsReader()
    readonly property var pairedDevices: {
        var result = [];
        for (var i = 0; i < devices.length; ++i) {
            if (isPairedDevice(devices[i]))
                result.push(devices[i]);
        }
        return result;
    }
    readonly property var savedDevices: {
        var result = [];
        for (var i = 0; i < devices.length; ++i) {
            if (!isPairedDevice(devices[i]) && (devices[i].paired || devices[i].trusted))
                result.push(devices[i]);
        }
        return result;
    }

    function isPairedDevice(device) {
        return device && device.bonded;
    }
    function isRememberedDevice(device) {
        return device && (device.paired || device.bonded || device.trusted);
    }
    function refreshNearbyDevices() {
        if (manualScanActive)
            BluetoothService.probeNearbyDevices(devices);
    }
    function startScan() {
        if (!adapter || !adapter.enabled)
            return;
        manualScanActive = true;
        ownsDiscovery = !adapter.discovering;
        if (ownsDiscovery)
            adapter.discovering = true;
        BluetoothService.beginNearbyScan();
        Qt.callLater(refreshNearbyDevices);
        scanStopTimer.restart();
    }
    function stopScan() {
        scanStopTimer.stop();
        manualScanActive = false;
        if (ownsDiscovery && adapter && adapter.discovering)
            adapter.discovering = false;
        ownsDiscovery = false;
    }
    function syncAirpodsReader() {
        var enabled = visible && controlRightWindow.active && connectedAirpodsAddress !== "";
        BluetoothService.setAirpodsDevice(connectedAirpodsAddress, enabled);
    }
    anchors.fill: parent

    onVisibleChanged: syncAirpodsReader()
    Component.onCompleted: {
        startScan();
        syncAirpodsReader();
    }
    Component.onDestruction: {
        stopScan();
        BluetoothService.setAirpodsDevice("", false);
    }

    Connections {
        function onActiveChanged() {
            root.syncAirpodsReader();
        }

        target: controlRightWindow
    }

    Timer {
        id: scanStopTimer

        interval: 15000

        onTriggered: root.stopScan()
    }
    Timer {
        interval: 800
        repeat: true
        running: root.manualScanActive

        onTriggered: root.refreshNearbyDevices()
    }
    SettingsPageTransition {
        panelActive: controlRightWindow.active
        targetItem: root
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 18
                visible: !root.adapter || !root.adapter.enabled

                IconImage {
                    id: disabledIcon

                    Layout.alignment: Qt.AlignHCenter
                    implicitHeight: 88
                    implicitWidth: 88
                    source: Quickshell.iconPath("bluetooth-disabled-symbolic")
                    visible: false
                }
                ColorOverlay {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: 88
                    Layout.preferredWidth: 88
                    color: Config.alpha(Config.md3.on_surface, 0.20)
                    source: disabledIcon
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    color: Config.alpha(Config.md3.on_surface, 0.6)
                    font.family: Config.fontName
                    font.pixelSize: 16
                    font.weight: Font.Medium
                    text: root.adapter ? "Bluetooth is disabled" : "Bluetooth is unavailable"
                }
            }
            Flickable {
                anchors.fill: parent
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                contentHeight: deviceSections.implicitHeight
                contentWidth: width
                visible: root.adapter && root.adapter.enabled

                ColumnLayout {
                    id: deviceSections

                    spacing: 14
                    width: parent.width

                    Text {
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        opacity: 0.82
                        text: "Paired devices"
                        visible: root.pairedDevices.length > 0
                    }
                    Repeater {
                        model: root.pairedDevices

                        BluetoothDeviceRow {
                            required property var modelData

                            device: modelData
                            pairedDevice: true
                        }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: 10
                        Layout.topMargin: 10
                        color: Config.md3.outline
                        font.family: Config.fontName
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        text: "No paired devices"
                        visible: root.pairedDevices.length === 0
                    }
                    Text {
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        opacity: 0.82
                        text: "Saved devices"
                        visible: root.savedDevices.length > 0
                    }
                    Repeater {
                        model: root.savedDevices

                        BluetoothDeviceRow {
                            required property var modelData

                            device: modelData
                            savedDevice: true
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 8

                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            opacity: 0.82
                            text: "Available devices"
                        }
                        Rectangle {
                            Layout.preferredHeight: 35
                            Layout.preferredWidth: 35
                            color: scanMouse.containsMouse ? Config.md3.surface_container_high : "transparent"
                            opacity: root.adapter && root.adapter.enabled ? 1 : 0.4
                            radius: 15

                            AnimatedSpinner {
                                anchors.centerIn: parent
                                color: Config.md3.on_surface
                                height: 25
                                lineWidth: 2.5
                                running: root.manualScanActive
                                width: 25
                            }
                            MouseArea {
                                id: scanMouse

                                anchors.fill: parent
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                enabled: root.adapter && root.adapter.enabled
                                hoverEnabled: true

                                onClicked: {
                                    if (!root.manualScanActive)
                                        root.startScan();
                                }
                            }
                        }
                    }
                    Repeater {
                        model: root.availableDevices

                        BluetoothDeviceRow {
                            required property var modelData

                            device: modelData
                            pairedDevice: false

                            onPairingStarted: root.stopScan()
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 88
                        border.color: Config.alpha(Config.md3.on_surface, 0.055)
                        border.width: 1
                        color: Config.alpha(Config.md3.on_surface, 0.025)
                        radius: 14
                        visible: root.availableDevices.length === 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 14

                            Rectangle {
                                Layout.preferredHeight: 44
                                Layout.preferredWidth: 44
                                color: Config.alpha(Config.md3.primary, 0.10)
                                radius: 13

                                IconImage {
                                    id: emptyBluetoothIcon

                                    anchors.centerIn: parent
                                    implicitHeight: 23
                                    implicitWidth: 23
                                    source: Quickshell.iconPath("bluetooth-symbolic")
                                    visible: false
                                }
                                ColorOverlay {
                                    anchors.fill: emptyBluetoothIcon
                                    color: Config.md3.primary
                                    source: emptyBluetoothIcon
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.pixelSize: 16
                                    font.weight: Font.DemiBold
                                    text: "No nearby devices found"
                                }
                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.outline
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: 14
                                    text: "Make the device visible, then press refresh"
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
