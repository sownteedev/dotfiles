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
    property Timer idleReleaseTimer: Timer {
        interval: 30000
        repeat: false

        onTriggered: root.releaseIdleData()
    }
    property bool idleReleased: false
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
        idleReleaseTimer.stop();
        idleReleased = false;
        activeConsumers += 1;
        ensureRunning();
        if (requestSocket.connected) {
            if (!subscriptionSocket.connected)
                subscriptionSocket.connected = true;
            if (!initialLoaded)
                fetchAll();
        }
    }
    function addDays(value, count) {
        return new Date(value.getFullYear(), value.getMonth(), value.getDate() + count);
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
    function buildEventDraft(title, startDate, endDate, startTime, endTime, allDay, location, description, recurrence, reminderMinutes, availability, visibility, useDefaultReminder) {
        var startParts = localDateParts(startDate);
        var endParts = localDateParts(endDate || startDate);
        if (!startParts || !endParts) {
            lastError = qsTr("The event date is invalid.");
            return null;
        }
        var start;
        var end;
        if (allDay === true) {
            start = new Date(Date.UTC(startParts[0], startParts[1], startParts[2]));
            end = new Date(Date.UTC(endParts[0], endParts[1], endParts[2] + 1));
        } else {
            var startClock = String(startTime || "00:00").split(":");
            var endClock = String(endTime || "01:00").split(":");
            start = new Date(startParts[0], startParts[1], startParts[2], Number(startClock[0] || 0), Number(startClock[1] || 0));
            end = new Date(endParts[0], endParts[1], endParts[2], Number(endClock[0] || 0), Number(endClock[1] || 0));
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
            "allDay": allDay === true,
            "recurrence": Array.isArray(recurrence) ? recurrence : [],
            "reminderMinutes": reminderMinutes !== null && reminderMinutes !== undefined && Number(reminderMinutes) >= 0 ? Math.floor(Number(reminderMinutes)) : null,
            "useDefaultReminder": useDefaultReminder === true,
            "availability": availability === "free" ? "free" : "busy",
            "visibility": ["default", "public", "private"].indexOf(visibility) >= 0 ? visibility : "default"
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
    function createEvent(calendarId, title, startDate, endDate, startTime, endTime, allDay, location, description, recurrence, reminderMinutes, callback, availability, visibility, useDefaultReminder) {
        if (eventActionBusy)
            return;
        var draft = buildEventDraft(title, startDate, endDate, startTime, endTime, allDay, location, description, recurrence, reminderMinutes, availability, visibility, useDefaultReminder);
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
    function eventOccursOnDay(eventData, targetDay) {
        if (!eventData || !targetDay)
            return false;
        var eventStart = eventData.allDay ? parseDateOnly(eventData.start) : new Date(eventData.start);
        var eventEnd = eventData.allDay ? parseDateOnly(eventData.end) : new Date(eventData.end);
        if (isNaN(eventStart.getTime()))
            return false;
        if (isNaN(eventEnd.getTime()) || eventEnd <= eventStart)
            eventEnd = eventData.allDay ? addDays(eventStart, 1) : new Date(eventStart.getTime() + 3600000);

        var firstDay = startOfDay(eventStart);
        var curDay = startOfDay(targetDay);
        if (curDay < firstDay)
            return false;

        var type = eventRecurrenceType(eventData);
        if (type === "none") {
            var lastDayExclusive = eventData.allDay ? startOfDay(eventEnd) : addDays(startOfDay(new Date(eventEnd.getTime() - 1)), 1);
            if (lastDayExclusive <= firstDay)
                lastDayExclusive = addDays(firstDay, 1);
            return curDay >= firstDay && curDay < lastDayExclusive;
        }

        var ruleStr = recurrenceRuleText(eventData.recurrence);
        var untilMatch = ruleStr.match(/UNTIL=([0-9]{8})/);
        if (untilMatch) {
            var rawUntil = untilMatch[1];
            var untilYear = Number(rawUntil.slice(0, 4));
            var untilMonth = Number(rawUntil.slice(4, 6)) - 1;
            var untilDate = Number(rawUntil.slice(6, 8));
            var untilDay = new Date(untilYear, untilMonth, untilDate);
            if (curDay > untilDay)
                return false;
        }

        var intervalMatch = ruleStr.match(/INTERVAL=([0-9]+)/);
        var interval = intervalMatch ? Math.max(1, parseInt(intervalMatch[1], 10)) : 1;
        var countMatch = ruleStr.match(/COUNT=([0-9]+)/);
        var byDayMatch = ruleStr.match(/BYDAY=([^;]+)/);
        var byDays = byDayMatch ? byDayMatch[1].split(",") : [];
        if (countMatch) {
            var occurrenceIndex = 0;
            var scan = new Date(firstDay);
            while (scan <= curDay) {
                var scanDiffDays = Math.round((scan.getTime() - firstDay.getTime()) / 86400000);
                var scanMatches = false;
                if (type === "daily")
                    scanMatches = scanDiffDays % interval === 0;
                else if (type === "weekly") {
                    var scanWeekDiff = Math.floor(scanDiffDays / 7);
                    var scanDayCode = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"][scan.getDay()];
                    scanMatches = scanWeekDiff % interval === 0 && (byDays.length === 0 ? scan.getDay() === firstDay.getDay() : byDays.indexOf(scanDayCode) >= 0);
                } else if (type === "monthly") {
                    var scanMonthDiff = (scan.getFullYear() - firstDay.getFullYear()) * 12 + scan.getMonth() - firstDay.getMonth();
                    var scanLastDay = new Date(scan.getFullYear(), scan.getMonth() + 1, 0).getDate();
                    scanMatches = scanMonthDiff >= 0 && scanMonthDiff % interval === 0 && scan.getDate() === Math.min(firstDay.getDate(), scanLastDay);
                } else if (type === "yearly") {
                    scanMatches = (scan.getFullYear() - firstDay.getFullYear()) % interval === 0 && scan.getMonth() === firstDay.getMonth() && scan.getDate() === firstDay.getDate();
                }
                if (scanMatches)
                    occurrenceIndex++;
                scan = addDays(scan, 1);
            }
            if (occurrenceIndex > Number(countMatch[1]))
                return false;
        }

        if (type === "daily") {
            if (interval > 1) {
                var diffDays = Math.round((curDay.getTime() - firstDay.getTime()) / 86400000);
                return diffDays % interval === 0;
            }
            return true;
        }
        if (type === "weekly") {
            var dayCode = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"][curDay.getDay()];
            if (byDays.length > 0 ? byDays.indexOf(dayCode) < 0 : curDay.getDay() !== firstDay.getDay())
                return false;
            if (interval > 1) {
                var diffWeeks = Math.round((curDay.getTime() - firstDay.getTime()) / (7 * 86400000));
                return diffWeeks % interval === 0;
            }
            return true;
        }
        if (type === "monthly") {
            var targetMonthLastDay = new Date(curDay.getFullYear(), curDay.getMonth() + 1, 0).getDate();
            var expectedDay = Math.min(firstDay.getDate(), targetMonthLastDay);
            if (curDay.getDate() !== expectedDay)
                return false;
            if (interval > 1) {
                var diffMonths = (curDay.getFullYear() - firstDay.getFullYear()) * 12 + (curDay.getMonth() - firstDay.getMonth());
                return diffMonths % interval === 0;
            }
            return true;
        }
        if (type === "yearly") {
            if (curDay.getMonth() !== firstDay.getMonth() || curDay.getDate() !== firstDay.getDate())
                return false;
            if (interval > 1) {
                var diffYears = curDay.getFullYear() - firstDay.getFullYear();
                return diffYears % interval === 0;
            }
            return true;
        }
        return false;
    }
    function eventRecurrenceType(eventData) {
        if (!eventData)
            return "none";
        var recurrence = eventData.recurrence;
        var first = recurrenceRuleText(recurrence);
        if (recurrence && typeof recurrence === "object" && recurrence.pattern) {
            var patternType = String(recurrence.pattern.type || "");
            if (patternType === "daily")
                return "daily";
            if (patternType === "weekly")
                return "weekly";
            if (patternType === "absoluteMonthly" || patternType === "relativeMonthly")
                return "monthly";
            if (patternType === "absoluteYearly" || patternType === "relativeYearly")
                return "yearly";
        }

        first = first.trim();
        if (first.charAt(0) === "{") {
            try {
                var parsed = JSON.parse(first);
                var graphType = parsed.pattern ? parsed.pattern.type : "";
                if (graphType === "daily")
                    return "daily";
                if (graphType === "weekly")
                    return "weekly";
                if (graphType === "absoluteMonthly" || graphType === "relativeMonthly")
                    return "monthly";
                if (graphType === "absoluteYearly" || graphType === "relativeYearly")
                    return "yearly";
            } catch (error) {
                return "none";
            }
        }
        var normalized = first.toUpperCase().replace(/^RRULE:/, "");
        if (normalized.indexOf("FREQ=DAILY") >= 0)
            return "daily";
        if (normalized.indexOf("FREQ=WEEKLY") >= 0)
            return "weekly";
        if (normalized.indexOf("FREQ=MONTHLY") >= 0)
            return "monthly";
        if (normalized.indexOf("FREQ=YEARLY") >= 0)
            return "yearly";
        return "none";
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
        var targetDay = new Date(year, month, day);
        var result = [];
        for (var index = 0; index < allEvents.length; ++index) {
            var event = allEvents[index];
            var calendar = calendarById(event.calendarId);
            if (!calendar || calendar.visible === false)
                continue;
            if (eventOccursOnDay(event, targetDay))
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
            if (idleReleased && activeConsumers === 0) {
                daemonStatus = "idle";
                return;
            }
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
    function parseDateOnly(value) {
        var raw = String(value || "");
        var parts = raw.slice(0, 10).split("-");
        if (parts.length === 3)
            return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
        var parsed = new Date(raw);
        return isNaN(parsed.getTime()) ? new Date() : new Date(parsed.getFullYear(), parsed.getMonth(), parsed.getDate());
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
    function recurrenceRuleText(value) {
        if (value === null || value === undefined)
            return "";
        if (typeof value === "string")
            return value;
        if (typeof value !== "object" || value.pattern)
            return "";

        // Repeater delegates expose a QML list as an object rather than a JS
        // Array.  Keep reading its length/index so recurring events remain
        // recurring after the event passes through a calendar delegate.
        var length = Number(value.length);
        if (isFinite(length) && length > 0 && value[0] !== undefined)
            return String(value[0]);
        return value[0] === undefined ? "" : String(value[0]);
    }
    function release() {
        activeConsumers = Math.max(0, activeConsumers - 1);
        if (activeConsumers === 0)
            idleReleaseTimer.restart();
    }
    function releaseIdleData() {
        if (activeConsumers > 0)
            return;
        if (fetchInFlight > 0 || accountActionBusy || eventActionBusy || Object.keys(pendingRequests).length > 0) {
            idleReleaseTimer.restart();
            return;
        }

        refreshDebounce.stop();
        connectionRetry.stop();
        daemonRestart.stop();
        daemonStartDelay.stop();
        subscriptionRetry.stop();
        idleReleased = true;
        if (subscriptionSocket.connected)
            subscriptionSocket.connected = false;
        if (requestSocket.connected)
            requestSocket.connected = false;
        subscribed = false;
        refreshPending = false;
        initialLoaded = false;
        syncBusy = false;
        syncingAccounts = ({});
        accounts = [];
        calendars = [];
        rawEvents = [];
        allEvents = [];
        taskSnapshots = [];
        taskEvents = [];
        lastError = "";
        daemonStatus = "idle";
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
        if (idleReleased && activeConsumers === 0)
            return;
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
    function startOfDay(value) {
        return new Date(value.getFullYear(), value.getMonth(), value.getDate());
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
    function updateEvent(calendarId, eventId, title, startDate, endDate, startTime, endTime, allDay, location, description, recurrence, reminderMinutes, callback, availability, visibility, useDefaultReminder) {
        if (eventActionBusy)
            return;
        var draft = buildEventDraft(title, startDate, endDate, startTime, endTime, allDay, location, description, recurrence, reminderMinutes, availability, visibility, useDefaultReminder);
        if (!draft) {
            if (callback)
                callback(false, lastError);
            return;
        }
        eventActionBusy = true;
        sendRequest("events.update", {
            "eventId": String(eventId || ""),
            "event": draft
        }, result => {
            if (result && result.id) {
                rawEvents = rawEvents.map(event => event.id === result.id ? result : event);
                rebuildDecoratedData();
            }
            finishEventAction("update", true, "", callback);
        }, message => finishEventAction("update", false, message, callback));
    }

    Component.onDestruction: {
        idleReleaseTimer.stop();
        requestSocket.connected = false;
        subscriptionSocket.connected = false;
        systemdStarter.running = false;
        daemonProcess.running = false;
    }
}
