pragma Singleton

import QtQuick
import Quickshell.Io
import "../.."
import ".."

QtObject {
    id: root

    property string activeInspectAppId: ""
    property bool available: false
    property string backend: ""
    property var blockers: []
    property var cache: ({})
    property string errorMessage: ""
    readonly property string helperPath: Config.quickshellDir + "/backend/python/system/application_package.py"
    property Process inspectProcess: Process {
        id: inspectProcess

        command: []

        stderr: StdioCollector {
            id: inspectError
        }
        stdout: StdioCollector {
            id: inspectOutput
        }

        onExited: (exitCode, exitStatus) => {
            var completedAppId = root.activeInspectAppId;
            var response = root.parseResponse(inspectOutput.text, completedAppId, inspectError.text);
            if (exitCode === 0 && response.ok === true) {
                var nextCache = Object.assign({}, root.cache);
                nextCache[completedAppId] = response;
                root.cache = nextCache;
            }
            if (root.inspectedAppId === completedAppId)
                root.applyInspection(response, exitCode === 0 && response.ok === true);

            root.activeInspectAppId = "";
            var nextAppId = root.queuedInspectAppId;
            root.queuedInspectAppId = "";
            if (nextAppId !== "")
                Qt.callLater(() => root.inspect(nextAppId));
        }
    }
    property string inspectedAppId: ""
    property bool inspecting: false
    property string packageName: ""
    property string queuedInspectAppId: ""
    property bool removable: false
    property string scope: ""
    property string uninstallAppId: ""
    property Process uninstallProcess: Process {
        id: uninstallProcess

        command: []

        stderr: StdioCollector {
            id: uninstallError
        }
        stdout: StdioCollector {
            id: uninstallOutput
        }

        onExited: (exitCode, exitStatus) => {
            var completedAppId = root.uninstallAppId;
            var response = root.parseResponse(uninstallOutput.text, completedAppId, uninstallError.text);
            var success = exitCode === 0 && response.ok === true;
            root.errorMessage = success ? "" : response.message;
            root.uninstalling = false;
            root.uninstallAppId = "";

            if (success) {
                var nextCache = Object.assign({}, root.cache);
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
                root.cache = nextCache;
                if (root.inspectedAppId === completedAppId)
                    root.clearInspection();
            }
            root.uninstallFinished(completedAppId, success, response.message);
        }
    }
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
        if (inspectProcess.running) {
            queuedInspectAppId = normalizedAppId;
            return;
        }
        startInspection(normalizedAppId);
    }
    function parseResponse(text, appId, fallback) {
        try {
            var response = JSON.parse(String(text || "").trim());
            if (!response.app_id)
                response.app_id = appId;
            return response;
        } catch (error) {
            return {
                "app_id": appId,
                "managed": false,
                "message": String(fallback || qsTr("Package operation failed")).trim(),
                "ok": false
            };
        }
    }
    function startInspection(appId) {
        activeInspectAppId = appId;
        inspectProcess.command = ["python3", helperPath, "inspect", appId];
        inspectProcess.running = true;
    }
    function uninstall(appId) {
        var normalizedAppId = String(appId || "");
        if (uninstalling || !available || !removable || normalizedAppId !== inspectedAppId)
            return false;
        uninstallAppId = normalizedAppId;
        uninstalling = true;
        errorMessage = "";
        uninstallProcess.command = ["python3", helperPath, "uninstall", normalizedAppId];
        uninstallProcess.running = true;
        return true;
    }
}
