import QtQuick
import ".."

QtObject {
    id: root

    property bool active: false
    property bool cancellable: true
    property Connections coreConnections: Connections {
        function onReadyChanged() {
            if (CoreService.ready && root.active && root.waitingForCore)
                root.dispatch();
        }

        target: CoreService
    }
    property int generation: 0
    property string jobId: ""
    property string method: ""
    property var params: ({})
    property string requestId: ""
    property int timeoutMs: 30000
    property bool waitingForCore: false

    signal cancelled
    signal failed(string message)
    signal succeeded(var result)

    function cancel() {
        return stop(true, true);
    }
    function completeFailure(requestGeneration, message) {
        if (!active || requestGeneration !== generation)
            return;
        active = false;
        waitingForCore = false;
        requestId = "";
        jobId = "";
        failed(String(message || qsTr("Core request failed.")));
    }
    function completeSuccess(requestGeneration, result) {
        if (!active || requestGeneration !== generation)
            return;
        active = false;
        waitingForCore = false;
        requestId = "";
        jobId = "";
        succeeded(result);
    }
    function dispatch() {
        if (!active || requestId !== "")
            return;
        if (!CoreService.ready) {
            waitingForCore = true;
            CoreService.ensureRunning();
            return;
        }

        waitingForCore = false;
        var requestGeneration = generation;
        var payload = Object.assign({}, params || {});
        if (cancellable && jobId !== "")
            payload._job_id = jobId;
        var id = CoreService.sendRequest(method, payload, function (result) {
            root.completeSuccess(requestGeneration, result);
        }, function (message) {
            root.completeFailure(requestGeneration, message);
        }, timeoutMs);
        if (active && requestGeneration === generation)
            requestId = id;
    }
    function nextJobId(methodName) {
        return String(methodName || "core-request").replace(/[^A-Za-z0-9_.-]/g, "_") + "-" + Date.now() + "-" + generation;
    }
    function start(methodName, parameters, requestedTimeoutMs) {
        stop(true, false);
        generation += 1;
        method = String(methodName || "");
        params = parameters || {};
        if (Number(requestedTimeoutMs) > 0)
            timeoutMs = Number(requestedTimeoutMs);
        jobId = cancellable ? nextJobId(method) : "";
        active = method !== "";
        waitingForCore = active;
        if (active)
            dispatch();
        return active;
    }
    function stop(cancelBackend, emitCancelled) {
        if (!active && requestId === "" && !waitingForCore)
            return false;
        var activeRequestId = requestId;
        var activeJobId = jobId;
        generation += 1;
        active = false;
        waitingForCore = false;
        requestId = "";
        jobId = "";
        if (activeRequestId !== "")
            CoreService.forgetRequest(activeRequestId);
        if (cancelBackend && activeJobId !== "")
            CoreService.cancelJob(activeJobId);
        if (emitCancelled)
            cancelled();
        return true;
    }

    Component.onDestruction: stop(true, false)
}
