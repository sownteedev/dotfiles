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
    property FileView persistedStateFile: FileView {
        atomicWrites: true
        path: root.persistedStatePath
        printErrors: false
        watchChanges: false

        adapter: JsonAdapter {
            id: persistedToggles

            property bool caffeineEnabled: false
            property bool dndActive: false
        }

        onAdapterUpdated: writeAdapter()
    }
    readonly property string persistedStatePath: Config.homeDir + "/.cache/quickshell/quick-settings.json"
    property bool stateRefreshQueued: false
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
                var queriedWarpEnabled = cleaned.substring(0, markerIndex).trim() === "on";
                if (!root.warpTransitionPending || queriedWarpEnabled === root.warpTargetEnabled) {
                    root.warpEnabled = queriedWarpEnabled;
                    if (root.warpTransitionPending) {
                        root.warpTransitionPending = false;
                        root.warpRefreshAttempts = 0;
                        root.warpRefreshTimer.stop();
                    }
                } else {
                    root.warpRefreshAttempts += 1;
                    if (root.warpRefreshAttempts >= 8) {
                        root.warpTransitionPending = false;
                        root.warpEnabled = queriedWarpEnabled;
                    } else {
                        root.warpRefreshTimer.interval = Math.min(2500, 400 + root.warpRefreshAttempts * 300);
                        root.warpRefreshTimer.restart();
                    }
                }
                try {
                    var status = JSON.parse(cleaned.substring(markerIndex + marker.length));
                    root.applyTailscaleQuery(status.BackendState === "Running");
                } catch (error) {
                    if (root.tailscaleTransitionPending)
                        root.scheduleTailscaleRefresh();
                    else
                        root.tailscaleEnabled = false;
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (root.stateRefreshQueued) {
                root.stateRefreshQueued = false;
                Qt.callLater(root.refreshStates);
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
    property bool tailscaleApplyingEnabled: false
    property Process tailscaleAction: Process {
        onExited: (exitCode, exitStatus) => {
            var completedTarget = root.tailscaleApplyingEnabled;
            if (exitCode !== 0 && root.tailscaleTargetEnabled === completedTarget) {
                root.tailscaleTransitionPending = false;
                root.tailscaleRefreshTimer.stop();
                console.warn("[QuickSettingsService] Tailscale action failed:", exitCode);
                root.refreshStates();
                return;
            }
            if (root.tailscaleTargetEnabled !== completedTarget) {
                root.startPendingTailscaleAction();
                return;
            }

            root.tailscaleRefreshAttempts = 0;
            root.tailscaleRefreshTimer.interval = 350;
            root.tailscaleRefreshTimer.restart();
        }
    }
    property int tailscaleRefreshAttempts: 0
    property Timer tailscaleRefreshTimer: Timer {
        interval: 350
        repeat: false

        onTriggered: root.refreshStates()
    }
    property bool tailscaleTargetEnabled: false
    property bool tailscaleTransitionPending: false
    property Process warpAction: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.warpTransitionPending = false;
                root.refreshStates();
                return;
            }
            root.warpRefreshAttempts = 0;
            root.warpRefreshTimer.interval = 350;
            root.warpRefreshTimer.restart();
        }
    }
    property bool warpEnabled: false
    property int warpRefreshAttempts: 0
    property Timer warpRefreshTimer: Timer {
        interval: 350
        repeat: false

        onTriggered: root.refreshStates()
    }
    property bool warpTargetEnabled: false
    property bool warpTransitionPending: false
    readonly property bool wifiEnabled: Networking.wifiEnabled

    function applyTailscaleQuery(queriedEnabled) {
        if (!tailscaleTransitionPending || queriedEnabled === tailscaleTargetEnabled) {
            tailscaleEnabled = queriedEnabled;
            if (tailscaleTransitionPending) {
                tailscaleTransitionPending = false;
                tailscaleRefreshAttempts = 0;
                tailscaleRefreshTimer.stop();
            }
            return;
        }

        scheduleTailscaleRefresh();
    }
    function refreshStates() {
        if (stateQuery.running) {
            stateRefreshQueued = true;
            return;
        }
        stateQuery.running = true;
    }
    function runAction(command) {
        actionExecutor.command = ["sh", "-c", command];
        actionExecutor.running = false;
        actionExecutor.running = true;
        stateRefreshDelay.restart();
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
        tailscaleRefreshTimer.stop();
        tailscaleRefreshAttempts = 0;
        tailscaleTargetEnabled = enabled;
        tailscaleTransitionPending = true;
        tailscaleEnabled = enabled;
        if (!tailscaleAction.running)
            startPendingTailscaleAction();
    }
    function setWarpEnabled(enabled) {
        warpRefreshTimer.stop();
        warpRefreshAttempts = 0;
        warpTargetEnabled = enabled;
        warpTransitionPending = true;
        warpEnabled = enabled;
        warpAction.running = false;
        warpAction.command = ["warp-cli", enabled ? "connect" : "disconnect"];
        warpAction.running = true;
    }
    function setWifiEnabled(enabled) {
        Networking.wifiEnabled = enabled;
    }
    function scheduleTailscaleRefresh() {
        tailscaleRefreshAttempts += 1;
        if (tailscaleRefreshAttempts >= 8) {
            tailscaleTransitionPending = false;
            tailscaleRefreshTimer.stop();
            refreshStates();
            return;
        }
        tailscaleRefreshTimer.interval = Math.min(2500, 400 + tailscaleRefreshAttempts * 300);
        tailscaleRefreshTimer.restart();
    }
    function startPendingTailscaleAction() {
        if (tailscaleAction.running || !tailscaleTransitionPending)
            return;

        tailscaleApplyingEnabled = tailscaleTargetEnabled;
        tailscaleAction.command = ["tailscale", tailscaleApplyingEnabled ? "up" : "down"];
        tailscaleAction.running = true;
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", Config.homeDir + "/.cache/quickshell"]);
    }
    onActiveChanged: {
        if (active)
            refreshStates();
    }
}
