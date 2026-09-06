pragma Singleton
import "../../"
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property bool active: activeConsumers > 0
    property int activeConsumers: 0
    property var activeTaskContext: ({})
    property string activeTaskJobId: ""
    property string activeTaskRequestId: ""
    property var allTasks: []
    property bool authCheckPending: false
    property string authCheckRequestId: ""
    property bool authChecked: false
    property string authClientIdDraft: ""
    property string authError: ""
    property bool authPanelVisible: false
    property Process authProcess: Process {
        id: authProcess

        property string credentialsJson: ""

        command: [root.coreRunner, "google-tasks-auth-local"]
        stdinEnabled: true

        stderr: SplitParser {
            onRead: line => {
                var message = String(line || "").trim();
                if (message !== "" && root.authError === "")
                    root.authError = message;
            }
        }
        stdout: SplitParser {
            onRead: line => root.handleAuthenticationEvent(line)
        }

        Component.onDestruction: running = false
        onExited: {
            if (!root.authenticated && root.authenticating && root.authError === "")
                root.authError = qsTr("Authentication stopped before completion");
            root.authenticating = false;
        }
        onStarted: {
            write(credentialsJson + "\n");
            credentialsJson = "";
        }
    }
    property string authStatus: ""
    property string authUrl: ""
    property bool authenticated: false
    property bool authenticating: false
    property string connectedAccount: ""
    property Connections coreConnections: Connections {
        function onReadyChanged() {
            if (!CoreService.ready)
                return;
            if (root.authCheckPending)
                Qt.callLater(root.checkAuthentication);
            if (root.disconnecting && root.disconnectRequestId === "")
                Qt.callLater(root.runDisconnect);
            if (root.tasksRefreshPending && root.authenticated && !root.isLoadingTasks)
                Qt.callLater(root.fetchTasks);
            if (root.taskActionQueue.length > 0 && root.activeTaskRequestId === "")
                Qt.callLater(root.startNextTaskAction);
        }

        target: CoreService
    }
    readonly property string coreRunner: Config.sownteeshellDir + "/backend/rust/core-daemon/run-core-daemon"
    property string disconnectRequestId: ""
    property bool disconnecting: false
    property string errorMessage: ""
    property string fetchTasksJobId: ""
    property string fetchTasksRequestId: ""
    property bool isLoadingTasks: false
    property string lastTaskListId: "@default"
    property date lastTasksUpdated
    readonly property int networkRequestTimeoutMs: 45000
    property string oauthClientId: ""
    property string oauthClientSecret: ""
    property string pendingAuthContext: ""
    property Timer refreshTimer: Timer {
        interval: 900000
        repeat: true
        running: root.active && root.authenticated

        onTriggered: root.fetchTasks()
    }
    readonly property bool taskActionBusy: activeTaskRequestId !== "" || taskActionQueue.length > 0
    property var taskActionQueue: []
    property bool tasksRefreshPending: false

    signal authenticationSucceeded(string context)
    signal taskActionFinished(string operation, string sourceId, bool succeeded, string remoteId, string message)
    signal tasksChanged

    function acquire() {
        activeConsumers++;
        if (!authChecked)
            checkAuthentication();
        else if (authenticated && needsRefresh())
            fetchTasks();
    }
    function cancelAuthentication() {
        if (authProcess.running)
            authProcess.running = false;
        authenticating = false;
        authPanelVisible = false;
        authStatus = "";
        authError = "";
        authUrl = "";
        pendingAuthContext = "";
    }
    function cancelCoreRequest(requestId, jobId) {
        if (requestId !== "")
            CoreService.forgetRequest(requestId);
        if (jobId !== "" && CoreService.ready)
            CoreService.sendRequest("job.cancel", {
                "jobId": jobId
            });
    }
    function checkAuthentication() {
        if (disconnecting)
            return;
        if (authCheckRequestId !== "") {
            authCheckPending = true;
            return;
        }
        if (!CoreService.ready) {
            authCheckPending = true;
            CoreService.ensureRunning();
            return;
        }

        authCheckPending = false;
        authCheckRequestId = CoreService.sendRequest("productivity.googleTasks.authStatus", {}, function (result) {
            root.authCheckRequestId = "";
            root.authChecked = true;
            root.authenticated = result && result.authenticated === true;
            root.oauthClientId = String(result && result.clientId || "");
            root.oauthClientSecret = String(result && result.clientSecret || "");
            root.connectedAccount = String(result && result.accountEmail || "");
            if (root.authClientIdDraft === "" && root.oauthClientId !== "")
                root.authClientIdDraft = root.oauthClientId;
            if (root.authenticated) {
                root.authStatus = "";
                root.fetchTasks();
            } else if (root.allTasks.length > 0) {
                root.allTasks = [];
                root.tasksChanged();
            }
        }, function (message) {
            root.authCheckRequestId = "";
            root.authChecked = true;
            root.authenticated = false;
            root.authStatus = String(message || qsTr("Could not check Google Tasks authentication"));
        });
    }
    function createTask(listId, title, due, notes, sourceId) {
        if (!authenticated) {
            requireAuthentication("todo-add");
            return false;
        }
        enqueueTaskAction("productivity.googleTasks.create", {
            "due": due,
            "listId": listId || "@default",
            "notes": notes,
            "title": title
        }, {
            "operation": sourceId ? "sync-local" : "create",
            "sourceId": String(sourceId || "")
        });
        return true;
    }
    function deleteTask(listId, taskId) {
        if (!authenticated) {
            requireAuthentication("");
            return false;
        }
        enqueueTaskAction("productivity.googleTasks.delete", {
            "listId": listId || "@default",
            "taskId": taskId
        }, {
            "operation": "delete",
            "sourceId": ""
        });
        return true;
    }
    function disconnectAccount() {
        if (disconnecting)
            return;

        disconnecting = true;
        authenticated = false;
        authCheckPending = false;
        tasksRefreshPending = false;
        var interruptedActions = taskActionQueue;
        taskActionQueue = [];
        cancelAuthentication();

        for (var i = 0; i < interruptedActions.length; ++i) {
            var interruptedActionContext = interruptedActions[i].context || {};
            taskActionFinished(String(interruptedActionContext.operation || ""), String(interruptedActionContext.sourceId || ""), false, "", qsTr("Google account was disconnected"));
        }

        if (authCheckRequestId !== "") {
            CoreService.forgetRequest(authCheckRequestId);
            authCheckRequestId = "";
        }
        if (fetchTasksRequestId !== "") {
            cancelCoreRequest(fetchTasksRequestId, fetchTasksJobId);
            fetchTasksRequestId = "";
            fetchTasksJobId = "";
            isLoadingTasks = false;
        }
        if (activeTaskRequestId !== "") {
            var interruptedContext = activeTaskContext || {};
            cancelCoreRequest(activeTaskRequestId, activeTaskJobId);
            activeTaskRequestId = "";
            activeTaskJobId = "";
            activeTaskContext = ({});
            taskActionFinished(String(interruptedContext.operation || ""), String(interruptedContext.sourceId || ""), false, "", qsTr("Google account was disconnected"));
        }
        authStatus = qsTr("Removing Google account…");
        runDisconnect();
    }
    function enqueueTaskAction(method, params, context) {
        var queue = taskActionQueue.slice();
        queue.push({
            "context": context || {},
            "method": method,
            "params": params || {}
        });
        taskActionQueue = queue;
        startNextTaskAction();
    }
    function fetchAll() {
        fetchTasks();
    }
    function fetchTasks(listId) {
        if (!authenticated)
            return;
        if (listId)
            lastTaskListId = String(listId);
        if (isLoadingTasks || fetchTasksRequestId !== "") {
            tasksRefreshPending = true;
            return;
        }
        if (!CoreService.ready) {
            tasksRefreshPending = true;
            CoreService.ensureRunning();
            return;
        }

        tasksRefreshPending = false;
        isLoadingTasks = true;
        fetchTasksJobId = requestJobId("google-tasks-list");
        fetchTasksRequestId = CoreService.sendRequest("productivity.googleTasks.list", {
            "_job_id": fetchTasksJobId,
            "listId": lastTaskListId
        }, function (result) {
            root.fetchTasksRequestId = "";
            root.fetchTasksJobId = "";
            root.isLoadingTasks = false;
            if (Array.isArray(result)) {
                root.allTasks = result;
                root.lastTasksUpdated = new Date();
                root.errorMessage = "";
                root.tasksChanged();
            } else {
                root.handleRequestError(qsTr("Google Tasks returned an invalid response"));
            }
            root.finishTaskRefresh();
        }, function (message) {
            root.fetchTasksRequestId = "";
            root.fetchTasksJobId = "";
            root.isLoadingTasks = false;
            root.handleRequestError(message);
            root.finishTaskRefresh();
        }, networkRequestTimeoutMs);
    }
    function finishDisconnect() {
        disconnecting = false;
        authenticated = false;
        authChecked = true;
        authPanelVisible = false;
        authError = "";
        authUrl = "";
        pendingAuthContext = "";
        errorMessage = "";
        allTasks = [];
        connectedAccount = "";
        oauthClientId = "";
        oauthClientSecret = "";
        authClientIdDraft = "";
        authStatus = qsTr("Google account removed from this device.");
        tasksChanged();
    }
    function finishTaskAction(succeeded, result, message) {
        var context = activeTaskContext || {};
        var remoteId = String(result && result.id || "");
        activeTaskRequestId = "";
        activeTaskJobId = "";
        activeTaskContext = ({});
        if (succeeded)
            fetchTasks();
        else
            handleRequestError(message);
        taskActionFinished(String(context.operation || ""), String(context.sourceId || ""), succeeded, remoteId, String(message || ""));
        Qt.callLater(startNextTaskAction);
    }
    function finishTaskRefresh() {
        if (!tasksRefreshPending || !authenticated)
            return;
        tasksRefreshPending = false;
        Qt.callLater(fetchTasks);
    }
    function handleAuthenticationEvent(line) {
        var text = String(line || "").trim();
        if (text === "")
            return;
        try {
            var message = JSON.parse(text);
            if (message.event === "authorization_url") {
                authUrl = String(message.url || "");
                authStatus = qsTr("Complete authentication in your browser");
                if (authUrl !== "")
                    Quickshell.execDetached(["xdg-open", authUrl]);
            } else if (message.event === "success") {
                var context = pendingAuthContext;
                authenticated = true;
                authChecked = true;
                authenticating = false;
                authPanelVisible = false;
                authStatus = qsTr("Connected");
                authError = "";
                authUrl = "";
                pendingAuthContext = "";
                fetchTasks();
                authenticationSucceeded(context);
            } else if (message.event === "error") {
                authError = String(message.message || qsTr("Authentication failed"));
                authStatus = "";
            }
        } catch (error) {
            authError = qsTr("Invalid authentication response");
        }
    }
    function handleRequestError(message) {
        var text = String(message || qsTr("Google Tasks request failed")).trim();
        errorMessage = text;
        var normalized = text.toLowerCase();
        if (normalized.indexOf("invalid_grant") >= 0 || normalized.indexOf("unauthorized") >= 0 || normalized.indexOf("session expired") >= 0 || normalized.indexOf("not connected") >= 0 || normalized.indexOf("401") >= 0) {
            authenticated = false;
            authChecked = true;
            authStatus = qsTr("Google session expired. Connect again to continue.");
        }
    }
    function needsRefresh() {
        var updatedAt = lastTasksUpdated && !isNaN(lastTasksUpdated.getTime()) ? lastTasksUpdated.getTime() : 0;
        return updatedAt === 0 || Date.now() - updatedAt >= refreshTimer.interval;
    }
    function release() {
        activeConsumers = Math.max(0, activeConsumers - 1);
    }
    function requestJobId(prefix) {
        return prefix + "-" + Date.now() + "-" + Math.floor(Math.random() * 1000000);
    }
    function requireAuthentication(context) {
        if (authenticated)
            return true;
        pendingAuthContext = context || "";
        authError = "";
        authStatus = authChecked ? qsTr("Connect your Google account to continue") : qsTr("Checking Google authentication…");
        authPanelVisible = true;
        return false;
    }
    function runDisconnect() {
        if (!disconnecting || disconnectRequestId !== "")
            return;
        if (!CoreService.ready) {
            CoreService.ensureRunning();
            return;
        }
        disconnectRequestId = CoreService.sendRequest("productivity.googleTasks.logout", {}, function (result) {
            root.disconnectRequestId = "";
            if (result && result.success === true)
                root.finishDisconnect();
            else {
                root.disconnecting = false;
                root.authStatus = qsTr("Could not remove Google account");
                root.checkAuthentication();
            }
        }, function (message) {
            root.disconnectRequestId = "";
            root.disconnecting = false;
            root.authStatus = qsTr("Could not remove Google account: %1").arg(String(message || qsTr("Unknown error")));
            root.checkAuthentication();
        });
    }
    function startAuthentication(clientId, clientSecret) {
        if (authenticating)
            return;
        if (!String(clientId || "").trim() || !String(clientSecret || "").trim()) {
            authError = qsTr("Client ID and Client Secret are required");
            return;
        }
        authError = "";
        authUrl = "";
        authStatus = qsTr("Starting local authentication…");
        oauthClientId = String(clientId).trim();
        oauthClientSecret = String(clientSecret).trim();
        authenticating = true;
        authProcess.credentialsJson = JSON.stringify({
            "clientId": oauthClientId,
            "clientSecret": oauthClientSecret
        });
        authProcess.running = true;
    }
    function startNextTaskAction() {
        if (activeTaskRequestId !== "" || taskActionQueue.length === 0)
            return;
        if (!authenticated) {
            var abandoned = taskActionQueue;
            taskActionQueue = [];
            for (var i = 0; i < abandoned.length; ++i) {
                var abandonedContext = abandoned[i].context || {};
                taskActionFinished(String(abandonedContext.operation || ""), String(abandonedContext.sourceId || ""), false, "", qsTr("Google account is not connected"));
            }
            return;
        }
        if (!CoreService.ready) {
            CoreService.ensureRunning();
            return;
        }

        var queue = taskActionQueue.slice();
        var action = queue.shift();
        taskActionQueue = queue;
        activeTaskContext = action.context || {};
        activeTaskJobId = requestJobId("google-task-action");
        var params = Object.assign({}, action.params || {});
        params._job_id = activeTaskJobId;
        activeTaskRequestId = CoreService.sendRequest(String(action.method || ""), params, function (result) {
            if (result && result.success === false) {
                root.finishTaskAction(false, result, String(result.error || qsTr("Google Tasks request failed")));
                return;
            }
            root.finishTaskAction(true, result || {}, "");
        }, function (message) {
            root.finishTaskAction(false, {}, String(message || qsTr("Google Tasks request failed")));
        }, networkRequestTimeoutMs);
    }
    function updateTask(listId, taskId, title, due, notes, status) {
        if (!authenticated) {
            requireAuthentication("");
            return false;
        }
        var params = {
            "listId": listId || "@default",
            "taskId": taskId
        };
        if (title !== undefined)
            params.title = title;
        if (due !== undefined)
            params.due = due;
        if (notes !== undefined)
            params.notes = notes;
        if (status !== undefined)
            params.status = status;
        enqueueTaskAction("productivity.googleTasks.update", params, {
            "operation": "update",
            "sourceId": ""
        });
        return true;
    }

    Component.onCompleted: checkAuthentication()
    Component.onDestruction: {
        if (authProcess.running)
            authProcess.running = false;
        cancelCoreRequest(fetchTasksRequestId, fetchTasksJobId);
        cancelCoreRequest(activeTaskRequestId, activeTaskJobId);
    }
}
