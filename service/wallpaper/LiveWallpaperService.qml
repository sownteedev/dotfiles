pragma Singleton
import ".."
import "../../"
import Qt.labs.folderlistmodel
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property bool active: desiredPath !== "" || activePath !== ""
    property string activePath: ""
    property bool availabilityKnown: true
    property QtObject availabilityQuery: QtObject {
        readonly property bool running: false
    }
    property bool available: true
    property bool browsing: false
    readonly property string cacheDir: Config.cacheRoot + "/live-wallpapers"
    readonly property int coverWidth: 2560
    property int desiredGeneration: 0
    property string desiredPath: ""
    property string errorMessage: ""
    property var knownThumbnails: ({})
    property bool playbackReadyState: false
    property Connections policyConnections: Connections {
        function onShouldPauseChanged() {
            if (!root.desiredPath || root.playbackReadyState)
                return;

            if (WallpaperPlaybackPolicy.shouldPause)
                root.readyTimeout.stop();
            else
                root.readyTimeout.restart();
        }

        target: WallpaperPlaybackPolicy
    }
    property var readyScreens: ({})
    property Timer readyTimeout: Timer {
        interval: 12000
        repeat: false

        onTriggered: {
            if (!root.desiredPath || root.playbackReadyState || WallpaperPlaybackPolicy.shouldPause)
                return;

            root.reportFailure(root.desiredPath, "Live wallpaper did not become ready", root.desiredGeneration);
        }
    }
    property var registeredScreens: ({})
    property int requestSerial: 0
    property Connections screenConnections: Connections {
        function onScreensChanged() {
            root.updateFrameReadiness();
            root.updateTransitionCompletion();
        }

        target: Quickshell
    }
    property FolderListModel thumbnailCacheModel: FolderListModel {
        folder: root.browsing ? "file://" + root.cacheDir : ""
        nameFilters: ["*.jpg"]
        showDirs: false
        showFiles: true

        onCountChanged: root.indexThumbnailCache()
        onStatusChanged: {
            if (status === FolderListModel.Ready)
                root.indexThumbnailCache();
        }
    }
    property var thumbnailJob: null
    property var thumbnailQueue: []
    property bool thumbnailStopRequested: false
    readonly property int thumbnailWidth: 960
    property Process thumbnailWorker: Process {
        onExited: (exitCode, exitStatus) => {
            var completedJob = root.thumbnailJob;
            root.thumbnailJob = null;
            var stopped = root.thumbnailStopRequested;
            root.thumbnailStopRequested = false;
            if (!stopped && completedJob && exitCode === 0) {
                var updated = Object.assign({}, root.knownThumbnails);
                updated[completedJob.target] = true;
                root.knownThumbnails = updated;
                root.thumbnailReady(completedJob.path, completedJob.target, Number(completedJob.requestToken || 0));
            } else if (!stopped && completedJob) {
                console.warn("[LiveWallpaperService] Could not create thumbnail for", completedJob.path);
            }
            root.processNextThumbnail();
        }
    }
    property var transitionScreens: ({})

    signal playbackFailed(string sourcePath, string message, int generation)
    signal playbackReady(string sourcePath, string framePath, int generation)
    signal thumbnailReady(string sourcePath, string thumbnailPath, int requestToken)

    function allScreensReported(screenMap, requireRegistration) {
        var names = currentScreenNames();
        if (names.length === 0)
            return false;

        for (var i = 0; i < names.length; ++i) {
            var name = names[i];
            if (requireRegistration && registeredScreens[name] !== true)
                return false;

            if (screenMap[name] !== true)
                return false;
        }
        return true;
    }
    function beginBrowsing() {
        browsing = true;
    }
    function checkAvailability() {
        available = true;
        availabilityKnown = true;
    }
    function coverKnown(path, modified) {
        return knownThumbnails[coverPath(path, modified)] === true;
    }
    function coverPath(path, modified) {
        return cacheDir + "/" + WallpaperService.stableHash("live-video-cover-v1|" + String(coverWidth) + "|" + String(path) + "|" + modifiedKey(modified)) + ".jpg";
    }
    function currentScreenNames() {
        var names = [];
        for (var i = 0; i < Quickshell.screens.length; ++i)
            names.push(String(Quickshell.screens[i].name || ""));
        return names;
    }
    function endBrowsing() {
        browsing = false;
        var requiredTarget = "";
        if (WallpaperService.isTransitionPending && WallpaperService.currentMode === "video" && !WallpaperService.isEngineVideo)
            requiredTarget = coverPath(WallpaperService.selectedRendererPath, WallpaperService.selectedModified);

        var retainedQueue = [];
        for (var i = 0; i < thumbnailQueue.length; ++i) {
            if (requiredTarget !== "" && thumbnailQueue[i].target === requiredTarget)
                retainedQueue.push(thumbnailQueue[i]);
        }
        thumbnailQueue = retainedQueue;
        if (thumbnailWorker.running && thumbnailJob && thumbnailJob.target !== requiredTarget) {
            thumbnailStopRequested = true;
            thumbnailWorker.running = false;
        }
    }
    function indexThumbnailCache() {
        var indexed = {};
        for (var i = 0; i < thumbnailCacheModel.count; ++i) {
            var path = String(thumbnailCacheModel.get(i, "filePath") || "");
            if (path.startsWith("file://"))
                path = decodeURIComponent(path.substring(7));

            if (path)
                indexed[path] = true;
        }
        knownThumbnails = indexed;
    }
    function isLivePath(path) {
        var cleanPath = String(path || "").split("?")[0].toLowerCase();
        return cleanPath.endsWith(".gif") || cleanPath.endsWith(".mp4") || cleanPath.endsWith(".webm") || cleanPath.endsWith(".mkv") || cleanPath.endsWith(".mov") || cleanPath.endsWith(".m4v");
    }
    function modifiedKey(modified) {
        if (modified === undefined || modified === null)
            return "0";

        if (modified.valueOf !== undefined)
            return String(modified.valueOf());

        return String(modified);
    }
    function play(path, generation) {
        var requestedPath = String(path || "");
        if (!requestedPath)
            return;

        desiredPath = requestedPath;
        desiredGeneration = Number(generation || 0);
        errorMessage = "";
        playbackReadyState = false;
        readyScreens = {};
        transitionScreens = {};
        requestSerial += 1;
        checkAvailability();
        if (WallpaperPlaybackPolicy.shouldPause)
            readyTimeout.stop();
        else
            readyTimeout.restart();
    }
    function processNextThumbnail() {
        if (thumbnailWorker.running || thumbnailJob || thumbnailQueue.length === 0)
            return;

        thumbnailJob = thumbnailQueue[0];
        thumbnailQueue = thumbnailQueue.slice(1);
        thumbnailWorker.command = ["sh", "-c", "mkdir -p \"$3\"; if [ ! -s \"$2\" ]; then rm -f \"$2.tmp.jpeg\"; if ! nice -n 10 ffmpeg -hide_banner -loglevel error -y -ss 0.5 -i \"$1\" -frames:v 1 -vf \"scale='min($4,iw)':'min($4,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2:flags=fast_bilinear,format=yuvj420p\" -q:v 3 -update 1 \"$2.tmp.jpeg\" || [ ! -s \"$2.tmp.jpeg\" ]; then rm -f \"$2.tmp.jpeg\"; nice -n 10 ffmpeg -hide_banner -loglevel error -y -i \"$1\" -frames:v 1 -vf \"scale='min($4,iw)':'min($4,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2:flags=fast_bilinear,format=yuvj420p\" -q:v 3 -update 1 \"$2.tmp.jpeg\"; fi && mv \"$2.tmp.jpeg\" \"$2\"; fi", "live-wallpaper-thumbnail", thumbnailJob.path, thumbnailJob.target, cacheDir, String(thumbnailJob.width)];
        thumbnailWorker.running = true;
    }
    function registerRenderer(screenName) {
        var name = String(screenName || "");
        var next = Object.assign({}, registeredScreens);
        next[name] = true;
        registeredScreens = next;
        updateFrameReadiness();
    }
    function reportFailure(path, message, generation) {
        var failureGeneration = Number(generation || 0);
        if (!path || path !== desiredPath || failureGeneration !== desiredGeneration)
            return;

        errorMessage = message;
        readyTimeout.stop();
        playbackFailed(path, message, failureGeneration);
    }
    function reportFrameReady(screenName, path, generation, serial) {
        if (String(path || "") !== desiredPath || Number(generation || 0) !== desiredGeneration || Number(serial || 0) !== requestSerial)
            return;

        var name = String(screenName || "");
        var next = Object.assign({}, readyScreens);
        next[name] = true;
        readyScreens = next;
        updateFrameReadiness();
    }
    function reportPlaybackError(screenName, path, generation, serial, message) {
        if (String(path || "") !== desiredPath || Number(generation || 0) !== desiredGeneration || Number(serial || 0) !== requestSerial)
            return;

        reportFailure(path, String(message || "Could not decode the live wallpaper"), generation);
    }
    function reportTransitionFinished(screenName, path, generation, serial) {
        if (String(path || "") !== desiredPath || Number(generation || 0) !== desiredGeneration || Number(serial || 0) !== requestSerial)
            return;

        var name = String(screenName || "");
        var next = Object.assign({}, transitionScreens);
        next[name] = true;
        transitionScreens = next;
        updateTransitionCompletion();
    }
    function requestCover(path, modified, priority, requestToken) {
        return requestImage(path, modified, priority, requestToken, coverPath(path, modified), coverWidth);
    }
    function requestImage(path, modified, priority, requestToken, target, width) {
        if (!isLivePath(path))
            return "";

        if (knownThumbnails[target] === true) {
            Qt.callLater(() => {
                root.thumbnailReady(path, target, Number(requestToken || 0));
            });
            return target;
        }
        if (thumbnailJob && thumbnailJob.path === path && thumbnailJob.target === target) {
            thumbnailJob.requestToken = Number(requestToken || 0);
            return target;
        }
        for (var i = 0; i < thumbnailQueue.length; ++i) {
            if (thumbnailQueue[i].path === path && thumbnailQueue[i].target === target) {
                if (priority && i > 0) {
                    var queuedJob = thumbnailQueue[i];
                    queuedJob.requestToken = Number(requestToken || 0);
                    thumbnailQueue = [queuedJob].concat(thumbnailQueue.slice(0, i), thumbnailQueue.slice(i + 1));
                } else {
                    thumbnailQueue[i].requestToken = Number(requestToken || 0);
                }
                return target;
            }
        }
        var job = {
            "path": path,
            "requestToken": Number(requestToken || 0),
            "target": target,
            "width": Number(width)
        };
        thumbnailQueue = priority ? [job].concat(thumbnailQueue) : thumbnailQueue.concat([job]);
        processNextThumbnail();
        return target;
    }
    function requestThumbnail(path, modified, priority, requestToken) {
        return requestImage(path, modified, priority, requestToken, thumbnailPath(path, modified), thumbnailWidth);
    }
    function shutdownForReload() {
        browsing = false;
        thumbnailQueue = [];
        desiredPath = "";
        activePath = "";
        readyTimeout.stop();
        if (thumbnailWorker.running)
            thumbnailStopRequested = true;

        if (thumbnailWorker.running)
            thumbnailWorker.running = false;
    }
    function stop() {
        desiredPath = "";
        desiredGeneration = 0;
        activePath = "";
        errorMessage = "";
        playbackReadyState = false;
        readyScreens = {};
        transitionScreens = {};
        readyTimeout.stop();
        requestSerial += 1;
    }
    function thumbnailKnown(path, modified) {
        return knownThumbnails[thumbnailPath(path, modified)] === true;
    }
    function thumbnailPath(path, modified) {
        return cacheDir + "/" + WallpaperService.stableHash(String(path) + "|" + modifiedKey(modified)) + ".jpg";
    }
    function unregisterRenderer(screenName) {
        var name = String(screenName || "");
        var nextRegistered = Object.assign({}, registeredScreens);
        var nextReady = Object.assign({}, readyScreens);
        var nextTransition = Object.assign({}, transitionScreens);
        delete nextRegistered[name];
        delete nextReady[name];
        delete nextTransition[name];
        registeredScreens = nextRegistered;
        readyScreens = nextReady;
        transitionScreens = nextTransition;
        updateFrameReadiness();
        updateTransitionCompletion();
    }
    function updateFrameReadiness() {
        if (!desiredPath || playbackReadyState || !allScreensReported(readyScreens, true))
            return;

        playbackReadyState = true;
        readyTimeout.stop();
        playbackReady(desiredPath, "", desiredGeneration);
    }
    function updateTransitionCompletion() {
        if (!desiredPath || !playbackReadyState || !allScreensReported(transitionScreens, true))
            return;

        activePath = desiredPath;
    }

    Component.onDestruction: shutdownForReload()
}
