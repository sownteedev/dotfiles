pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "../../"

QtObject {
    id: root

    property bool active: false
    property string activeBandwidth: "N/A"
    property string activeFrequency: "N/A"
    property string activeIp: "N/A"
    readonly property var activeNetwork: {
        for (var i = 0; i < networkValues.length; ++i) {
            if (networkValues[i].connected)
                return networkValues[i];
        }
        return null;
    }
    readonly property int activeSignal: activeNetwork ? Math.round(activeNetwork.signalStrength * 100) : 0
    readonly property string activeSsid: activeNetwork ? activeNetwork.name : "Disconnected"
    readonly property bool canCheckConnectivity: Networking.canCheckConnectivity
    readonly property bool captivePortal: connected && connectivity === NetworkConnectivity.Portal
    readonly property bool connected: activeNetwork !== null || wiredDevice !== null
    readonly property string connectionName: wiredDevice ? wiredDevice.name : activeNetwork ? activeNetwork.name : ""
    readonly property string connectionType: wiredDevice ? "ethernet" : activeNetwork ? "wifi" : "none"
    readonly property int connectivity: Networking.connectivity
    readonly property color connectivityColor: captivePortal || limitedConnectivity ? Config.md3.tertiary : noInternet ? Config.md3.error : Config.md3.primary
    readonly property bool connectivityIssue: captivePortal || limitedConnectivity || noInternet
    readonly property string connectivityText: {
        if (!connected)
            return "Disconnected";
        if (captivePortal)
            return "Sign in required";
        if (limitedConnectivity)
            return "Limited connection";
        if (noInternet)
            return "No Internet";
        if (connectivity === NetworkConnectivity.Full)
            return "Internet connected";
        return "Checking connection…";
    }
    property Process detailQuery: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split("|");
                var frequency = parseFloat(parts[0]);
                var bandwidth = parseFloat(parts[1]);
                root.activeFrequency = isNaN(frequency) ? "N/A" : (frequency / 1000).toFixed(1) + " GHz";
                root.activeBandwidth = isNaN(bandwidth) ? "N/A" : bandwidth + " Mbps";
                root.activeIp = parts.length > 2 && parts[2] !== "" ? parts[2] : "N/A";
            }
        }
    }
    readonly property var devices: Networking.devices ? Networking.devices.values : []
    readonly property string iconName: {
        if (!connected)
            return "network-offline-symbolic";
        if (captivePortal)
            return "network-wireless-hotspot-symbolic";
        if (limitedConnectivity || noInternet)
            return "network-error-symbolic";
        if (connectionType === "ethernet")
            return "network-wired-symbolic";
        if (activeSignal > 80)
            return "network-wireless-signal-excellent-symbolic";
        if (activeSignal > 60)
            return "network-wireless-signal-good-symbolic";
        if (activeSignal > 40)
            return "network-wireless-signal-ok-symbolic";
        if (activeSignal > 20)
            return "network-wireless-signal-weak-symbolic";
        return "network-wireless-signal-none-symbolic";
    }
    readonly property bool limitedConnectivity: connected && connectivity === NetworkConnectivity.Limited
    readonly property var networkValues: {
        var values = wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : [];
        var result = [];
        for (var i = 0; i < values.length; ++i) {
            if (values[i] && values[i].name !== "")
                result.push(values[i]);
        }
        result.sort(function (left, right) {
            if (left.connected !== right.connected)
                return left.connected ? -1 : 1;
            if (left.known !== right.known)
                return left.known ? -1 : 1;
            return right.signalStrength - left.signalStrength;
        });
        return result;
    }
    property Connections networkingConnections: Connections {
        function onCanCheckConnectivityChanged() {
            root.enableConnectivityCheck();
        }

        target: Networking
    }
    readonly property bool noInternet: connected && connectivity === NetworkConnectivity.None
    property Timer scanIndicatorTimer: Timer {
        interval: 1400
        repeat: false

        onTriggered: root.scanning = false
    }
    property bool scanning: false
    property Process settingsQuery: Process {
        property string requestedSsid: ""

        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split("|");
                if (parts.length < 5)
                    return;
                root.settingsLoaded(settingsQuery.requestedSsid, parts[0] || "auto", parts[1].replace(/,/g, " "), parts[2], parts[3], parts[4].trim() !== "no");
            }
        }
    }
    property Process settingsSaveProcess: Process {
        onExited: root.refreshDetails()
    }
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

    signal settingsLoaded(string ssid, string method, string dns, string address, string gateway, bool autoConnect)

    function connectNetwork(network) {
        if (network)
            network.connect();
    }
    function connectWithPassword(network, password) {
        if (network)
            network.connectWithPsk(password);
    }
    function enableConnectivityCheck() {
        if (!Networking.canCheckConnectivity)
            return;
        if (!Networking.connectivityCheckEnabled)
            Networking.connectivityCheckEnabled = true;
        Networking.checkConnectivity();
    }
    function findNetwork(ssid) {
        for (var i = 0; i < networkValues.length; ++i) {
            if (networkValues[i].name === ssid)
                return networkValues[i];
        }
        return null;
    }
    function forgetNetwork(networkOrSsid) {
        var network = typeof networkOrSsid === "string" ? findNetwork(networkOrSsid) : networkOrSsid;
        if (network)
            network.forget();
    }
    function loadSettings(ssid) {
        settingsQuery.requestedSsid = ssid;
        settingsQuery.command = ["sh", "-c", "ssid=\"$1\"; " + "method=$(nmcli -g ipv4.method connection show \"$ssid\" 2>/dev/null); " + "dns=$(nmcli -g ipv4.dns connection show \"$ssid\" 2>/dev/null); " + "addr=$(nmcli -g ipv4.addresses connection show \"$ssid\" 2>/dev/null); " + "gw=$(nmcli -g ipv4.gateway connection show \"$ssid\" 2>/dev/null); " + "ac=$(nmcli -g connection.autoconnect connection show \"$ssid\" 2>/dev/null); " + "printf '%s|%s|%s|%s|%s\\n' \"$method\" \"$dns\" \"$addr\" \"$gw\" \"$ac\"", "wifi-settings", ssid];
        settingsQuery.running = false;
        settingsQuery.running = true;
    }
    function openCaptivePortal() {
        // A plain HTTP endpoint allows captive portals to redirect to their login page.
        Quickshell.execDetached(["xdg-open", "http://neverssl.com/"]);
    }
    function recheckConnectivity() {
        if (Networking.canCheckConnectivity)
            Networking.checkConnectivity();
    }
    function refreshDetails() {
        if (!active || (!activeNetwork && !wiredDevice)) {
            activeFrequency = "N/A";
            activeBandwidth = "N/A";
            activeIp = "N/A";
            return;
        }
        detailQuery.command = ["sh", "-c", "if [ \"$1\" = \"ethernet\" ]; then " + "freq=\"\"; rate=\"\"; " + "else " + "freq=$(nmcli -t -f active,freq dev wifi | grep '^yes:' | cut -d: -f2 | tr -d ' MHz'); " + "rate=$(nmcli -t -f active,rate dev wifi | grep '^yes:' | cut -d: -f2 | tr -d ' Mbit/s'); " + "fi; " + "ip=$(ip route get 1.1.1.1 2>/dev/null | sed -n 's/.* src \\([^ ]*\\).*/\\1/p'); " + "printf '%s|%s|%s\\n' \"$freq\" \"$rate\" \"$ip\"", "wifi-details", connectionType];
        detailQuery.running = false;
        detailQuery.running = true;
    }
    function saveSettings(ssid, method, dns, address, gateway, autoConnect) {
        settingsSaveProcess.command = ["sh", "-c", "ssid=\"$1\"; method=\"$2\"; dns=\"$3\"; address=\"$4\"; " + "gateway=\"$5\"; autoconnect=\"$6\"; " + "if [ \"$method\" = auto ]; then " + "nmcli connection modify \"$ssid\" ipv4.method auto " + "ipv4.addresses \"\" ipv4.gateway \"\" ipv4.dns \"$dns\" " + "connection.autoconnect \"$autoconnect\"; " + "else nmcli connection modify \"$ssid\" ipv4.method manual " + "ipv4.addresses \"$address\" ipv4.gateway \"$gateway\" " + "ipv4.dns \"$dns\" connection.autoconnect \"$autoconnect\"; fi " + "&& nmcli connection up \"$ssid\"", "wifi-save", ssid, method, dns, address, gateway, autoConnect ? "yes" : "no"];
        settingsSaveProcess.running = false;
        settingsSaveProcess.running = true;
    }
    function scan() {
        if (!wifiDevice || !active)
            return;
        wifiDevice.scannerEnabled = false;
        wifiDevice.scannerEnabled = true;
        scanning = true;
        scanIndicatorTimer.restart();
    }

    Component.onCompleted: enableConnectivityCheck()
    onActiveChanged: {
        if (wifiDevice)
            wifiDevice.scannerEnabled = active;
        if (active) {
            scan();
            refreshDetails();
        } else {
            scanning = false;
            scanIndicatorTimer.stop();
        }
    }
    onActiveNetworkChanged: refreshDetails()
    onConnectionTypeChanged: refreshDetails()
    onWifiDeviceChanged: {
        if (wifiDevice)
            wifiDevice.scannerEnabled = active;
    }
}
