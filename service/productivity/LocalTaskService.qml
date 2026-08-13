pragma Singleton
import QtQuick
import Quickshell.Io
import "../../"
import ".."

QtObject {
    id: root

    readonly property string statePath: Config.cacheRoot + "/local_tasks.json"
    property bool storageReady: false
    property string activeSyncId: ""
    property string syncError: ""
    property var syncQueue: []
    property var syncingTasks: ({})
    property var tasks: []
    property FileView taskFile: FileView {
        atomicWrites: true
        blockLoading: true
        blockWrites: true
        path: root.storageReady ? root.statePath : ""
        printErrors: false
        watchChanges: false

        onLoadFailed: {
            if (root.storageReady)
                root.persist();
        }
        onLoadedChanged: {
            if (loaded)
                root.loadTasks(text());
        }
        onSaveFailed: error => console.warn("[LocalTaskService] Could not save local tasks:", error)
    }
    property Timer writeDelay: Timer {
        interval: 60
        repeat: false

        onTriggered: root.persist()
    }
    property Process cacheInitializer: Process {
        command: ["mkdir", "-p", Config.cacheRoot]
        running: false

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                root.storageReady = true;
            else
                console.warn("[LocalTaskService] Could not initialize task storage:", exitCode);
        }
    }
    property Process googleSyncProcess: Process {
        id: googleSyncProcess

        property string errorBuffer: ""
        property string outputBuffer: ""

        command: []
        running: false

        stderr: SplitParser {
            onRead: line => googleSyncProcess.errorBuffer += line + "\n"
        }
        stdout: SplitParser {
            onRead: line => googleSyncProcess.outputBuffer += line
        }

        onExited: (exitCode, exitStatus) => {
            var taskId = root.activeSyncId;
            var succeeded = false;
            var message = "";
            try {
                if (outputBuffer.trim() !== "") {
                    var response = JSON.parse(outputBuffer);
                    succeeded = response.success === true;
                    if (!succeeded)
                        message = String(response.error || "Google Tasks sync failed");
                } else if (errorBuffer.trim() !== "") {
                    message = errorBuffer.trim();
                    try {
                        var errorResponse = JSON.parse(message);
                        message = String(errorResponse.error || message);
                    } catch (parseError) {}
                }
            } catch (error) {
                message = "Invalid response from Google Tasks";
            }
            if (!succeeded && message === "")
                message = exitCode === 0 ? "Google Tasks returned an empty response" : "Google Tasks process exited with code " + exitCode;

            root.activeSyncId = "";
            root.setSyncing(taskId, false);
            outputBuffer = "";
            errorBuffer = "";
            if (succeeded) {
                root.deleteTask(taskId);
                root.syncError = "";
                GoogleService.fetchTasks();
            } else {
                root.syncError = message;
                console.warn("[LocalTaskService] Google sync failed:", message);
            }
            root.syncFinished(taskId, succeeded);
            Qt.callLater(root.startNextGoogleSync);
        }
    }

    signal syncFinished(string taskId, bool succeeded)

    function createTask(title, due, notes) {
        var now = Date.now();
        var task = {
            "id": "local-" + now + "-" + Math.floor(Math.random() * 1000000),
            "title": String(title || "").trim(),
            "notes": String(notes || ""),
            "due": String(due || ""),
            "status": "needsAction",
            "createdAt": now,
            "updatedAt": now
        };
        if (task.title === "")
            return "";
        tasks = [task].concat(tasks);
        writeDelay.restart();
        return task.id;
    }
    function deleteTask(taskId) {
        var next = [];
        for (var i = 0; i < tasks.length; ++i) {
            if (String(tasks[i].id) !== String(taskId))
                next.push(tasks[i]);
        }
        if (next.length !== tasks.length) {
            tasks = next;
            writeDelay.restart();
        }
    }
    function findTask(taskId) {
        for (var i = 0; i < tasks.length; ++i) {
            if (String(tasks[i].id) === String(taskId))
                return tasks[i];
        }
        return null;
    }
    function isSyncing(taskId) {
        return syncingTasks[String(taskId)] === true;
    }
    function loadTasks(rawText) {
        try {
            var parsed = JSON.parse(String(rawText || "{}"));
            var stored = Array.isArray(parsed) ? parsed : parsed.tasks;
            if (!Array.isArray(stored))
                stored = [];
            var normalized = [];
            for (var i = 0; i < stored.length && normalized.length < 1000; ++i) {
                var item = stored[i] || {};
                var title = String(item.title || "").trim();
                var id = String(item.id || "");
                if (id === "" || title === "")
                    continue;
                normalized.push({
                    "id": id,
                    "title": title,
                    "notes": String(item.notes || ""),
                    "due": String(item.due || ""),
                    "status": item.status === "completed" ? "completed" : "needsAction",
                    "createdAt": Number(item.createdAt || Date.now()),
                    "updatedAt": Number(item.updatedAt || item.createdAt || Date.now())
                });
            }
            tasks = normalized;
        } catch (error) {
            console.warn("[LocalTaskService] Ignoring invalid local task state:", error);
            tasks = [];
        }
    }
    function persist() {
        if (!storageReady)
            return;
        taskFile.setText(JSON.stringify({
            "version": 1,
            "tasks": tasks
        }) + "\n");
    }
    function setSyncing(taskId, syncing) {
        var next = Object.assign({}, syncingTasks);
        if (syncing)
            next[String(taskId)] = true;
        else
            delete next[String(taskId)];
        syncingTasks = next;
    }
    function startNextGoogleSync() {
        if (googleSyncProcess.running || activeSyncId !== "" || syncQueue.length === 0)
            return;
        var queue = syncQueue.slice();
        var taskId = String(queue.shift() || "");
        syncQueue = queue;
        var task = findTask(taskId);
        if (!task) {
            setSyncing(taskId, false);
            Qt.callLater(startNextGoogleSync);
            return;
        }
        activeSyncId = taskId;
        googleSyncProcess.outputBuffer = "";
        googleSyncProcess.errorBuffer = "";
        googleSyncProcess.command = ["python3", "-u", GoogleService.getScriptPath(), "--create-task", "@default", JSON.stringify({
            "title": task.title,
            "due": task.due || "",
            "notes": task.notes || ""
        })];
        googleSyncProcess.running = true;
    }
    function syncToGoogle(taskId) {
        var task = findTask(taskId);
        if (!task)
            return false;
        if (isSyncing(taskId)) {
            if (activeSyncId === String(taskId) || syncQueue.indexOf(String(taskId)) >= 0)
                return true;
            setSyncing(taskId, false);
        }
        if (!GoogleService.authenticated) {
            syncError = "Connect Google before syncing local tasks";
            GoogleService.requireAuthentication("todo-sync");
            return false;
        }
        syncError = "";
        var queue = syncQueue.slice();
        queue.push(String(taskId));
        syncQueue = queue;
        setSyncing(taskId, true);
        startNextGoogleSync();
        return true;
    }
    function updateTask(taskId, title, due, notes, status) {
        var next = [];
        var changed = false;
        for (var i = 0; i < tasks.length; ++i) {
            var item = tasks[i];
            if (String(item.id) !== String(taskId)) {
                next.push(item);
                continue;
            }
            next.push({
                "id": item.id,
                "title": title === undefined ? item.title : String(title || "").trim(),
                "notes": notes === undefined ? item.notes : String(notes || ""),
                "due": due === undefined ? item.due : String(due || ""),
                "status": status === "completed" ? "completed" : status === "needsAction" ? "needsAction" : item.status,
                "createdAt": item.createdAt,
                "updatedAt": Date.now()
            });
            changed = true;
        }
        if (changed) {
            tasks = next;
            writeDelay.restart();
        }
    }

    Component.onCompleted: cacheInitializer.running = true
}
