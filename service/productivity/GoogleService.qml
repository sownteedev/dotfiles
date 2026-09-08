pragma Singleton
import "../../"
import ".."
import QtQuick

QtObject {
    id: root

    readonly property var accounts: CalendarService.accounts.filter(account => account.provider === "google" && account.enabled !== false)
    property int actionCount: 0
    readonly property bool active: activeConsumers > 0
    property int activeConsumers: 0
    readonly property var allTasks: buildTasks()
    readonly property bool authChecked: CalendarService.ready
    readonly property string authStatus: authenticated ? "" : qsTr("Connect Google in SownteeShell Calendar to use Tasks")
    readonly property bool authenticated: accounts.length > 0
    property Connections calendarConnections: Connections {
        function onAccountsChanged() {
            root.tasksChanged();
        }
        function onReadyChanged() {
            if (CalendarService.ready && root.active)
                root.refreshIfStale();
        }
        function onTaskSnapshotsChanged() {
            root.tasksChanged();
        }

        target: CalendarService
    }
    readonly property string connectedAccount: accounts.map(account => account.email || account.displayName).join(", ")
    property string errorMessage: ""
    readonly property bool isLoadingTasks: refreshCount > 0 || CalendarService.isLoading
    property int refreshCount: 0
    readonly property bool taskActionBusy: actionCount > 0
    readonly property var taskLists: buildTaskLists()

    signal taskActionFinished(string operation, string sourceId, bool succeeded, string remoteId, string message)
    signal tasksChanged

    function accountLabel(accountId) {
        for (var i = 0; i < accounts.length; ++i) {
            if (accounts[i].id === accountId)
                return accounts[i].email || accounts[i].displayName;
        }
        return "";
    }
    function acquire() {
        activeConsumers++;
        CalendarService.acquire();
        refreshIfStale();
    }
    function buildTaskLists() {
        var result = [];
        var snapshots = CalendarService.taskSnapshots;
        for (var i = 0; i < snapshots.length; ++i) {
            var snapshot = snapshots[i];
            if (!accounts.some(account => account.id === snapshot.accountId))
                continue;
            var lists = snapshot.lists || [];
            for (var j = 0; j < lists.length; ++j) {
                result.push({
                    "id": lists[j].id,
                    "title": lists[j].title || qsTr("Tasks"),
                    "accountId": snapshot.accountId,
                    "accountLabel": accountLabel(snapshot.accountId)
                });
            }
        }
        return result;
    }
    function buildTasks() {
        var result = [];
        var snapshots = CalendarService.taskSnapshots;
        var knownAccounts = accounts;
        for (var i = 0; i < snapshots.length; ++i) {
            var snapshot = snapshots[i];
            if (!knownAccounts.some(account => account.id === snapshot.accountId))
                continue;
            var tasks = snapshot.tasks || [];
            for (var j = 0; j < tasks.length; ++j) {
                if (tasks[j].deleted)
                    continue;
                result.push(Object.assign({}, tasks[j], {
                    "accountId": snapshot.accountId,
                    "accountLabel": accountLabel(snapshot.accountId)
                }));
            }
        }
        return result;
    }
    function checkAuthentication() {
        CalendarService.ensureRunning();
    }
    function createTask(listId, title, due, notes, sourceId, accountId, callback) {
        return mutate("create", {
            "accountId": accountId,
            "listId": listId,
            "title": title,
            "due": due || "",
            "notes": notes || ""
        }, sourceId, callback);
    }
    function deleteTask(listId, taskId, accountId, callback) {
        return mutate("delete", {
            "accountId": accountId,
            "listId": listId,
            "taskId": taskId
        }, "", callback);
    }
    function errorForAccount(accountId) {
        var snapshot = CalendarService.taskSnapshots.find(item => item.accountId === accountId);
        return snapshot ? String(snapshot.error || "") : "";
    }
    function fetchAll() {
        fetchTasks();
    }
    function fetchTasks() {
        if (!CalendarService.ready || refreshCount > 0)
            return;
        errorMessage = "";
        var targets = accounts.slice();
        refreshCount = targets.length;
        for (var i = 0; i < targets.length; ++i) {
            CalendarService.sendRequest("tasks.google.refresh", {
                "accountId": targets[i].id
            }, function () {
                root.finishRefresh("");
            }, function (message) {
                root.finishRefresh(message);
            });
        }
    }
    function finishRefresh(message) {
        if (message)
            errorMessage = message;
        refreshCount = Math.max(0, refreshCount - 1);
        if (refreshCount === 0)
            CalendarService.fetchAll();
    }
    function listsForAccount(accountId) {
        return taskLists.filter(list => list.accountId === accountId);
    }
    function mutate(operation, params, sourceId, callback) {
        if (!params.accountId) {
            errorMessage = qsTr("Select a Google account for this task");
            if (callback)
                callback(false, errorMessage);
            return false;
        }
        actionCount++;
        CalendarService.sendRequest("tasks.google." + operation, params, function (result) {
            root.actionCount--;
            root.errorMessage = "";
            root.taskActionFinished(operation, sourceId || "", true, String(result.id || ""), "");
            CalendarService.fetchAll();
            if (callback)
                callback(true, "");
        }, function (message) {
            root.actionCount--;
            root.errorMessage = message;
            root.taskActionFinished(operation, sourceId || "", false, "", message);
            if (callback)
                callback(false, message);
        });
        return true;
    }
    function refreshIfStale() {
        if (!CalendarService.ready || refreshCount > 0 || CalendarService.syncBusy)
            return;
        var snapshots = CalendarService.taskSnapshots;
        var stale = accounts.some(account => {
            var snapshot = snapshots.find(item => item.accountId === account.id);
            return !snapshot || !snapshot.updatedAt || Date.now() - new Date(snapshot.updatedAt).getTime() > 60000;
        });
        if (stale)
            fetchTasks();
    }
    function release() {
        if (activeConsumers > 0) {
            activeConsumers--;
            CalendarService.release();
        }
    }
    function requireAuthentication(context) {
        if (authenticated)
            return true;
        StateManager.showCalendarApp();
        return false;
    }
    function updateTask(listId, taskId, title, due, notes, status, accountId, callback) {
        var params = {
            "accountId": accountId,
            "listId": listId,
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
        return mutate("update", params, "", callback);
    }
}
