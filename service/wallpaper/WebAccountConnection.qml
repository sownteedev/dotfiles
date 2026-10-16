import "../../"
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property string accountId: ""
    property string accountLabel: ""
    readonly property bool busy: process.running || process.launchPending
    property bool connected: false
    property string errorMessage: ""
    property string itemId: ""
    property string operation: ""
    property Process process: Process {
        property bool launchPending: false
        property string requestJson: ""

        command: ["python3", Config.sownteeshellDir + "/backend/python/wallpaper/web_account.py", "--watch-stdin"]
        stdinEnabled: true

        stderr: StdioCollector {
        }
        stdout: StdioCollector {
            id: output
        }

        onExited: (exitCode, exitStatus) => {
            var response;
            try {
                response = JSON.parse(output.text.trim());
            } catch (error) {
                response = {
                    ok: false,
                    message: qsTr("The account helper stopped unexpectedly. Check the website before retrying.")
                };
            }
            if (!response || typeof response !== "object")
                response = {
                    ok: false,
                    message: qsTr("Invalid account response")
                };
            if (response.connected !== undefined)
                root.connected = Boolean(response.connected);
            if (response.account) {
                root.accountId = String(response.account.id || "");
                root.accountLabel = String(response.account.label || "");
            }
            if (!root.connected) {
                root.accountId = "";
                root.accountLabel = "";
            }
            if (response.ok && exitCode === 0) {
                root.errorMessage = "";
                root.statusMessage = root.operation === "status" || root.operation === "restore" ? "" : String(response.message || "");
                root.succeeded(root.operation, response);
            } else {
                root.errorMessage = String(response.message || qsTr("Account request failed"));
                root.statusMessage = "";
            }
        }
        onRunningChanged: {
            if (!running && launchPending) {
                launchPending = false;
                root.errorMessage = qsTr("Could not start the account helper. Install pyside6 and qt6-webengine.");
                root.statusMessage = "";
            }
        }
        onStarted: {
            launchPending = false;
            write(requestJson + "\n");
            requestJson = "";
        }
    }
    required property string provider
    property string statusMessage: ""

    signal succeeded(string action, var response)

    function connectAccount() {
        return start("connect", {});
    }
    function disconnectAccount() {
        return start("disconnect", {});
    }
    function refresh() {
        return start("status", {});
    }
    function start(action, parameters) {
        if (busy)
            return false;
        var request = Object.assign({}, parameters || {}, {
            provider: provider,
            action: action
        });
        operation = action;
        itemId = String(request.item_id || "");
        errorMessage = "";
        statusMessage = action === "restore" ? "" : action === "connect" ? qsTr("Complete sign-in in the account window") : action === "status" ? qsTr("Checking account session...") : qsTr("Contacting account website...");
        process.requestJson = JSON.stringify(request);
        process.launchPending = true;
        process.running = true;
        return true;
    }

    Component.onCompleted: start("restore", {})
}
