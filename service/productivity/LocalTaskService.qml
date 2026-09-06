pragma Singleton
import QtQuick
import Quickshell.Io
import "../../"
import ".."

QtObject {
    id: root

    property string activeSyncId: ""
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
    property Connections googleConnections: Connections {
        function onTaskActionFinished(operation, sourceId, succeeded, remoteId, message) {
            if (operation !== "sync-local" || sourceId === "")
                return;
            root.finishGoogleSync(sourceId, succeeded, message);
        }

        target: GoogleService
    }
    readonly property string statePath: Config.cacheRoot + "/local_tasks.json"
    property bool storageReady: false
    property string syncError: ""
    property var syncQueue: []
    property var syncingTasks: ({})
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
    property var tasks: []
    property Timer writeDelay: Timer {
        interval: 60
        repeat: false

        onTriggered: root.persist()
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
    function finishGoogleSync(taskId, succeeded, message) {
        taskId = String(taskId || "");
        if (taskId === "" || taskId !== activeSyncId)
            return;

        activeSyncId = "";
        setSyncing(taskId, false);
        if (succeeded) {
            deleteTask(taskId);
            syncError = "";
        } else {
            syncError = String(message || qsTr("Google Tasks sync failed"));
            console.warn("[LocalTaskService] Google sync failed:", syncError);
        }
        syncFinished(taskId, succeeded);
        Qt.callLater(startNextGoogleSync);
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
        if (activeSyncId !== "" || syncQueue.length === 0)
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
        if (!GoogleService.createTask("@default", task.title, task.due || "", task.notes || "", taskId))
            finishGoogleSync(taskId, false, qsTr("Google account is not connected"));
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
            syncError = qsTr("Connect Google before syncing local tasks");
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
