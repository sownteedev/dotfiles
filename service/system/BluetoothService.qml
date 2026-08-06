pragma Singleton
import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io
import "../../"

QtObject {
    id: root

    property string action: ""
    property Process actionProcess: Process {
        stdinEnabled: true

        stderr: SplitParser {
            onRead: line => root.handleProcessOutput(line)
        }
        stdout: SplitParser {
            onRead: line => root.handleProcessOutput(line)
        }

        onExited: (exitCode, exitStatus) => root.handleStepFinished(exitCode)
        onStarted: {
            if (root.action === "pair" && root.step === "pair")
                write("pair " + root.pendingAddress + "\n");
        }
    }
    property Timer actionTimeout: Timer {
        interval: 23000

        onTriggered: root.failAction()
    }
    property string airpodsAddress: ""
    property var airpodsBattery: null
    readonly property bool airpodsBatteryAvailable: airpodsBattery !== null
    property Process airpodsBatteryProcess: Process {
        command: [Config.quickshellDir + "/scripts/airpods_battery", root.airpodsAddress]

        stderr: SplitParser {
            onRead: line => root.airpodsProcessError = String(line || "").trim()
        }
        stdout: SplitParser {
            onRead: line => root.handleAirpodsBatteryOutput(line)
        }

        onExited: (exitCode, exitStatus) => {
            root.airpodsBatteryScanning = false;
            if (root.airpodsMonitoringEnabled && root.airpodsAddress !== "") {
                if (root.airpodsRestartRequested) {
                    root.airpodsRestartRequested = false;
                    root.airpodsRetryAttempts = 0;
                    root.airpodsPollTimer.interval = 250;
                } else if (exitCode !== 0) {
                    root.airpodsRetryAttempts += 1;
                    root.airpodsPollTimer.interval = Math.min(30000, 1500 * Math.pow(2, Math.min(root.airpodsRetryAttempts, 4)));
                    if (root.airpodsRetryAttempts === 1 && root.airpodsProcessError !== "")
                        console.warn("[BluetoothService] AirPods battery reader:", root.airpodsProcessError);
                }
                root.airpodsPollTimer.restart();
            }
        }
    }
    property bool airpodsBatteryScanning: false
    property Timer airpodsCacheExpiry: Timer {
        interval: 120000

        onTriggered: {
            root.airpodsBattery = null;
            if (root.airpodsBatteryProcess.running) {
                root.airpodsRestartRequested = true;
                root.airpodsBatteryProcess.running = false;
            }
            if (root.airpodsMonitoringEnabled && root.airpodsAddress !== "")
                root.airpodsPollTimer.restart();
        }
    }
    property bool airpodsMonitoringEnabled: false
    property Timer airpodsPollTimer: Timer {
        interval: 1500

        onTriggered: root.requestAirpodsBattery()
    }
    property string airpodsProcessError: ""
    property bool airpodsRestartRequested: false
    property int airpodsRetryAttempts: 0
    readonly property bool busy: pendingAddress !== ""
    property Timer clearErrorTimer: Timer {
        interval: 5000

        onTriggered: {
            root.lastError = "";
            root.lastErrorAddress = "";
        }
    }
    property int connectVerifyAttempts: 0
    property Timer connectVerifyTimer: Timer {
        interval: 350

        onTriggered: root.verifyConnectionState()
    }
    property string lastError: ""
    property string lastErrorAddress: ""
    property var nearbyAddresses: ({})
    property Process nearbyProbeProcess: Process {
        id: nearbyProbeProcess

        stdout: StdioCollector {
            id: nearbyProbeOutput
        }

        onExited: root.handleNearbyProbeOutput(nearbyProbeOutput.text)
    }
    property int nearbyRevision: 0
    property string nextStep: ""
    property Timer pairAgentSettleTimer: Timer {
        interval: 700

        onTriggered: {
            if (root.action === "pair" && root.step === "pair" && root.actionProcess.running)
                root.actionProcess.running = false;
        }
    }
    property bool pairBondObserved: false
    property int pairVerifyAttempts: 0
    property Timer pairVerifyTimer: Timer {
        interval: 350

        onTriggered: root.verifyPairState()
    }
    property string pendingAddress: ""
    property var pendingDevice: null
    property string processOutput: ""

    // Hot reload can terminate Process before its exited signal reaches the
    // restored singleton. Never leave a device card stuck in a pending state.
    property Timer staleActionGuard: Timer {
        interval: 600
        running: root.busy && !root.actionProcess.running && !root.stepDelay.running && !root.pairVerifyTimer.running && !root.connectVerifyTimer.running

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
        action = actionName;
        lastError = "";
        lastErrorAddress = "";
        clearErrorTimer.stop();
        connectVerifyAttempts = 0;
        pairBondObserved = false;
        return pendingAddress !== "";
    }
    function beginNearbyScan() {
        nearbyAddresses = ({});
        nearbyRevision += 1;
    }
    function connect(device) {
        if (!beginAction("connect", device))
            return;
        runStep("trust");
    }
    function currentPendingDevice() {
        var adapter = Bluetooth.defaultAdapter;
        var devices = adapter ? adapter.devices.values : [];
        for (var i = 0; i < devices.length; ++i) {
            if (normalizeAddress(devices[i].address) === pendingAddress)
                return devices[i];
        }
        return null;
    }
    function disconnect(device) {
        if (!beginAction("disconnect", device))
            return;
        runStep("disconnect");
    }
    function failAction() {
        var failedAction = action;
        lastErrorAddress = pendingAddress;
        if (failedAction === "pair") {
            var failureOutput = processOutput.toLowerCase();
            if (step.indexOf("connect") === 0)
                lastError = "Paired · connection failed";
            else
                lastError = failureOutput.indexOf("connectionattemptfailed") !== -1 || failureOutput.indexOf("page-timeout") !== -1 ? "Put AirPods in pairing mode" : "Pairing failed";
        } else if (failedAction === "connect")
            lastError = "Connection failed";
        else if (failedAction === "disconnect")
            lastError = "Could not disconnect";
        else
            lastError = "Could not remove device";
        actionProcess.running = false;
        connectVerifyTimer.stop();
        pairAgentSettleTimer.stop();
        pairVerifyTimer.stop();
        finishAction();
        clearErrorTimer.restart();
    }
    function finishAction() {
        actionTimeout.stop();
        connectVerifyTimer.stop();
        pairAgentSettleTimer.stop();
        pairVerifyTimer.stop();
        stepDelay.stop();
        pendingDevice = null;
        pendingAddress = "";
        action = "";
        step = "";
        nextStep = "";
        processOutput = "";
        pairBondObserved = false;
        connectVerifyAttempts = 0;
        pairVerifyAttempts = 0;
    }
    function forget(device) {
        if (!beginAction("forget", device))
            return;
        runStep("remove");
    }
    function handleAirpodsBatteryOutput(output) {
        var cleaned = String(output || "").trim();
        if (cleaned === "")
            return;
        try {
            var data = JSON.parse(cleaned);
            if (normalizeAddress(data.address) !== airpodsAddress)
                return;
            if (data.available && data.accurate === true) {
                airpodsBattery = data;
                airpodsBatteryScanning = false;
                airpodsRetryAttempts = 0;
                airpodsPollTimer.interval = 1500;
                airpodsProcessError = "";
                airpodsCacheExpiry.restart();
            } else {
                airpodsBattery = null;
                airpodsCacheExpiry.stop();
            }
        } catch (error) {
            console.warn("[BluetoothService] Invalid AirPods battery data:", error);
        }
    }
    function handleNearbyProbeOutput(output) {
        var addresses = ({});
        var lines = String(output || "").split(/\r?\n/);
        for (var i = 0; i < lines.length; ++i) {
            var address = normalizeAddress(lines[i].trim());
            if (address !== "")
                addresses[address] = true;
        }
        nearbyAddresses = addresses;
        nearbyRevision += 1;
    }
    function handleProcessOutput(line) {
        processOutput += line + "\n";
        var cleaned = line.replace(/\x1b\[[0-9;]*m/g, "").toLowerCase();
        if (action === "pair" && step === "pair") {
            if (cleaned.indexOf("bonded: yes") !== -1) {
                pairBondObserved = true;
                pairAgentSettleTimer.restart();
            } else if (cleaned.indexOf("failed to pair") !== -1 || cleaned.indexOf("not available") !== -1) {
                failAction();
                return;
            }
        }
        if (action === "forget" && cleaned.indexOf("device has been removed") !== -1) {
            finishAction();
            actionProcess.running = false;
        }
    }
    function handleStepFinished(exitCode) {
        if (pendingAddress === "")
            return;
        actionTimeout.stop();
        if (action === "pair" && step === "pair" && pairBondObserved) {
            pairBondObserved = false;
            queueStep("trust", 200);
            return;
        }
        if (exitCode !== 0 || outputIndicatesFailure()) {
            failAction();
            return;
        }

        if (action === "pair" && step === "pair") {
            pairVerifyAttempts = 0;
            pairVerifyTimer.restart();
        } else if (action === "pair" && step === "trust") {
            var pairedDevice = currentPendingDevice();
            if (pairedDevice && pairedDevice.connected)
                finishAction();
            else
                queueStep(preferredConnectStep(), 300);
        } else if (action === "connect" && step === "trust") {
            queueStep(preferredConnectStep(), 250);
        } else if ((action === "connect" || action === "pair") && step === "connect") {
            connectVerifyAttempts = 0;
            connectVerifyTimer.restart();
        } else {
            finishAction();
        }
    }
    function isNearby(address) {
        var revision = nearbyRevision;
        return nearbyAddresses[normalizeAddress(address)] === true;
    }
    function normalizeAddress(address) {
        var clean = String(address || "").replace(/[:-]/g, "").toUpperCase();
        if (clean.length !== 12)
            return String(address || "");
        return clean.match(/.{2}/g).join(":");
    }
    function outputIndicatesFailure() {
        var output = processOutput.toLowerCase();
        if (output.indexOf("already connected") !== -1)
            return false;
        if (output.indexOf("already exists") !== -1) {
            var device = currentPendingDevice();
            return !(device && device.bonded);
        }
        return output.indexOf("failed to") !== -1 || output.indexOf("not available") !== -1;
    }
    function pair(device) {
        if (!beginAction("pair", device))
            return;
        runStep("pair");
    }
    function preferredConnectStep() {
        return "connect";
    }
    function probeNearbyDevices(devices) {
        if (nearbyProbeProcess.running)
            return;
        var command = [Config.quickshellDir + "/scripts/bluetooth_nearby"];
        for (var i = 0; i < devices.length; ++i) {
            var device = devices[i];
            if (!device || device.paired || device.bonded || device.trusted)
                continue;
            var address = normalizeAddress(device.address);
            var path = String(device.dbusPath || "");
            if (address !== "" && path !== "") {
                command.push(address);
                command.push(path);
            }
        }
        nearbyProbeProcess.command = command;
        nearbyProbeProcess.running = true;
    }
    function queueStep(stepName, delay) {
        nextStep = stepName;
        stepDelay.interval = delay;
        stepDelay.restart();
    }
    function requestAirpodsBattery() {
        if (!airpodsMonitoringEnabled || airpodsAddress === "" || airpodsBatteryProcess.running)
            return;
        airpodsPollTimer.stop();
        airpodsBatteryScanning = true;
        airpodsProcessError = "";
        airpodsBatteryProcess.running = true;
    }
    function runStep(stepName) {
        stepDelay.stop();
        step = stepName;
        processOutput = "";
        actionTimeout.interval = stepName === "pair" ? 45000 : 23000;
        actionTimeout.restart();
        actionProcess.running = false;
        var command = stepName === "pair" ? ["bluetoothctl", "--agent=NoInputNoOutput"] : ["bluetoothctl", "--agent=NoInputNoOutput", stepName, pendingAddress];
        actionProcess.command = command;
        actionProcess.running = true;
    }
    function setAirpodsDevice(address, enabled) {
        var normalized = enabled ? normalizeAddress(address) : "";
        var changed = normalized !== airpodsAddress;
        var wasRunning = airpodsBatteryProcess.running;
        airpodsMonitoringEnabled = enabled && normalized !== "";
        if (changed) {
            airpodsAddress = normalized;
            airpodsBattery = null;
            airpodsRetryAttempts = 0;
            airpodsPollTimer.interval = 1500;
            airpodsProcessError = "";
            airpodsCacheExpiry.stop();
            if (airpodsBatteryProcess.running) {
                airpodsRestartRequested = airpodsMonitoringEnabled;
                airpodsBatteryProcess.running = false;
            }
        }
        if (airpodsMonitoringEnabled) {
            if (!wasRunning)
                requestAirpodsBattery();
        } else {
            airpodsRestartRequested = false;
            airpodsPollTimer.stop();
        }
    }
    function verifyConnectionState() {
        if (action !== "connect" && action !== "pair")
            return;
        var device = currentPendingDevice();
        if (device && device.connected) {
            finishAction();
            return;
        }
        connectVerifyAttempts += 1;
        if (connectVerifyAttempts >= 10) {
            failAction();
            return;
        }
        connectVerifyTimer.restart();
    }
    function verifyPairState() {
        if (action !== "pair" || !pendingDevice)
            return;
        var device = currentPendingDevice();
        if (device && device.bonded) {
            pendingDevice = device;
            queueStep("trust", 0);
            return;
        }
        pairVerifyAttempts += 1;
        if (pairVerifyAttempts >= 16) {
            failAction();
            return;
        }
        pairVerifyTimer.restart();
    }
}
