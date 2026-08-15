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
    property bool caffeineAppliedState: false
    property Timer caffeineAutoDisableTimer: Timer {
        repeat: false

        onTriggered: root.setCaffeineEnabled(false)
    }
    property Process caffeineControlProcess: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("[QuickSettingsService] Failed to update Caffeine inhibitor:", exitCode);
            if (root.caffeineSyncPending || root.caffeineAppliedState !== root.caffeineEnabled) {
                root.caffeineSyncPending = false;
                Qt.callLater(root.syncCaffeineInhibitor);
            }
        }
    }
    property alias caffeineEnabled: persistedToggles.caffeineEnabled
    property bool caffeineSyncPending: false
    property Connections configConnections: Connections {
        function onCaffeineAutoDisableMinutesChanged() {
            if (root.caffeineEnabled)
                root.setCaffeineEnabled(true);
        }
        function onIdleDisplayTimeoutChanged() {
            root.idleSyncTimer.restart();
        }
        function onIdleEnabledChanged() {
            root.idleSyncTimer.restart();
        }
        function onIdleLockBeforeSleepChanged() {
            root.idleSyncTimer.restart();
        }
        function onIdleLockTimeoutChanged() {
            root.idleSyncTimer.restart();
        }
        function onIdleLockedDisplayTimeoutChanged() {
            root.idleSyncTimer.restart();
        }
        function onIdleSuspendTimeoutChanged() {
            root.idleSyncTimer.restart();
        }
        function onNotificationDndEndChanged() {
            root.updateDndSchedule();
        }
        function onNotificationDndScheduleEnabledChanged() {
            root.updateDndSchedule();
        }
        function onNotificationDndStartChanged() {
            root.updateDndSchedule();
        }

        target: Config
    }
    property alias dndActive: persistedToggles.dndActive
    property bool dndScheduleSuppressed: false
    property Timer dndScheduleTimer: Timer {
        interval: 30000
        repeat: true
        running: true

        onTriggered: root.updateDndSchedule()
    }
    property bool dndScheduledActive: false
    readonly property bool effectiveDndActive: dndActive || (dndScheduledActive && !dndScheduleSuppressed)
    property Process idleControlProcess: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("[QuickSettingsService] Failed to update idle policy:", exitCode);
            if (root.idleSyncPending) {
                root.idleSyncPending = false;
                root.idleSyncTimer.restart();
            }
        }
    }
    property bool idleSyncPending: false
    property Timer idleSyncTimer: Timer {
        interval: 250
        repeat: false

        onTriggered: root.syncIdlePolicy()
    }
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
    property bool stateRefreshQueued: false
    property Timer stateRefresher: Timer {
        interval: 15000
        repeat: true
        running: root.active

        onTriggered: root.refreshStates()
    }
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
    property bool tailscaleApplyingEnabled: false
    property bool tailscaleEnabled: false
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
        caffeineAutoDisableTimer.stop();
        if (enabled && Config.caffeineAutoDisableMinutes > 0) {
            caffeineAutoDisableTimer.interval = Config.caffeineAutoDisableMinutes * 60000;
            caffeineAutoDisableTimer.restart();
        }
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
    function startPendingTailscaleAction() {
        if (tailscaleAction.running || !tailscaleTransitionPending)
            return;

        tailscaleApplyingEnabled = tailscaleTargetEnabled;
        tailscaleAction.command = ["tailscale", tailscaleApplyingEnabled ? "up" : "down"];
        tailscaleAction.running = true;
    }
    function syncCaffeineInhibitor() {
        if (caffeineControlProcess.running) {
            caffeineSyncPending = true;
            return;
        }

        caffeineAppliedState = caffeineEnabled;
        caffeineControlProcess.command = [Config.quickshellDir + "/scripts/caffeine-control.sh", caffeineAppliedState ? "enable" : "disable"];
        caffeineControlProcess.running = true;
    }
    function syncIdlePolicy() {
        if (idleControlProcess.running) {
            idleSyncPending = true;
            return;
        }
        idleControlProcess.command = Config.idleEnabled ? [Config.quickshellDir + "/scripts/idle-control.sh", "apply", String(Config.idleLockTimeout), String(Config.idleDisplayTimeout), String(Config.idleSuspendTimeout), Config.idleLockBeforeSleep ? "true" : "false", String(Config.idleLockedDisplayTimeout)] : [Config.quickshellDir + "/scripts/idle-control.sh", "disable"];
        idleControlProcess.running = true;
    }
    function timeMinutes(value) {
        var match = /^(\d\d):(\d\d)$/.exec(String(value || ""));
        if (!match)
            return -1;
        return Number(match[1]) * 60 + Number(match[2]);
    }
    function toggleDnd() {
        if (effectiveDndActive) {
            dndActive = false;
            if (dndScheduledActive)
                dndScheduleSuppressed = true;
            return;
        }
        if (dndScheduledActive)
            dndScheduleSuppressed = false;
        else
            dndActive = true;
    }
    function updateDndSchedule() {
        if (!Config.notificationDndScheduleEnabled) {
            dndScheduledActive = false;
            dndScheduleSuppressed = false;
            return;
        }
        var start = timeMinutes(Config.notificationDndStart);
        var end = timeMinutes(Config.notificationDndEnd);
        if (start < 0 || end < 0 || start === end) {
            dndScheduledActive = false;
            dndScheduleSuppressed = false;
            return;
        }
        var now = new Date();
        var current = now.getHours() * 60 + now.getMinutes();
        var scheduled = start < end ? current >= start && current < end : current >= start || current < end;
        if (!scheduled)
            dndScheduleSuppressed = false;
        dndScheduledActive = scheduled;
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", Config.homeDir + "/.cache/quickshell"]);
        Qt.callLater(root.syncCaffeineInhibitor);
        Qt.callLater(root.syncIdlePolicy);
        root.updateDndSchedule();
    }
    onActiveChanged: {
        if (active)
            refreshStates();
    }
    onCaffeineEnabledChanged: syncCaffeineInhibitor()
}
