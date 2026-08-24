pragma Singleton
import "../../"
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    readonly property bool busy: syncProcess.running
    readonly property string configuredPath: Config.profileImagePath
    property string errorMessage: ""
    property bool hasPendingSync: false
    readonly property string helperPath: Config.quickshellDir + "/scripts/sync-profile-image.py"
    property bool initialized: false
    property string pendingPath: ""
    property string statusMessage: ""
    property Process syncProcess: Process {
        stderr: StdioCollector {
            id: syncError
        }
        stdout: StdioCollector {
            id: syncOutput
        }

        onExited: (exitCode, exitStatus) => {
            var response = root.parseResponse(syncOutput.text, syncError.text);
            if (exitCode !== 0 || !response.ok) {
                root.errorMessage = response.message || qsTr("Could not update the login profile image");
                root.statusMessage = "";
            } else {
                root.errorMessage = "";
                root.statusMessage = response.path ? qsTr("Profile image updated for Polkit and Greetd") : qsTr("Profile image removed");
            }
            if (root.hasPendingSync) {
                var nextPath = root.pendingPath;
                root.hasPendingSync = false;
                root.pendingPath = "";
                Qt.callLater(function () {
                    root.sync(nextPath);
                });
            }
        }
    }

    function parseResponse(stdoutText, stderrText) {
        try {
            var parsed = JSON.parse(String(stdoutText || "").trim());
            if (parsed && typeof parsed === "object")
                return parsed;
        } catch (error) {}
        return {
            "ok": false,
            "message": String(stderrText || "").trim()
        };
    }
    function sync(path) {
        var sourcePath = Config.expandHomePath(String(path || "").trim());
        if (busy) {
            hasPendingSync = true;
            pendingPath = sourcePath;
            return false;
        }
        errorMessage = "";
        statusMessage = sourcePath === "" ? qsTr("Removing profile image…") : qsTr("Updating profile image…");
        syncProcess.command = sourcePath === "" ? ["python3", "-u", helperPath, "--clear"] : ["python3", "-u", helperPath, sourcePath];
        syncProcess.running = true;
        return true;
    }

    Component.onCompleted: Qt.callLater(function () {
        root.initialized = true;
        root.sync(root.configuredPath);
    })
    onConfiguredPathChanged: {
        if (initialized)
            sync(configuredPath);
    }
}
