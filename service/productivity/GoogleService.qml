pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property Process actionProcess: Process {
        id: actionProcess

        property string errorBuffer: ""
        property string outputBuffer: ""

        command: []
        running: false

        stderr: SplitParser {
            onRead: line => {
                actionProcess.errorBuffer += line + "\n";
                console.log("Google API Action Error:", line);
            }
        }
        stdout: SplitParser {
            onRead: line => {
                actionProcess.outputBuffer += line;
            }
        }

        onExited: {
            console.log("Action completed. Output:", outputBuffer);
            var succeeded = false;
            try {
                if (outputBuffer.trim() !== "") {
                    var parsed = JSON.parse(outputBuffer);
                    if (parsed.success) {
                        succeeded = true;
                    } else if (parsed.error) {
                        root.handleRequestError(parsed.error);
                    }
                } else if (errorBuffer.trim() !== "") {
                    root.handleRequestError(errorBuffer.trim());
                }
            } catch (e) {
                root.handleRequestError("Invalid response from Google Calendar");
            }
            outputBuffer = "";
            errorBuffer = "";
            if (succeeded)
                root.fetchEvents();
            root.startNextEventAction();
        }
    }
    property Process actionTasksProcess: Process {
        id: actionTasksProcess

        property var actionContext: ({})
        property string errorBuffer: ""
        property string outputBuffer: ""

        command: []
        running: false

        stderr: SplitParser {
            onRead: line => {
                actionTasksProcess.errorBuffer += line + "\n";
                console.log("Google API Task Action Error:", line);
            }
        }
        stdout: SplitParser {
            onRead: line => {
                actionTasksProcess.outputBuffer += line;
            }
        }

        onExited: {
            var succeeded = false;
            var remoteId = "";
            var failureMessage = "";
            try {
                if (outputBuffer.trim() !== "") {
                    var parsed = JSON.parse(outputBuffer);
                    if (parsed.success) {
                        succeeded = true;
                        remoteId = String(parsed.id || "");
                    } else if (parsed.error) {
                        failureMessage = String(parsed.error);
                        root.handleRequestError(failureMessage);
                    }
                } else if (errorBuffer.trim() !== "") {
                    failureMessage = errorBuffer.trim();
                    try {
                        var parsedError = JSON.parse(failureMessage);
                        failureMessage = String(parsedError.error || failureMessage);
                    } catch (parseError) {}
                    root.handleRequestError(failureMessage);
                }
            } catch (e) {
                failureMessage = "Invalid response from Google Tasks";
                root.handleRequestError(failureMessage);
            }
            if (!succeeded && failureMessage === "")
                failureMessage = "Google Tasks request failed";
            var completedContext = actionContext || {};
            actionContext = ({});
            outputBuffer = "";
            errorBuffer = "";
            if (succeeded)
                root.fetchTasks();
            root.taskActionFinished(String(completedContext.operation || ""), String(completedContext.sourceId || ""), succeeded, remoteId, failureMessage);
            root.startNextTaskAction();
        }
    }

    // An array of all events for the current loaded time window
    property var allEvents: []
    property var allTasks: []
    readonly property bool active: activeConsumers > 0
    property int activeConsumers: 0
    property Process authCheckProcess: Process {
        id: authCheckProcess

        command: ["python3", "-u", root.getScriptPath(), "--auth-status"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var result = JSON.parse(text.trim());
                    root.authenticated = result.authenticated === true;
                } catch (error) {
                    root.authenticated = false;
                }
                root.authChecked = true;
                if (root.authenticated)
                    root.fetchAll();
            }
        }

        onExited: {
            if (root.authCheckPending) {
                root.authCheckPending = false;
                root.checkAuthentication();
            }
        }
    }
    property bool authChecked: false
    property bool authCheckPending: false
    // Non-sensitive draft kept outside the panel so closing/recreating its
    // Loader does not discard a Client ID the user has already pasted.
    property string authClientIdDraft: ""
    property string authError: ""
    property bool authPanelVisible: false
    property Process authProcess: Process {
        property string credentialsJson: ""

        command: ["python3", "-u", root.getScriptPath(), "--auth-local"]
        stdinEnabled: true

        stderr: SplitParser {
            onRead: line => root.authError = line
        }
        stdout: SplitParser {
            onRead: line => {
                try {
                    var message = JSON.parse(line);
                    if (message.event === "authorization_url") {
                        root.authUrl = message.url || "";
                        root.authStatus = "Complete authentication in your browser";
                        if (root.authUrl !== "")
                            Quickshell.execDetached(["xdg-open", root.authUrl]);
                    } else if (message.event === "success") {
                        var context = root.pendingAuthContext;
                        root.authenticated = true;
                        root.authChecked = true;
                        root.authenticating = false;
                        root.authPanelVisible = false;
                        root.authStatus = "Connected";
                        root.authError = "";
                        root.authUrl = "";
                        root.pendingAuthContext = "";
                        root.fetchAll();
                        root.authenticationSucceeded(context);
                    } else if (message.event === "error") {
                        root.authError = message.message || "Authentication failed";
                        root.authStatus = "";
                    }
                } catch (error) {
                    root.authError = "Invalid authentication response";
                }
            }
        }

        onExited: {
            if (!root.authenticated && root.authenticating && root.authError === "")
                root.authError = "Authentication stopped before completion";
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
    property bool disconnecting: false
    property Process disconnectProcess: Process {
        id: disconnectProcess

        command: ["python3", "-u", root.getScriptPath(), "--logout"]

        stderr: StdioCollector {
            id: disconnectError
        }
        stdout: StdioCollector {
            id: disconnectOutput
        }

        onExited: {
            var succeeded = false;
            var failureMessage = disconnectError.text.trim();
            try {
                var result = JSON.parse(disconnectOutput.text.trim());
                succeeded = result.success === true;
                if (!succeeded && result.error)
                    failureMessage = String(result.error);
            } catch (error) {
                if (failureMessage === "")
                    failureMessage = "Invalid response while removing Google account";
            }

            root.disconnecting = false;
            if (succeeded) {
                root.finishDisconnect();
            } else {
                root.authStatus = "Could not remove Google account: " + (failureMessage || "Unknown error");
                root.checkAuthentication();
            }
        }
    }
    property var calendars: []
    property bool calendarsRefreshPending: false
    property Process calendarsProcess: Process {
        id: calendarsProcess

        property string outputBuffer: ""

        command: ["python3", "-u", root.getScriptPath(), "--get-calendars"]
        running: false

        stderr: SplitParser {
            onRead: line => {
                console.log("Google API Calendars Error:", line);
            }
        }
        stdout: SplitParser {
            onRead: line => {
                calendarsProcess.outputBuffer += line;
            }
        }

        onExited: {
            try {
                if (outputBuffer.trim() !== "") {
                    var parsed = JSON.parse(outputBuffer);
                    if (!parsed.error) {
                        root.calendars = parsed;
                        console.log("Loaded", root.calendars.length, "calendars");
                        root.calendarsChanged();
                    } else {
                        root.handleRequestError(parsed.error);
                    }
                }
            } catch (e) {
                console.log("Failed to parse calendars output:", e);
            }
            outputBuffer = "";
            if (root.calendarsRefreshPending) {
                root.calendarsRefreshPending = false;
                root.fetchCalendars();
            }
        }
    }
    property string errorMessage: ""
    property var eventActionQueue: []
    readonly property bool eventActionBusy: actionProcess.running || eventActionQueue.length > 0
    property bool eventsRefreshPending: false
    property Process fetchProcess: Process {
        id: fetchProcess

        property string outputBuffer: ""

        command: ["python3", "-u", root.getScriptPath(), root.loadedMonth.toString(), root.loadedYear.toString()]
        running: false

        stderr: SplitParser {
            onRead: line => {
                console.log("Google API Error:", line);
                root.errorMessage = line;
            }
        }
        stdout: SplitParser {
            onRead: line => {
                fetchProcess.outputBuffer += line;
            }
        }

        onExited: {
            root.isLoading = false;
            try {
                if (outputBuffer.trim() !== "") {
                    var parsed = JSON.parse(outputBuffer);
                    if (parsed.error) {
                        root.errorMessage = parsed.error;
                        console.log("Google API Error:", parsed.error);
                    } else {
                        root.allEvents = parsed;
                        root.errorMessage = "";
                        root.lastEventsUpdated = new Date();
                        console.log("Loaded", root.allEvents.length, "events for month", root.loadedMonth);
                        root.eventsChanged();
                    }
                }
            } catch (e) {
                console.log("Failed to parse Google API output:", e);
                root.errorMessage = "Failed to parse JSON";
            }
            outputBuffer = "";
            if (root.eventsRefreshPending) {
                root.eventsRefreshPending = false;
                root.fetchEvents();
            }
        }
    }
    property Process fetchTasksProcess: Process {
        id: fetchTasksProcess

        property string errorBuffer: ""
        property string outputBuffer: ""

        command: []
        running: false

        stderr: SplitParser {
            onRead: line => {
                fetchTasksProcess.errorBuffer += line + "\n";
                console.log("Google API Tasks Error:", line);
            }
        }
        stdout: SplitParser {
            onRead: line => {
                fetchTasksProcess.outputBuffer += line;
            }
        }

        onExited: {
            root.isLoadingTasks = false;
            try {
                if (outputBuffer.trim() !== "") {
                    var parsed = JSON.parse(outputBuffer);
                    if (!parsed.error) {
                        root.allTasks = parsed;
                        root.lastTasksUpdated = new Date();
                        console.log("Loaded", root.allTasks.length, "tasks");
                        root.tasksChanged();
                    } else {
                        root.handleRequestError(parsed.error);
                    }
                } else if (errorBuffer.trim() !== "") {
                    root.handleRequestError(errorBuffer.trim());
                }
            } catch (e) {
                console.log("Failed to parse tasks output:", e);
            }
            outputBuffer = "";
            errorBuffer = "";
            if (root.tasksRefreshPending) {
                root.tasksRefreshPending = false;
                root.fetchTasks(root.lastTaskListId);
            }
        }
    }
    property bool isLoading: false
    property bool isLoadingTasks: false
    property date lastEventsUpdated
    property date lastTasksUpdated
    property string lastTaskListId: "@default"
    // Internal state
    property int loadedMonth: new Date().getMonth() + 1
    property int loadedYear: new Date().getFullYear()
    property string pendingAuthContext: ""
    property var taskActionQueue: []
    readonly property bool taskActionBusy: actionTasksProcess.running || taskActionQueue.length > 0
    property bool tasksRefreshPending: false
    property Timer refreshTimer: Timer {
        interval: 900000
        repeat: true
        running: root.active && root.authenticated

        onTriggered: root.fetchAll()
    }

    signal authenticationSucceeded(string context)
    signal eventsChanged
    signal taskActionFinished(string operation, string sourceId, bool succeeded, string remoteId, string message)
    signal tasksChanged

    function acquire() {
        activeConsumers++;
        if (!authChecked) {
            checkAuthentication();
        } else if (authenticated && needsRefresh()) {
            fetchAll();
        }
    }

    function cancelAuthentication() {
        authProcess.running = false;
        authenticating = false;
        authPanelVisible = false;
        authStatus = "";
        authError = "";
        authUrl = "";
        pendingAuthContext = "";
    }
    function checkAuthentication() {
        if (authCheckProcess.running) {
            authCheckPending = true;
            return;
        }
        authCheckProcess.running = true;
    }
    function enqueueEventAction(command) {
        var queue = eventActionQueue.slice();
        queue.push(command);
        eventActionQueue = queue;
        startNextEventAction();
    }
    function enqueueTaskAction(command, context) {
        var queue = taskActionQueue.slice();
        queue.push({
            "command": command,
            "context": context || ({})
        });
        taskActionQueue = queue;
        startNextTaskAction();
    }
    function handleRequestError(message) {
        var text = String(message || "Google request failed").trim();
        errorMessage = text;
        var normalized = text.toLowerCase();
        if (normalized.indexOf("invalid_grant") >= 0 || normalized.indexOf("unauthorized") >= 0 || normalized.indexOf("no access token") >= 0 || normalized.indexOf("no token file") >= 0 || normalized.indexOf("401") >= 0) {
            authenticated = false;
            authChecked = true;
            authStatus = "Google session expired. Connect again to continue.";
        }
    }
    function startNextEventAction() {
        if (actionProcess.running || eventActionQueue.length === 0)
            return;
        var queue = eventActionQueue.slice();
        actionProcess.command = queue.shift();
        eventActionQueue = queue;
        actionProcess.outputBuffer = "";
        actionProcess.errorBuffer = "";
        actionProcess.running = true;
    }
    function startNextTaskAction() {
        if (actionTasksProcess.running || taskActionQueue.length === 0)
            return;
        var queue = taskActionQueue.slice();
        var action = queue.shift();
        // Accept queued commands created by an older hot-reloaded service.
        var argv = Array.isArray(action) ? action : action && action.command;
        var context = Array.isArray(action) ? ({}) : action && action.context || ({});
        taskActionQueue = queue;
        if (!argv || argv.length === 0) {
            taskActionFinished(String(context.operation || ""), String(context.sourceId || ""), false, "", "Invalid Google Tasks command");
            Qt.callLater(startNextTaskAction);
            return;
        }
        var normalizedArgv = [];
        for (var i = 0; i < argv.length; ++i)
            normalizedArgv.push(String(argv[i]));
        actionTasksProcess.command = normalizedArgv;
        actionTasksProcess.actionContext = context;
        actionTasksProcess.outputBuffer = "";
        actionTasksProcess.errorBuffer = "";
        actionTasksProcess.running = true;
    }
    function createEvent(calendarId, title, date, startTime, endTime, allDay, location, description) {
        if (!authenticated) {
            requireAuthentication("calendar-add");
            return;
        }
        var jsonData = {
            calendarId: calendarId,
            title: title,
            date: date,
            startTime: startTime,
            endTime: endTime,
            allDay: allDay,
            location: location,
            description: description
        };
        var jsonString = JSON.stringify(jsonData);
        console.log("Creating event:", jsonString);
        enqueueEventAction(["python3", "-u", getScriptPath(), "--create", jsonString]);
    }
    function createTask(listId, title, due, notes, sourceId) {
        if (!authenticated) {
            requireAuthentication("todo-add");
            return false;
        }
        if (!listId)
            listId = "@default";
        var jsonData = {
            title: title,
            due: due,
            notes: notes
        };
        enqueueTaskAction(["python3", "-u", getScriptPath(), "--create-task", listId, JSON.stringify(jsonData)], {
            "operation": sourceId ? "sync-local" : "create",
            "sourceId": String(sourceId || "")
        });
        return true;
    }
    function deleteEvent(calendarId, eventId) {
        if (!authenticated) {
            requireAuthentication("");
            return;
        }
        if (!calendarId)
            calendarId = "primary";
        console.log("Deleting event:", eventId, "from", calendarId);
        enqueueEventAction(["python3", "-u", getScriptPath(), "--delete", calendarId, eventId]);
    }
    function deleteTask(listId, taskId) {
        if (!authenticated) {
            requireAuthentication("");
            return;
        }
        if (!listId)
            listId = "@default";
        enqueueTaskAction(["python3", "-u", getScriptPath(), "--delete-task", listId, taskId], {
            "operation": "delete",
            "sourceId": ""
        });
    }
    function disconnectAccount() {
        if (disconnecting)
            return;

        disconnecting = true;
        authenticated = false;
        authCheckPending = false;
        eventsRefreshPending = false;
        calendarsRefreshPending = false;
        tasksRefreshPending = false;
        eventActionQueue = [];
        taskActionQueue = [];

        cancelAuthentication();
        authCheckProcess.running = false;
        actionProcess.running = false;
        actionTasksProcess.running = false;
        fetchProcess.running = false;
        fetchTasksProcess.running = false;
        calendarsProcess.running = false;

        authStatus = "Removing Google account…";
        disconnectProcess.running = true;
    }
    function fetchAll() {
        if (!authenticated)
            return;
        fetchEvents();
        fetchCalendars();
        fetchTasks();
    }
    function fetchCalendars() {
        if (!authenticated)
            return;
        if (calendarsProcess.running) {
            calendarsRefreshPending = true;
            return;
        }
        calendarsProcess.running = true;
    }
    function fetchEvents(month, year) {
        if (!authenticated)
            return;

        if (isLoading) {
            eventsRefreshPending = true;
            return;
        }

        // Month should be 1-12
        if (month !== undefined)
            root.loadedMonth = month + 1;
        if (year !== undefined)
            root.loadedYear = year;

        console.log("Fetching events for", root.loadedMonth, root.loadedYear);
        isLoading = true;
        fetchProcess.command = ["python3", "-u", getScriptPath(), root.loadedMonth.toString(), root.loadedYear.toString()];
        fetchProcess.running = true;
    }
    function fetchTasks(listId) {
        if (!authenticated)
            return;
        if (!listId)
            listId = "@default";
        lastTaskListId = listId;
        if (isLoadingTasks) {
            tasksRefreshPending = true;
            return;
        }
        isLoadingTasks = true;
        fetchTasksProcess.command = ["python3", "-u", getScriptPath(), "--get-tasks", listId];
        fetchTasksProcess.running = true;
    }
    function finishDisconnect() {
        authenticated = false;
        authChecked = true;
        authPanelVisible = false;
        authError = "";
        authUrl = "";
        pendingAuthContext = "";
        errorMessage = "";
        allEvents = [];
        calendars = [];
        allTasks = [];
        authStatus = "Google account removed from this device.";
        eventsChanged();
        tasksChanged();
    }
    function getEventsForDate(day, month, year) {
        // month is 0-indexed here
        var targetDateStr = year + "-" + String(month + 1).padStart(2, '0') + "-" + String(day).padStart(2, '0');
        var res = [];

        for (var i = 0; i < allEvents.length; i++) {
            var ev = allEvents[i];
            var evStartStr = "";

            // Check if the event falls on this date
            if (ev.allDay) {
                // All-day event: 'start' is 'YYYY-MM-DD'
                evStartStr = ev.start;
                if (evStartStr === targetDateStr) {
                    res.push(ev);
                }
            } else {
                // Timed event: 'start' is ISO string 'YYYY-MM-DDThh:mm:ss...'
                if (ev.start && ev.start.startsWith(targetDateStr)) {
                    res.push(ev);
                }
            }
        }
        return res;
    }
    function needsRefresh() {
        var eventsTime = lastEventsUpdated && !isNaN(lastEventsUpdated.getTime()) ? lastEventsUpdated.getTime() : 0;
        var tasksTime = lastTasksUpdated && !isNaN(lastTasksUpdated.getTime()) ? lastTasksUpdated.getTime() : 0;
        var newest = Math.min(eventsTime, tasksTime);
        return newest === 0 || Date.now() - newest >= refreshTimer.interval;
    }
    function release() {
        activeConsumers = Math.max(0, activeConsumers - 1);
    }

    // Helper to get script path
    function getScriptPath() {
        var path = Qt.resolvedUrl("../../scripts/google_api.py").toString();
        if (path.startsWith("file://")) {
            path = path.substring(7);
        }
        return path;
    }
    function hasEvents(day, month, year) {
        return getEventsForDate(day, month, year).length > 0;
    }
    function requireAuthentication(context) {
        if (authenticated)
            return true;
        pendingAuthContext = context || "";
        authError = "";
        authStatus = authChecked ? "Connect your Google account to continue" : "Checking Google authentication…";
        authPanelVisible = true;
        return false;
    }
    function startAuthentication(clientId, clientSecret) {
        if (authenticating)
            return;
        if (!clientId.trim() || !clientSecret.trim()) {
            authError = "Client ID and Client Secret are required";
            return;
        }
        authError = "";
        authUrl = "";
        authStatus = "Starting local authentication…";
        authenticating = true;
        authProcess.credentialsJson = JSON.stringify({
            client_id: clientId.trim(),
            client_secret: clientSecret.trim()
        });
        authProcess.running = true;
    }
    function updateEvent(calendarId, eventId, title, date, startTime, endTime, allDay, location, description) {
        if (!authenticated) {
            requireAuthentication("");
            return;
        }
        if (!calendarId)
            calendarId = "primary";
        var jsonData = {
            title: title,
            date: date,
            startTime: startTime,
            endTime: endTime,
            allDay: allDay,
            location: location,
            description: description
        };
        var jsonString = JSON.stringify(jsonData);
        console.log("Updating event:", eventId, "in", calendarId);
        enqueueEventAction(["python3", "-u", getScriptPath(), "--update", calendarId, eventId, jsonString]);
    }
    function updateTask(listId, taskId, title, due, notes, status) {
        if (!authenticated) {
            requireAuthentication("");
            return;
        }
        if (!listId)
            listId = "@default";
        var jsonData = {};
        if (title !== undefined)
            jsonData.title = title;
        if (due !== undefined)
            jsonData.due = due;
        if (notes !== undefined)
            jsonData.notes = notes;
        if (status !== undefined)
            jsonData.status = status;
        enqueueTaskAction(["python3", "-u", getScriptPath(), "--update-task", listId, taskId, JSON.stringify(jsonData)], {
            "operation": "update",
            "sourceId": ""
        });
    }

    Component.onCompleted: checkAuthentication()
}
