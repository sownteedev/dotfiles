import "../../"
import "../../service"
import QtQuick
import Quickshell

Item {
    id: root

    property bool loading: false
    property var pendingRequestIds: []
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

    function copy(entry) {
        if (!entry || !entry.glyph)
            return;

        var command = Config.launcherClipboardAutoPaste ? "if wl-copy \"$1\"; then if command -v wtype >/dev/null 2>&1; then sleep 0.35; wtype -M ctrl -k v -m ctrl; fi; fi" : "wl-copy \"$1\"";
        Quickshell.execDetached(["sh", "-c", command, "emoji_paste", entry.glyph]);
    }
    function forgetRequest(requestId) {
        if (!requestId)
            return;
        pendingRequestIds = pendingRequestIds.filter(function (id) {
            return id !== requestId;
        });
    }
    function scheduleSearch() {
        pendingSearchTerm = searchTerm;
        requestGeneration += 1;
        loading = true;
        results = [];
        searchTimer.restart();
    }
    function sendSearch() {
        if (!CoreService.ready) {
            sendWhenReady = true;
            CoreService.ensureRunning();
            return;
        }

        sendWhenReady = false;
        var generation = requestGeneration;
        var requestId = CoreService.sendRequest("launcher.catalog.search", {
            "emojiPath": Config.sownteeshellDir + "/backend/python/launcher/emoji_catalog.jsonl",
            "unicodePath": Config.sownteeshellDir + "/backend/python/launcher/unicode_catalog.jsonl",
            "requestId": generation,
            "query": pendingSearchTerm,
            "limit": Math.max(1, Config.launcherMaxResults)
        }, function (response) {
            root.forgetRequest(requestId);
            if (generation !== root.requestGeneration)
                return;
            root.results = response && Array.isArray(response.results) ? response.results : [];
            root.loading = false;
        }, function (message) {
            root.forgetRequest(requestId);
            if (generation !== root.requestGeneration)
                return;
            root.results = [];
            root.loading = false;
            console.warn("[LauncherEmoji]", message);
        });
        if (requestId !== "")
            pendingRequestIds = pendingRequestIds.concat([requestId]);
    }

    Component.onCompleted: scheduleSearch()
    Component.onDestruction: {
        for (var index = 0; index < pendingRequestIds.length; ++index)
            CoreService.forgetRequest(pendingRequestIds[index]);
        CoreService.sendRequest("launcher.catalog.release", {});
    }
    onSearchTermChanged: scheduleSearch()

    Timer {
        id: searchTimer

        interval: 120
        repeat: false

        onTriggered: root.sendSearch()
    }
    Connections {
        function onReadyChanged() {
            if (CoreService.ready && root.sendWhenReady)
                root.sendSearch();
        }

        target: CoreService
    }
    Connections {
        function onLauncherMaxResultsChanged() {
            root.scheduleSearch();
        }

        target: Config
    }
}
