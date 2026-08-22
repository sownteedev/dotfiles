import "../../"
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
    property var pinnedIds: ({})
    readonly property string pinnedStatePath: Config.cacheRoot + "/launcher_clipboard_pins.json"
    property var previewQueue: []
    readonly property string previewSessionId: String(Date.now())
    property string query: ""
    property var readyPreviewIds: ({})
    property int requestGeneration: 0

    function classifyContent(content, isImage, characterCount, decodedLineCount) {
        var text = String(content || "").trim();
        if (isImage)
            return imageDetails(text);

        var firstLine = firstNonEmptyLine(text);
        var singleLine = text.indexOf("\n") === -1;
        if (singleLine && /^(https?:\/\/|www\.)\S+$/i.test(text)) {
            return {
                kind: "url",
                title: text,
                subtitle: qsTr("URL · %1").arg(urlHost(text)),
                iconName: "web-browser-symbolic"
            };
        }
        if (singleLine && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(text)) {
            return {
                kind: "email",
                title: text,
                subtitle: qsTr("Email address"),
                iconName: "mail-message-new-symbolic"
            };
        }
        if (singleLine && /^#[0-9a-f]{3,4}([0-9a-f]{3,4})?$/i.test(text)) {
            return {
                kind: "color",
                title: text.toUpperCase(),
                subtitle: qsTr("Color value"),
                iconName: "color-select-symbolic"
            };
        }
        if (singleLine && (/^file:\/\//i.test(text) || /^\//.test(text) || /^~\//.test(text))) {
            var sourcePath = localPath(text);
            var path = displayPath(sourcePath);
            var isFolder = /\/$/.test(sourcePath);
            return {
                kind: isFolder ? "folder" : "file",
                title: pathName(path),
                subtitle: (isFolder ? qsTr("Folder · %1") : qsTr("File · %1")).arg(path),
                iconName: isFolder ? "folder-symbolic" : fileIcon(sourcePath),
                isFileImage: !isFolder && isImageFile(sourcePath),
                isVideo: !isFolder && isVideoFile(sourcePath),
                sourcePath: sourcePath
            };
        }

        var lineCount = decodedLineCount >= 0 ? decodedLineCount : (text === "" ? 0 : text.split(/\r?\n/).length);
        var textLength = characterCount >= 0 ? characterCount : text.length;
        return {
            kind: "text",
            title: firstLine || qsTr("Empty text"),
            subtitle: lineCount > 1 ? qsTr("Text · %1 lines").arg(lineCount) : qsTr("Text · %1 characters").arg(textLength),
            iconName: "edit-paste-symbolic"
        };
    }
    function copySelected(id) {
        var command = Config.launcherClipboardAutoPaste ? "if cliphist decode \"$1\" | wl-copy; then if command -v wtype >/dev/null 2>&1; then sleep 0.4; wtype -M ctrl -k v -m ctrl; fi; fi" : "cliphist decode \"$1\" | wl-copy";
        Quickshell.execDetached(["sh", "-c", command, "clip_decode_paste", id]);
    }
    function displayPath(value) {
        return localPath(value).replace(Config.homeDir, "~");
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
            if (result.id !== id || (!result.isImage && !result.isVideo) || readyPreviewIds[id])
                continue;

            var path = previewPathForId(id, result.isVideo ? "jpg" : "png");
            if (generatedPreviewPaths.indexOf(path) === -1)
                generatedPreviewPaths = generatedPreviewPaths.concat([path]);
            if (result.isVideo && generatedPreviewPaths.indexOf(path + ".tmp.jpg") === -1)
                generatedPreviewPaths = generatedPreviewPaths.concat([path + ".tmp.jpg"]);
            previewQueue = previewQueue.concat([
                {
                    generation: requestGeneration,
                    id: id,
                    mode: result.isVideo ? "video" : "clipboardImage",
                    path: path,
                    sourcePath: result.sourcePath || ""
                }
            ]);
            startNextPreview();
            return;
        }
    }
    function fileIcon(path) {
        var extension = String(path || "").split(".").pop().toLowerCase();
        var icons = {
            png: "image-x-generic-symbolic",
            jpg: "image-x-generic-symbolic",
            jpeg: "image-x-generic-symbolic",
            avif: "image-x-generic-symbolic",
            bmp: "image-x-generic-symbolic",
            gif: "image-x-generic-symbolic",
            webp: "image-x-generic-symbolic",
            svg: "image-x-generic-symbolic",
            mp4: "video-x-generic-symbolic",
            mkv: "video-x-generic-symbolic",
            mov: "video-x-generic-symbolic",
            webm: "video-x-generic-symbolic",
            m4v: "video-x-generic-symbolic",
            mpeg: "video-x-generic-symbolic",
            mpg: "video-x-generic-symbolic",
            mp3: "audio-x-generic-symbolic",
            flac: "audio-x-generic-symbolic",
            wav: "audio-x-generic-symbolic",
            ogg: "audio-x-generic-symbolic",
            pdf: "document-send-symbolic",
            zip: "package-x-generic-symbolic",
            rar: "package-x-generic-symbolic",
            "7z": "package-x-generic-symbolic"
        };
        return icons[extension] || "text-x-generic-symbolic";
    }
    function firstNonEmptyLine(text) {
        var lines = String(text || "").split(/\r?\n/);
        for (var i = 0; i < lines.length; ++i) {
            var line = lines[i].trim();
            if (line !== "")
                return line;
        }
        return "";
    }
    function imageDetails(content) {
        var details = String(content || "").replace(/^\[\[\s*binary data\s*/i, "").replace(/\s*\]\]$/, "").trim();
        var dimensionsMatch = details.match(/(\d+)\s*x\s*(\d+)/i);
        var formatMatch = details.match(/\b(png|jpe?g|avif|webp|gif|bmp|svg|tiff?)\b/i);
        var dimensions = dimensionsMatch ? dimensionsMatch[1] + " × " + dimensionsMatch[2] : "";
        var format = formatMatch ? formatMatch[1].toUpperCase().replace("JPG", "JPEG") : "";
        var size = details;
        if (dimensionsMatch)
            size = size.replace(dimensionsMatch[0], "");
        if (formatMatch)
            size = size.replace(formatMatch[0], "");
        size = size.replace(/\s+/g, " ").trim();

        var subtitleParts = [];
        if (dimensions !== "")
            subtitleParts.push(dimensions);
        if (size !== "")
            subtitleParts.push(size);
        return {
            kind: "image",
            title: format !== "" ? qsTr("%1 image").arg(format) : qsTr("Image"),
            subtitle: subtitleParts.length > 0 ? subtitleParts.join(" · ") : qsTr("Clipboard image"),
            iconName: "image-x-generic-symbolic"
        };
    }
    function isImageFile(path) {
        var extension = String(path || "").split(".").pop().toLowerCase();
        return ["png", "jpg", "jpeg", "avif", "gif", "webp", "bmp", "svg"].indexOf(extension) !== -1;
    }
    function isPinned(id) {
        return pinnedIds[String(id)] === true;
    }
    function isVideoFile(path) {
        var extension = String(path || "").split(".").pop().toLowerCase();
        return ["mp4", "mkv", "avi", "mov", "webm", "m4v", "mpeg", "mpg"].indexOf(extension) !== -1;
    }
    function loadPinnedState(rawText) {
        var next = {};
        try {
            var parsed = JSON.parse(String(rawText || "{}"));
            var ids = Array.isArray(parsed) ? parsed : parsed.ids;
            if (Array.isArray(ids)) {
                for (var i = 0; i < ids.length; ++i) {
                    var id = String(ids[i] || "");
                    if (id !== "")
                        next[id] = true;
                }
            }
        } catch (error) {
            console.warn("[LauncherClipboard] Ignoring invalid pinned clipboard state:", error);
        }
        pinnedIds = next;
        refreshPinnedResults();
    }
    function localPath(value) {
        var path = String(value || "").replace(/^file:\/\//i, "");
        try {
            path = decodeURIComponent(path);
        } catch (error) {}
        if (path.startsWith("~/"))
            return Config.homeDir + path.substring(1);
        return path;
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
    function pathName(path) {
        var normalized = String(path || "").replace(/\/+$/, "");
        if (normalized === "")
            return "/";
        var separator = normalized.lastIndexOf("/");
        return separator >= 0 ? normalized.substring(separator + 1) || normalized : normalized;
    }
    function persistPinnedState() {
        pinnedStateFile.setText(JSON.stringify({
            "version": 1,
            "ids": Object.keys(pinnedIds)
        }) + "\n");
    }
    function previewPathForId(id, extension) {
        var safeId = String(id).replace(/[^A-Za-z0-9_-]/g, "_");
        return "/tmp/quickshell-launcher-cliphist-" + previewSessionId + "-" + safeId + "." + extension;
    }
    function refreshPinnedResults() {
        var updated = [];
        for (var i = 0; i < clipboardResults.length; ++i) {
            var item = Object.assign({}, clipboardResults[i]);
            item.pinned = isPinned(item.id);
            updated.push(item);
        }
        updated.sort(function (a, b) {
            if (a.pinned !== b.pinned)
                return a.pinned ? -1 : 1;
            return a.historyIndex - b.historyIndex;
        });
        clipboardResults = updated;
    }
    function runClipboardSearch() {
        cliphistProcess.running = false;
        var q = query.trim();
        // Determine search term after "c "
        var searchTerm = "";
        var prefix = Config.launcherClipboardPrefix.toLowerCase();
        if (q.toLowerCase().startsWith(prefix + " ")) {
            searchTerm = q.substring(prefix.length + 1).trim();
        } else if (q.toLowerCase() === prefix) {
            searchTerm = "";
        } else {
            clipboardResults = [];
            return;
        }

        var generation = requestGeneration;
        var pinnedIdList = Object.keys(pinnedIds).join(",");
        var script = "printf '__QS_REQUEST__%s\\n' \"$1\"; cliphist list 2>/dev/null | grep -aFi -- \"$2\" 2>/dev/null | awk -F '\t' -v max=\"$3\" -v pins=\",$4,\" '{ id=$1; if (index(pins, \",\" id \",\") > 0) pinnedRows[++pinnedCount]=$0; else if (recentCount < max) recentRows[++recentCount]=$0 } END { emitted=0; for (i=1; i<=pinnedCount && emitted<max; ++i) { print pinnedRows[i]; ++emitted } for (i=1; i<=recentCount && emitted<max; ++i) { print recentRows[i]; ++emitted } }' | while IFS= read -r entry; do clip_id=${entry%%\t*}; preview=${entry#*\t}; if printf '%s' \"$preview\" | grep -aqE 'binary data|image/'; then printf '%s\\t-1\\t-1\\n' \"$entry\"; else stats=$(cliphist decode \"$clip_id\" 2>/dev/null | awk '{ if (NR > 1) chars++; chars += length($0); lines++ } END { printf \"%d\\t%d\", chars, lines }'); printf '%s\\t%s\\n' \"$entry\" \"$stats\"; fi; done";
        cliphistProcess.command = ["sh", "-c", script, "cliphist_script", String(generation), searchTerm, String(Config.launcherMaxResults), pinnedIdList];
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
            if (job.mode === "video")
                previewDecodeProcess.command = ["sh", "-c", "rm -f -- \"$2.tmp.jpg\"; if ffmpeg -hide_banner -loglevel error -y -ss 0.1 -i \"$1\" -frames:v 1 -vf 'scale=160:160:force_original_aspect_ratio=increase,crop=160:160' \"$2.tmp.jpg\" && [ -s \"$2.tmp.jpg\" ]; then mv -- \"$2.tmp.jpg\" \"$2\"; printf ready; else rm -f -- \"$2.tmp.jpg\"; fi", "clipboard_video_preview", job.sourcePath, job.path];
            else
                previewDecodeProcess.command = ["sh", "-c", "if [ -s \"$2\" ] || { cliphist decode \"$1\" > \"$2\" && [ -s \"$2\" ]; }; then printf ready; else rm -f -- \"$2\"; fi", "decode_image", job.id, job.path];
            previewDecodeProcess.running = true;
            return;
        }
    }
    function togglePinned(id) {
        var key = String(id || "");
        if (key === "")
            return -1;

        var next = Object.assign({}, pinnedIds);
        if (next[key])
            delete next[key];
        else
            next[key] = true;
        pinnedIds = next;
        refreshPinnedResults();
        persistPinnedState();
        for (var i = 0; i < clipboardResults.length; ++i) {
            if (String(clipboardResults[i].id) === key)
                return i;
        }
        return -1;
    }
    function urlHost(value) {
        return String(value || "").replace(/^https?:\/\//i, "").replace(/^www\./i, "").split(/[\/?#]/)[0];
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
    FileView {
        id: pinnedStateFile

        atomicWrites: true
        blockLoading: true
        blockWrites: true
        path: clipboardRoot.pinnedStatePath
        printErrors: false
        watchChanges: false

        onLoadFailed: clipboardRoot.persistPinnedState()
        onLoadedChanged: {
            if (loaded)
                clipboardRoot.loadPinnedState(text());
        }
        onSaveFailed: error => console.warn("[LauncherClipboard] Could not save pinned clipboard state:", error)
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
                        var lineCountTab = line.lastIndexOf("\t");
                        var characterCountTab = line.lastIndexOf("\t", lineCountTab - 1);
                        if (characterCountTab === -1 || lineCountTab === -1)
                            continue;

                        var decodedCharacterCount = parseInt(line.substring(characterCountTab + 1, lineCountTab));
                        var decodedLineCount = parseInt(line.substring(lineCountTab + 1));
                        var clipboardLine = line.substring(0, characterCountTab);
                        var tabIdx = clipboardLine.indexOf("\t");
                        if (tabIdx !== -1) {
                            var id = clipboardLine.substring(0, tabIdx).trim();
                            var content = clipboardLine.substring(tabIdx + 1);
                            var isImg = content.indexOf("binary data") !== -1 || content.indexOf("image/") !== -1;
                            var classification = classifyContent(content, isImg, decodedCharacterCount, decodedLineCount);
                            results.push({
                                id: id,
                                content: content,
                                historyIndex: results.length,
                                pinned: isPinned(id),
                                isImage: isImg,
                                isFileImage: Boolean(classification.isFileImage),
                                isVideo: Boolean(classification.isVideo),
                                kind: classification.kind,
                                title: classification.title,
                                subtitle: classification.subtitle,
                                iconName: classification.iconName,
                                sourcePath: classification.sourcePath || ""
                            });
                        }
                    }
                    clipboardResults = results.slice(0, Config.launcherMaxResults);
                    refreshPinnedResults();
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
