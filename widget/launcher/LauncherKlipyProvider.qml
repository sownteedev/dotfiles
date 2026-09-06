import "../../"
import "../../service"
import QtQuick

QtObject {
    id: root

    property string apiKey: Config.launcherKlipyApiKey
    property string errorCode: ""
    property string kind: "gif"
    property bool loading: false
    property string query: ""
    property var queuedRequest: null
    property int requestGeneration: 0
    property var results: []
    property Timer searchDebounce: Timer {
        interval: 350
        repeat: false

        onTriggered: root.runSearch()
    }
    property CoreRequest searchRequest: CoreRequest {
        timeoutMs: 20000

        onFailed: message => {
            var generation = Number(params.requestId || -1);
            if (generation !== root.requestGeneration)
                return;
            root.loading = false;
            root.errorCode = "process_error";
            root.results = [];
            console.warn("[LauncherKlipyProvider]", message);
        }
        onSucceeded: response => root.handleResponse(Number(params.requestId || -1), response)
    }

    function cancel() {
        requestGeneration += 1;
        searchDebounce.stop();
        queuedRequest = null;
        loading = false;
        if (searchRequest.active)
            searchRequest.cancel();
    }
    function handleResponse(generation, response) {
        if (generation !== requestGeneration)
            return;

        loading = false;
        if (!response || typeof response !== "object") {
            errorCode = "invalid_response";
            results = [];
            return;
        }
        if (Number(response.requestId || 0) !== generation)
            return;
        if (!response.ok) {
            errorCode = String(response.error || "request_failed");
            results = [];
            return;
        }
        errorCode = "";
        results = Array.isArray(response.items) ? response.items : [];
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
        queuedRequest = {
            "apiKey": apiKey.trim(),
            "kind": kind,
            "perPage": 24,
            "query": query.trim(),
            "requestId": requestGeneration
        };
        startQueuedRequest();
    }
    function scheduleSearch() {
        searchDebounce.stop();
        requestGeneration += 1;
        queuedRequest = null;
        if (searchRequest.active)
            searchRequest.cancel();
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
        if (!queuedRequest)
            return;
        var request = queuedRequest;
        queuedRequest = null;
        searchRequest.start("launcher.klipy.search", request);
    }

    Component.onCompleted: scheduleSearch()
    Component.onDestruction: cancel()
    onApiKeyChanged: scheduleSearch()
    onKindChanged: scheduleSearch()
    onQueryChanged: scheduleSearch()
}
