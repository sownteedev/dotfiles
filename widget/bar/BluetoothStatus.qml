import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Widgets
import "../../"

MouseArea {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool connected: connectedDevice !== null
    readonly property var connectedDevice: {
        for (var i = 0; i < devices.length; ++i) {
            if (devices[i].connected)
                return devices[i];
        }
        return null;
    }
    readonly property var devices: adapter ? adapter.devices.values : []
    property bool hoverExpansionEnabled: true
    readonly property color iconColor: !adapter || !adapter.enabled ? Config.alpha(Config.md3.on_surface, 0.42) : transitioning ? Config.md3.tertiary : connected ? Config.md3.primary : Config.md3.on_surface
    readonly property string iconName: {
        if (!adapter || adapter.state === BluetoothAdapterState.Blocked)
            return "bluetooth-hardware-disabled-symbolic";
        if (adapter.state === BluetoothAdapterState.Enabling || adapter.state === BluetoothAdapterState.Disabling || transitioningDevice)
            return "bluetooth-acquiring-symbolic";
        if (!adapter.enabled)
            return "bluetooth-disabled-symbolic";
        return connected ? "bluetooth-active-symbolic" : "bluetooth-disconnected-symbolic";
    }
    readonly property bool showStatus: hoverExpansionEnabled && containsMouse
    readonly property string statusText: {
        if (!adapter)
            return "Unavailable";
        if (adapter.state === BluetoothAdapterState.Blocked)
            return "Blocked";
        if (adapter.state === BluetoothAdapterState.Enabling)
            return "Turning on…";
        if (adapter.state === BluetoothAdapterState.Disabling)
            return "Turning off…";
        if (!adapter.enabled)
            return "Turn on";
        if (transitioningDevice)
            return transitioningDevice.state === BluetoothDeviceState.Connecting ? "Connecting…" : "Disconnecting…";
        if (connectedDevice)
            return connectedDevice.name || connectedDevice.deviceName || "Connected";
        return "Disconnected";
    }
    property var targetScreen: null
    readonly property bool transitioning: adapter && (adapter.state === BluetoothAdapterState.Enabling || adapter.state === BluetoothAdapterState.Disabling || transitioningDevice !== null)
    readonly property var transitioningDevice: {
        for (var i = 0; i < devices.length; ++i) {
            if (devices[i].state === BluetoothDeviceState.Connecting || devices[i].state === BluetoothDeviceState.Disconnecting)
                return devices[i];
        }
        return null;
    }

    cursorShape: adapter ? Qt.PointingHandCursor : Qt.ArrowCursor
    hoverEnabled: true
    implicitHeight: 30
    implicitWidth: layout.implicitWidth

    onClicked: {
        if (!adapter)
            return;
        if (!adapter.enabled) {
            adapter.enabled = true;
            return;
        }
        StateManager.showControlPanel(2, targetScreen);
    }

    RowLayout {
        id: layout

        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -1
        spacing: root.showStatus ? 9 : 0

        Behavior on spacing {
            NumberAnimation {
                duration: 240
                easing.type: Easing.InOutQuad
            }
        }

        Item {
            property real pulseOpacity: 1

            implicitHeight: 24
            implicitWidth: 24
            opacity: root.transitioning ? pulseOpacity : 1

            SequentialAnimation on pulseOpacity {
                loops: Animation.Infinite
                running: root.transitioning

                NumberAnimation {
                    duration: 450
                    easing.type: Easing.InOutSine
                    to: 0.42
                }
                NumberAnimation {
                    duration: 450
                    easing.type: Easing.InOutSine
                    to: 1
                }
            }

            IconImage {
                id: bluetoothIcon

                anchors.centerIn: parent
                implicitHeight: 22
                implicitWidth: 22
                source: Quickshell.iconPath(root.iconName)
                visible: false
            }
            ColorOverlay {
                anchors.fill: bluetoothIcon
                color: root.iconColor
                source: bluetoothIcon

                Behavior on color {
                    ColorAnimation {
                        duration: 180
                    }
                }
            }
        }
        Item {
            clip: true
            implicitHeight: statusLabel.implicitHeight
            implicitWidth: root.showStatus ? Math.min(statusLabel.implicitWidth, 210) : 0

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.InOutQuad
                }
            }

            Text {
                id: statusLabel

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: root.connected ? Config.md3.on_surface : Config.md3.on_surface_variant
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.DemiBold
                opacity: parent.implicitWidth > 0 ? 1 : 0
                text: root.statusText

                Behavior on opacity {
                    NumberAnimation {
                        duration: 140
                    }
                }
            }
        }
    }
}
