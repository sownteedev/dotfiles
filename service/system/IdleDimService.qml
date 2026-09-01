pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell.Wayland
import "../.."
import ".."

QtObject {
    id: root

    property bool active: false
    property IdleMonitor activityMonitor: IdleMonitor {
        enabled: root.policyEnabled
        respectInhibitors: false
        timeout: 1

        onIsIdleChanged: {
            if (!isIdle)
                root.handleUserActivity();
        }
    }
    readonly property real dimOpacity: previewing && previewOpacity >= 0 ? previewOpacity : Config.idleDimOpacity
    property int faceRetryAttempts: 0
    property Timer faceRetryCooldownTimer: Timer {
        interval: 1000
        repeat: false

        onTriggered: root.faceRetryCoolingDown = false
    }
    property bool faceRetryCoolingDown: false
    property Timer faceRetryTimer: Timer {
        interval: 100
        repeat: false

        onTriggered: root.retryFaceAuthentication()
    }
    property IdleMonitor lockedDimMonitor: IdleMonitor {
        enabled: root.policyEnabled && !root.monitorsPoweredOff && StateManager.sessionLocked && root.lockedDisplayTimeout > QuickSettingsService.idleDimDuration
        respectInhibitors: false
        timeout: Math.max(0, root.lockedDisplayTimeout - QuickSettingsService.idleDimDuration)

        onIsIdleChanged: {
            if (isIdle)
                root.show();
        }
    }
    property IdleMonitor lockedDisplayMonitor: IdleMonitor {
        enabled: root.policyEnabled && !root.monitorsPoweredOff && StateManager.sessionLocked && root.lockedDisplayTimeout > 0
        respectInhibitors: false
        timeout: root.lockedDisplayTimeout

        onIsIdleChanged: {
            if (isIdle)
                root.powerOffMonitors();
        }
    }
    readonly property int lockedDisplayTimeout: Math.max(0, Config.idleLockedDisplayTimeout)
    property bool monitorsPoweredOff: false
    property IdleMonitor normalDimMonitor: IdleMonitor {
        enabled: root.policyEnabled && !root.monitorsPoweredOff && !StateManager.sessionLocked && root.normalDisplayTimeout > QuickSettingsService.idleDimDuration
        respectInhibitors: Config.idleRespectInhibitors
        timeout: Math.max(0, root.normalDisplayTimeout - QuickSettingsService.idleDimDuration)

        onIsIdleChanged: {
            if (isIdle)
                root.show();
        }
    }
    property IdleMonitor normalDisplayMonitor: IdleMonitor {
        enabled: root.policyEnabled && !root.monitorsPoweredOff && !StateManager.sessionLocked && root.normalDisplayTimeout > 0
        respectInhibitors: Config.idleRespectInhibitors
        timeout: root.normalDisplayTimeout

        onIsIdleChanged: {
            if (isIdle)
                root.lockAndPowerOff();
        }
    }
    readonly property int normalDisplayTimeout: Math.max(0, QuickSettingsService.effectiveIdleDisplayTimeout)
    property IdleMonitor normalLockMonitor: IdleMonitor {
        enabled: root.policyEnabled && !Config.idleRespectInhibitors && !StateManager.sessionLocked && root.normalLockTimeout > 0 && root.normalLockTimeout !== root.normalDisplayTimeout
        respectInhibitors: false
        timeout: root.normalLockTimeout

        onIsIdleChanged: {
            if (isIdle)
                root.lockSession();
        }
    }
    readonly property int normalLockTimeout: Math.max(0, QuickSettingsService.effectiveIdleLockTimeout)
    readonly property string normalSleepAction: QuickSettingsService.effectiveIdleSleepAction
    property IdleMonitor normalSuspendMonitor: IdleMonitor {
        enabled: root.policyEnabled && !Config.idleRespectInhibitors && root.normalSuspendTimeout > 0 && root.normalSleepAction !== "none"
        respectInhibitors: false
        timeout: root.normalSuspendTimeout

        onIsIdleChanged: {
            if (isIdle)
                root.requestSleep();
        }
    }
    readonly property int normalSuspendTimeout: Math.max(0, QuickSettingsService.effectiveIdleSuspendTimeout)
    readonly property bool policyEnabled: Config.idleEnabled && QuickSettingsService.idlePolicyReady && !QuickSettingsService.caffeineEnabled
    property Process powerOffProcess: Process {
        command: ["niri", "msg", "action", "power-off-monitors"]

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.monitorsPoweredOff = false;
                console.warn("[IdleDimService] Failed to power off monitors:", exitCode);
            }
        }
    }
    property real previewOpacity: -1
    property Timer previewTimer: Timer {
        interval: 1800
        repeat: false

        onTriggered: {
            if (root.previewing)
                root.hide();
        }
    }
    property bool previewing: false
    property Process sleepProcess: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("[IdleDimService] Failed to enter", root.normalSleepAction + ":", exitCode);
        }
    }

    function handleUserActivity() {
        hide();
        if (!monitorsPoweredOff)
            return;

        monitorsPoweredOff = false;
        faceRetryAttempts = 0;
        Qt.callLater(root.retryFaceAfterWake);
    }
    function hide() {
        previewTimer.stop();
        previewOpacity = -1;
        previewing = false;
        if (active)
            console.info("[IdleDimService] Hiding idle dim");
        active = false;
    }
    function lockAndPowerOff() {
        if (!StateManager.sessionLocked && normalLockTimeout > 0 && normalLockTimeout <= normalDisplayTimeout)
            lockSession();

        Qt.callLater(root.powerOffMonitors);
    }
    function lockSession() {
        if (StateManager.sessionLocked)
            return;

        console.info("[IdleDimService] Locking idle session");
        StateManager.lockScreen();
    }
    function powerOffMonitors() {
        if (powerOffProcess.running)
            return;
        monitorsPoweredOff = true;
        console.info("[IdleDimService] Powering off monitors after", StateManager.sessionLocked ? lockedDisplayTimeout : normalDisplayTimeout, "seconds");
        powerOffProcess.running = true;
    }
    function preview(opacity) {
        var requestedOpacity = Number(opacity);
        previewOpacity = isFinite(requestedOpacity) ? Math.max(0.2, Math.min(0.9, requestedOpacity)) : Config.idleDimOpacity;
        previewing = true;
        active = true;
        previewTimer.restart();
    }
    function requestSleep() {
        if (sleepProcess.running || normalSleepAction === "none")
            return;
        if (Config.idleLockBeforeSleep)
            lockSession();

        sleepProcess.command = ["systemctl", normalSleepAction];
        sleepProcess.running = true;
    }
    function retryFaceAfterWake() {
        if (Config.lockFaceRetryOnWake)
            retryFaceAuthentication();
    }
    function retryFaceAuthentication() {
        if (!StateManager.sessionLocked || faceRetryCoolingDown)
            return;

        var loader = StateManager.lockscreenLoader;
        if (loader && loader.active && loader.item && typeof loader.item.retryFace === "function") {
            faceRetryAttempts = 0;
            faceRetryCoolingDown = true;
            loader.item.retryFace();
            faceRetryCooldownTimer.restart();
            return;
        }

        faceRetryAttempts += 1;
        if (faceRetryAttempts < 20)
            faceRetryTimer.restart();
    }
    function show() {
        previewTimer.stop();
        previewOpacity = -1;
        previewing = false;
        console.info("[IdleDimService] Starting idle dim");
        active = true;
    }
}
