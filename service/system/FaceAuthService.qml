pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property Process actionProcess: Process {
        id: actionProcess

        stderr: StdioCollector {
            id: actionError
        }
        stdout: StdioCollector {
            id: actionOutput
        }

        onExited: (exitCode, exitStatus) => {
            var cancelled = exitCode === 126 || exitCode === 127;
            var response = root.parseResponse(actionOutput.text, actionError.text.trim() || (cancelled ? "Authorization cancelled" : "Face authentication action failed"));
            var success = exitCode === 0 && response.ok === true;
            root.statusSuccess = success;
            root.statusMessage = response.message || (success ? "Face authentication updated" : "Face authentication action failed");
            root.operationFinished(success, root.statusMessage);
            root.activeAction = "";
            root.busy = false;
            Qt.callLater(root.refresh);
        }
    }
    property string activeAction: ""
    property bool busy: false
    property string camera: ""
    property var cameras: []
    property bool enabled: false
    property bool installed: false
    readonly property string managerPath: "/usr/lib/quickshell/howdy-face-manager"
    property var models: []
    property string statusMessage: ""
    property Process statusProcess: Process {
        id: statusProcess

        command: [root.managerPath, "status"]

        stderr: StdioCollector {
            id: statusError
        }
        stdout: StdioCollector {
            id: statusOutput
        }

        onExited: (exitCode, exitStatus) => {
            var response = root.parseResponse(statusOutput.text, statusError.text.trim() || "Face manager is not installed");
            if (exitCode === 0 && response.ok === true) {
                root.applyResponse(response);
                if (root.statusMessage === "") {
                    root.statusSuccess = true;
                    root.statusMessage = response.message || "Face authentication status refreshed";
                }
            } else {
                root.installed = false;
                root.enabled = false;
                root.models = [];
                root.cameras = [];
                root.statusSuccess = false;
                root.statusMessage = response.message || "Face manager is not installed";
            }
            root.busy = false;
        }
    }
    property bool statusSuccess: true
    property string user: ""

    signal operationFinished(bool success, string message)

    function addModel(label) {
        runAction("add", label);
    }
    function applyResponse(response) {
        installed = response.installed === true;
        enabled = response.enabled === true;
        models = response.models || [];
        camera = response.camera || "";
        cameras = response.cameras || [];
        user = response.user || "";
    }
    function parseResponse(text, fallback) {
        try {
            return JSON.parse(String(text || "").trim());
        } catch (error) {
            return {
                "ok": false,
                "message": fallback
            };
        }
    }
    function refresh() {
        if (statusProcess.running || actionProcess.running)
            return;
        busy = true;
        statusProcess.running = true;
    }
    function removeModel(modelId) {
        runAction("remove", modelId);
    }
    function runAction(action, argument) {
        if (busy || actionProcess.running)
            return;
        activeAction = action;
        statusMessage = action === "add" || action === "test" ? "Authorize, then look straight into the camera…" : action === "set-camera" ? "Authorize to change the face camera…" : "Waiting for administrator authorization…";
        statusSuccess = true;
        busy = true;
        var args = ["pkexec", managerPath, action];
        if (argument !== undefined && String(argument) !== "")
            args.push(String(argument));
        actionProcess.command = args;
        actionProcess.running = true;
    }
    function setCamera(path) {
        runAction("set-camera", path);
    }
    function setEnabled(value) {
        runAction(value ? "enable" : "disable");
    }
    function testModel() {
        runAction("test");
    }
}
