import "../../"
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string apiKey: Config.launcherKlipyApiKey
    property string errorCode: ""
    readonly property string helperPath: Config.quickshellDir + "/backend/python/launcher/klipy_client.py"
    property string kind: "gif"
    property bool loading: false
    property string query: ""
    property string queuedRequest: ""
    property int requestGeneration: 0
    property bool restartPending: false
    property var results: []
    property Timer searchDebounce: Timer {
        interval: 350
        repeat: false

        onTriggered: root.runSearch()
    }
    property Process searchProcess: Process {
        property int generation: -1
        property bool launchPending: false
        property string requestJson: ""

        command: ["python3", "-u", root.helperPath, "query", "-"]
        stdinEnabled: true

        stderr: StdioCollector {
            id: searchError
        }
        stdout: StdioCollector {
            id: searchOutput
        }

        onExited: (exitCode, exitStatus) => {
            root.handleResponse(generation, exitCode, searchOutput.text, searchError.text);
            if (root.restartPending) {
                root.restartPending = false;
                Qt.callLater(root.startQueuedRequest);
            }
        }
        onRunningChanged: {
            if (!running && launchPending) {
                launchPending = false;
                if (generation === root.requestGeneration) {
                    root.loading = false;
                    root.errorCode = "process_error";
                }
                if (root.restartPending) {
                    root.restartPending = false;
                    Qt.callLater(root.startQueuedRequest);
                }
            }
        }
        onStarted: {
            launchPending = false;
            write(requestJson + "\n");
            requestJson = "";
        }
    }

    function cancel() {
        requestGeneration += 1;
        searchDebounce.stop();
        queuedRequest = "";
        restartPending = false;
        loading = false;
        if (searchProcess.running)
            searchProcess.running = false;
    }
    function handleResponse(generation, exitCode, output, errorOutput) {
        if (generation !== requestGeneration)
            return;

        loading = false;
        var raw = String(output || "").trim();
        if (raw === "") {
            errorCode = exitCode === 0 ? "invalid_response" : "process_error";
            results = [];
            return;
        }
        try {
            var response = JSON.parse(raw);
            if (Number(response.requestId || 0) !== generation)
                return;
            if (!response.ok) {
                errorCode = String(response.error || "request_failed");
                results = [];
                return;
            }
            errorCode = "";
            results = Array.isArray(response.items) ? response.items : [];
        } catch (error) {
            errorCode = "invalid_response";
            results = [];
        }
    }
    function runSearch() {
        if (apiKey.trim() === "") {
            cancel();
            errorCode = "missing_api_key";
            results = [];
            return;
        }

        requestGeneration += 1;
        errorCode = "";
        loading = true;
        results = [];
        queuedRequest = JSON.stringify({
            "apiKey": apiKey.trim(),
            "kind": kind,
            "perPage": 24,
            "query": query.trim(),
            "requestId": requestGeneration
        });
        startQueuedRequest();
    }
    function scheduleSearch() {
        searchDebounce.stop();
        requestGeneration += 1;
        queuedRequest = "";
        restartPending = false;
        if (searchProcess.running)
            searchProcess.running = false;
        if (apiKey.trim() === "") {
            loading = false;
            errorCode = "missing_api_key";
            results = [];
            return;
        }
        errorCode = "";
        loading = true;
        results = [];
        searchDebounce.start();
    }
    function startQueuedRequest() {
        if (queuedRequest === "")
            return;
        if (searchProcess.running) {
            restartPending = true;
            searchProcess.running = false;
            return;
        }

        searchProcess.generation = requestGeneration;
        searchProcess.requestJson = queuedRequest;
        searchProcess.launchPending = true;
        queuedRequest = "";
        searchProcess.running = true;
    }

    Component.onCompleted: scheduleSearch()
    Component.onDestruction: cancel()
    onApiKeyChanged: scheduleSearch()
    onKindChanged: scheduleSearch()
    onQueryChanged: scheduleSearch()
}
