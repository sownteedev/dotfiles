pragma Singleton
import "../.."
import ".."
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property string activeRequestId: ""
    property bool busy: false
    readonly property string configuredDefaultSession: Config.greeterDefaultSession
    readonly property bool configuredRememberLastSession: Config.greeterRememberLastSession
    property Connections coreConnections: Connections {
        function onReadyChanged() {
            if (!CoreService.ready)
                return;
            if (root.sessionsPending)
                Qt.callLater(root.refreshSessions);
            if (root.pendingSync && !root.busy)
                Qt.callLater(root.sync);
        }

        target: CoreService
    }
    property string errorMessage: ""
    property bool initialized: false
    property bool pendingSync: false
    property var sessions: []
    property bool sessionsPending: false
    property string sessionsRequestId: ""
    property string statusMessage: ""
    property Timer syncDebounce: Timer {
        interval: 120

        onTriggered: root.sync()
    }

    function finishSync(response, transportSuccess) {
        activeRequestId = "";
        busy = false;
        var succeeded = transportSuccess && response && response.ok === true;
        if (!succeeded) {
            errorMessage = String(response && response.message || qsTr("Could not update greetd settings"));
            statusMessage = "";
            if (!CoreService.ready)
                pendingSync = true;
        } else {
            errorMessage = "";
            statusMessage = qsTr("Greeter settings synchronized");
        }
        if (pendingSync && CoreService.ready) {
            pendingSync = false;
            Qt.callLater(root.sync);
        }
    }
    function refreshSessions() {
        if (sessionsRequestId !== "")
            return;
        if (!CoreService.ready) {
            sessionsPending = true;
            CoreService.ensureRunning();
            return;
        }
        sessionsPending = false;
        sessionsRequestId = CoreService.sendRequest("greeter.sessions.list", {}, function (result) {
            root.sessionsRequestId = "";
            root.sessions = Array.isArray(result) ? result : [];
        }, function (message) {
            root.sessionsRequestId = "";
            root.sessions = [];
            if (!CoreService.ready)
                root.sessionsPending = true;
            console.warn("[GreeterSettingsService] Could not list sessions:", message);
        }, 10000);
    }
    function scheduleSync() {
        if (initialized)
            syncDebounce.restart();
    }
    function sync() {
        if (busy) {
            pendingSync = true;
            return;
        }
        if (!CoreService.ready) {
            pendingSync = true;
            statusMessage = qsTr("Waiting for the core backend…");
            errorMessage = "";
            CoreService.ensureRunning();
            return;
        }
        pendingSync = false;
        statusMessage = qsTr("Synchronizing greeter settings…");
        errorMessage = "";
        busy = true;
        activeRequestId = CoreService.sendRequest("greeter.settings.sync", {
            "defaultSession": configuredDefaultSession,
            "rememberLastSession": configuredRememberLastSession
        }, function (result) {
            root.finishSync(result, true);
        }, function (message) {
            root.finishSync({
                "ok": false,
                "message": message
            }, false);
        }, 15000);
    }

    Component.onCompleted: {
        initialized = true;
        refreshSessions();
        scheduleSync();
    }
    Component.onDestruction: {
        CoreService.forgetRequest(activeRequestId);
        CoreService.forgetRequest(sessionsRequestId);
    }
    onConfiguredDefaultSessionChanged: scheduleSync()
    onConfiguredRememberLastSessionChanged: scheduleSync()
}
