import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Widgets
import "../../../../"
import "../../../../components"

Item {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var availableDevices: {
        var result = [];
        for (var i = 0; i < devices.length; ++i) {
            if (!devices[i].paired && !devices[i].bonded)
                result.push(devices[i]);
        }
        return result;
    }
    readonly property var devices: adapter ? adapter.devices.values : []
    readonly property var pairedDevices: {
        var result = [];
        for (var i = 0; i < devices.length; ++i) {
            if (devices[i].paired || devices[i].bonded)
                result.push(devices[i]);
        }
        return result;
    }

    function startScan() {
        if (!adapter || !adapter.enabled)
            return;
        adapter.discovering = true;
        scanStopTimer.restart();
    }
    function stopScan() {
        scanStopTimer.stop();
        if (adapter && adapter.discovering)
            adapter.discovering = false;
    }

    anchors.fill: parent

    Component.onCompleted: startScan()
    Component.onDestruction: stopScan()

    Timer {
        id: scanStopTimer

        interval: 15000

        onTriggered: root.stopScan()
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
                                running: root.adapter && root.adapter.discovering
                                width: 25
                            }
                            MouseArea {
                                id: scanMouse

                                anchors.fill: parent
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                enabled: root.adapter && root.adapter.enabled
                                hoverEnabled: true

                                onClicked: {
                                    if (!root.adapter.discovering)
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
