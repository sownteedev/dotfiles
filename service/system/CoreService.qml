pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../.."

QtObject {
    id: root

    property bool batteryEnabled: false
    property Timer batteryRetry: Timer {
        interval: 800
        repeat: false

        onTriggered: {
            if (root.batteryEnabled && root.ready && !batterySocket.connected)
                batterySocket.connected = true;
        }
    }
    property Socket batterySocket: Socket {
        id: batterySocket

        connected: false
        path: root.socketPath

        parser: SplitParser {
            splitMarker: "\n"

            onRead: line => root.handleBatteryLine(line)
        }

        onConnectionStateChanged: {
            if (!connected) {
                root.batterySubscribed = false;
                if (root.batteryEnabled && root.ready)
                    root.batteryRetry.restart();
                return;
            }
            root.writeSubscriptionRequest(batterySocket, "battery-subscribe", "battery.subscribe", {});
        }
        onError: error => root.handleBatteryDisconnect()
    }
    property bool batterySubscribed: false
    property var cancelQueue: []
    property Timer cancelRetry: Timer {
        interval: 500
        repeat: false

        onTriggered: {
            if (root.cancelQueue.length === 0 || cancelSocket.connected || !root.ready)
                return;
            cancelSocket.connected = true;
        }
    }
    property Socket cancelSocket: Socket {
        id: cancelSocket

        connected: false
        path: root.socketPath

        parser: SplitParser {
            splitMarker: "\n"

            onRead: line => root.handleCancelLine(line)
        }

        onConnectionStateChanged: {
            if (connected) {
                root.flushCancelQueue();
                return;
            }
            if (root.cancelQueue.length > 0 && root.ready)
                root.cancelRetry.restart();
        }
        onError: error => root.handleCancelDisconnect()
    }
    property Timer connectionRetry: Timer {
        interval: 500
        repeat: true

        onTriggered: {
            if (requestSocket.connected) {
                stop();
                return;
            }
            requestSocket.connected = false;
            Qt.callLater(function () {
                if (!requestSocket.connected)
                    requestSocket.connected = true;
            });
        }
    }
    property Process daemonProcess: Process {
        id: daemonProcess

        command: [Config.sownteeshellDir + "/backend/rust/core-daemon/run-core-daemon", "serve"]
        running: false

        stderr: SplitParser {
            onRead: line => {
                var message = String(line || "").trim();
                if (message !== "" && message.indexOf("listening at") < 0)
                    console.log("[CoreService]", message);
            }
        }

        onExited: exitCode => {
            root.daemonStarted = false;
            if (!requestSocket.connected) {
                root.daemonStatus = "stopped";
                root.daemonRestart.restart();
            }
        }
        onStarted: {
            root.daemonStarted = true;
            root.daemonStatus = "starting";
            root.connectionRetry.restart();
        }
    }
    property Timer daemonRestart: Timer {
        interval: 5000
        repeat: false

        onTriggered: root.ensureRunning()
    }
    property Timer daemonStartDelay: Timer {
        interval: 5000
        repeat: false

        onTriggered: {
            if (!root.requestSocket.connected)
                root.daemonRestart.restart();
        }
    }
    property bool daemonStarted: false
    property string daemonStatus: "starting"
    readonly property string daemonUnit: "sownteeshell-core.service"
    property double lastBatteryUpdate: 0
    property double lastStatsUpdate: 0
    property double lastUpdatesUpdate: 0
    property int nextRequestId: 1
    property var pendingRequests: ({})
    readonly property bool ready: requestSocket.connected
    property Socket requestSocket: Socket {
        id: requestSocket

        connected: false
        path: root.socketPath

        parser: SplitParser {
            splitMarker: "\n"

            onRead: line => root.handleResponse(line)
        }

        onConnectionStateChanged: root.handleRequestConnection()
        onError: error => root.requestReconnect()
    }
    readonly property int requestTimeoutMs: 30000
    property Timer requestTimeoutSweep: Timer {
        interval: 500
        repeat: true
        running: Object.keys(root.pendingRequests).length > 0

        onTriggered: root.expirePendingRequests()
    }
    readonly property string runtimeBase: Quickshell.env("XDG_RUNTIME_DIR") || ""
    readonly property string socketOverride: Quickshell.env("SOWNTEE_CORE_SOCKET") || ""
    readonly property string socketPath: socketOverride !== "" ? socketOverride : (runtimeBase !== "" ? runtimeBase + "/sownteeshell/core/core.sock" : (Quickshell.env("XDG_DATA_HOME") || Config.homeDir + "/.local/share") + "/sownteeshell/core/runtime/core.sock")
    property bool statsEnabled: false
    property string statsMode: "none"
    property Timer statsRetry: Timer {
        interval: 800
        repeat: false

        onTriggered: {
            if (root.statsEnabled && root.ready && !statsSocket.connected)
                statsSocket.connected = true;
        }
    }
    property Socket statsSocket: Socket {
        id: statsSocket

        connected: false
        path: root.socketPath

        parser: SplitParser {
            splitMarker: "\n"

            onRead: line => root.handleStatsLine(line)
        }

        onConnectionStateChanged: {
            if (!connected) {
                root.statsSubscribed = false;
                if (root.statsEnabled && root.ready)
                    root.statsRetry.restart();
                return;
            }
            root.writeSubscriptionRequest(statsSocket, "stats-subscribe", "stats.subscribe", {
                "mode": root.statsMode
            });
        }
        onError: error => root.handleStatsDisconnect()
    }
    property bool statsSubscribed: false
    property Process systemdStarter: Process {
        id: systemdStarter

        command: ["systemctl", "--user", "start", "--no-block", root.daemonUnit]
        running: false

        stderr: StdioCollector {
        }
        stdout: StdioCollector {
        }

        onExited: (exitCode, exitStatus) => {
            if (requestSocket.connected)
                return;
            if (exitCode !== 0) {
                root.daemonStatus = "stopped";
                root.daemonStartDelay.stop();
                root.daemonRestart.restart();
            }
        }
        onStarted: {
            root.daemonStatus = "starting";
            root.daemonStartDelay.restart();
        }
    }
    property bool updatesEnabled: false
    property Timer updatesRetry: Timer {
        interval: 800
        repeat: false

        onTriggered: {
            if (root.updatesEnabled && root.ready && !updatesSocket.connected)
                updatesSocket.connected = true;
        }
    }
    property Socket updatesSocket: Socket {
        id: updatesSocket

        connected: false
        path: root.socketPath

        parser: SplitParser {
            splitMarker: "\n"

            onRead: line => root.handleUpdatesLine(line)
        }

        onConnectionStateChanged: {
            if (!connected) {
                root.updatesSubscribed = false;
                if (root.updatesEnabled && root.ready)
                    root.updatesRetry.restart();
                return;
            }
            root.writeSubscriptionRequest(updatesSocket, "updates-subscribe", "updates.subscribe", {});
        }
        onError: error => root.handleUpdatesDisconnect()
    }
    property bool updatesSubscribed: false

    signal batteryUpdated(var data)
    signal statsUpdated(var data)
    signal updatesFailed(string message)
    signal updatesUpdated(var data)

    function cancelJob(jobId) {
        var normalizedJobId = String(jobId || "").trim();
        if (normalizedJobId === "")
            return false;
        var queued = cancelQueue.slice();
        if (queued.indexOf(normalizedJobId) < 0) {
            queued.push(normalizedJobId);
            if (queued.length > 64)
                queued.shift();
            cancelQueue = queued;
        }
        if (cancelSocket.connected)
            flushCancelQueue();
        else if (ready)
            cancelSocket.connected = true;
        else
            ensureRunning();
        return true;
    }
    function closeSubscriptions() {
        statsRetry.stop();
        batteryRetry.stop();
        updatesRetry.stop();
        statsSubscribed = false;
        batterySubscribed = false;
        updatesSubscribed = false;
        if (statsSocket.connected)
            statsSocket.connected = false;
        if (batterySocket.connected)
            batterySocket.connected = false;
        if (updatesSocket.connected)
            updatesSocket.connected = false;
    }
    function ensureRunning() {
        if (requestSocket.connected) {
            daemonStartDelay.stop();
            daemonRestart.stop();
            return;
        }
        if (!connectionRetry.running)
            connectionRetry.start();
        if (socketOverride !== "") {
            startFallbackDaemon();
            return;
        }
        if (systemdStarter.running || daemonStartDelay.running || daemonRestart.running)
            return;
        systemdStarter.running = true;
    }
    function expirePendingRequests() {
        var now = Date.now();
        var pending = pendingRequests;
        var identifiers = Object.keys(pending);
        var expired = [];
        var nextPending = Object.assign({}, pending);
        for (var index = 0; index < identifiers.length; ++index) {
            var identifier = identifiers[index];
            var entry = pending[identifier];
            if (!entry || Number(entry.deadline || 0) > now)
                continue;
            expired.push(entry);
            delete nextPending[identifier];
        }
        if (expired.length === 0)
            return;
        pendingRequests = nextPending;
        for (var expiredIndex = 0; expiredIndex < expired.length; ++expiredIndex) {
            if (expired[expiredIndex].failure)
                expired[expiredIndex].failure(qsTr("Core request timed out."));
        }
    }
    function failPendingRequests(message) {
        var pending = pendingRequests;
        var identifiers = Object.keys(pending);
        pendingRequests = ({});
        for (var index = 0; index < identifiers.length; ++index) {
            var entry = pending[identifiers[index]];
            if (entry && entry.failure)
                entry.failure(message);
        }
    }
    function flushCancelQueue() {
        if (!cancelSocket.connected || cancelQueue.length === 0)
            return;
        var queued = cancelQueue;
        cancelQueue = [];
        for (var index = 0; index < queued.length; ++index) {
            cancelSocket.write(JSON.stringify({
                "id": "cancel-" + String(nextRequestId++),
                "method": "job.cancel",
                "params": {
                    "jobId": queued[index]
                }
            }) + "\n");
        }
        cancelSocket.flush();
    }
    function forgetRequest(requestId) {
        var id = String(requestId || "");
        if (id === "" || !pendingRequests[id])
            return;
        var nextPending = Object.assign({}, pendingRequests);
        delete nextPending[id];
        pendingRequests = nextPending;
    }
    function handleBatteryDisconnect() {
        batterySubscribed = false;
        if (batterySocket.connected)
            batterySocket.connected = false;
        if (batteryEnabled && ready)
            batteryRetry.restart();
    }
    function handleBatteryLine(line) {
        var response = parseLine(line, "battery");
        if (!response)
            return;
        if (response.ok === true && String(response.id || "") === "battery-subscribe") {
            batterySubscribed = true;
            return;
        }
        if (response.event === "battery.updated" && response.data) {
            lastBatteryUpdate = Date.now();
            batteryUpdated(response.data);
        }
    }
    function handleCancelDisconnect() {
        if (cancelSocket.connected)
            cancelSocket.connected = false;
        if (cancelQueue.length > 0 && ready)
            cancelRetry.restart();
    }
    function handleCancelLine(line) {
        var response = parseLine(line, "cancel");
        if (!response || response.ok !== false)
            return;
        var message = response.error && response.error.message ? String(response.error.message) : qsTr("Core cancellation failed.");
        console.warn("[CoreService]", message);
    }
    function handleRequestConnection() {
        if (!requestSocket.connected) {
            daemonStatus = "connecting";
            closeSubscriptions();
            failPendingRequests(qsTr("Core backend disconnected."));
            ensureRunning();
            return;
        }
        connectionRetry.stop();
        daemonStartDelay.stop();
        daemonRestart.stop();
        daemonStatus = "ready";
        if (!cancelSocket.connected)
            cancelSocket.connected = true;
        if (statsEnabled && !statsSocket.connected)
            statsSocket.connected = true;
        if (batteryEnabled && !batterySocket.connected)
            batterySocket.connected = true;
        if (updatesEnabled && !updatesSocket.connected)
            updatesSocket.connected = true;
    }
    function handleResponse(line) {
        var response = parseLine(line, "request");
        if (!response)
            return;
        var id = String(response.id === undefined || response.id === null ? "" : response.id);
        var entry = pendingRequests[id];
        if (!entry)
            return;
        var nextPending = Object.assign({}, pendingRequests);
        delete nextPending[id];
        pendingRequests = nextPending;
        if (response.ok === true) {
            if (entry.success)
                entry.success(response.result);
            return;
        }
        var message = response.error && response.error.message ? String(response.error.message) : qsTr("Core request failed.");
        if (entry.failure)
            entry.failure(message);
    }
    function handleStatsDisconnect() {
        statsSubscribed = false;
        if (statsSocket.connected)
            statsSocket.connected = false;
        if (statsEnabled && ready)
            statsRetry.restart();
    }
    function handleStatsLine(line) {
        var response = parseLine(line, "stats");
        if (!response)
            return;
        if (response.ok === true && String(response.id || "") === "stats-subscribe") {
            statsSubscribed = true;
            if (response.result && String(response.result.mode || "none") !== statsMode)
                writeStatsMode();
            return;
        }
        if (response.event === "stats.updated" && response.data) {
            lastStatsUpdate = Date.now();
            statsUpdated(response.data);
        }
    }
    function handleUpdatesDisconnect() {
        updatesSubscribed = false;
        if (updatesSocket.connected)
            updatesSocket.connected = false;
        if (updatesEnabled && ready)
            updatesRetry.restart();
    }
    function handleUpdatesLine(line) {
        var response = parseLine(line, "updates");
        if (!response)
            return;
        var identifier = String(response.id || "");
        if (response.ok === true && identifier === "updates-subscribe") {
            updatesSubscribed = true;
            return;
        }
        if (response.ok === true && identifier === "updates-refresh") {
            lastUpdatesUpdate = Date.now();
            updatesUpdated(response.result || {});
            return;
        }
        if (response.ok === false && (identifier === "updates-subscribe" || identifier === "updates-refresh")) {
            var message = response.error && response.error.message ? String(response.error.message) : qsTr("Update check failed.");
            updatesFailed(message);
            return;
        }
        if (response.event === "updates.updated" && response.data) {
            lastUpdatesUpdate = Date.now();
            updatesUpdated(response.data);
        }
    }
    function parseLine(line, channel) {
        var text = String(line || "").trim();
        if (text === "")
            return null;
        try {
            return JSON.parse(text);
        } catch (error) {
            console.warn("[CoreService] Invalid " + channel + " message:", text);
            return null;
        }
    }
    function requestReconnect() {
        if (requestSocket.connected)
            requestSocket.connected = false;
        closeSubscriptions();
        connectionRetry.restart();
    }
    function requestUpdateCheck(force) {
        setUpdatesEnabled(true);
        if (!updatesSocket.connected)
            return false;
        writeSubscriptionRequest(updatesSocket, "updates-refresh", "updates.check", {
            "force": force === true
        });
        return true;
    }
    function sendRequest(method, params, success, failure, timeoutMs) {
        if (!requestSocket.connected) {
            ensureRunning();
            if (failure)
                failure(qsTr("Core backend is not connected yet."));
            return "";
        }
        var id = String(nextRequestId++);
        var requestedTimeout = Number(timeoutMs);
        var effectiveTimeout = isFinite(requestedTimeout) && requestedTimeout > 0 ? requestedTimeout : requestTimeoutMs;
        var nextPending = Object.assign({}, pendingRequests);
        nextPending[id] = {
            "deadline": Date.now() + effectiveTimeout,
            "success": success,
            "failure": failure
        };
        pendingRequests = nextPending;
        requestSocket.write(JSON.stringify({
            "id": id,
            "method": method,
            "params": params || {}
        }) + "\n");
        requestSocket.flush();
        return id;
    }
    function setBatteryEnabled(enabled) {
        var wanted = enabled === true;
        if (batteryEnabled === wanted && (!wanted || batterySocket.connected))
            return;
        batteryEnabled = wanted;
        if (!wanted) {
            batteryRetry.stop();
            batterySubscribed = false;
            if (batterySocket.connected)
                batterySocket.connected = false;
            return;
        }
        ensureRunning();
        if (requestSocket.connected && !batterySocket.connected)
            batterySocket.connected = true;
    }
    function setStatsEnabled(enabled) {
        var wanted = enabled === true;
        if (statsEnabled === wanted && (!wanted || statsSocket.connected))
            return;
        statsEnabled = wanted;
        if (!wanted) {
            statsRetry.stop();
            statsSubscribed = false;
            if (statsSocket.connected)
                statsSocket.connected = false;
            return;
        }
        ensureRunning();
        if (requestSocket.connected && !statsSocket.connected)
            statsSocket.connected = true;
    }
    function setStatsMode(mode) {
        var wanted = ["none", "cpu", "ram", "gpu"].indexOf(String(mode)) >= 0 ? String(mode) : "none";
        if (statsMode === wanted)
            return;
        statsMode = wanted;
        if (statsSubscribed)
            writeStatsMode();
    }
    function setUpdatesEnabled(enabled) {
        var wanted = enabled === true;
        if (updatesEnabled === wanted && (!wanted || updatesSocket.connected))
            return;
        updatesEnabled = wanted;
        if (!wanted) {
            updatesRetry.stop();
            updatesSubscribed = false;
            if (updatesSocket.connected)
                updatesSocket.connected = false;
            return;
        }
        ensureRunning();
        if (requestSocket.connected && !updatesSocket.connected)
            updatesSocket.connected = true;
    }
    function startFallbackDaemon() {
        daemonStartDelay.stop();
        if (socketOverride === "" || requestSocket.connected || daemonProcess.running)
            return;
        daemonStatus = "starting";
        daemonProcess.running = true;
    }
    function writeStatsMode() {
        if (!statsSocket.connected)
            return;
        writeSubscriptionRequest(statsSocket, "stats-mode", "stats.setMode", {
            "mode": statsMode
        });
    }
    function writeSubscriptionRequest(socket, id, method, params) {
        socket.write(JSON.stringify({
            "id": id,
            "method": method,
            "params": params || {}
        }) + "\n");
        socket.flush();
    }

    Component.onCompleted: {
        ensureRunning();
        requestSocket.connected = true;
    }
    Component.onDestruction: {
        cancelRetry.stop();
        cancelQueue = [];
        cancelSocket.connected = false;
        closeSubscriptions();
        requestSocket.connected = false;
        systemdStarter.running = false;
        daemonProcess.running = false;
    }
}
