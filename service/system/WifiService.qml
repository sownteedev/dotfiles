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
    property string settingsConnectionPhase: ""
    property bool settingsConnectionStarted: false
    // NMSettings expects dns-data as a D-Bus string array (`as`). Keeping these
    // values in typed QML lists prevents JavaScript arrays becoming `av`.
    property list<string> settingsIpv4Dns: []
    property list<string> settingsIpv6Dns: []
    property int settingsLoadAttempts: 0
    property Timer settingsLoadRetry: Timer {
        interval: 120
        repeat: false

        onTriggered: root.readSettingsProfile()
    }
    property Connections settingsNetworkConnections: Connections {
        function onConnectedChanged() {
            root.checkSettingsConnectionResult();
        }
        function onConnectionFailed(reason) {
            if (!root.settingsSaving || root.settingsConnectionPhase !== "connecting")
                return;
            var reasonText = ConnectionFailReason.toString(reason);
            root.failSettingsSave(reasonText === "" ? "NetworkManager rejected the connection." : "Connection failed: " + reasonText);
        }
        function onStateChanged() {
            root.checkSettingsConnectionResult();
        }
        function onStateChangingChanged() {
            root.checkSettingsConnectionResult();
        }

        enabled: root.settingsSaving && target !== null
        target: root.settingsRequestedNetwork
    }
    property Connections settingsProfileConnections: Connections {
        function onSettingsChanged(settings) {
            root.beginSettingsReconnect();
        }

        enabled: root.settingsSaving && target !== null
        target: root.settingsRequestedProfile
    }
    property var settingsRequestedNetwork: null
    property var settingsRequestedProfile: null
    property string settingsRequestedSsid: ""
    property Timer settingsSaveTimeout: Timer {
        interval: 15000
        repeat: false

        onTriggered: root.failSettingsSave("NetworkManager did not finish applying the connection in time.")
    }
    property bool settingsSaving: false
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

    signal settingsLoaded(string ssid, var settings)
    signal settingsSaveFailed(string ssid, string message)
    signal settingsSaveSucceeded(string ssid)

    function addressData(value) {
        var parts = String(value || "").trim().split("/");
        return [
            {
                "address": parts[0],
                "prefix": parseInt(parts[1])
            }
        ];
    }
    function beginSettingsReconnect() {
        if (!settingsSaving || settingsConnectionStarted)
            return;

        var network = findNetwork(settingsRequestedSsid);
        if (!network || !settingsRequestedProfile) {
            failSettingsSave("The saved network is no longer available.");
            return;
        }

        settingsRequestedNetwork = network;
        settingsConnectionStarted = true;
        if (network.connected) {
            settingsConnectionPhase = "disconnecting";
            network.disconnect();
        } else {
            startSettingsConnection();
        }
        checkSettingsConnectionResult();
    }
    function checkSettingsConnectionResult() {
        if (!settingsSaving || !settingsConnectionStarted || !settingsRequestedNetwork)
            return;

        if (settingsConnectionPhase === "disconnecting") {
            if (settingsRequestedNetwork.stateChanging || settingsRequestedNetwork.connected)
                return;
            startSettingsConnection();
            return;
        }

        if (settingsConnectionPhase !== "connecting" || settingsRequestedNetwork.stateChanging || !settingsRequestedNetwork.connected)
            return;

        var ssid = settingsRequestedSsid;
        resetSettingsSaveState();
        refreshDetails();
        settingsSaveSucceeded(ssid);
    }
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
    function failSettingsSave(message) {
        if (!settingsSaving)
            return;
        var ssid = settingsRequestedSsid;
        resetSettingsSaveState();
        settingsSaveFailed(ssid, message);
    }
    function findNetwork(ssid) {
        for (var i = 0; i < networkValues.length; ++i) {
            if (networkValues[i].name === ssid)
                return networkValues[i];
        }
        return null;
    }
    function firstAddress(addressData) {
        if (!addressData || addressData.length === 0)
            return "";
        var entry = addressData[0] || {};
        var address = String(entry.address || "");
        var prefix = Number(entry.prefix);
        return address === "" ? "" : address + (isNaN(prefix) ? "" : "/" + prefix);
    }
    function forgetNetwork(networkOrSsid) {
        var network = typeof networkOrSsid === "string" ? findNetwork(networkOrSsid) : networkOrSsid;
        if (network)
            network.forget();
    }
    function loadSettings(ssid) {
        resetSettingsSaveState();
        settingsRequestedSsid = ssid;
        settingsRequestedProfile = null;
        settingsLoadAttempts = 0;
        readSettingsProfile();
    }
    function openCaptivePortal() {
        // A plain HTTP endpoint allows captive portals to redirect to their login page.
        Quickshell.execDetached(["xdg-open", "http://neverssl.com/"]);
    }
    function profileForSsid(ssid) {
        var network = findNetwork(ssid);
        var profiles = network && network.nmSettings ? network.nmSettings : [];
        if (!profiles || profiles.length === 0)
            return null;
        for (var i = 0; i < profiles.length; ++i) {
            if (profiles[i] && profiles[i].id === ssid)
                return profiles[i];
        }
        return profiles[0];
    }
    function readSettingsProfile() {
        var profile = profileForSsid(settingsRequestedSsid);
        if (!profile) {
            if (++settingsLoadAttempts < 8)
                settingsLoadRetry.restart();
            return;
        }

        settingsRequestedProfile = profile;
        var settings = profile.read();
        var connection = settings.connection || {};
        var ipv4 = settings.ipv4 || {};
        if (Object.keys(settings).length === 0 && ++settingsLoadAttempts < 8) {
            settingsLoadRetry.restart();
            return;
        }

        var ipv6 = settings.ipv6 || {};
        var ipv4DnsData = ipv4["dns-data"] || [];
        var ipv6DnsData = ipv6["dns-data"] || [];
        settingsLoaded(settingsRequestedSsid, {
            "autoConnect": connection.autoconnect !== false,
            "ipv4": {
                "method": String(ipv4.method || "auto"),
                "automaticDns": ipv4["ignore-auto-dns"] !== true,
                "dns": ipv4DnsData.length ? ipv4DnsData.join(" ") : "",
                "address": firstAddress(ipv4["address-data"]),
                "gateway": String(ipv4.gateway || "")
            },
            "ipv6": {
                "method": String(ipv6.method || "auto"),
                "automaticDns": ipv6["ignore-auto-dns"] !== true,
                "dns": ipv6DnsData.length ? ipv6DnsData.join(" ") : "",
                "address": firstAddress(ipv6["address-data"]),
                "gateway": String(ipv6.gateway || "")
            }
        });
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
    function resetSettingsSaveState() {
        settingsSaveTimeout.stop();
        settingsSaving = false;
        settingsConnectionStarted = false;
        settingsConnectionPhase = "";
        settingsRequestedNetwork = null;
        settingsRequestedProfile = null;
        settingsRequestedSsid = "";
    }
    function saveSettings(ssid, options) {
        if (settingsSaving)
            return;
        var profile = profileForSsid(ssid);
        if (!profile) {
            settingsSaveFailed(ssid, "The NetworkManager profile could not be found.");
            return;
        }

        var ipv4Options = options.ipv4 || {};
        var ipv6Options = options.ipv6 || {};
        settingsIpv4Dns = splitDns(ipv4Options.dns);
        settingsIpv6Dns = splitDns(ipv6Options.dns);
        var ipv4 = {
            "method": ipv4Options.method === "manual" ? "manual" : "auto",
            "ignore-auto-dns": !Boolean(ipv4Options.automaticDns),
            "dns-data": ipv4Options.automaticDns ? null : settingsIpv4Dns
        };
        if (ipv4.method === "manual") {
            ipv4["address-data"] = addressData(ipv4Options.address);
            ipv4.gateway = String(ipv4Options.gateway || "").trim();
        } else {
            ipv4["address-data"] = null;
            ipv4.gateway = null;
        }

        var ipv6Method = ipv6Options.method === "manual" ? "manual" : ipv6Options.method === "disabled" ? "disabled" : "auto";
        var ipv6 = {
            "method": ipv6Method,
            "ignore-auto-dns": ipv6Method === "disabled" ? false : !Boolean(ipv6Options.automaticDns),
            "dns-data": ipv6Method === "disabled" || ipv6Options.automaticDns ? null : settingsIpv6Dns
        };
        if (ipv6Method === "manual") {
            ipv6["address-data"] = addressData(ipv6Options.address);
            ipv6.gateway = String(ipv6Options.gateway || "").trim();
        } else {
            ipv6["address-data"] = null;
            ipv6.gateway = null;
        }

        settingsRequestedSsid = ssid;
        settingsRequestedProfile = profile;
        settingsRequestedNetwork = null;
        settingsSaving = true;
        settingsConnectionStarted = false;
        settingsSaveTimeout.restart();
        profile.write({
            "connection": {
                "autoconnect": Boolean(options.autoConnect)
            },
            "ipv4": ipv4,
            "ipv6": ipv6
        });
    }
    function scan() {
        if (!wifiDevice || !active)
            return;
        wifiDevice.scannerEnabled = false;
        wifiDevice.scannerEnabled = true;
        scanning = true;
        scanIndicatorTimer.restart();
    }
    function splitDns(value) {
        return String(value || "").trim().split(/[,\s]+/).filter(function (entry) {
            return entry !== "";
        });
    }
    function startSettingsConnection() {
        if (!settingsSaving || !settingsRequestedNetwork || !settingsRequestedProfile)
            return;
        settingsConnectionPhase = "connecting";
        settingsRequestedNetwork.connectWithSettings(settingsRequestedProfile);
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
