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
    property Connections batteryConnections: Connections {
        function onOnBatteryChanged() {
            if (Config.idleSeparatePowerProfiles)
                root.idleSyncTimer.restart();
        }

        target: BatteryService
    }
    readonly property bool bluetoothEnabled: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    property bool caffeineAppliedState: false
    property Timer caffeineAutoDisableTimer: Timer {
        interval: 1000
        repeat: true
        running: root.caffeineEnabled && root.caffeineExpiresAt > 0

        onTriggered: {
            root.caffeineNow = Date.now();
            if (root.caffeineNow >= root.caffeineExpiresAt)
                root.setCaffeineEnabled(false);
        }
    }
    property Process caffeineControlProcess: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("[QuickSettingsService] Failed to update Caffeine inhibitor:", exitCode);
            if (root.caffeineSyncPending || root.caffeineAppliedState !== root.caffeineEnabled) {
                root.caffeineSyncPending = false;
                Qt.callLater(root.syncCaffeineInhibitor);
            } else {
                root.idleSyncTimer.restart();
            }
        }
    }
    property alias caffeineEnabled: persistedToggles.caffeineEnabled
    property alias caffeineExpiresAt: persistedToggles.caffeineExpiresAt
    property real caffeineNow: Date.now()
    readonly property int caffeineRemainingSeconds: caffeineEnabled && caffeineExpiresAt > 0 ? Math.max(0, Math.ceil((caffeineExpiresAt - caffeineNow) / 1000)) : 0
    property bool caffeineSyncPending: false
    property Connections configConnections: Connections {
        function onCaffeineAutoDisableMinutesChanged() {
            if (root.caffeineEnabled)
                root.setCaffeineEnabled(true);
        }
        function onIdleBatteryDisplayTimeoutChanged() {
            root.idleSyncTimer.restart();
        }
        function onIdleBatteryLockTimeoutChanged() {
            root.idleSyncTimer.restart();
        }
        function onIdleBatterySleepActionChanged() {
            root.idleSyncTimer.restart();
        }
        function onIdleBatterySuspendTimeoutChanged() {
            root.idleSyncTimer.restart();
        }
        function onIdleDimDurationChanged() {
            root.idleSyncTimer.restart();
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
        function onIdleRespectInhibitorsChanged() {
            root.idleSyncTimer.restart();
        }
        function onIdleSeparatePowerProfilesChanged() {
            root.idleSyncTimer.restart();
        }
        function onIdleSleepActionChanged() {
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
    readonly property int effectiveIdleDisplayTimeout: usingBatteryIdleProfile ? Config.idleBatteryDisplayTimeout : Config.idleDisplayTimeout
    readonly property int effectiveIdleLockTimeout: usingBatteryIdleProfile ? Config.idleBatteryLockTimeout : Config.idleLockTimeout
    readonly property string effectiveIdleSleepAction: resolvedSleepAction(usingBatteryIdleProfile ? Config.idleBatterySleepAction : Config.idleSleepAction)
    readonly property int effectiveIdleSuspendTimeout: usingBatteryIdleProfile ? Config.idleBatterySuspendTimeout : Config.idleSuspendTimeout
    property Process idleControlProcess: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn("[QuickSettingsService] Failed to update idle policy:", exitCode);
                root.idlePolicyError = qsTr("Could not apply the idle policy (exit %1)").arg(exitCode);
            }
            if (root.idleSyncPending) {
                root.idleSyncPending = false;
                root.idleSyncTimer.restart();
            } else {
                root.idlePolicyReady = exitCode === 0;
                if (exitCode === 0)
                    root.idlePolicyError = "";
            }
        }
    }
    readonly property int idleDimDuration: Math.max(0, Config.idleDimDuration)
    readonly property bool idlePolicyApplying: idleControlProcess.running || idleSyncPending
    property string idlePolicyError: ""
    property bool idlePolicyReady: false
    readonly property string idleProfileName: Config.idleSeparatePowerProfiles ? (usingBatteryIdleProfile ? qsTr("Battery") : qsTr("Plugged in")) : qsTr("Shared")
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
            property real caffeineExpiresAt: 0
            property bool dndActive: false
        }

        onAdapterUpdated: writeAdapter()
    }
    readonly property string persistedStatePath: Config.homeDir + "/.cache/quickshell/quick-settings.json"
    property bool sleepCapabilitiesReady: false
    property string sleepCapabilityHibernate: "unknown"
    property Process sleepCapabilityProcess: Process {
        command: [Config.quickshellDir + "/scripts/power/idle-session-manager.sh", "capabilities"]

        stdout: StdioCollector {
            id: sleepCapabilityOutput
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.sleepCapabilitiesReady = false;
                console.warn("[QuickSettingsService] Failed to query sleep capabilities:", exitCode);
                return;
            }
            try {
                var capabilities = JSON.parse(sleepCapabilityOutput.text.trim());
                root.sleepCapabilitySuspend = String(capabilities.suspend || "unknown");
                root.sleepCapabilityHibernate = String(capabilities.hibernate || "unknown");
                root.sleepCapabilitySuspendThenHibernate = String(capabilities["suspend-then-hibernate"] || "unknown");
                root.sleepCapabilitiesReady = true;
                root.idleSyncTimer.restart();
            } catch (error) {
                root.sleepCapabilitiesReady = false;
                console.warn("[QuickSettingsService] Invalid sleep capability response:", error);
            }
        }
    }
    property string sleepCapabilitySuspend: "unknown"
    property string sleepCapabilitySuspendThenHibernate: "unknown"
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
                    var queriedTailscaleEnabled = status.BackendState === "Running";
                    var peers = status.Peer || {};
                    var onlinePeerCount = 0;
                    for (var peerId in peers) {
                        if (Object.prototype.hasOwnProperty.call(peers, peerId) && peers[peerId] && peers[peerId].Online === true)
                            onlinePeerCount += 1;
                    }
                    root.tailscaleOnlinePeerCount = queriedTailscaleEnabled ? onlinePeerCount : 0;
                    root.applyTailscaleQuery(queriedTailscaleEnabled);
                } catch (error) {
                    root.tailscaleOnlinePeerCount = 0;
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
        running: root.active || root.tailscaleStatusConsumerCount > 0

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
    property int tailscaleOnlinePeerCount: 0
    property int tailscaleRefreshAttempts: 0
    property Timer tailscaleRefreshTimer: Timer {
        interval: 350
        repeat: false

        onTriggered: root.refreshStates()
    }
    property int tailscaleStatusConsumerCount: 0
    property bool tailscaleTargetEnabled: false
    property bool tailscaleTransitionPending: false
    readonly property bool usingBatteryIdleProfile: Config.idleSeparatePowerProfiles && BatteryService.onBattery
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
    function refreshSleepCapabilities() {
        if (!sleepCapabilityProcess.running)
            sleepCapabilityProcess.running = true;
    }
    function refreshStates() {
        if (stateQuery.running) {
            stateRefreshQueued = true;
            return;
        }
        stateQuery.running = true;
    }
    function registerTailscaleStatusConsumer() {
        tailscaleStatusConsumerCount += 1;
        if (tailscaleStatusConsumerCount === 1)
            refreshStates();
    }
    function resolvedSleepAction(action) {
        var requested = String(action || "none");
        if (!sleepCapabilitiesReady || supportsSleepAction(requested))
            return requested;
        if (requested !== "none" && supportsSleepAction("suspend"))
            return "suspend";
        return "none";
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
        caffeineNow = Date.now();
        if (enabled && Config.caffeineAutoDisableMinutes > 0) {
            caffeineExpiresAt = caffeineNow + Config.caffeineAutoDisableMinutes * 60000;
        } else {
            caffeineExpiresAt = 0;
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
    function sleepCapability(action) {
        switch (String(action || "none")) {
        case "suspend":
            return sleepCapabilitySuspend;
        case "hibernate":
            return sleepCapabilityHibernate;
        case "suspend-then-hibernate":
            return sleepCapabilitySuspendThenHibernate;
        case "none":
            return "yes";
        default:
            return "no";
        }
    }
    function startPendingTailscaleAction() {
        if (tailscaleAction.running || !tailscaleTransitionPending)
            return;

        tailscaleApplyingEnabled = tailscaleTargetEnabled;
        tailscaleAction.command = ["tailscale", tailscaleApplyingEnabled ? "up" : "down"];
        tailscaleAction.running = true;
    }
    function supportsSleepAction(action) {
        var capability = sleepCapability(action);
        return capability === "yes" || capability === "challenge";
    }
    function syncCaffeineInhibitor() {
        if (caffeineControlProcess.running) {
            caffeineSyncPending = true;
            return;
        }

        idlePolicyReady = false;
        caffeineAppliedState = caffeineEnabled;
        caffeineControlProcess.command = [Config.quickshellDir + "/scripts/power/caffeine-inhibitor.sh", caffeineAppliedState ? "enable" : "disable"];
        caffeineControlProcess.running = true;
    }
    function syncIdlePolicy() {
        if (idleControlProcess.running) {
            idlePolicyReady = false;
            idleSyncPending = true;
            return;
        }
        idlePolicyReady = false;
        idleControlProcess.command = Config.idleEnabled ? [Config.quickshellDir + "/scripts/power/idle-session-manager.sh", "apply", String(effectiveIdleLockTimeout), String(effectiveIdleDisplayTimeout), String(effectiveIdleSuspendTimeout), Config.idleLockBeforeSleep ? "true" : "false", String(Config.idleLockedDisplayTimeout), String(root.idleDimDuration), effectiveIdleSleepAction, Config.idleRespectInhibitors ? "true" : "false"] : [Config.quickshellDir + "/scripts/power/idle-session-manager.sh", "disable"];
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
    function unregisterTailscaleStatusConsumer() {
        tailscaleStatusConsumerCount = Math.max(0, tailscaleStatusConsumerCount - 1);
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
        caffeineNow = Date.now();
        if (caffeineEnabled && Config.caffeineAutoDisableMinutes > 0) {
            if (caffeineExpiresAt <= 0)
                caffeineExpiresAt = caffeineNow + Config.caffeineAutoDisableMinutes * 60000;
            else if (caffeineExpiresAt <= caffeineNow)
                setCaffeineEnabled(false);
        } else if (!caffeineEnabled || Config.caffeineAutoDisableMinutes <= 0) {
            caffeineExpiresAt = 0;
        }
        Qt.callLater(root.syncCaffeineInhibitor);
        Qt.callLater(root.refreshSleepCapabilities);
        root.updateDndSchedule();
    }
    onActiveChanged: {
        if (active)
            refreshStates();
    }
    onCaffeineEnabledChanged: syncCaffeineInhibitor()
}
