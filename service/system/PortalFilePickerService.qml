pragma Singleton
import "../.."
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    readonly property bool active: pickerProcess.running || activeRequestId !== ""
    property string activeRequestId: ""
    property string errorMessage: ""
    readonly property string helperPath: Config.quickshellDir + "/backend/python/portal/file_picker.py"
    property Process pickerProcess: Process {
        id: pickerProcess

        command: []

        stderr: StdioCollector {
            id: pickerError
        }
        stdout: StdioCollector {
            id: pickerOutput
        }

        onExited: (exitCode, exitStatus) => {
            var requestId = root.activeRequestId;
            root.activeRequestId = "";

            var response = null;
            try {
                response = JSON.parse(pickerOutput.text.trim());
            } catch (error) {
                response = {
                    "ok": false,
                    "canceled": false,
                    "message": pickerError.text.trim() || qsTr("Could not open the file picker")
                };
            }

            if (response.ok && response.canceled) {
                root.errorMessage = "";
                root.canceled(requestId);
                return;
            }
            if (exitCode === 0 && response.ok) {
                var paths = response.paths || [];
                var uris = response.uris || [];
                root.errorMessage = "";
                root.accepted(requestId, paths, uris);
                return;
            }

            root.errorMessage = response.message || pickerError.text.trim() || qsTr("Could not open the file picker");
            root.failed(requestId, root.errorMessage);
        }
    }
    property int requestSerial: 0

    signal accepted(string requestId, var paths, var uris)
    signal canceled(string requestId)
    signal failed(string requestId, string message)

    function cancel(requestId) {
        if (requestId !== activeRequestId || !pickerProcess.running)
            return false;
        pickerProcess.signal(15);
        return true;
    }
    function nextRequestId(prefix) {
        requestSerial += 1;
        var safePrefix = String(prefix || "picker").replace(/[^A-Za-z0-9_-]/g, "_");
        return safePrefix + "-" + Date.now() + "-" + requestSerial;
    }
    function open(requestId, options) {
        var normalizedRequestId = String(requestId || "").trim();
        if (normalizedRequestId === "" || active)
            return false;

        var selectedOptions = options || {};
        var args = ["python3", "-u", helperPath, "--title", String(selectedOptions.title || qsTr("Select file"))];
        var currentFolder = String(selectedOptions.currentFolder || "").trim();
        var parentWindow = String(selectedOptions.parentWindow || "").trim();
        var filters = Array.isArray(selectedOptions.filters) ? selectedOptions.filters : [];
        if (currentFolder !== "")
            args.push("--current", currentFolder);
        if (parentWindow !== "")
            args.push("--parent-window", parentWindow);
        if (selectedOptions.directory === true)
            args.push("--directory");
        if (selectedOptions.multiple === true)
            args.push("--multiple");
        if (filters.length > 0)
            args.push("--filters-json", JSON.stringify(filters));

        errorMessage = "";
        activeRequestId = normalizedRequestId;
        pickerProcess.command = args;
        pickerProcess.running = true;
        return true;
    }
}
