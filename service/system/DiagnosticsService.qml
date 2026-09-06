pragma Singleton
import "../../"
import QtQuick
import ".."

QtObject {
    id: root

    property string activeRequestId: ""
    property bool busy: false
    property var caches: []
    property var dependencies: []
    property string message: ""
    property var services: []

    function clearCache(scope) {
        if (busy)
            return;
        runRequest("clear", String(scope || ""));
    }
    function formatBytes(bytes) {
        var value = Number(bytes || 0);
        if (value < 1024)
            return value + " B";
        if (value < 1024 * 1024)
            return (value / 1024).toFixed(1) + " KiB";
        if (value < 1024 * 1024 * 1024)
            return (value / (1024 * 1024)).toFixed(1) + " MiB";
        return (value / (1024 * 1024 * 1024)).toFixed(2) + " GiB";
    }
    function refresh() {
        if (busy)
            return;
        runRequest("snapshot", "");
    }
    function runRequest(action, scope) {
        busy = true;
        var method = action === "clear" ? "diagnostics.clear" : "diagnostics.snapshot";
        activeRequestId = CoreService.sendRequest(method, {
            "scope": scope
        }, function (result) {
            root.activeRequestId = "";
            root.busy = false;
            var succeeded = result && result.ok === true;
            root.message = String(result && result.message || (succeeded ? qsTr("Diagnostics refreshed") : qsTr("Diagnostics failed")));
            if (succeeded && action === "snapshot") {
                root.dependencies = result.dependencies || [];
                root.caches = result.caches || [];
                root.services = result.services || [];
            } else if (succeeded && action === "clear") {
                Qt.callLater(root.refresh);
            }
        }, function (errorMessage) {
            root.activeRequestId = "";
            root.busy = false;
            root.message = String(errorMessage || qsTr("Diagnostics failed"));
        }, 60000);
    }
}
