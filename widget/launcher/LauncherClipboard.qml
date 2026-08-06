import QtQuick
import Quickshell
import Quickshell.Io

// Logic-only component for clipboard history using cliphist
Item {
    id: clipboardRoot

    property int activePreviewGeneration: -1
    property string activePreviewId: ""
    property string activePreviewPath: ""
    property var clipboardResults: []
    property var generatedPreviewPaths: []
    property var previewQueue: []
    readonly property string previewSessionId: String(Date.now())
    property string query: ""
    property var readyPreviewIds: ({})
    property int requestGeneration: 0

    function copySelected(id) {
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "clip_decode", id]);
    }
    function ensurePreview(id) {
        if (activePreviewGeneration === requestGeneration && activePreviewId === id)
            return;

        for (var queuedIndex = 0; queuedIndex < previewQueue.length; ++queuedIndex) {
            if (previewQueue[queuedIndex].generation === requestGeneration && previewQueue[queuedIndex].id === id)
                return;
        }

        for (var resultIndex = 0; resultIndex < clipboardResults.length; ++resultIndex) {
            var result = clipboardResults[resultIndex];
            if (result.id !== id || !result.isImage || readyPreviewIds[id])
                continue;

            var path = previewPathForId(id);
            if (generatedPreviewPaths.indexOf(path) === -1)
                generatedPreviewPaths = generatedPreviewPaths.concat([path]);
            previewQueue = previewQueue.concat([
                {
                    id: id,
                    path: path,
                    generation: requestGeneration
                }
            ]);
            startNextPreview();
            return;
        }
    }
    function markPreviewReady(id, path, generation) {
        if (generation !== requestGeneration)
            return;

        var updated = {};
        for (var key in readyPreviewIds)
            updated[key] = readyPreviewIds[key];
        updated[id] = path;
        readyPreviewIds = updated;
    }
    function previewPathForId(id) {
        var safeId = String(id).replace(/[^A-Za-z0-9_-]/g, "_");
        return "/tmp/quickshell-launcher-cliphist-" + previewSessionId + "-" + safeId + ".png";
    }
    function runClipboardSearch() {
        cliphistProcess.running = false;
        var q = query.trim();
        // Determine search term after "c "
        var searchTerm = "";
        if (q.toLowerCase().startsWith("c ")) {
            searchTerm = q.substring(2).trim();
        } else if (q.toLowerCase() === "c") {
            searchTerm = "";
        } else {
            clipboardResults = [];
            return;
        }

        var generation = requestGeneration;
        cliphistProcess.command = ["sh", "-c", "printf '__QS_REQUEST__%s\\n' \"$1\"; cliphist list 2>/dev/null | grep -aFi -- \"$2\" 2>/dev/null | head -n 20", "cliphist_script", String(generation), searchTerm];
        cliphistProcess.running = true;
    }
    function startNextPreview() {
        if (previewDecodeProcess.running)
            return;

        while (previewQueue.length > 0) {
            var pending = previewQueue.slice();
            var job = pending.shift();
            previewQueue = pending;
            if (job.generation !== requestGeneration)
                continue;

            activePreviewId = job.id;
            activePreviewPath = job.path;
            activePreviewGeneration = job.generation;
            previewDecodeProcess.command = ["sh", "-c", "if [ -s \"$2\" ] || { cliphist decode \"$1\" > \"$2\" && [ -s \"$2\" ]; }; then printf ready; else rm -f -- \"$2\"; fi", "decode_image", job.id, job.path];
            previewDecodeProcess.running = true;
            return;
        }
    }

    Component.onDestruction: {
        requestGeneration += 1;
        previewQueue = [];
        cliphistProcess.running = false;
        previewDecodeProcess.running = false;
        if (generatedPreviewPaths.length > 0) {
            var cleanupCommand = ["rm", "-f", "--"];
            for (var i = 0; i < generatedPreviewPaths.length; ++i)
                cleanupCommand.push(generatedPreviewPaths[i]);
            Quickshell.execDetached(cleanupCommand);
        }
    }
    onQueryChanged: {
        requestGeneration += 1;
        clipboardResults = [];
        previewQueue = [];
        readyPreviewIds = ({});
        cliphistProcess.running = false;
        previewDecodeProcess.running = false;
        searchDebounceTimer.restart();
    }

    Timer {
        id: searchDebounceTimer

        interval: 220
        repeat: false

        onTriggered: {
            runClipboardSearch();
        }
    }
    Process {
        id: cliphistProcess

        stdout: StdioCollector {
            id: cliphistCollector
        }

        onRunningChanged: {
            if (!running) {
                var output = cliphistCollector.text.trim();
                var lines = output === "" ? [] : output.split("\n");
                var markerPrefix = "__QS_REQUEST__";
                if (lines.length === 0 || lines[0].indexOf(markerPrefix) !== 0)
                    return;

                var responseGeneration = parseInt(lines.shift().substring(markerPrefix.length));
                if (responseGeneration !== requestGeneration)
                    return;

                if (lines.length === 0) {
                    clipboardResults = [];
                } else {
                    var results = [];
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i];
                        if (line.trim() === "")
                            continue;
                        var tabIdx = line.indexOf("\t");
                        if (tabIdx !== -1) {
                            var id = line.substring(0, tabIdx).trim();
                            var content = line.substring(tabIdx + 1);
                            var isImg = content.indexOf("binary data") !== -1 || content.indexOf("image/") !== -1;
                            results.push({
                                id: id,
                                content: content,
                                isImage: isImg
                            });
                        }
                    }
                    clipboardResults = results;
                }
            }
        }
    }
    Process {
        id: previewDecodeProcess

        stdout: StdioCollector {
            id: previewDecodeCollector
        }

        onRunningChanged: {
            if (!running) {
                if (activePreviewGeneration === requestGeneration && previewDecodeCollector.text.trim() === "ready")
                    markPreviewReady(activePreviewId, "file://" + activePreviewPath, activePreviewGeneration);

                activePreviewGeneration = -1;
                activePreviewId = "";
                activePreviewPath = "";
                startNextPreview();
            }
        }
    }
}
