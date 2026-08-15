pragma Singleton
import "../../"
import ".."
import Qt.labs.folderlistmodel
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property bool active: player.running
    property string activePath: ""
    property bool availabilityKnown: false
    property Process availabilityQuery: Process {
        command: ["sh", "-c", "command -v mpvpaper >/dev/null 2>&1"]

        onExited: (exitCode, exitStatus) => {
            if (root.availabilityRestartPending) {
                root.availabilityRestart.restart();
                return;
            }
            root.available = exitCode === 0;
            root.availabilityKnown = true;
            if (root.available)
                root.requestStart();
            else if (root.desiredPath)
                root.reportFailure(root.desiredPath, "Install mpvpaper to play live wallpapers", root.desiredGeneration);
        }
    }
    property Timer availabilityRestart: Timer {
        interval: 60
        repeat: false

        onTriggered: {
            if (availabilityQuery.running) {
                availabilityRestart.restart();
                return;
            }
            root.availabilityRestartPending = false;
            availabilityQuery.running = true;
        }
    }
    property bool availabilityRestartPending: false
    property bool available: false
    property bool browsing: false
    readonly property string cacheDir: Config.cacheRoot + "/live-wallpapers"
    property Timer cleanupRestart: Timer {
        interval: 60
        repeat: false

        onTriggered: {
            if (ownedProcessStopper.running) {
                cleanupRestart.restart();
                return;
            }
            root.cleanupRestartPending = false;
            ownedProcessStopper.running = true;
        }
    }
    property bool cleanupRestartPending: false
    property int desiredGeneration: 0
    property string desiredPath: ""
    property string errorMessage: ""
    readonly property string ipcPath: cacheDir + "/mpvpaper.sock"
    readonly property string ipcScript: Config.quickshellDir + "/scripts/mpv_wallpaper_ipc.py"
    property var knownThumbnails: ({})
    property Process ownedProcessStopper: Process {
        onExited: (exitCode, exitStatus) => {
            if (root.cleanupRestartPending) {
                root.cleanupRestart.restart();
                return;
            }
            if (!root.startAfterCleanup)
                return;

            root.startAfterCleanup = false;
            root.launchDesired();
        }
    }
    property FileView pidFile: FileView {
        blockLoading: true
        path: root.pidPath
        printErrors: false
        watchChanges: false
    }
    readonly property string pidPath: cacheDir + "/mpvpaper.pid"
    property bool playbackReadyState: false
    property Process player: Process {
        onExited: (exitCode, exitStatus) => {
            var exitedPath = root.startedPath;
            root.activePath = "";
            root.playbackReadyState = false;
            root.readyTimeout.stop();
            if (root.readyProbe.running)
                root.readyProbe.running = false;
            if (root.desiredPath && root.desiredPath !== exitedPath && !root.startAfterCleanup)
                Qt.callLater(root.requestStart);
            else if (root.desiredPath && root.desiredPath === exitedPath && !root.startAfterCleanup)
                root.reportFailure(exitedPath, "Live wallpaper stopped unexpectedly", root.startedGeneration);
        }
        onStarted: {
            root.activePath = root.startedPath;
            root.errorMessage = "";
            root.syncPolicy();
            if (!WallpaperPlaybackPolicy.shouldPause)
                root.startReadyProbe();
        }
    }
    property Connections policyConnections: Connections {
        function onShouldPauseChanged() {
            root.syncPolicy();
            if (WallpaperPlaybackPolicy.shouldPause) {
                if (!root.playbackReadyState) {
                    root.readyTimeout.stop();
                    if (root.readyProbe.running)
                        root.readyProbe.running = false;
                }
            } else if (root.player.running && !root.playbackReadyState) {
                root.startReadyProbe();
            }
        }
        function onTargetFpsChanged() {
            root.syncPolicy();
        }

        target: WallpaperPlaybackPolicy
    }
    property Process policyController: Process {
        onExited: (exitCode, exitStatus) => {
            if (root.policySyncPending) {
                root.policySyncPending = false;
                root.syncPolicy();
            } else if (exitCode !== 0 && root.player.running) {
                root.policyRetry.restart();
            }
        }
    }
    property Timer policyRetry: Timer {
        interval: 120
        repeat: false

        onTriggered: root.syncPolicy()
    }
    property bool policySyncPending: false
    property string readyFramePath: ""
    property Process readyProbe: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && root.player.running && root.startedPath === root.desiredPath)
                root.markReady(root.startedPath, root.readyFramePath);
        }
    }
    property Timer readyTimeout: Timer {
        interval: 5000
        repeat: false

        onTriggered: {
            if (!root.player.running || root.startedPath !== root.desiredPath)
                return;
            if (WallpaperPlaybackPolicy.shouldPause)
                return;
            root.reportFailure(root.startedPath, "Live wallpaper did not become ready", root.startedGeneration);
        }
    }
    property bool startAfterCleanup: false
    property int startedGeneration: 0
    property string startedPath: ""
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

    signal playbackFailed(string sourcePath, string message, int generation)
    signal playbackReady(string sourcePath, string framePath, int generation)
    signal thumbnailReady(string sourcePath, string thumbnailPath, int requestToken)

    function beginBrowsing() {
        browsing = true;
    }
    function checkAvailability() {
        availabilityKnown = false;
        availabilityRestartPending = true;
        if (availabilityQuery.running)
            availabilityQuery.running = false;

        availabilityRestart.restart();
    }
    function endBrowsing() {
        browsing = false;
        var requiredTarget = "";
        if (WallpaperService.isTransitionPending && WallpaperService.currentMode === "video" && !WallpaperService.isEngineVideo)
            requiredTarget = thumbnailPath(WallpaperService.currentWallpaper, WallpaperService.selectedModified);
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
        if (thumbnailJob && thumbnailJob.target)
            indexed[thumbnailJob.target] = true;
        knownThumbnails = indexed;
    }
    function isLivePath(path) {
        var cleanPath = String(path || "").split("?")[0].toLowerCase();
        return cleanPath.endsWith(".gif") || cleanPath.endsWith(".mp4") || cleanPath.endsWith(".webm") || cleanPath.endsWith(".mkv") || cleanPath.endsWith(".mov") || cleanPath.endsWith(".m4v");
    }
    function launchDesired() {
        if (!available || !desiredPath || player.running)
            return;

        startedPath = desiredPath;
        startedGeneration = desiredGeneration;
        playbackReadyState = false;
        var currentFrame = String(Config.wallpaper || "");
        var nextSlot = currentFrame === cacheDir + "/render-frame-1.jpg" ? 0 : 1;
        readyFramePath = cacheDir + "/render-frame-" + String(nextSlot) + ".jpg";
        var options = "no-config no-audio loop-file=inf hwdec=auto-safe panscan=1.0 terminal=no screenshot-jpeg-quality=95 input-ipc-server=" + ipcPath + " vf=fps=" + WallpaperPlaybackPolicy.targetFps;
        player.command = ["sh", "-c", "mkdir -p \"$1\"; rm -f \"$2\" \"$4\"; printf '%s' \"$$\" > \"$3\"; exec mpvpaper -o \"$5\" ALL \"$6\"", "live-wallpaper-player", cacheDir, ipcPath, pidPath, readyFramePath, options, startedPath];
        player.running = true;
        pidFile.reload();
    }
    function markReady(path, framePath) {
        if (playbackReadyState || !path || path !== startedPath)
            return;

        playbackReadyState = true;
        readyTimeout.stop();
        playbackReady(path, framePath || "", startedGeneration);
        syncPolicy();
    }
    function modifiedKey(modified) {
        if (modified === undefined || modified === null)
            return "0";

        if (modified.valueOf !== undefined)
            return String(modified.valueOf());

        return String(modified);
    }
    function play(path, generation) {
        if (!path)
            return;

        desiredPath = path;
        desiredGeneration = Number(generation || 0);
        errorMessage = "";
        if (!availabilityKnown || !available) {
            availabilityKnown = false;
            checkAvailability();
            return;
        }
        if (player.running) {
            if (startedPath === desiredPath) {
                startedGeneration = desiredGeneration;
                if (playbackReadyState) {
                    var runningPath = startedPath;
                    var runningFrame = readyFramePath;
                    var runningGeneration = desiredGeneration;
                    Qt.callLater(() => {
                        if (root.player.running && root.startedPath === runningPath)
                            root.playbackReady(runningPath, runningFrame, runningGeneration);
                    });
                }
                return;
            }

            player.running = false;
        }
        requestStart();
    }
    function processNextThumbnail() {
        if (thumbnailWorker.running || thumbnailJob || thumbnailQueue.length === 0)
            return;

        thumbnailJob = thumbnailQueue[0];
        thumbnailQueue = thumbnailQueue.slice(1);
        thumbnailWorker.command = ["sh", "-c", "mkdir -p \"$3\"; if [ ! -s \"$2\" ]; then ffmpeg -hide_banner -loglevel error -y -ss 0.5 -i \"$1\" -frames:v 1 -vf 'scale=960:-2:force_original_aspect_ratio=decrease' \"$2.tmp.jpg\" && mv \"$2.tmp.jpg\" \"$2\"; fi", "live-wallpaper-thumbnail", thumbnailJob.path, thumbnailJob.target, cacheDir];
        thumbnailWorker.running = true;
    }
    function reportFailure(path, message, generation) {
        var failureGeneration = Number(generation || 0);
        if (!path || path !== desiredPath || failureGeneration !== desiredGeneration)
            return;
        errorMessage = message;
        playbackFailed(path, message, failureGeneration);
    }
    function requestStart() {
        if (!available || !desiredPath || player.running)
            return;

        startAfterCleanup = true;
        stopOwnedProcess();
    }
    function requestThumbnail(path, modified, priority, requestToken) {
        if (!isLivePath(path))
            return "";

        var target = thumbnailPath(path, modified);
        if (knownThumbnails[target] === true) {
            Qt.callLater(() => {
                return root.thumbnailReady(path, target, Number(requestToken || 0));
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
                } else
                    thumbnailQueue[i].requestToken = Number(requestToken || 0);
                return target;
            }
        }
        var job = {
            "path": path,
            "requestToken": Number(requestToken || 0),
            "target": target
        };
        thumbnailQueue = priority ? [job].concat(thumbnailQueue) : thumbnailQueue.concat([job]);
        processNextThumbnail();
        return target;
    }
    function shutdownForReload() {
        pidFile.reload();
        var expectedPid = pidFile.loaded ? pidFile.text().trim() : "";
        browsing = false;
        thumbnailQueue = [];
        desiredPath = "";
        startAfterCleanup = false;
        if (thumbnailWorker.running)
            thumbnailStopRequested = true;
        if (thumbnailWorker.running)
            thumbnailWorker.running = false;
        if (readyProbe.running)
            readyProbe.running = false;
        if (player.running)
            player.running = false;
        if (expectedPid !== "")
            Quickshell.execDetached(["sh", "-c", "pid=\"$3\"; if [ -r \"/proc/$pid/comm\" ] && [ \"$(cat \"/proc/$pid/comm\")\" = mpvpaper ]; then cmd=$(tr '\\0' ' ' < \"/proc/$pid/cmdline\"); case \"$cmd\" in *\"input-ipc-server=$2\"*) kill -CONT \"$pid\" 2>/dev/null || true; kill \"$pid\" 2>/dev/null || true ;; esac; fi; current=$(cat \"$1\" 2>/dev/null || true); if [ \"$current\" = \"$pid\" ]; then rm -f \"$1\" \"$2\"; fi", "live-wallpaper-reload-stop", pidPath, ipcPath, expectedPid]);
    }
    function startReadyProbe() {
        if (!player.running)
            return;

        if (readyProbe.running)
            readyProbe.running = false;
        readyProbe.command = ["python3", ipcScript, "wait-ready", ipcPath, "2.5", readyFramePath];
        readyProbe.running = true;
        readyTimeout.restart();
    }
    function stop() {
        desiredPath = "";
        activePath = "";
        errorMessage = "";
        startAfterCleanup = false;
        playbackReadyState = false;
        readyFramePath = "";
        policyRetry.stop();
        readyTimeout.stop();
        if (readyProbe.running)
            readyProbe.running = false;
        if (player.running)
            player.running = false;

        stopOwnedProcess();
    }
    function stopOwnedProcess() {
        ownedProcessStopper.command = ["sh", "-c", "pid=$(cat \"$1\" 2>/dev/null || true); if [ -n \"$pid\" ] && [ -r \"/proc/$pid/comm\" ] && [ \"$(cat \"/proc/$pid/comm\")\" = mpvpaper ]; then cmd=$(tr '\\0' ' ' < \"/proc/$pid/cmdline\"); case \"$cmd\" in *\"input-ipc-server=$2\"*) kill -CONT \"$pid\" 2>/dev/null || true; kill \"$pid\" 2>/dev/null || true ;; esac; fi; rm -f \"$1\" \"$2\"", "live-wallpaper-stop", pidPath, ipcPath];
        cleanupRestartPending = true;
        if (ownedProcessStopper.running)
            ownedProcessStopper.running = false;

        cleanupRestart.restart();
    }
    function syncPolicy() {
        if (!player.running)
            return;
        if (policyController.running) {
            policySyncPending = true;
            return;
        }

        policyController.command = ["python3", ipcScript, "configure", ipcPath, WallpaperPlaybackPolicy.shouldPause ? "true" : "false", String(WallpaperPlaybackPolicy.targetFps)];
        policyController.running = true;
    }
    function thumbnailKnown(path, modified) {
        return knownThumbnails[thumbnailPath(path, modified)] === true;
    }
    function thumbnailPath(path, modified) {
        return cacheDir + "/" + WallpaperService.stableHash(String(path) + "|" + modifiedKey(modified)) + ".jpg";
    }

    Component.onDestruction: shutdownForReload()
}
