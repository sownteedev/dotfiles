pragma Singleton
import "../../"
import ".."
import QtQuick

QtObject {
    id: root

    property string activePath: ""
    property string activeRequestId: ""
    property bool busy: false
    readonly property string configuredPath: Config.profileImagePath
    property Connections coreConnections: Connections {
        function onReadyChanged() {
            if (CoreService.ready)
                root.startPendingSync();
        }

        target: CoreService
    }
    property string errorMessage: ""
    property bool hasPendingSync: false
    property bool initialized: false
    property string pendingPath: ""
    property string statusMessage: ""

    function finishSync(response, transportSuccess) {
        var completedPath = activePath;
        activePath = "";
        activeRequestId = "";
        busy = false;
        var succeeded = transportSuccess && response && response.ok === true;
        if (!succeeded) {
            errorMessage = String(response && response.message || qsTr("Could not update the login profile image"));
            statusMessage = "";
            if (!CoreService.ready && !hasPendingSync) {
                hasPendingSync = true;
                pendingPath = completedPath;
            }
        } else {
            errorMessage = "";
            statusMessage = response.path ? qsTr("Profile image updated for Polkit and Greetd") : qsTr("Profile image removed");
        }
        startPendingSync();
    }
    function startPendingSync() {
        if (busy || !CoreService.ready || !hasPendingSync)
            return;
        var nextPath = pendingPath;
        hasPendingSync = false;
        pendingPath = "";
        Qt.callLater(function () {
            root.sync(nextPath);
        });
    }
    function sync(path) {
        var sourcePath = Config.expandHomePath(String(path || "").trim());
        if (busy) {
            hasPendingSync = true;
            pendingPath = sourcePath;
            return false;
        }
        if (!CoreService.ready) {
            hasPendingSync = true;
            pendingPath = sourcePath;
            errorMessage = "";
            statusMessage = qsTr("Waiting for the core backend…");
            CoreService.ensureRunning();
            return true;
        }
        errorMessage = "";
        statusMessage = sourcePath === "" ? qsTr("Removing profile image…") : qsTr("Updating profile image…");
        activePath = sourcePath;
        busy = true;
        activeRequestId = CoreService.sendRequest("greeter.profile.sync", {
            "source": sourcePath
        }, function (result) {
            root.finishSync(result, true);
        }, function (message) {
            root.finishSync({
                "ok": false,
                "message": message
            }, false);
        }, 60000);
        return true;
    }

    Component.onCompleted: Qt.callLater(function () {
        root.initialized = true;
        root.sync(root.configuredPath);
    })
    Component.onDestruction: CoreService.forgetRequest(activeRequestId)
    onConfiguredPathChanged: {
        if (initialized)
            sync(configuredPath);
    }
}
