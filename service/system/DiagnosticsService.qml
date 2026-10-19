pragma Singleton
import "../../"
import QtQuick
import ".."

QtObject {
    id: root

    property bool actionFailed: false
    property string actionMessage: ""
    property string activeRequestId: ""
    property bool busy: false
    property var caches: []
    property var dependencies: []
    property string message: ""
    property bool mutationBusy: false
    property var queuedMutation: null
    property var services: []
    property ListModel startupApps: ListModel {
    }
    property ListModel systemServices: ListModel {
    }
    property ListModel userServices: ListModel {
    }

    function clearCache(scope) {
        if (busy)
            return;
        runRequest("clear", String(scope || ""));
    }
    function dispatchQueuedMutation() {
        if (busy || !queuedMutation)
            return;
        var request = queuedMutation;
        queuedMutation = null;
        busy = true;
        activeRequestId = CoreService.sendRequest(request.method, request.params, function (result) {
            root.activeRequestId = "";
            root.mutationBusy = false;
            root.busy = false;
            root.message = String(result && result.message || (result && result.ok ? qsTr("Saved") : qsTr("Action failed")));
            root.actionFailed = !(result && result.ok === true);
            root.actionMessage = root.message;
            Qt.callLater(root.refresh);
        }, function (errorMessage) {
            root.activeRequestId = "";
            root.mutationBusy = false;
            root.busy = false;
            root.message = String(errorMessage || qsTr("Action failed"));
            root.actionFailed = true;
            root.actionMessage = root.message;
            Qt.callLater(root.refresh);
        }, request.method === "diagnostics.serviceAction" ? 150000 : 15000);
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
        if (busy || mutationBusy)
            return;
        runRequest("snapshot", "");
    }
    function runMutation(method, params) {
        mutationBusy = true;
        actionFailed = false;
        actionMessage = params.scope === "system" ? qsTr("Applying system service change; authorize if prompted...") : qsTr("Applying change...");
        queuedMutation = {
            "method": method,
            "params": params
        };
        dispatchQueuedMutation();
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
                root.syncModel(root.startupApps, result.startupApps, "path");
                root.syncModel(root.userServices, result.userServices, "name");
                root.syncModel(root.systemServices, result.systemServices, "name");
            } else if (succeeded && action === "clear") {
                Qt.callLater(root.refresh);
            }
            root.dispatchQueuedMutation();
        }, function (errorMessage) {
            root.activeRequestId = "";
            root.busy = false;
            root.message = String(errorMessage || qsTr("Diagnostics failed"));
            root.dispatchQueuedMutation();
        }, 60000);
    }
    function serviceAction(name, action, scope) {
        if (mutationBusy)
            return;
        runMutation("diagnostics.serviceAction", {
            "name": String(name || ""),
            "action": String(action || ""),
            "scope": String(scope || "user")
        });
    }
    function startupAction(path, enabled) {
        if (mutationBusy)
            return;
        runMutation("diagnostics.startupAction", {
            "path": String(path || ""),
            "enabled": enabled === true
        });
    }
    function syncModel(model, items, keyRole) {
        var incoming = items || [];
        var incomingKeys = {};
        for (var incomingIndex = 0; incomingIndex < incoming.length; ++incomingIndex)
            incomingKeys[String(incoming[incomingIndex][keyRole] || "")] = true;

        for (var existingIndex = model.count - 1; existingIndex >= 0; --existingIndex) {
            var existingKey = String(model.get(existingIndex).stableKey || "");
            if (!incomingKeys[existingKey])
                model.remove(existingIndex);
        }

        for (var targetIndex = 0; targetIndex < incoming.length; ++targetIndex) {
            var item = incoming[targetIndex];
            var key = String(item[keyRole] || "");
            var payload = JSON.stringify(item);
            var modelIndex = -1;
            for (var searchIndex = 0; searchIndex < model.count; ++searchIndex) {
                if (String(model.get(searchIndex).stableKey || "") === key) {
                    modelIndex = searchIndex;
                    break;
                }
            }
            if (modelIndex < 0) {
                model.insert(targetIndex, {
                    "payload": payload,
                    "stableKey": key
                });
            } else {
                if (modelIndex !== targetIndex)
                    model.move(modelIndex, targetIndex, 1);
                if (model.get(targetIndex).payload !== payload)
                    model.setProperty(targetIndex, "payload", payload);
            }
        }
    }
}
