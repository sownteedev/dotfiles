pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../.."
import ".."

QtObject {
    id: root

    property bool accountActionBusy: false
    property var accounts: []
    property int activeConsumers: 0
    property var allEvents: []
    readonly property bool authenticated: accounts.length > 0
    readonly property var calendarAppEvents: allEvents.concat(taskEvents, Config.calendarShowLocalTasks ? localTaskEvents : [])
    property var calendars: []
    readonly property string connectedAccount: accounts.length > 0 ? String(accounts[0].email || accounts[0].displayName || "") : ""
    property Timer connectionRetry: Timer {
        interval: 500
        repeat: false

        onTriggered: {
            if (requestSocket.connected)
                return;
            requestSocket.connected = false;
            Qt.callLater(function () {
                requestSocket.connected = true;
            });
        }
    }
    property Process daemonProcess: Process {
        id: daemonProcess

        command: [Config.sownteeshellDir + "/backend/rust/calendar-daemon/run-calendar-daemon", "serve"]
        running: false

        stderr: SplitParser {
            onRead: line => {
                var message = String(line || "").trim();
                if (message !== "" && message.indexOf("listening at") < 0)
                    console.log("[CalendarService]", message);
            }
        }

        onExited: exitCode => {
            root.daemonStarted = false;
            if (!requestSocket.connected) {
                root.daemonStatus = "stopped";
                root.daemonRestart.restart();
            }
        }
        onStarted: {
            root.daemonStarted = true;
            root.daemonStatus = "starting";
            root.connectionRetry.restart();
        }
    }
    property Timer daemonRestart: Timer {
        interval: 5000
        repeat: false

        onTriggered: root.ensureRunning()
    }
    property Timer daemonStartDelay: Timer {
        interval: 5000
        repeat: false

        onTriggered: {
            if (!root.requestSocket.connected)
                root.daemonRestart.restart();
        }
    }
    property bool daemonStarted: false
    property string daemonStatus: "starting"
    readonly property string daemonUnit: "sownteeshell-calendar.service"
    property bool eventActionBusy: false
    property int fetchInFlight: 0
    property bool initialLoaded: false
    readonly property bool isLoading: fetchInFlight > 0 || syncBusy || accountActionBusy
    property string lastError: ""
    property date lastEventsUpdated
    readonly property var localTaskEvents: buildLocalTaskEvents(LocalTaskService.tasks)
    property int nextRequestId: 1
    property var pendingRequests: ({})
    property var rawEvents: []
    readonly property bool ready: requestSocket.connected && initialLoaded
    property Timer refreshDebounce: Timer {
        interval: 120
        repeat: false

        onTriggered: root.fetchAll()
    }
    property bool refreshPending: false
    property Socket requestSocket: Socket {
        id: requestSocket

        connected: false
        path: root.socketPath

        parser: SplitParser {
            splitMarker: "\n"

            onRead: line => root.handleResponse(line)
        }

        onConnectionStateChanged: root.handleRequestConnection()
        onError: error => root.requestReconnect()
    }
    readonly property string runtimeBase: Quickshell.env("XDG_RUNTIME_DIR") || ""
    readonly property string socketOverride: Quickshell.env("SOWNTEE_CALENDAR_SOCKET") || ""
    readonly property string socketPath: socketOverride !== "" ? socketOverride : (runtimeBase !== "" ? runtimeBase + "/sownteeshell/calendar/calendar.sock" : (Quickshell.env("XDG_DATA_HOME") || Config.homeDir + "/.local/share") + "/sownteeshell/calendar/runtime/calendar.sock")
    property bool subscribed: false
    property Timer subscriptionRetry: Timer {
        interval: 800
        repeat: false

        onTriggered: {
            if (!requestSocket.connected || subscriptionSocket.connected)
                return;
            subscriptionSocket.connected = true;
        }
    }
    property Socket subscriptionSocket: Socket {
        id: subscriptionSocket

        connected: false
        path: root.socketPath

        parser: SplitParser {
            splitMarker: "\n"

            onRead: line => root.handleSubscriptionLine(line)
        }

        onConnectionStateChanged: {
            if (!connected) {
                root.subscribed = false;
                return;
            }
            write(JSON.stringify({
                "id": "subscription",
                "method": "subscribe",
                "params": {
                    "topics": ["accounts", "calendars", "events", "tasks", "sync"]
                }
            }) + "\n");
            flush();
        }
        onError: error => {
            root.subscribed = false;
            if (connected)
                connected = false;
            root.subscriptionRetry.restart();
        }
    }
    property bool syncBusy: false
    property var syncingAccounts: ({})
    property Process systemdStarter: Process {
        id: systemdStarter

        command: ["systemctl", "--user", "start", "--no-block", root.daemonUnit]
        running: false

        stderr: StdioCollector {
        }
        stdout: StdioCollector {
        }

        onExited: (exitCode, exitStatus) => {
            if (requestSocket.connected)
                return;
            if (exitCode !== 0) {
                root.daemonStatus = "stopped";
                root.daemonStartDelay.stop();
                root.daemonRestart.restart();
            }
        }
        onStarted: {
            root.daemonStatus = "starting";
            root.daemonStartDelay.restart();
        }
    }
    property var taskEvents: []
    property var taskSnapshots: []

    signal accountAdded(string accountId)
    signal accountRemoved(string accountId)
    signal eventActionFinished(string operation, bool success, string message)

    function acquire() {
        activeConsumers += 1;
        ensureRunning();
    }
    function addGoogle(clientId, clientSecret, callback) {
        if (accountActionBusy)
            return;
        accountActionBusy = true;
        sendRequest("accounts.google.add", {
            "clientId": String(clientId || "").trim(),
            "clientSecret": String(clientSecret || "").trim()
        }, result => {
            accountActionBusy = false;
            applyAccountResult(result);
            var accountId = result && result.account ? String(result.account.id || "") : "";
            fetchAll();
            accountAdded(accountId);
            if (callback)
                callback(true, "");
        }, message => {
            accountActionBusy = false;
            if (callback)
                callback(false, message);
        });
    }
    function addIcloud(email, username, appPassword, server, displayName, callback) {
        if (accountActionBusy)
            return;
        accountActionBusy = true;
        sendRequest("accounts.icloud.add", {
            "email": String(email || "").trim(),
            "username": String(username || "").trim(),
            "appPassword": String(appPassword || ""),
            "server": String(server || "").trim(),
            "displayName": String(displayName || "").trim()
        }, result => {
            accountActionBusy = false;
            applyAccountResult(result);
            var accountId = result && result.account ? String(result.account.id || "") : "";
            fetchAll();
            accountAdded(accountId);
            if (callback)
                callback(true, "");
        }, message => {
            accountActionBusy = false;
            if (callback)
                callback(false, message);
        });
    }
    function addMicrosoft(clientId, tenant, callback) {
        if (accountActionBusy)
            return;
        accountActionBusy = true;
        sendRequest("accounts.microsoft.add", {
            "clientId": String(clientId || "").trim(),
            "tenant": String(tenant || "common").trim() || "common"
        }, result => {
            accountActionBusy = false;
            applyAccountResult(result);
            var accountId = result && result.account ? String(result.account.id || "") : "";
            fetchAll();
            accountAdded(accountId);
            if (callback)
                callback(true, "");
        }, message => {
            accountActionBusy = false;
            if (callback)
                callback(false, message);
        });
    }
    function applyAccountResult(result) {
        if (!result || !result.account)
            return;
        var accountId = String(result.account.id || "");
        var nextAccounts = [];
        for (var accountIndex = 0; accountIndex < accounts.length; ++accountIndex) {
            if (String(accounts[accountIndex].id || "") !== accountId)
                nextAccounts.push(accounts[accountIndex]);
        }
        nextAccounts.push(result.account);
        accounts = nextAccounts;

        var nextCalendars = [];
        for (var calendarIndex = 0; calendarIndex < calendars.length; ++calendarIndex) {
            if (String(calendars[calendarIndex].accountId || "") !== accountId)
                nextCalendars.push(calendars[calendarIndex]);
        }
        var addedCalendars = Array.isArray(result.calendars) ? result.calendars : [];
        for (var addedIndex = 0; addedIndex < addedCalendars.length; ++addedIndex)
            nextCalendars.push(addedCalendars[addedIndex]);
        calendars = nextCalendars;
        rebuildDecoratedData();
    }
    function buildEventDraft(title, date, startTime, endTime, allDay, location, description) {
        var parts = localDateParts(date);
        if (!parts) {
            lastError = qsTr("The event date is invalid.");
            return null;
        }
        var start;
        var end;
        if (allDay === true) {
            start = new Date(Date.UTC(parts[0], parts[1], parts[2]));
            end = new Date(Date.UTC(parts[0], parts[1], parts[2] + 1));
        } else {
            var startParts = String(startTime || "00:00").split(":");
            var endParts = String(endTime || "01:00").split(":");
            start = new Date(parts[0], parts[1], parts[2], Number(startParts[0] || 0), Number(startParts[1] || 0));
            end = new Date(parts[0], parts[1], parts[2], Number(endParts[0] || 0), Number(endParts[1] || 0));
        }
        if (isNaN(start.getTime()) || isNaN(end.getTime()) || end <= start) {
            lastError = qsTr("The event time range is invalid.");
            return null;
        }
        return {
            "title": String(title || "").trim(),
            "description": String(description || "").trim(),
            "location": String(location || "").trim(),
            "start": start.toISOString(),
            "end": end.toISOString(),
            "allDay": allDay === true
        };
    }
    function buildLocalTaskEvents(sourceTasks) {
        var tasks = Array.isArray(sourceTasks) ? sourceTasks : (typeof LocalTaskService !== "undefined" && LocalTaskService ? LocalTaskService.tasks : []);
        if (!tasks)
            return [];
        return tasks.filter(task => task && (task.status === "needsAction" || task.status === "completed") && task.due).map(task => {
            var day = String(task.due).slice(0, 10);
            var parts = day.split("-");
            var end = new Date(Date.UTC(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]) + 1));
            return {
                "id": task.id,
                "taskId": task.id,
                "calendarId": "local-tasks",
                "isTask": true,
                "taskSource": "local",
                "title": task.title,
                "description": task.notes || "",
                "start": day + "T00:00:00Z",
                "end": isNaN(end.getTime()) ? "" : end.toISOString(),
                "allDay": true,
                "readOnly": false,
                "status": task.status,
                "calendarColor": Config.md3.secondary,
                "calendarName": qsTr("Local tasks"),
                "accountName": qsTr("On this device")
            };
        }).filter(task => task.end !== "");
    }
    function calendarById(calendarId) {
        var wanted = String(calendarId || "");
        for (var index = 0; index < calendars.length; ++index) {
            if (String(calendars[index].id || "") === wanted)
                return calendars[index];
        }
        return null;
    }
    function calendarsForAccount(accountId) {
        var wanted = String(accountId || "");
        var result = [];
        for (var index = 0; index < calendars.length; ++index) {
            if (String(calendars[index].accountId || "") === wanted)
                result.push(calendars[index]);
        }
        return result;
    }
    function createEvent(calendarId, title, date, startTime, endTime, allDay, location, description, callback) {
        if (eventActionBusy)
            return;
        var draft = buildEventDraft(title, date, startTime, endTime, allDay, location, description);
        if (!draft) {
            if (callback)
                callback(false, lastError);
            return;
        }
        eventActionBusy = true;
        sendRequest("events.create", {
            "calendarId": String(calendarId || ""),
            "event": draft
        }, result => finishEventAction("create", true, "", callback), message => finishEventAction("create", false, message, callback));
    }
    function deleteEvent(calendarId, eventId, callback) {
        if (eventActionBusy)
            return;
        eventActionBusy = true;
        sendRequest("events.delete", {
            "eventId": String(eventId || "")
        }, result => finishEventAction("delete", true, "", callback), message => finishEventAction("delete", false, message, callback));
    }
    function ensureRunning() {
        if (requestSocket.connected) {
            daemonStartDelay.stop();
            return;
        }
        if (!connectionRetry.running)
            connectionRetry.start();
        if (socketOverride !== "") {
            startFallbackDaemon();
            return;
        }
        if (systemdStarter.running || daemonStartDelay.running || daemonRestart.running)
            return;
        systemdStarter.running = true;
    }
    function failPendingRequests(message) {
        var pending = pendingRequests;
        var identifiers = Object.keys(pending);
        if (identifiers.length === 0)
            return;
        pendingRequests = ({});
        for (var index = 0; index < identifiers.length; ++index) {
            var entry = pending[identifiers[index]];
            if (entry && entry.failure)
                entry.failure(message);
        }
        fetchInFlight = 0;
        accountActionBusy = false;
        eventActionBusy = false;
        syncBusy = false;
        syncingAccounts = ({});
    }
    function fetchAll() {
        ensureRunning();
        if (!requestSocket.connected) {
            refreshPending = true;
            return;
        }
        if (fetchInFlight > 0) {
            refreshPending = true;
            return;
        }

        refreshPending = false;
        lastError = "";
        fetchInFlight = 4;
        sendRequest("tasks.list", {}, result => {
            taskSnapshots = Array.isArray(result) ? result : [];
            rebuildDecoratedData();
            finishFetch();
        }, message => finishFetch());
        sendRequest("accounts.list", {}, result => {
            accounts = Array.isArray(result) ? result : [];
            rebuildDecoratedData();
            finishFetch();
        }, message => finishFetch());
        sendRequest("calendars.list", {}, result => {
            calendars = Array.isArray(result) ? result : [];
            rebuildDecoratedData();
            finishFetch();
        }, message => finishFetch());
        sendRequest("events.list", {
            "visibleOnly": false
        }, result => {
            rawEvents = Array.isArray(result) ? result : [];
            lastEventsUpdated = new Date();
            rebuildDecoratedData();
            finishFetch();
        }, message => finishFetch());
    }
    function finishEventAction(operation, success, message, callback) {
        eventActionBusy = false;
        if (success)
            fetchAll();
        eventActionFinished(operation, success, message);
        if (callback)
            callback(success, message);
    }
    function finishFetch() {
        fetchInFlight = Math.max(0, fetchInFlight - 1);
        if (fetchInFlight !== 0)
            return;
        initialLoaded = true;
        daemonStatus = "ready";
        if (refreshPending)
            Qt.callLater(fetchAll);
    }
    function getEventsForDate(day, month, year) {
        var targetLocalStart = new Date(year, month, day);
        var targetLocalEnd = new Date(year, month, day + 1);
        var targetUtcStart = new Date(Date.UTC(year, month, day));
        var targetUtcEnd = new Date(Date.UTC(year, month, day + 1));
        var result = [];
        for (var index = 0; index < allEvents.length; ++index) {
            var event = allEvents[index];
            var calendar = calendarById(event.calendarId);
            if (!calendar || calendar.visible === false)
                continue;
            var start = new Date(event.start);
            var end = new Date(event.end);
            if (isNaN(start.getTime()))
                continue;
            if (isNaN(end.getTime()) || end <= start)
                end = new Date(start.getTime() + 3600000);
            var rangeStart = event.allDay === true ? targetUtcStart : targetLocalStart;
            var rangeEnd = event.allDay === true ? targetUtcEnd : targetLocalEnd;
            if (start < rangeEnd && end > rangeStart)
                result.push(event);
        }
        return result;
    }
    function handleDaemonEvent(event) {
        if (!event)
            return;
        if (event.topic === "sync") {
            var accountId = String(event.accountId || "");
            var nextSyncing = Object.assign({}, syncingAccounts);
            if (event.kind === "started" && accountId !== "")
                nextSyncing[accountId] = true;
            else if ((event.kind === "completed" || event.kind === "failed") && accountId !== "")
                delete nextSyncing[accountId];
            syncingAccounts = nextSyncing;
            syncBusy = Object.keys(nextSyncing).length > 0;
        }
        refreshDebounce.restart();
    }
    function handleRequestConnection() {
        if (!requestSocket.connected) {
            failPendingRequests(qsTr("Calendar backend disconnected."));
            initialLoaded = false;
            daemonStatus = "connecting";
            ensureRunning();
            return;
        }
        connectionRetry.stop();
        daemonStartDelay.stop();
        daemonRestart.stop();
        daemonStatus = "connected";
        lastError = "";
        if (!subscriptionSocket.connected)
            subscriptionSocket.connected = true;
        fetchAll();
    }
    function handleResponse(line) {
        var text = String(line || "").trim();
        if (text === "")
            return;
        var response;
        try {
            response = JSON.parse(text);
        } catch (error) {
            lastError = qsTr("Calendar backend returned invalid data.");
            return;
        }
        var id = String(response.id === undefined || response.id === null ? "" : response.id);
        var entry = pendingRequests[id];
        if (!entry)
            return;
        var nextPending = Object.assign({}, pendingRequests);
        delete nextPending[id];
        pendingRequests = nextPending;
        if (response.ok === true) {
            if (entry.success)
                entry.success(response.result);
            return;
        }
        var message = response.error && response.error.message ? String(response.error.message) : qsTr("Calendar request failed.");
        lastError = message;
        if (entry.failure)
            entry.failure(message);
    }
    function handleSubscriptionLine(line) {
        var text = String(line || "").trim();
        if (text === "")
            return;
        try {
            var response = JSON.parse(text);
            if (response.ok === true && String(response.id || "") === "subscription") {
                subscribed = true;
                return;
            }
            if (response.event)
                handleDaemonEvent(response.event);
        } catch (error) {
            console.log("[CalendarService] Invalid subscription message:", text);
        }
    }
    function hasEvents(day, month, year) {
        return getEventsForDate(day, month, year).length > 0;
    }
    function importIcs(calendarId, filePath, callback) {
        if (eventActionBusy)
            return;
        eventActionBusy = true;
        sendRequest("events.importIcs", {
            "calendarId": String(calendarId || "").trim(),
            "filePath": String(filePath || "").trim()
        }, result => {
            finishEventAction("import-ics", true, "", callback);
        }, message => {
            finishEventAction("import-ics", false, message, callback);
        });
    }
    function localDateParts(value) {
        if (value instanceof Date && !isNaN(value.getTime())) {
            return [value.getFullYear(), value.getMonth(), value.getDate()];
        }
        var parts = String(value || "").split("-");
        if (parts.length !== 3)
            return null;
        return [Number(parts[0]), Number(parts[1]) - 1, Number(parts[2])];
    }
    function parseIcs(filePath, callback) {
        sendRequest("events.parseIcs", {
            "filePath": String(filePath || "").trim()
        }, result => {
            if (callback)
                callback(true, result, "");
        }, message => {
            if (callback)
                callback(false, null, message);
        });
    }
    function rebuildDecoratedData() {
        var accountMap = {};
        for (var accountIndex = 0; accountIndex < accounts.length; ++accountIndex) {
            var account = accounts[accountIndex];
            accountMap[String(account.id || "")] = account;
        }

        var calendarMap = {};
        var decoratedCalendars = [];
        for (var calendarIndex = 0; calendarIndex < calendars.length; ++calendarIndex) {
            var sourceCalendar = calendars[calendarIndex];
            if (sourceCalendar.isTaskList)
                continue;
            var sourceAccount = accountMap[String(sourceCalendar.accountId || "")] || null;
            var decoratedCalendar = Object.assign({}, sourceCalendar, {
                "accountName": sourceAccount ? String(sourceAccount.displayName || sourceAccount.email || "") : "",
                "accountEmail": sourceAccount ? String(sourceAccount.email || "") : "",
                "provider": sourceAccount ? String(sourceAccount.provider || "") : ""
            });
            decoratedCalendars.push(decoratedCalendar);
            calendarMap[String(decoratedCalendar.id || "")] = decoratedCalendar;
        }
        var decoratedTasks = [];
        for (var taskIndex = 0; taskIndex < taskSnapshots.length; ++taskIndex) {
            var snapshot = taskSnapshots[taskIndex];
            var taskAccount = accountMap[String(snapshot.accountId || "")];
            if (!taskAccount || taskAccount.enabled === false)
                continue;
            var taskCalendarId = "google-tasks:" + snapshot.accountId;
            decoratedCalendars.push({
                "id": taskCalendarId,
                "accountId": snapshot.accountId,
                "name": qsTr("Tasks"),
                "accountName": taskAccount.displayName || taskAccount.email,
                "accountEmail": taskAccount.email,
                "provider": "google",
                "isTaskList": true,
                "readOnly": true,
                "visible": snapshot.visible !== false,
                "color": taskAccountColor(snapshot.accountId),
                "syncError": snapshot.error || ""
            });
            var tasks = snapshot.tasks || [];
            for (var index = 0; index < tasks.length; ++index) {
                var task = tasks[index];
                if (!task.due || (task.status !== "needsAction" && task.status !== "completed") || task.deleted || task.hidden)
                    continue;
                var day = String(task.due).slice(0, 10);
                var parts = day.split("-");
                var nextDay = new Date(Date.UTC(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]) + 1));
                if (isNaN(nextDay.getTime()))
                    continue;
                decoratedTasks.push({
                    "id": "task:" + snapshot.accountId + ":" + task.taskListId + ":" + task.id,
                    "taskId": task.id,
                    "taskListId": task.taskListId,
                    "taskListName": task.taskListName,
                    "calendarId": taskCalendarId,
                    "accountId": snapshot.accountId,
                    "accountName": taskAccount.displayName || taskAccount.email,
                    "title": task.title || qsTr("Untitled task"),
                    "description": task.notes || "",
                    "start": day + "T00:00:00Z",
                    "end": nextDay.toISOString(),
                    "allDay": true,
                    "isTask": true,
                    "status": task.status,
                    "readOnly": false,
                    "calendarColor": taskListColor(snapshot.accountId, task.taskListId),
                    "calendarName": qsTr("Tasks"),
                    "provider": "google"
                });
            }
        }
        calendars = decoratedCalendars;
        taskEvents = decoratedTasks;

        var decoratedEvents = [];
        for (var eventIndex = 0; eventIndex < rawEvents.length; ++eventIndex) {
            var sourceEvent = rawEvents[eventIndex];
            var eventCalendar = calendarMap[String(sourceEvent.calendarId || "")] || null;
            decoratedEvents.push(Object.assign({}, sourceEvent, {
                "accountId": eventCalendar ? String(eventCalendar.accountId || "") : "",
                "accountName": eventCalendar ? String(eventCalendar.accountName || "") : "",
                "calendarColor": eventCalendar ? String(eventCalendar.color || "") : "",
                "calendarName": eventCalendar ? String(eventCalendar.name || "") : "",
                "provider": eventCalendar ? String(eventCalendar.provider || "") : "",
                "readOnly": eventCalendar ? eventCalendar.readOnly === true : false
            }));
        }
        allEvents = decoratedEvents;
    }
    function release() {
        activeConsumers = Math.max(0, activeConsumers - 1);
    }
    function removeAccount(accountId, callback) {
        if (accountActionBusy)
            return;
        accountActionBusy = true;
        var wanted = String(accountId || "");
        sendRequest("accounts.remove", {
            "accountId": wanted
        }, result => {
            accountActionBusy = false;
            fetchAll();
            accountRemoved(wanted);
            if (callback)
                callback(true, "");
        }, message => {
            accountActionBusy = false;
            if (callback)
                callback(false, message);
        });
    }
    function requestReconnect() {
        subscribed = false;
        if (subscriptionSocket.connected)
            subscriptionSocket.connected = false;
        if (requestSocket.connected)
            requestSocket.connected = false;
        connectionRetry.restart();
    }
    function sendRequest(method, params, success, failure) {
        if (!requestSocket.connected) {
            var unavailable = qsTr("Calendar backend is not connected yet.");
            lastError = unavailable;
            ensureRunning();
            if (failure)
                failure(unavailable);
            return "";
        }
        var id = String(nextRequestId++);
        var nextPending = Object.assign({}, pendingRequests);
        nextPending[id] = {
            "method": method,
            "success": success,
            "failure": failure
        };
        pendingRequests = nextPending;
        requestSocket.write(JSON.stringify({
            "id": id,
            "method": method,
            "params": params || {}
        }) + "\n");
        requestSocket.flush();
        return id;
    }
    function setAccountVisible(accountId, visible) {
        var accountCalendars = calendarsForAccount(accountId);
        for (var index = 0; index < accountCalendars.length; ++index)
            setCalendarVisible(String(accountCalendars[index].id || ""), visible);
    }
    function setCalendarVisible(calendarId, visible) {
        var wanted = String(calendarId || "");
        if (wanted.indexOf("google-tasks:") === 0) {
            var accountId = wanted.slice("google-tasks:".length);
            taskSnapshots = taskSnapshots.map(snapshot => snapshot.accountId === accountId ? Object.assign({}, snapshot, {
                    "visible": visible === true
                }) : snapshot);
            rebuildDecoratedData();
            sendRequest("tasks.setVisible", {
                "accountId": accountId,
                "visible": visible === true
            }, null, message => refreshDebounce.restart());
            return;
        }
        var nextCalendars = [];
        for (var index = 0; index < calendars.length; ++index) {
            var calendar = calendars[index];
            nextCalendars.push(String(calendar.id || "") === wanted ? Object.assign({}, calendar, {
                "visible": visible === true
            }) : calendar);
        }
        calendars = nextCalendars;
        rebuildDecoratedData();
        sendRequest("calendars.setVisible", {
            "calendarId": wanted,
            "visible": visible === true
        }, null, message => refreshDebounce.restart());
    }
    function startFallbackDaemon() {
        daemonStartDelay.stop();
        if (socketOverride === "" || requestSocket.connected || daemonProcess.running)
            return;
        daemonStatus = "starting";
        daemonProcess.running = true;
    }
    function syncNow(accountId) {
        if (syncBusy)
            return;
        syncBusy = true;
        var params = {};
        if (String(accountId || "") !== "")
            params.accountId = String(accountId);
        sendRequest("sync.now", params, result => {
            syncBusy = false;
            fetchAll();
        }, message => syncBusy = false);
    }
    function taskAccountColor(accountId) {
        var basePalette = ["#4285F4", "#34A853", "#FB8C00", "#A142F4", "#00ACC1", "#E91E63", "#3F51B5", "#00897B", "#D81B60", "#8E24AA", "#1E88E5", "#43A047", "#F4511E", "#00B0FF", "#7CB342", "#00E676"];
        var googleAccounts = accounts.filter(account => account.provider === "google");
        var index = googleAccounts.findIndex(account => account.id === accountId);
        if (index >= 0) {
            var slot = index * 5;
            if (slot < basePalette.length)
                return basePalette[slot];
            var hue = (0.58 + slot * 0.618033988749895) % 1.0;
            return String(Qt.hsla(hue, 0.78, 0.60, 1.0));
        }
        var hash = 0;
        var str = String(accountId || "");
        for (var i = 0; i < str.length; i++)
            hash = (hash * 31 + str.charCodeAt(i)) & 0x7fffffff;
        var hashSlot = hash % 360;
        return String(Qt.hsla(hashSlot / 360.0, 0.78, 0.60, 1.0));
    }
    function taskListColor(accountId, listId) {
        var basePalette = ["#4285F4", "#34A853", "#FB8C00", "#A142F4", "#00ACC1", "#E91E63", "#3F51B5", "#00897B", "#D81B60", "#8E24AA", "#1E88E5", "#43A047", "#F4511E", "#00B0FF", "#7CB342", "#00E676"];
        var snapshot = taskSnapshots.find(item => item.accountId === accountId);
        if (snapshot && Array.isArray(snapshot.lists) && listId) {
            var listIndex = snapshot.lists.findIndex(list => list.id === listId);
            if (listIndex >= 0) {
                var googleAccounts = accounts.filter(account => account.provider === "google");
                var accIndex = Math.max(0, googleAccounts.findIndex(account => account.id === accountId));
                var slot = accIndex * 5 + listIndex;
                if (slot < basePalette.length)
                    return basePalette[slot];
                var hue = (0.58 + slot * 0.618033988749895) % 1.0;
                return String(Qt.hsla(hue, 0.78, 0.60, 1.0));
            }
        }
        var hash = 0;
        var str = String(accountId || "") + ":" + String(listId || "");
        for (var i = 0; i < str.length; i++)
            hash = (hash * 31 + str.charCodeAt(i)) & 0x7fffffff;
        var hashSlot = hash % 360;
        return String(Qt.hsla(hashSlot / 360.0, 0.78, 0.60, 1.0));
    }
    function updateEvent(calendarId, eventId, title, date, startTime, endTime, allDay, location, description, callback) {
        if (eventActionBusy)
            return;
        var draft = buildEventDraft(title, date, startTime, endTime, allDay, location, description);
        if (!draft) {
            if (callback)
                callback(false, lastError);
            return;
        }
        eventActionBusy = true;
        sendRequest("events.update", {
            "eventId": String(eventId || ""),
            "event": draft
        }, result => finishEventAction("update", true, "", callback), message => finishEventAction("update", false, message, callback));
    }

    Component.onCompleted: {
        ensureRunning();
        requestSocket.connected = true;
    }
    Component.onDestruction: {
        requestSocket.connected = false;
        subscriptionSocket.connected = false;
        systemdStarter.running = false;
        daemonProcess.running = false;
    }
}
