pragma Singleton
import ".."
import QtQuick

QtObject {
    id: root

    readonly property var accounts: CalendarService.accounts.filter(account => account.provider === "google" && account.enabled !== false)
    property var refreshErrors: ({})
    property var refreshingAccounts: ({})

    function createTask(listId, title, due, notes, accountId, callback) {
        if (!accounts.some(account => account.id === accountId) || !listsForAccount(accountId).some(list => list.id === listId) || String(title || "").trim() === "") {
            if (callback)
                callback(false, qsTr("Choose an available Google account and task list, and enter a title."));
            return false;
        }
        return mutate("create", {
            "accountId": accountId,
            "listId": listId,
            "title": String(title).trim(),
            "due": due || "",
            "notes": notes || ""
        }, callback);
    }
    function deleteTask(listId, taskId, accountId, callback) {
        return mutate("delete", {
            "accountId": accountId,
            "listId": listId,
            "taskId": taskId
        }, callback);
    }
    function errorForAccount(accountId) {
        var snapshot = CalendarService.taskSnapshots.find(item => item.accountId === accountId);
        return refreshErrors[accountId] || (snapshot ? String(snapshot.error || "") : "");
    }
    function finishRefresh(accountId, message) {
        refreshingAccounts = Object.assign({}, refreshingAccounts, {
            [accountId]: false
        });
        refreshErrors = Object.assign({}, refreshErrors, {
            [accountId]: message
        });
        CalendarService.fetchAll();
    }
    function listsForAccount(accountId) {
        if (!accounts.some(account => account.id === accountId))
            return [];
        var snapshot = CalendarService.taskSnapshots.find(item => item.accountId === accountId);
        return snapshot && Array.isArray(snapshot.lists) ? snapshot.lists : [];
    }
    function mutate(operation, params, callback) {
        if (!params.accountId) {
            if (callback)
                callback(false, qsTr("Select a Google account for this task"));
            return false;
        }
        CalendarService.sendRequest("tasks.google." + operation, params, function () {
            CalendarService.fetchAll();
            if (callback)
                callback(true, "");
        }, function (message) {
            if (callback)
                callback(false, message);
        });
        return true;
    }
    function refreshTasks(accountId) {
        if (!accountId || refreshingAccounts[accountId] || !accounts.some(account => account.id === accountId))
            return;
        refreshingAccounts = Object.assign({}, refreshingAccounts, {
            [accountId]: true
        });
        refreshErrors = Object.assign({}, refreshErrors, {
            [accountId]: ""
        });
        CalendarService.sendRequest("tasks.google.refresh", {
            "accountId": accountId
        }, function () {
            root.finishRefresh(accountId, "");
        }, function (message) {
            root.finishRefresh(accountId, message);
        });
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
        return mutate("update", params, callback);
    }
}
