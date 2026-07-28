pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import "../../"

QtObject {
    id: root

    property Process actionExecutor: Process {
    }
    property bool active: false
    readonly property bool airplaneEnabled: !Networking.wifiEnabled && (Bluetooth.defaultAdapter ? !Bluetooth.defaultAdapter.enabled : true)
    readonly property bool bluetoothEnabled: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    property alias caffeineEnabled: persistedToggles.caffeineEnabled
    property alias dndActive: persistedToggles.dndActive
    property bool hotReloadStateRestored: false
    property FileView persistedStateFile: FileView {
        atomicWrites: true
        blockLoading: true
        path: root.persistedStatePath
        printErrors: false
        watchChanges: false

        onLoadFailed: {
            root.persistedStateReady = true;
            root.savePersistedState();
        }
        onLoadedChanged: {
            if (loaded)
                root.loadPersistedState();
        }
    }
    readonly property string persistedStatePath: Config.homeDir + "/.cache/quickshell/quick-settings.json"
    property bool persistedStateReady: false
    property PersistentProperties persistedToggles: PersistentProperties {
        id: persistedToggles

        property bool caffeineEnabled: false
        property bool dndActive: false

        reloadableId: "quick-settings-toggles"

        onReloaded: {
            root.hotReloadStateRestored = true;
            root.persistedStateReady = true;
            root.savePersistedState();
        }
    }
    property Process stateQuery: Process {
        command: ["sh", "-c", "warp_state=$(warp-cli status 2>/dev/null " + "| grep -q 'Status update: Connected' && echo on || echo off); " + "printf '%s\\n__TAILSCALE__\\n' \"$warp_state\"; " + "tailscale status --json 2>/dev/null || printf '{}\\n'"]

        stdout: StdioCollector {
            onStreamFinished: {
                var cleaned = text.trim();
                if (cleaned === "")
                    return;
                var marker = "\n__TAILSCALE__\n";
                var markerIndex = cleaned.indexOf(marker);
                if (markerIndex < 0)
                    return;
                root.warpEnabled = cleaned.substring(0, markerIndex).trim() === "on";
                try {
                    var status = JSON.parse(cleaned.substring(markerIndex + marker.length));
                    root.tailscaleEnabled = status.BackendState === "Running";
                } catch (error) {
                    root.tailscaleEnabled = false;
                }
            }
        }
    }
    property Timer stateRefreshDelay: Timer {
        interval: 400
        repeat: false

        onTriggered: root.refreshStates()
    }
    property Timer stateRefresher: Timer {
        interval: 15000
        repeat: true
        running: root.active

        onTriggered: root.refreshStates()
    }
    property bool tailscaleEnabled: false
    property bool warpEnabled: false
    readonly property bool wifiEnabled: Networking.wifiEnabled

    function loadPersistedState() {
        if (!persistedStateFile.loaded)
            return;
        if (hotReloadStateRestored) {
            persistedStateReady = true;
            return;
        }
        try {
            var raw = persistedStateFile.text().trim();
            if (raw !== "") {
                var state = JSON.parse(raw);
                if (typeof state.dndActive === "boolean")
                    dndActive = state.dndActive;
                if (typeof state.caffeineEnabled === "boolean")
                    caffeineEnabled = state.caffeineEnabled;
            }
        } catch (error) {
            console.warn("[QuickSettingsService] Invalid persisted state:", error);
        }
        persistedStateReady = true;
    }
    function refreshStates() {
        stateQuery.running = false;
        stateQuery.running = true;
    }
    function runAction(command) {
        actionExecutor.command = ["sh", "-c", command];
        actionExecutor.running = false;
        actionExecutor.running = true;
        stateRefreshDelay.restart();
    }
    function savePersistedState() {
        if (!persistedStateReady)
            return;
        persistedStateFile.setText(JSON.stringify({
            "dndActive": dndActive,
            "caffeineEnabled": caffeineEnabled
        }));
    }
    function setAirplaneEnabled(enabled) {
        Networking.wifiEnabled = !enabled;
        if (Bluetooth.defaultAdapter)
            Bluetooth.defaultAdapter.enabled = !enabled;
    }
    function setBluetoothEnabled(enabled) {
        if (Bluetooth.defaultAdapter)
            Bluetooth.defaultAdapter.enabled = enabled;
    }
    function setCaffeineEnabled(enabled) {
        caffeineEnabled = enabled;
    }
    function setTailscaleEnabled(enabled) {
        tailscaleEnabled = enabled;
        runAction("tailscale " + (enabled ? "up" : "down"));
    }
    function setWarpEnabled(enabled) {
        warpEnabled = enabled;
        runAction("warp-cli " + (enabled ? "connect" : "disconnect"));
    }
    function setWifiEnabled(enabled) {
        Networking.wifiEnabled = enabled;
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", Config.homeDir + "/.cache/quickshell"]);
    }
    onActiveChanged: {
        if (active)
            refreshStates();
    }
    onCaffeineEnabledChanged: savePersistedState()
    onDndActiveChanged: savePersistedState()
}
