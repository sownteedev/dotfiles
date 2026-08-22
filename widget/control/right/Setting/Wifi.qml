import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Networking
import Quickshell.Widgets
import "../../../../" // for Config
import "../../../../service"
import "../../../../components"

Item {
    id: wifiPageRoot

    readonly property string activeBandwidth: WifiService.activeBandwidth
    readonly property string activeFreq: WifiService.activeFrequency
    readonly property string activeIp: WifiService.activeIp
    readonly property int activeSignal: WifiService.activeSignal
    readonly property string activeSsid: WifiService.activeSsid
    property string connectionError: ""

    // ── Existing state ──────────────────────────────────────────────────────
    readonly property string connectionName: WifiService.connectionName || "Disconnected"
    readonly property string connectionType: WifiService.connectionType
    property string expandedSsid: ""
    readonly property bool isScanning: WifiService.scanning

    function connectWithPassword(network, password) {
        wifiPageRoot.connectionError = "";
        WifiService.connectWithPassword(network, password);
    }
    function openSettings(ssid) {
        settingsPanel.openFor(ssid);
        WifiService.loadSettings(ssid);
    }
    function startScan() {
        WifiService.scan();
    }
    function updateServiceActivity() {
        WifiService.active = controlRightWindow.active && wifiPageRoot.visible;
    }

    anchors.fill: parent

    Component.onCompleted: {
        updateServiceActivity();
        if (controlRightWindow.active)
            startScan();
    }
    Component.onDestruction: {
        WifiService.active = false;
    }

    SettingsPageTransition {
        panelActive: controlRightWindow.active
        targetItem: wifiPageRoot
    }
    Connections {
        function onVisibleChanged() {
            wifiPageRoot.updateServiceActivity();
        }

        target: wifiPageRoot
    }
    Connections {
        function onActiveChanged() {
            wifiPageRoot.updateServiceActivity();
        }

        target: controlRightWindow
    }
    Connections {
        function onStatsUpdated() {
            if (controlRightWindow.active && wifiPageRoot.visible && networkChart) {
                networkChart.requestPaint();
            }
        }

        target: SysStats
    }
    Connections {
        function onSettingsLoaded(ssid, settings) {
            settingsPanel.loadSettings(ssid, settings);
        }
        function onSettingsSaveFailed(ssid, message) {
            if (settingsPanel.networkSsid === ssid)
                settingsPanel.markSaveFailed(message);
        }
        function onSettingsSaveSucceeded(ssid) {
            if (settingsPanel.networkSsid === ssid)
                settingsPanel.markSaveSucceeded();
        }

        target: WifiService
    }

    // ══════════════════════════════════════════════════════════════════════
    //  ROOT – toggles between list view and settings panel
    // ══════════════════════════════════════════════════════════════════════
    Flickable {
        id: wifiPageFlick

        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        contentHeight: settingsPanel.opened ? height : Math.max(height, wifiListContent.implicitHeight)
        contentWidth: width
        flickableDirection: Flickable.VerticalFlick
        interactive: !settingsPanel.opened && contentHeight > height
        maximumFlickVelocity: 1800

        // ── LIST VIEW ──────────────────────────────────────────────────────
        ColumnLayout {
            id: wifiListContent

            anchors.fill: parent
            spacing: 15
            visible: !settingsPanel.opened

            // 1. Current network card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: currentNetworkLayout.implicitHeight + 36
                border.color: Config.alpha(Config.md3.on_surface, 0.04)
                border.width: 1
                color: Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.58 : 0.22)
                radius: 12

                ColumnLayout {
                    id: currentNetworkLayout

                    anchors.left: parent.left
                    anchors.margins: 18
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        WifiSignalIcon {
                            color: !WifiService.connected ? Config.md3.on_surface_variant : Config.md3.primary
                            connected: WifiService.connected
                            connectivityIssue: WifiService.connectivityIssue
                            height: 26
                            signalStrength: WifiService.activeSignal
                            visible: WifiService.connectionType !== "ethernet"
                            width: 26
                        }
                        IconImage {
                            height: 26
                            layer.enabled: true
                            source: Quickshell.iconPath(WifiService.iconName)
                            visible: WifiService.connectionType === "ethernet"
                            width: 26

                            layer.effect: ColorOverlay {
                                color: Config.md3.primary
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            text: wifiPageRoot.connectionName
                        }
                        Rectangle {
                            color: reloadMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.12) : "transparent"
                            height: 35
                            radius: 15
                            width: 35

                            AnimatedSpinner {
                                anchors.centerIn: parent
                                color: Config.md3.on_surface
                                height: 25
                                lineWidth: 2.5
                                running: wifiPageRoot.isScanning
                                width: 25
                            }
                            MouseArea {
                                id: reloadMouse

                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true

                                onClicked: {
                                    if (!wifiPageRoot.isScanning)
                                        startScan();
                                }
                            }
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true
                        columnSpacing: 15
                        columns: 2
                        rowSpacing: 10

                        Text {
                            color: Config.md3.on_surface_variant
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                            text: "Frequency:"
                            visible: wifiPageRoot.connectionType !== "ethernet"
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignRight
                            renderType: Text.NativeRendering
                            text: wifiPageRoot.activeFreq
                            visible: wifiPageRoot.connectionType !== "ethernet"
                        }
                        Text {
                            color: Config.md3.on_surface_variant
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                            text: "Bandwidth:"
                            visible: wifiPageRoot.connectionType !== "ethernet"
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignRight
                            renderType: Text.NativeRendering
                            text: wifiPageRoot.activeBandwidth
                            visible: wifiPageRoot.connectionType !== "ethernet"
                        }
                        Text {
                            color: Config.md3.on_surface_variant
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            renderType: Text.NativeRendering
                            text: "IP Address:"
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignRight
                            renderType: Text.NativeRendering
                            text: wifiPageRoot.activeIp
                        }
                        StatChart {
                            id: networkChart

                            Layout.columnSpan: 2
                            Layout.fillWidth: true
                            Layout.preferredHeight: implicitHeight
                            chartHeight: 50
                            historyData: SysStats.rxHistory
                            historyData2: SysStats.txHistory
                            lineColor: Config.md3.primary
                            lineColor2: Config.md3.secondary
                            maxValue: SysStats.maxNetworkSpeed
                            modelFontSize: 15
                            modelText: "<font color='" + Config.md3.primary + "'>↓ " + SysStats.downloadSpeed + "</font>  <font color='" + Config.md3.on_surface_variant + "'>•</font>  <font color='" + Config.md3.secondary + "'>↑ " + SysStats.uploadSpeed + "</font>"
                            title: "Network"
                            titleFontSize: 15
                            valueText: ""
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        border.color: Config.alpha(WifiService.connectivityColor, 0.35)
                        border.width: 1
                        color: Config.alpha(WifiService.connectivityColor, 0.10)
                        radius: 12
                        visible: WifiService.connectivityIssue

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 8
                            spacing: 10

                            WifiSignalIcon {
                                color: WifiService.connectivityColor
                                connected: true
                                connectivityIssue: true
                                height: 21
                                signalStrength: WifiService.activeSignal
                                width: 21
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    text: WifiService.connectivityText
                                }
                                Text {
                                    Layout.fillWidth: true
                                    color: Config.md3.on_surface_variant
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: 12
                                    text: WifiService.captivePortal ? "Open the network login page" : "The network is connected but Internet access is restricted"
                                }
                            }
                            Rectangle {
                                Layout.preferredHeight: 34
                                Layout.preferredWidth: issueActionLabel.implicitWidth + 22
                                color: issueActionMouse.containsMouse ? Config.alpha(WifiService.connectivityColor, 0.28) : Config.alpha(WifiService.connectivityColor, 0.18)
                                radius: 10

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 140
                                    }
                                }

                                Text {
                                    id: issueActionLabel

                                    anchors.centerIn: parent
                                    color: Config.md3.on_surface
                                    font.family: Config.fontName
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    text: WifiService.captivePortal ? "Sign in" : "Check again"
                                }
                                MouseArea {
                                    id: issueActionMouse

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true

                                    onClicked: {
                                        if (WifiService.captivePortal)
                                            WifiService.openCaptivePortal();
                                        else
                                            WifiService.recheckConnectivity();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 2. Section title
            Text {
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 16
                font.weight: Font.Bold
                text: "Available Networks"
            }

            // 3. Network list
            Item {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.preferredHeight: availableListView.contentHeight

                ListView {
                    id: availableListView

                    anchors.fill: parent
                    clip: true
                    interactive: false
                    spacing: 8

                    delegate: WifiNetworkRow {
                        required property var modelData

                        connected: modelData.connected
                        connecting: modelData.state === ConnectionState.Connecting
                        errorMessage: expanded ? wifiPageRoot.connectionError : ""
                        expanded: modelData.name === wifiPageRoot.expandedSsid
                        saved: modelData.known
                        secured: modelData.security !== WifiSecurityType.Open
                        signalStrength: Math.round(modelData.signalStrength * 100)
                        ssid: modelData.name

                        onActivateRequested: {
                            WifiService.connectNetwork(modelData);
                        }
                        onClearErrorRequested: wifiPageRoot.connectionError = ""
                        onConnectRequested: password => {
                            wifiPageRoot.connectWithPassword(modelData, password);
                        }
                        onExpansionToggleRequested: {
                            wifiPageRoot.expandedSsid = expanded ? "" : ssid;
                            wifiPageRoot.connectionError = "";
                        }
                        onForgetRequested: {
                            WifiService.forgetNetwork(modelData);
                        }
                        onSettingsRequested: wifiPageRoot.openSettings(ssid)

                        Connections {
                            function onConnectedChanged() {
                                if (modelData.connected) {
                                    wifiPageRoot.connectionError = "";
                                    wifiPageRoot.expandedSsid = "";
                                }
                            }
                            function onConnectionFailed(reason) {
                                wifiPageRoot.connectionError = reason === ConnectionFailReason.NoSecrets ? "Wrong password or missing credentials" : "Connection failed: " + ConnectionFailReason.toString(reason);
                            }

                            target: modelData
                        }
                    }
                    model: ScriptModel {
                        values: WifiService.networkValues
                    }
                } // ListView
            } // network list Item
        } // list ColumnLayout

        // (Password panel removed — password entry is now inline in the list)

        // ══════════════════════════════════════════════════════════════════
        //  SETTINGS PANEL
        // ══════════════════════════════════════════════════════════════════
        WifiSettingsPanel {
            id: settingsPanel

            anchors.fill: parent

            onApplyRequested: (ssid, settings) => WifiService.saveSettings(ssid, settings)
            onForgetRequested: ssid => WifiService.forgetNetwork(ssid)
        }
    } // root Flickable
} // wifiPageRoot
