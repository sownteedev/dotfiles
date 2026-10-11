pragma Singleton
import QtQuick
import Quickshell.Io
import "../../"

QtObject {
    id: root

    property string activeAction: ""
    property bool busy: false
    property var controlNames: []
    property Process controlProcess: Process {
        id: controlProcess

        stderr: StdioCollector {
            id: controlError
        }
        stdout: StdioCollector {
            id: controlOutput
        }

        onExited: (exitCode, exitStatus) => {
            var completedAction = root.activeAction;
            var response = null;
            try {
                response = JSON.parse(controlOutput.text.trim());
            } catch (error) {
                response = null;
            }
            var success = exitCode === 0 && response && response.ok === true;
            var message = response && response.message ? String(response.message) : success ? "" : controlError.text.trim() || qsTr("Camera control operation failed");
            root.statusMessage = root.activeAction === "set" && success ? "" : message;
            root.statusSuccess = success;
            if (success) {
                root.device = String(response.device || root.device);
                root.updateControls(response.controls || []);
                root.saved = response.saved === true;
            }
            root.busy = false;
            root.activeAction = "";
            root.operationFinished(success, message);
            if (root.defaultCompareRestorePending && completedAction === "reset") {
                root.defaultCompareRestorePending = false;
                Qt.callLater(function () {
                    root.invoke("set-values", [JSON.stringify(root.defaultCompareSnapshot)]);
                    root.defaultCompareSnapshot = {};
                });
            }
            if (root.pendingSetName !== "") {
                var pendingName = root.pendingSetName;
                var pendingValue = root.pendingSetValue;
                root.pendingSetName = "";
                root.pendingSetValue = "";
                Qt.callLater(function () {
                    root.invoke("set", [pendingName, pendingValue]);
                });
            }
        }
    }
    property var controls: []
    property bool defaultCompareActive: false
    property bool defaultCompareRestorePending: false
    property var defaultCompareSnapshot: ({})
    property string device: ""
    property string pendingSetName: ""
    property string pendingSetValue: ""
    property bool saved: false
    property string statusMessage: ""
    property bool statusSuccess: true
    readonly property bool updatingControl: busy && activeAction === "set"

    signal operationFinished(bool success, string message)

    function applySaved() {
        invoke("apply", []);
    }
    function beginDefaultComparison() {
        if (busy || device === "" || controls.length === 0)
            return;

        var snapshot = {};
        for (var index = 0; index < controls.length; ++index) {
            var control = controls[index];
            if (!control.inactive && !control.disabled && control.value !== undefined)
                snapshot[String(control.name)] = control.value;
        }
        if (Object.keys(snapshot).length === 0)
            return;

        defaultCompareSnapshot = snapshot;
        defaultCompareActive = true;
        defaultCompareRestorePending = false;
        invoke("reset", []);
    }
    function endDefaultComparison() {
        if (!defaultCompareActive)
            return;

        defaultCompareActive = false;
        if (Object.keys(defaultCompareSnapshot).length === 0)
            return;
        if (busy) {
            defaultCompareRestorePending = true;
            return;
        }
        invoke("set-values", [JSON.stringify(defaultCompareSnapshot)]);
        defaultCompareSnapshot = {};
    }
    function invoke(action, commandArguments) {
        if (busy || device === "")
            return;

        var command = ["python3", Config.sownteeshellDir + "/backend/python/camera/v4l2_controls.py", action, device];
        if (commandArguments)
            command = command.concat(commandArguments);
        controlProcess.command = command;
        activeAction = action;
        if (action !== "set") {
            statusMessage = action === "list" ? qsTr("Reading camera controls…") : qsTr("Updating camera controls…");
            statusSuccess = true;
        }
        busy = true;
        controlProcess.running = true;
    }
    function load(nextDevice) {
        var normalized = normalizeDevice(nextDevice);
        if (normalized === "") {
            device = "";
            updateControls([]);
            saved = false;
            return;
        }
        if (device !== normalized)
            updateControls([]);
        device = normalized;
        invoke("list", []);
    }
    function normalizeDevice(value) {
        var text = String(value || "");
        return text.indexOf("file://") === 0 ? text.substring(7) : text;
    }
    function reset() {
        invoke("reset", []);
    }
    function save() {
        invoke("save", []);
    }
    function setControl(name, value) {
        var nextName = String(name);
        var nextValue = String(Math.round(Number(value)));
        if (busy) {
            pendingSetName = nextName;
            pendingSetValue = nextValue;
            return;
        }
        invoke("set", [nextName, nextValue]);
    }
    function updateControls(nextControls) {
        var nextNames = [];
        var mergedControls = [];
        var changed = nextControls.length !== controls.length;
        for (var index = 0; index < nextControls.length; ++index) {
            var nextControl = nextControls[index];
            var previousControl = controls[index];
            nextNames.push(String(nextControl.name));
            if (previousControl && JSON.stringify(previousControl) === JSON.stringify(nextControl)) {
                mergedControls.push(previousControl);
            } else {
                mergedControls.push(nextControl);
                changed = true;
            }
        }
        if (changed)
            controls = mergedControls;
        if (JSON.stringify(controlNames) !== JSON.stringify(nextNames))
            controlNames = nextNames;
    }
}
