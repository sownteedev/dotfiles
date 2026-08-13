pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

QtObject {
    id: root

    readonly property string configPath: Config.niriOutputConfig
    property string pendingPersistPayload: ""
    property bool refreshPending: false
    property Process outputPersistor: Process {
        stdout: StdioCollector {
            id: outputPersistResult
        }

        onExited: (exitCode, exitStatus) => {
            try {
                var result = JSON.parse(outputPersistResult.text.trim() || "{}");
                if (result.error)
                    console.warn("[DisplayHotplugService] Output persistence failed:", result.error);
            } catch (error) {
                console.warn("[DisplayHotplugService] Invalid persistence response:", error);
            }
            if (exitCode !== 0)
                console.warn("[DisplayHotplugService] Persistence helper exited with:", exitCode);
            if (root.pendingPersistPayload !== "") {
                var payload = root.pendingPersistPayload;
                root.pendingPersistPayload = "";
                Qt.callLater(function () {
                    root.persistOutputs(payload);
                });
            }
        }
    }
    property Process outputsQuery: Process {
        command: ["niri", "msg", "-j", "outputs"]

        stdout: StdioCollector {
            onStreamFinished: {
                var cleaned = text.trim();
                if (cleaned === "")
                    return;
                try {
                    var data = JSON.parse(cleaned);
                    var outputs = [];
                    for (var key in data) {
                        if (data.hasOwnProperty(key))
                            outputs.push(data[key]);
                    }
                    root.persistOutputs(JSON.stringify(outputs));
                } catch (error) {
                    console.warn("[DisplayHotplugService] Failed to parse outputs:", error);
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("[DisplayHotplugService] Failed to query outputs:", exitCode);
            if (root.refreshPending) {
                root.refreshPending = false;
                root.syncDelay.restart();
            }
        }
    }
    property Timer syncDelay: Timer {
        interval: 450
        repeat: false

        onTriggered: root.refreshOutputs()
    }
    property Connections screenConnections: Connections {
        function onScreensChanged() {
            root.syncDelay.restart();
        }

        target: Quickshell
    }

    function persistOutputs(payload) {
        if (!payload)
            return;
        if (outputPersistor.running) {
            pendingPersistPayload = payload;
            return;
        }
        outputPersistor.command = ["python3", Config.quickshellDir + "/scripts/display_output_config.py", configPath, payload];
        outputPersistor.running = true;
    }
    function refreshOutputs() {
        if (outputsQuery.running) {
            refreshPending = true;
            return;
        }
        refreshPending = false;
        outputsQuery.running = true;
    }
    function start() {
        syncDelay.restart();
    }
}
