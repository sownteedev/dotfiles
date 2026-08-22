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
        respectInhibitors: false
        timeout: Math.max(0, root.normalDisplayTimeout - QuickSettingsService.idleDimDuration)

        onIsIdleChanged: {
            if (isIdle)
                root.show();
        }
    }
    property IdleMonitor normalDisplayMonitor: IdleMonitor {
        enabled: root.policyEnabled && !root.monitorsPoweredOff && !StateManager.sessionLocked && root.normalDisplayTimeout > 0
        respectInhibitors: false
        timeout: root.normalDisplayTimeout

        onIsIdleChanged: {
            if (isIdle)
                root.lockAndPowerOff();
        }
    }
    readonly property int normalDisplayTimeout: Math.max(0, Config.idleDisplayTimeout)
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

    function handleUserActivity() {
        hide();
        if (!monitorsPoweredOff)
            return;

        monitorsPoweredOff = false;
        faceRetryAttempts = 0;
        Qt.callLater(root.retryFaceAuthentication);
    }
    function hide() {
        if (active)
            console.info("[IdleDimService] Hiding idle dim");
        active = false;
    }
    function lockAndPowerOff() {
        if (!StateManager.sessionLocked) {
            console.info("[IdleDimService] Locking session and powering off monitors");
            StateManager.lockScreen();
        }

        Qt.callLater(root.powerOffMonitors);
    }
    function powerOffMonitors() {
        if (powerOffProcess.running)
            return;
        monitorsPoweredOff = true;
        console.info("[IdleDimService] Powering off monitors after", StateManager.sessionLocked ? lockedDisplayTimeout : normalDisplayTimeout, "seconds");
        powerOffProcess.running = true;
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
        console.info("[IdleDimService] Starting idle dim");
        active = true;
    }
}
