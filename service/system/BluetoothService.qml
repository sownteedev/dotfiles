pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    readonly property string a2dpSinkUuid: "0000110b-0000-1000-8000-00805f9b34fb"
    property string action: ""
    property Process actionProcess: Process {
        stderr: SplitParser {
            onRead: line => root.handleProcessOutput(line)
        }
        stdout: SplitParser {
            onRead: line => root.handleProcessOutput(line)
        }

        onExited: (exitCode, exitStatus) => root.handleStepFinished(exitCode)
    }
    property Timer actionTimeout: Timer {
        interval: 23000

        onTriggered: root.failAction()
    }
    readonly property bool busy: pendingAddress !== ""
    property Timer clearErrorTimer: Timer {
        interval: 5000

        onTriggered: {
            root.lastError = "";
            root.lastErrorAddress = "";
        }
    }
    property string lastError: ""
    property string lastErrorAddress: ""
    property string nextStep: ""
    property string pendingAddress: ""
    property var pendingDevice: null
    property bool preferA2dp: false
    property string processOutput: ""

    // Hot reload can terminate Process before its exited signal reaches the
    // restored singleton. Never leave a device card stuck in a pending state.
    property Timer staleActionGuard: Timer {
        interval: 600
        running: root.busy && !root.actionProcess.running && !root.stepDelay.running

        onTriggered: root.finishAction()
    }
    readonly property string statusText: {
        if (action === "pair")
            return step.indexOf("connect") === 0 ? "Connecting…" : "Pairing…";
        if (action === "connect")
            return step.indexOf("connect") === 0 ? "Connecting…" : "Preparing connection…";
        if (action === "disconnect")
            return "Disconnecting…";
        if (action === "forget")
            return "Removing…";
        return "Working…";
    }
    property string step: ""
    property Timer stepDelay: Timer {
        onTriggered: root.runStep(root.nextStep)
    }

    function beginAction(actionName, device) {
        if (!device || busy)
            return false;
        pendingDevice = device;
        pendingAddress = normalizeAddress(device.address);
        var icon = String(device.icon || "").toLowerCase();
        preferA2dp = icon.indexOf("audio") !== -1 || icon.indexOf("headset") !== -1 || icon.indexOf("headphone") !== -1;
        action = actionName;
        lastError = "";
        lastErrorAddress = "";
        clearErrorTimer.stop();
        return pendingAddress !== "";
    }
    function connect(device) {
        if (!beginAction("connect", device))
            return;
        runStep("trust");
    }
    function disconnect(device) {
        if (!beginAction("disconnect", device))
            return;
        runStep("disconnect");
    }
    function failAction() {
        var failedAction = action;
        lastErrorAddress = pendingAddress;
        if (failedAction === "pair")
            lastError = "Pairing failed";
        else if (failedAction === "connect")
            lastError = "Connection failed";
        else if (failedAction === "disconnect")
            lastError = "Could not disconnect";
        else
            lastError = "Could not remove device";
        actionProcess.running = false;
        finishAction();
        clearErrorTimer.restart();
    }
    function finishAction() {
        actionTimeout.stop();
        stepDelay.stop();
        if (pendingDevice && (action === "pair" || action === "connect"))
            pendingDevice.trusted = true;
        pendingDevice = null;
        pendingAddress = "";
        action = "";
        step = "";
        nextStep = "";
        processOutput = "";
        preferA2dp = false;
    }
    function forget(device) {
        if (!beginAction("forget", device))
            return;
        runStep("remove");
    }
    function handleProcessOutput(line) {
        processOutput += line + "\n";
        var cleaned = line.replace(/\x1b\[[0-9;]*m/g, "").toLowerCase();
        if (action === "forget" && cleaned.indexOf("device has been removed") !== -1) {
            finishAction();
            actionProcess.running = false;
        }
    }
    function handleStepFinished(exitCode) {
        if (pendingAddress === "")
            return;
        actionTimeout.stop();
        if (exitCode !== 0 || outputIndicatesFailure()) {
            failAction();
            return;
        }

        if (action === "pair" && step === "pair") {
            queueStep("trust", 900);
        } else if (action === "pair" && step === "trust" && preferA2dp) {
            queueStep("disconnect-pair", 300);
        } else if (action === "pair" && step === "disconnect-pair") {
            queueStep("connect-a2dp", 400);
        } else if (action === "connect" && step === "trust") {
            queueStep(preferredConnectStep(), 250);
        } else {
            finishAction();
        }
    }
    function normalizeAddress(address) {
        var clean = String(address || "").replace(/[:-]/g, "").toUpperCase();
        if (clean.length !== 12)
            return String(address || "");
        return clean.match(/.{2}/g).join(":");
    }
    function outputIndicatesFailure() {
        var output = processOutput.toLowerCase();
        if (output.indexOf("already connected") !== -1 || output.indexOf("already exists") !== -1)
            return false;
        if (step === "disconnect-pair" && (output.indexOf("not connected") !== -1 || output.indexOf("notconnected") !== -1 || output.indexOf("connection-unknown") !== -1))
            return false;
        return output.indexOf("failed to") !== -1 || output.indexOf("not available") !== -1;
    }
    function pair(device) {
        if (!beginAction("pair", device))
            return;
        runStep("pair");
    }
    function preferredConnectStep() {
        return preferA2dp ? "connect-a2dp" : "connect";
    }
    function queueStep(stepName, delay) {
        nextStep = stepName;
        stepDelay.interval = delay;
        stepDelay.restart();
    }
    function runStep(stepName) {
        stepDelay.stop();
        step = stepName;
        processOutput = "";
        actionTimeout.restart();
        actionProcess.running = false;
        var commandName = stepName;
        if (stepName === "connect-a2dp")
            commandName = "connect";
        else if (stepName === "disconnect-pair")
            commandName = "disconnect";

        var command = ["bluetoothctl", "--agent=NoInputNoOutput", commandName, pendingAddress];
        if (stepName === "connect-a2dp")
            command.push(a2dpSinkUuid);
        actionProcess.command = command;
        actionProcess.running = true;
    }
}
