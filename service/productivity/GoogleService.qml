pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property Process actionProcess: Process {
        id: actionProcess

        property string outputBuffer: ""

        command: []
        running: false

        stderr: SplitParser {
            onRead: line => {
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
            try {
                if (outputBuffer.trim() !== "") {
                    var parsed = JSON.parse(outputBuffer);
                    if (parsed.success) {
                        console.log("Action succeeded, refreshing events...");
                        root.fetchEvents(); // Reload events
                    } else if (parsed.error) {
                        console.log("Action error from Python:", parsed.error);
                    }
                }
            } catch (e) {
                console.log("Failed to parse action output:", e);
            }
            outputBuffer = "";
        }
    }
    property Process actionTasksProcess: Process {
        id: actionTasksProcess

        property string outputBuffer: ""

        command: []
        running: false

        stderr: SplitParser {
            onRead: line => {
                console.log("Google API Task Action Error:", line);
            }
        }
        stdout: SplitParser {
            onRead: line => {
                actionTasksProcess.outputBuffer += line;
            }
        }

        onExited: {
            try {
                if (outputBuffer.trim() !== "") {
                    var parsed = JSON.parse(outputBuffer);
                    if (parsed.success) {
                        root.fetchTasks(); // Reload
                    } else if (parsed.error) {
                        console.log("Task action error:", parsed.error);
                    }
                }
            } catch (e) {
                console.log("Failed to parse task action output:", e);
            }
            outputBuffer = "";
        }
    }

    // An array of all events for the current loaded time window
    property var allEvents: []
    property var allTasks: []
    property Process authCheckProcess: Process {
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
    }
    property bool authChecked: false
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
    property var calendars: []
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
                    }
                }
            } catch (e) {
                console.log("Failed to parse calendars output:", e);
            }
            outputBuffer = "";
        }
    }
    property string errorMessage: ""
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
                        console.log("Loaded", root.allEvents.length, "events for month", root.loadedMonth);
                        root.eventsChanged();
                    }
                }
            } catch (e) {
                console.log("Failed to parse Google API output:", e);
                root.errorMessage = "Failed to parse JSON";
            }
            outputBuffer = "";
        }
    }
    property Process fetchTasksProcess: Process {
        id: fetchTasksProcess

        property string outputBuffer: ""

        command: []
        running: false

        stderr: SplitParser {
            onRead: line => {
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
                        console.log("Loaded", root.allTasks.length, "tasks");
                        root.tasksChanged();
                    }
                }
            } catch (e) {
                console.log("Failed to parse tasks output:", e);
            }
            outputBuffer = "";
        }
    }
    property bool isLoading: false
    property bool isLoadingTasks: false
    // Internal state
    property int loadedMonth: new Date().getMonth() + 1
    property int loadedYear: new Date().getFullYear()
    property string pendingAuthContext: ""

    signal authenticationSucceeded(string context)
    signal eventsChanged
    signal tasksChanged

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
        authCheckProcess.running = false;
        authCheckProcess.running = true;
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
        actionProcess.command = ["python3", "-u", getScriptPath(), "--create", jsonString];
        actionProcess.running = false;
        actionProcess.running = true;
    }
    function createTask(listId, title, due, notes) {
        if (!authenticated) {
            requireAuthentication("todo-add");
            return;
        }
        if (!listId)
            listId = "@default";
        var jsonData = {
            title: title,
            due: due,
            notes: notes
        };
        actionTasksProcess.command = ["python3", "-u", getScriptPath(), "--create-task", listId, JSON.stringify(jsonData)];
        actionTasksProcess.running = false;
        actionTasksProcess.running = true;
    }
    function deleteEvent(calendarId, eventId) {
        if (!authenticated) {
            requireAuthentication("");
            return;
        }
        if (!calendarId)
            calendarId = "primary";
        console.log("Deleting event:", eventId, "from", calendarId);
        actionProcess.command = ["python3", "-u", getScriptPath(), "--delete", calendarId, eventId];
        actionProcess.running = false;
        actionProcess.running = true;
    }
    function deleteTask(listId, taskId) {
        if (!authenticated) {
            requireAuthentication("");
            return;
        }
        if (!listId)
            listId = "@default";
        actionTasksProcess.command = ["python3", "-u", getScriptPath(), "--delete-task", listId, taskId];
        actionTasksProcess.running = false;
        actionTasksProcess.running = true;
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
        calendarsProcess.running = false;
        calendarsProcess.running = true;
    }
    function fetchEvents(month, year) {
        if (!authenticated || isLoading)
            return;

        // Month should be 1-12
        if (month !== undefined)
            root.loadedMonth = month + 1;
        if (year !== undefined)
            root.loadedYear = year;

        console.log("Fetching events for", root.loadedMonth, root.loadedYear);
        isLoading = true;
        fetchProcess.command = ["python3", "-u", getScriptPath(), root.loadedMonth.toString(), root.loadedYear.toString()];
        fetchProcess.running = false;
        fetchProcess.running = true;
    }
    function fetchTasks(listId) {
        if (!authenticated || isLoadingTasks)
            return;
        if (!listId)
            listId = "@default";
        isLoadingTasks = true;
        fetchTasksProcess.command = ["python3", "-u", getScriptPath(), "--get-tasks", listId];
        fetchTasksProcess.running = false;
        fetchTasksProcess.running = true;
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
        authProcess.running = false;
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
        actionProcess.command = ["python3", "-u", getScriptPath(), "--update", calendarId, eventId, jsonString];
        actionProcess.running = false;
        actionProcess.running = true;
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
        actionTasksProcess.command = ["python3", "-u", getScriptPath(), "--update-task", listId, taskId, JSON.stringify(jsonData)];
        actionTasksProcess.running = false;
        actionTasksProcess.running = true;
    }

    Component.onCompleted: checkAuthentication()
}
