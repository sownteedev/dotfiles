pragma Singleton
import "../../"
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property bool busy: false
    property var caches: []
    property var dependencies: []
    readonly property string helperPath: Config.quickshellDir + "/backend/python/system/shell_diagnostics.py"
    property string message: ""
    property var services: []
    property Process worker: Process {
        id: worker

        property string action: "snapshot"
        property string scope: ""

        command: action === "clear" ? ["python3", root.helperPath, "clear", scope] : ["python3", root.helperPath, "snapshot"]

        stdout: StdioCollector {
            id: output
        }

        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            try {
                var result = JSON.parse(output.text.trim() || "{}");
                root.message = result.message || (exitCode === 0 ? "Diagnostics refreshed" : "Diagnostics failed");
                if (exitCode === 0 && worker.action === "snapshot") {
                    root.dependencies = result.dependencies || [];
                    root.caches = result.caches || [];
                    root.services = result.services || [];
                }
            } catch (error) {
                root.message = "Invalid diagnostics response";
            }
            if (exitCode === 0 && worker.action === "clear")
                Qt.callLater(root.refresh);
        }
    }

    function clearCache(scope) {
        if (busy)
            return;
        worker.action = "clear";
        worker.scope = String(scope || "");
        busy = true;
        worker.running = true;
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
        worker.action = "snapshot";
        worker.scope = "";
        busy = true;
        worker.running = true;
    }
}
