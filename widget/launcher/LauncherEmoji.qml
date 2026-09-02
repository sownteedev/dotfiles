import "../../"
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property string helperPath: Config.quickshellDir + "/backend/python/launcher/emoji_search_worker.py"
    property bool loading: false
    property string pendingSearchTerm: ""
    property string query: ""
    property int requestGeneration: 0
    property var results: []
    readonly property string searchTerm: {
        var prefix = Config.launcherEmojiPrefix.toLowerCase();
        if (!query.toLowerCase().startsWith(prefix + " "))
            return "";
        return query.substring(prefix.length + 1).trim().toLowerCase();
    }
    property bool sendWhenReady: false
    property bool workerReady: false

    function copy(entry) {
        if (!entry || !entry.glyph)
            return;

        var command = Config.launcherClipboardAutoPaste ? "if wl-copy \"$1\"; then if command -v wtype >/dev/null 2>&1; then sleep 0.35; wtype -M ctrl -k v -m ctrl; fi; fi" : "wl-copy \"$1\"";
        Quickshell.execDetached(["sh", "-c", command, "emoji_paste", entry.glyph]);
    }
    function handleWorkerLine(line) {
        var response;
        try {
            response = JSON.parse(String(line || ""));
        } catch (error) {
            return;
        }
        if (response.ready) {
            workerReady = true;
            if (sendWhenReady)
                sendSearch();
            return;
        }

        var generation = Number(response.requestId);
        if (generation !== requestGeneration)
            return;
        results = Array.isArray(response.results) ? response.results : [];
        loading = false;
    }
    function scheduleSearch() {
        pendingSearchTerm = searchTerm;
        requestGeneration += 1;
        loading = true;
        results = [];
        searchTimer.restart();
    }
    function sendSearch() {
        if (!workerReady || !searchProcess.running) {
            sendWhenReady = true;
            return;
        }

        sendWhenReady = false;
        searchProcess.write(JSON.stringify({
            "requestId": requestGeneration,
            "query": pendingSearchTerm,
            "limit": Math.max(1, Config.launcherMaxResults)
        }) + "\n");
    }

    Component.onCompleted: scheduleSearch()
    onSearchTermChanged: scheduleSearch()

    Process {
        id: searchProcess

        command: ["python3", "-u", root.helperPath]
        running: true
        stdinEnabled: true

        stderr: SplitParser {
            onRead: line => console.warn("[LauncherEmoji]", line)
        }
        stdout: SplitParser {
            onRead: line => root.handleWorkerLine(line)
        }

        onExited: (exitCode, exitStatus) => {
            root.workerReady = false;
            root.sendWhenReady = false;
            root.loading = false;
            if (exitCode !== 0)
                root.results = [];
        }
    }
    Timer {
        id: searchTimer

        interval: 120
        repeat: false

        onTriggered: root.sendSearch()
    }
    Connections {
        function onLauncherMaxResultsChanged() {
            root.scheduleSearch();
        }

        target: Config
    }
}
