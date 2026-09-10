import "../../"
import "../../service"
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
    property int favoriteIndex: -1
    property var generatedPreviewPaths: []
    readonly property bool loading: searchDebounceTimer.running || searchRequest.active
    readonly property bool pinning: favoriteRequest.active
    property string preferredSelectedId: ""
    property var previewQueue: []
    readonly property string previewSessionId: String(Date.now())
    property string query: ""
    property var readyPreviewIds: ({})
    property int requestGeneration: 0

    signal selectionRequested(int index)

    function applyEntries(entries) {
        var results = [];
        for (var i = 0; i < entries.length; ++i) {
            var entry = entries[i];
            var classification = classifyContent(entry.content, entry.isImage, entry.characterCount, entry.lineCount, entry.fileCount, entry.firstFile);
            results.push(Object.assign({}, entry, {
                historyIndex: i,
                isFileImage: Boolean(classification.isFileImage),
                isVideo: Boolean(classification.isVideo),
                kind: classification.kind,
                title: classification.title,
                subtitle: classification.subtitle,
                iconName: classification.iconName,
                sourcePath: classification.sourcePath || ""
            }));
        }
        clipboardResults = results;
        if (favoriteIndex >= 0) {
            var selected = Math.min(favoriteIndex, Math.max(0, results.length - 1));
            for (var index = 0; index < results.length; ++index) {
                if (results[index].id === preferredSelectedId) {
                    selected = index;
                    break;
                }
            }
            preferredSelectedId = "";
            favoriteIndex = -1;
            selectionRequested(selected);
        }
    }
    function classifyContent(content, isImage, characterCount, decodedLineCount, decodedFileCount, decodedFirstFile) {
        var text = String(content || "").trim();
        if (isImage)
            return imageDetails(text);

        if (decodedFileCount > 0 && decodedFirstFile !== "")
            return fileDetails(decodedFirstFile, decodedFileCount);

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
            return fileDetails(text, 1);
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
        var key = String(id || "");
        if (key === "")
            return;
        CoreService.sendRequest("clipboard.restore", {
            "entryId": key,
            "autoPaste": Config.launcherClipboardAutoPaste
        }, function (result) {
            if (!result || result.ok !== true)
                console.warn("[LauncherClipboard]", result && result.message ? result.message : "Could not restore the clipboard entry");
        }, function (message) {
            console.warn("[LauncherClipboard]", message);
        });
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

            if (result.isImage && result.previewPath) {
                markPreviewReady(id, result.previewPath, requestGeneration);
                return;
            }
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
    function fileDetails(value, itemCount) {
        var sourcePath = localPath(value);
        var path = displayPath(sourcePath);
        if (itemCount > 1) {
            var directory = parentPath(path);
            return {
                kind: "files",
                title: pathName(path),
                subtitle: directory !== "" ? qsTr("%1 files · %2").arg(itemCount).arg(directory) : qsTr("%1 files").arg(itemCount),
                iconName: "edit-copy-symbolic",
                isFileImage: isImageFile(sourcePath),
                isVideo: isVideoFile(sourcePath),
                sourcePath: sourcePath
            };
        }

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
    function isVideoFile(path) {
        var extension = String(path || "").split(".").pop().toLowerCase();
        return ["mp4", "mkv", "avi", "mov", "webm", "m4v", "mpeg", "mpg"].indexOf(extension) !== -1;
    }
    function localPath(value) {
        var path = String(value || "").replace(/^file:\/\/localhost(?=\/)/i, "").replace(/^file:\/\//i, "");
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
    function parentPath(path) {
        var normalized = String(path || "").replace(/\/+$/, "");
        var separator = normalized.lastIndexOf("/");
        if (separator < 0)
            return "";
        if (separator === 0)
            return "/";
        return normalized.substring(0, separator);
    }
    function pathName(path) {
        var normalized = String(path || "").replace(/\/+$/, "");
        if (normalized === "")
            return "/";
        var separator = normalized.lastIndexOf("/");
        return separator >= 0 ? normalized.substring(separator + 1) || normalized : normalized;
    }
    function previewPathForId(id, extension) {
        var safeId = String(id).replace(/[^A-Za-z0-9_-]/g, "_");
        return "/tmp/sownteeshell-launcher-cliphist-" + previewSessionId + "-" + safeId + "." + extension;
    }
    function runClipboardSearch() {
        searchRequest.cancel();
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

        searchRequest.start("clipboard.list", {
            query: searchTerm,
            limit: Config.launcherMaxResults
        });
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
        if (key === "" || favoriteRequest.active)
            return -1;

        for (var i = 0; i < clipboardResults.length; ++i) {
            if (String(clipboardResults[i].id) === key) {
                favoriteIndex = i;
                preferredSelectedId = "";
                favoriteRequest.start(clipboardResults[i].pinned ? "clipboard.favorite.remove" : "clipboard.favorite.add", {
                    entryId: key
                });
                return i;
            }
        }
        return -1;
    }
    function urlHost(value) {
        return String(value || "").replace(/^https?:\/\//i, "").replace(/^www\./i, "").split(/[\/?#]/)[0];
    }

    Component.onDestruction: {
        requestGeneration += 1;
        previewQueue = [];
        searchRequest.cancel();
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
        searchRequest.cancel();
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
    CoreRequest {
        id: searchRequest

        onFailed: message => console.warn("[LauncherClipboard]", message)
        onSucceeded: result => {
            if (result && result.ok === true)
                clipboardRoot.applyEntries(result.entries || []);
            else
                console.warn("[LauncherClipboard]", result && result.message ? result.message : "Could not load clipboard history");
        }
    }
    CoreRequest {
        id: favoriteRequest

        // An accepted save must finish even if the Launcher provider is unloaded.
        cancellable: false

        onFailed: message => {
            clipboardRoot.favoriteIndex = -1;
            console.warn("[LauncherClipboard]", message);
        }
        onSucceeded: result => {
            if (result && result.ok === true) {
                clipboardRoot.preferredSelectedId = result.entryId || "";
                clipboardRoot.runClipboardSearch();
            } else {
                clipboardRoot.favoriteIndex = -1;
                console.warn("[LauncherClipboard]", result && result.message ? result.message : "Could not update clipboard favorite");
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
