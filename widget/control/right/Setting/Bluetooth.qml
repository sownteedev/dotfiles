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
    readonly property string connectedAirpodsAddress: {
        for (var i = 0; i < pairedDevices.length; ++i) {
            var name = String(pairedDevices[i].name || pairedDevices[i].deviceName || "").toLowerCase();
            if (name.indexOf("airpods") !== -1 && pairedDevices[i].connected)
                return String(pairedDevices[i].address || "");
        }
        return "";
    }
    readonly property var devices: adapter ? adapter.devices.values : []
    property bool manualScanActive: false
    property bool ownsDiscovery: false
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

    Component.onCompleted: {
        startScan();
        syncAirpodsReader();
    }
    Component.onDestruction: {
        stopScan();
        BluetoothService.setAirpodsDevice("", false);
    }
    onConnectedAirpodsAddressChanged: syncAirpodsReader()
    onVisibleChanged: syncAirpodsReader()

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

                    spacing: 10
                    width: parent.width

                    RowLayout {
                        Layout.bottomMargin: 2
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        visible: root.pairedDevices.length > 0

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            text: qsTr("Paired devices")
                            verticalAlignment: Text.AlignVCenter
                        }
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
                    RowLayout {
                        Layout.bottomMargin: 2
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        Layout.topMargin: 6
                        visible: root.savedDevices.length > 0

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            text: qsTr("Saved devices")
                            verticalAlignment: Text.AlignVCenter
                        }
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
                        Layout.bottomMargin: 2
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        Layout.topMargin: root.pairedDevices.length > 0 || root.savedDevices.length > 0 ? 12 : 0
                        spacing: 8

                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            text: qsTr("Available devices")
                            verticalAlignment: Text.AlignVCenter
                        }
                        Rectangle {
                            id: scanButton

                            function trigger() {
                                if (!root.manualScanActive)
                                    root.startScan();
                            }

                            Accessible.name: root.manualScanActive ? qsTr("Scanning for Bluetooth devices") : qsTr("Scan for Bluetooth devices")
                            Accessible.role: Accessible.Button
                            Layout.preferredHeight: 36
                            Layout.preferredWidth: 36
                            activeFocusOnTab: true
                            border.color: activeFocus ? Config.alpha(Config.md3.primary, 0.48) : "transparent"
                            border.width: 1
                            color: Config.alpha(scanMouse.containsMouse ? Config.md3.primary : Config.md3.on_surface, scanMouse.containsMouse ? 0.13 : 0.055)
                            opacity: root.adapter && root.adapter.enabled ? 1 : 0.4
                            radius: 18

                            Behavior on color {
                                ColorAnimation {
                                    duration: 130
                                }
                            }

                            Accessible.onPressAction: scanButton.trigger()
                            Keys.onReturnPressed: event => {
                                scanButton.trigger();
                                event.accepted = true;
                            }
                            Keys.onSpacePressed: event => {
                                scanButton.trigger();
                                event.accepted = true;
                            }

                            AnimatedSpinner {
                                anchors.centerIn: parent
                                color: root.manualScanActive ? Config.md3.primary : Config.md3.on_surface_variant
                                height: 22
                                lineWidth: 2.2
                                running: root.manualScanActive
                                visible: root.manualScanActive
                                width: 22
                            }
                            IconImage {
                                id: refreshIcon

                                anchors.centerIn: parent
                                implicitHeight: 19
                                implicitWidth: 19
                                source: Quickshell.iconPath("view-refresh-symbolic")
                                visible: false
                            }
                            ColorOverlay {
                                anchors.fill: refreshIcon
                                color: Config.md3.on_surface_variant
                                source: refreshIcon
                                visible: !root.manualScanActive
                            }
                            MouseArea {
                                id: scanMouse

                                anchors.fill: parent
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                enabled: root.adapter && root.adapter.enabled
                                hoverEnabled: true

                                onClicked: scanButton.trigger()
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
                        Layout.preferredHeight: 76
                        border.color: Config.alpha(Config.md3.on_surface, Config.lightTheme ? 0.12 : 0.09)
                        border.width: 1
                        color: Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.64 : 0.30)
                        radius: 18
                        visible: root.availableDevices.length === 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Rectangle {
                                Layout.preferredHeight: 44
                                Layout.preferredWidth: 44
                                color: Config.alpha(Config.md3.primary, 0.09)
                                radius: 22

                                IconImage {
                                    id: emptyBluetoothIcon

                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: -1
                                    implicitHeight: 22
                                    implicitWidth: 22
                                    source: Qt.resolvedUrl("../../../../assets/icons/device-bluetooth.svg")
                                    visible: false
                                }
                                ColorOverlay {
                                    anchors.fill: emptyBluetoothIcon
                                    color: Config.md3.primary
                                    source: emptyBluetoothIcon
                                }
                            }
                            ColumnLayout {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 18
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    text: qsTr("No nearby devices found")
                                    verticalAlignment: Text.AlignVCenter
                                }
                                Text {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 18
                                    color: Config.md3.on_surface_variant
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    text: qsTr("Make the device visible, then press refresh")
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
