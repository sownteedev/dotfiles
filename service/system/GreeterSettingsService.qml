pragma Singleton
import "../.."
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    readonly property bool busy: syncProcess.running
    readonly property string configuredDefaultSession: Config.greeterDefaultSession
    readonly property bool configuredRememberLastSession: Config.greeterRememberLastSession
    property string errorMessage: ""
    readonly property string helperPath: Config.quickshellDir + "/backend/python/profile/greeter_settings_sync.py"
    property bool initialized: false
    property bool pendingSync: false
    property Process sessionScanner: Process {
        command: ["python3", Config.quickshellDir + "/widget/greeter/scripts/list_sessions.py"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var result = JSON.parse(String(text || "[]"));
                    root.sessions = Array.isArray(result) ? result : [];
                } catch (error) {
                    root.sessions = [];
                    console.warn("[GreeterSettingsService] Invalid session list:", error);
                }
            }
        }
    }
    property var sessions: []
    property string statusMessage: ""
    property Timer syncDebounce: Timer {
        interval: 120

        onTriggered: root.sync()
    }
    property Process syncProcess: Process {
        stderr: StdioCollector {
            id: syncError
        }
        stdout: StdioCollector {
            id: syncOutput
        }

        onExited: (exitCode, exitStatus) => {
            var response = root.parseResponse(syncOutput.text, syncError.text);
            if (exitCode !== 0 || response.ok !== true) {
                root.errorMessage = response.message || qsTr("Could not update greetd settings");
                root.statusMessage = "";
            } else {
                root.errorMessage = "";
                root.statusMessage = qsTr("Greeter settings synchronized");
            }
            if (root.pendingSync) {
                root.pendingSync = false;
                Qt.callLater(root.sync);
            }
        }
    }

    function parseResponse(stdoutText, stderrText) {
        try {
            var response = JSON.parse(String(stdoutText || "").trim());
            if (response && typeof response === "object")
                return response;
        } catch (error) {}
        return {
            "ok": false,
            "message": String(stderrText || "").trim()
        };
    }
    function refreshSessions() {
        if (!sessionScanner.running)
            sessionScanner.running = true;
    }
    function scheduleSync() {
        if (initialized)
            syncDebounce.restart();
    }
    function sync() {
        if (syncProcess.running) {
            pendingSync = true;
            return;
        }
        statusMessage = qsTr("Synchronizing greeter settings…");
        errorMessage = "";
        syncProcess.command = ["python3", "-u", helperPath, "--default-session", configuredDefaultSession, "--remember-last-session", configuredRememberLastSession ? "true" : "false"];
        syncProcess.running = true;
    }

    Component.onCompleted: {
        initialized = true;
        refreshSessions();
        scheduleSync();
    }
    onConfiguredDefaultSessionChanged: scheduleSync()
    onConfiguredRememberLastSessionChanged: scheduleSync()
}
