import "../../"
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: filesRoot

    property int activePreviewGeneration: -1
    property string activePreviewPath: ""
    property string activePreviewTarget: ""
    property var fileResults: []
    readonly property bool loading: searchDebounceTimer.running || fileSearchProcess.running
    property var previewQueue: []
    property string query: ""
    property var readyPreviewPaths: ({})
    property int requestGeneration: 0
    readonly property string videoPreviewCacheDir: "/tmp/quickshell-launcher-video-previews"

    function ensureVideoPreview(path) {
        var sourcePath = String(path || "");
        if (!isVideoFile(sourcePath) || readyPreviewPaths[sourcePath])
            return;
        if (previewProcess.running && activePreviewGeneration === requestGeneration && activePreviewPath === sourcePath)
            return;
        for (var i = 0; i < previewQueue.length; ++i) {
            var queued = previewQueue[i];
            if (queued.generation === requestGeneration && queued.path === sourcePath)
                return;
        }

        previewQueue = previewQueue.concat([
            {
                generation: requestGeneration,
                path: sourcePath,
                target: videoPreviewPath(sourcePath)
            }
        ]);
        startNextPreview();
    }
    function isVideoFile(path) {
        var extension = String(path || "").split(".").pop().toLowerCase();
        return ["mp4", "mkv", "avi", "mov", "webm", "m4v", "mpeg", "mpg"].indexOf(extension) !== -1;
    }
    function isVideoPreviewReady(path) {
        return !!readyPreviewPaths[String(path || "")];
    }
    function markVideoPreviewReady(path, target, generation) {
        if (generation !== requestGeneration)
            return;
        var updated = {};
        for (var key in readyPreviewPaths)
            updated[key] = readyPreviewPaths[key];
        updated[path] = target;
        readyPreviewPaths = updated;
    }
    function removeFile(path) {
        var arr = [];
        for (var i = 0; i < fileResults.length; i++) {
            if (!fileResults[i] || fileResults[i].path !== path)
                arr.push(fileResults[i]);
        }
        fileResults = arr;
    }
    function runFileSearch() {
        fileSearchProcess.running = false;
        var q = query.trim();
        var searchTerm = "";
        var prefix = Config.launcherFilesPrefix.toLowerCase();
        if (q.toLowerCase().startsWith(prefix + " ")) {
            searchTerm = q.substring(prefix.length + 1).trim();
        } else if (q.toLowerCase() !== prefix) {
            fileResults = [];
            return;
        }

        var generation = requestGeneration;
        if (searchTerm === "") {
            var recentScript = "printf '__QS_REQUEST__%s\\n' \"$1\"; limit=$2; " + "find \"$HOME\" -maxdepth 3 -not -path '*/.*' -type f -printf '%T@ %p\\n' 2>/dev/null " + "| sort -nr 2>/dev/null | head -n \"$limit\" | cut -d' ' -f2-";
            fileSearchProcess.command = ["sh", "-c", recentScript, "recent_files", String(generation), String(Config.launcherMaxResults)];
        } else {
            if (searchTerm.length < 2) {
                fileResults = [];
                return;
            }

            var searchScript = "printf '__QS_REQUEST__%s\\n' \"$1\"; term=$2; limit=$3; set -- \"$HOME\"; " + "for candidate in /mnt/windows/Users/*/Downloads; do [ -d \"$candidate\" ] && set -- \"$@\" \"$candidate\"; done; " + "LC_ALL=C find \"$@\" -maxdepth 6 " + "\\( -name '.cache' -o -name '.git' -o -name '.local' -o -name '.mozilla' -o -name '.npm' -o -name '.cargo' -o -name '.rustup' " + "-o -name 'node_modules' -o -name 'venv' -o -name 'target' -o -name 'build' -o -name 'dist' -o -name 'Code' -o -name 'google-chrome' " + "-o -name '.gemini' -o -name '.antigravity-ide' -o -name 'Cache' -o -name 'CachedData' -o -name 'Code Cache' -o -name 'GPUCache' " + "-o -name 'logs' -o -name 'blob_storage' -o -name 'Service Worker' -o -name 'Session Storage' -o -name 'session' " + "-o -name 'Local Storage' -o -name 'WebStorage' -o -name 'storage' -o -name '__pycache__' \\) -prune -o " + "\\( -type f -o -type d -o -xtype d \\) -iname \"*$term*\" -printf '%y\\t%f\\t%p\\n' 2>/dev/null " + "| awk -F '\\t' -v term=\"$term\" 'BEGIN { term=tolower(term) } { kind=($1 == \"d\" || $1 == \"l\") ? \"d\" : \"f\"; name=tolower($2); rank=(name == term ? 0 : (index(name, term) == 1 ? 2 : 4)) + (kind == \"f\" ? 1 : 0); path=substr($0, length($1) + length($2) + 3); print rank \"\\t\" kind \"\\t\" path }' " + "| sort -n | head -n \"$limit\" | cut -f2-";
            fileSearchProcess.command = ["sh", "-c", searchScript, "find_script", String(generation), searchTerm, String(Config.launcherMaxResults)];
        }
        fileSearchProcess.running = true;
    }
    function startNextPreview() {
        if (previewProcess.running)
            return;

        while (previewQueue.length > 0) {
            var pending = previewQueue.slice();
            var job = pending.shift();
            previewQueue = pending;
            if (job.generation !== requestGeneration)
                continue;

            activePreviewGeneration = job.generation;
            activePreviewPath = job.path;
            activePreviewTarget = job.target;
            previewProcess.command = ["sh", "-c", "mkdir -p -- \"$3\"; if [ -s \"$2\" ] && [ \"$2\" -nt \"$1\" ]; then printf ready; exit 0; fi; rm -f -- \"$2.tmp.jpg\"; if ffmpeg -hide_banner -loglevel error -y -ss 0.1 -i \"$1\" -frames:v 1 -vf 'scale=160:160:force_original_aspect_ratio=increase,crop=160:160' \"$2.tmp.jpg\" && [ -s \"$2.tmp.jpg\" ]; then mv -- \"$2.tmp.jpg\" \"$2\"; printf ready; else rm -f -- \"$2.tmp.jpg\"; fi", "launcher_video_preview", job.path, job.target, videoPreviewCacheDir];
            previewProcess.running = true;
            return;
        }
    }
    function videoPreviewPath(path) {
        return videoPreviewCacheDir + "/" + Qt.md5(String(path || "")) + ".jpg";
    }
    function videoPreviewSource(path) {
        return readyPreviewPaths[String(path || "")] || "";
    }

    Component.onDestruction: {
        requestGeneration += 1;
        previewQueue = [];
        fileSearchProcess.running = false;
        previewProcess.running = false;
    }
    onQueryChanged: {
        requestGeneration += 1;
        fileResults = [];
        previewQueue = [];
        readyPreviewPaths = ({});
        fileSearchProcess.running = false;
        previewProcess.running = false;
        searchDebounceTimer.restart();
    }

    Timer {
        id: searchDebounceTimer

        interval: 260
        repeat: false

        onTriggered: runFileSearch()
    }
    Process {
        id: fileSearchProcess

        stdout: StdioCollector {
            id: fileCollector
        }

        onRunningChanged: {
            if (!running) {
                var output = fileCollector.text.trim();
                var lines = output === "" ? [] : output.split("\n");
                var markerPrefix = "__QS_REQUEST__";
                if (lines.length === 0 || lines[0].indexOf(markerPrefix) !== 0)
                    return;

                var responseGeneration = parseInt(lines.shift().substring(markerPrefix.length));
                if (responseGeneration !== requestGeneration)
                    return;

                if (lines.length === 0) {
                    fileResults = [];
                    return;
                }

                var results = [];
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (line === "")
                        continue;

                    var tabIdx = line.indexOf("\t");
                    if (tabIdx !== -1) {
                        var kind = line.substring(0, tabIdx);
                        var path = line.substring(tabIdx + 1);
                        results.push({
                            kind: kind === "d" ? "folder" : "file",
                            path: path,
                            name: path.substring(path.lastIndexOf("/") + 1)
                        });
                    } else {
                        results.push({
                            kind: "file",
                            path: line,
                            name: line.substring(line.lastIndexOf("/") + 1)
                        });
                    }
                }
                fileResults = results.slice(0, Config.launcherMaxResults);
            }
        }
    }
    Process {
        id: previewProcess

        stdout: StdioCollector {
            id: previewCollector
        }

        onRunningChanged: {
            if (running)
                return;
            if (activePreviewPath !== "" && previewCollector.text.trim() === "ready")
                markVideoPreviewReady(activePreviewPath, activePreviewTarget, activePreviewGeneration);
            activePreviewGeneration = -1;
            activePreviewPath = "";
            activePreviewTarget = "";
            startNextPreview();
        }
    }
}
