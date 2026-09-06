pragma Singleton

import QtQuick
import "../.."
import ".."

QtObject {
    id: root

    property string activeInspectAppId: ""
    property string activeInspectRequestId: ""
    property string activeUninstallRequestId: ""
    property bool available: false
    property string backend: ""
    property var blockers: []
    property var cache: ({})
    property string errorMessage: ""
    property string inspectedAppId: ""
    property bool inspecting: false
    property string packageName: ""
    property string queuedInspectAppId: ""
    property bool removable: false
    property string scope: ""
    property string uninstallAppId: ""
    property bool uninstalling: false

    signal uninstallFinished(string appId, bool success, string message)

    function applyInspection(response, success) {
        inspecting = false;
        available = success && response.managed === true;
        backend = available ? String(response.backend || "") : "";
        blockers = available && Array.isArray(response.blockers) ? response.blockers : [];
        packageName = available ? String(response.package || "") : "";
        removable = available && response.removable === true;
        scope = available ? String(response.scope || "") : "";
        errorMessage = success ? String(response.message || "") : String(response.message || qsTr("Could not identify the package"));
    }
    function clearInspection() {
        available = false;
        backend = "";
        blockers = [];
        packageName = "";
        removable = false;
        scope = "";
    }
    function finishInspection(completedAppId, response, success) {
        activeInspectRequestId = "";
        if (!response)
            response = {};
        if (!response.app_id)
            response.app_id = completedAppId;
        if (success && response.ok === true) {
            var nextCache = Object.assign({}, cache);
            nextCache[completedAppId] = response;
            cache = nextCache;
        }
        if (inspectedAppId === completedAppId)
            applyInspection(response, success && response.ok === true);

        activeInspectAppId = "";
        var nextAppId = queuedInspectAppId;
        queuedInspectAppId = "";
        if (nextAppId !== "")
            Qt.callLater(() => root.inspect(nextAppId));
    }
    function finishUninstall(completedAppId, response, success) {
        activeUninstallRequestId = "";
        if (!response)
            response = {};
        var completedSuccessfully = success && response.ok === true;
        var message = String(response.message || (completedSuccessfully ? "" : qsTr("Package operation failed")));
        errorMessage = completedSuccessfully ? "" : message;
        uninstalling = false;
        uninstallAppId = "";

        if (completedSuccessfully) {
            var nextCache = Object.assign({}, cache);
            var relatedAppIds = Array.isArray(response.desktop_ids) ? response.desktop_ids : [completedAppId];
            for (var appIndex = 0; appIndex < relatedAppIds.length; ++appIndex) {
                var relatedAppId = String(relatedAppIds[appIndex] || "");
                if (relatedAppId === "")
                    continue;
                delete nextCache[relatedAppId];
                DockService.unpin(relatedAppId);
                var group = LauncherGroupService.groupForApp(relatedAppId);
                if (group)
                    LauncherGroupService.removeApp(group.id, relatedAppId);
            }
            cache = nextCache;
            if (inspectedAppId === completedAppId)
                clearInspection();
        }
        uninstallFinished(completedAppId, completedSuccessfully, message);
    }
    function inspect(appId) {
        var normalizedAppId = String(appId || "");
        inspectedAppId = normalizedAppId;
        clearInspection();
        errorMessage = "";
        if (normalizedAppId === "") {
            inspecting = false;
            return;
        }

        var cached = cache[normalizedAppId];
        if (cached !== undefined) {
            applyInspection(cached, true);
            return;
        }
        inspecting = true;
        if (activeInspectRequestId !== "") {
            queuedInspectAppId = normalizedAppId;
            return;
        }
        startInspection(normalizedAppId);
    }
    function startInspection(appId) {
        activeInspectAppId = appId;
        activeInspectRequestId = CoreService.sendRequest("application.inspect", {
            "appId": appId
        }, response => root.finishInspection(appId, response, true), message => root.finishInspection(appId, {
                "app_id": appId,
                "managed": false,
                "message": message,
                "ok": false
            }, false), 20000);
    }
    function uninstall(appId) {
        var normalizedAppId = String(appId || "");
        if (uninstalling || !available || !removable || normalizedAppId !== inspectedAppId)
            return false;
        uninstallAppId = normalizedAppId;
        uninstalling = true;
        errorMessage = "";
        activeUninstallRequestId = CoreService.sendRequest("application.uninstall", {
            "appId": normalizedAppId
        }, response => root.finishUninstall(normalizedAppId, response, true), message => root.finishUninstall(normalizedAppId, {
                "message": message,
                "ok": false
            }, false), 10 * 60 * 1000);
        return true;
    }
}
