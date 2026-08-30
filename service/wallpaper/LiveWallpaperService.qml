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
            if (!root.desiredPath)
                return;

            if (root.renderer.running && !root.rendererStopExpected)
                root.writeRendererRequest();

            if (WallpaperPlaybackPolicy.shouldPause)
                root.readyTimeout.stop();
            else if (!root.playbackReadyState)
                root.readyTimeout.restart();
        }

        target: WallpaperPlaybackPolicy
    }
    property Timer readyTimeout: Timer {
        interval: 12000
        repeat: false

        onTriggered: {
            if (!root.desiredPath || root.playbackReadyState || WallpaperPlaybackPolicy.shouldPause)
                return;

            root.reportFailure(root.desiredPath, "Live wallpaper did not become ready", root.desiredGeneration);
        }
    }
    property Process renderer: Process {
        command: ["env", "QS_NATIVE_VIDEO_REQUEST_FILE=" + root.rendererRequestPath, "QS_NATIVE_VIDEO_STATUS_FILE=" + root.rendererStatusPath, "quickshell", "--no-color", "-p", root.rendererEntryPath]

        stderr: StdioCollector {
            id: rendererError
        }

        onExited: exitCode => {
            var expected = root.rendererStopExpected;
            var restart = root.startAfterExit && root.desiredPath !== "";
            root.rendererLaunchPending = false;
            root.rendererStopTimeout.stop();
            root.rendererStopExpected = false;
            root.startAfterExit = false;
            root.playbackReadyState = false;
            root.readyTimeout.stop();
            root.activePath = "";
            root.rendererPidFile.setText("");
            if (restart)
                Qt.callLater(root.launchRendererNow);
            else if (root.desiredPath && !expected)
                root.reportFailure(root.desiredPath, root.rendererFailureMessage(exitCode), root.desiredGeneration);
        }
        onStarted: {
            root.rendererLaunchPending = false;
            root.rendererPidFile.setText(String(processId) + "\n");
            if (!WallpaperPlaybackPolicy.shouldPause && !root.playbackReadyState)
                root.readyTimeout.restart();
        }
    }
    property Process rendererCleanup: Process {
        onExited: () => {
            root.rendererPrepared = true;
            var start = root.startAfterCleanup && root.desiredPath !== "";
            root.startAfterCleanup = false;
            if (!start)
                return;

            Qt.callLater(root.launchRendererNow);
        }
    }
    readonly property string rendererEntryPath: Config.quickshellDir + "/widget/desktop/nativevideo/NativeVideoRenderer.qml"
    property bool rendererLaunchPending: false
    property FileView rendererPidFile: FileView {
        atomicWrites: true
        blockLoading: true
        blockWrites: true
        path: root.rendererPidPath
        printErrors: false
    }
    readonly property string rendererPidPath: Config.cacheRoot + "/native-video-renderer.pid"
    property bool rendererPrepared: false
    property FileView rendererRequestFile: FileView {
        atomicWrites: true
        blockWrites: true
        path: root.rendererRequestPath
        printErrors: false
    }
    readonly property string rendererRequestPath: Config.cacheRoot + "/native-video-renderer-request.json"
    readonly property string rendererSessionToken: String(Date.now()) + "-" + String(Math.floor(Math.random() * 1e+09))
    property FileView rendererStatusFile: FileView {
        atomicWrites: true
        blockLoading: true
        blockWrites: true
        path: root.rendererStatusPath
        printErrors: false
        watchChanges: true

        onFileChanged: reload()
        onLoaded: root.handleRendererStatus()
    }
    readonly property string rendererStatusPath: Config.cacheRoot + "/native-video-renderer-status.json"
    property bool rendererStopExpected: false
    property Timer rendererStopTimeout: Timer {
        interval: 1500
        repeat: false

        onTriggered: {
            if (root.renderer.running && root.rendererStopExpected)
                root.renderer.signal(9);
        }
    }
    property int requestSerial: 0
    property bool startAfterCleanup: false
    property bool startAfterExit: false
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
        onExited: exitCode => {
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
    property Connections transitionConnections: Connections {
        function onIsTransitionPendingChanged() {
            if (!WallpaperService.isTransitionPending)
                root.maybeCompleteTransition();
        }

        target: WallpaperService
    }

    signal playbackFailed(string sourcePath, string message, int generation)
    signal playbackReady(string sourcePath, string framePath, int generation)
    signal thumbnailReady(string sourcePath, string thumbnailPath, int requestToken)

    function beginBrowsing() {
        browsing = true;
    }
    function checkAvailability() {
        available = true;
        availabilityKnown = true;
    }
    function cleanupRendererCommand() {
        return ["sh", "-c", "pid=$(cat \"$1\" 2>/dev/null || true); if [ -n \"$pid\" ] && [ -e \"/proc/$pid/exe\" ]; then exe=$(readlink \"/proc/$pid/exe\" 2>/dev/null || true); cmd=$(tr '\\0' ' ' < \"/proc/$pid/cmdline\" 2>/dev/null || true); case \"$exe:$cmd\" in */quickshell:*\"$2\"*) kill -CONT \"$pid\" 2>/dev/null || true; kill \"$pid\" 2>/dev/null || true; i=0; while [ -e \"/proc/$pid/exe\" ] && [ \"$i\" -lt 50 ]; do sleep 0.02; i=$((i + 1)); done; [ -e \"/proc/$pid/exe\" ] && kill -KILL \"$pid\" 2>/dev/null || true ;; esac; fi; rm -f \"$1\"", "native-video-renderer-cleanup", rendererPidPath, rendererEntryPath];
    }
    function coverKnown(path, modified) {
        return knownThumbnails[coverPath(path, modified)] === true;
    }
    function coverPath(path, modified) {
        return cacheDir + "/" + WallpaperService.stableHash("live-video-cover-v1|" + String(coverWidth) + "|" + String(path) + "|" + modifiedKey(modified)) + ".jpg";
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
    function handleRendererStatus() {
        if (!renderer.running || rendererStopExpected)
            return;

        var status;
        try {
            status = JSON.parse(rendererStatusFile.text().trim());
        } catch (error) {
            return;
        }
        if (String(status.session || "") !== rendererSessionToken || String(status.path || "") !== desiredPath || Number(status.generation || 0) !== desiredGeneration || Number(status.serial || 0) !== requestSerial)
            return;

        var state = String(status.state || "");
        if (state === "ready") {
            if (!playbackReadyState) {
                playbackReadyState = true;
                readyTimeout.stop();
                playbackReady(desiredPath, "", desiredGeneration);
            }
            maybeCompleteTransition();
        } else if (state === "error") {
            reportFailure(desiredPath, String(status.message || "Could not decode the live wallpaper"), desiredGeneration);
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
    function launchRendererNow() {
        if (!desiredPath || renderer.running || rendererStopExpected || rendererCleanup.running)
            return;

        startAfterCleanup = false;
        startAfterExit = false;
        rendererStopExpected = false;
        rendererStatusFile.setText("{}\n");
        writeRendererRequest();
        rendererLaunchPending = true;
        renderer.running = true;
    }
    function maybeCompleteTransition() {
        if (!desiredPath || !playbackReadyState || WallpaperService.isTransitionPending)
            return;

        if (WallpaperService.currentMode !== "video" || WallpaperService.isEngineVideo || WallpaperService.selectedRendererPath !== desiredPath)
            return;

        activePath = desiredPath;
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
        requestSerial += 1;
        checkAvailability();
        if (WallpaperPlaybackPolicy.shouldPause)
            readyTimeout.stop();
        else
            readyTimeout.restart();
        requestRendererStart();
    }
    function processNextThumbnail() {
        if (thumbnailWorker.running || thumbnailJob || thumbnailQueue.length === 0)
            return;

        thumbnailJob = thumbnailQueue[0];
        thumbnailQueue = thumbnailQueue.slice(1);
        thumbnailWorker.command = ["sh", "-c", "mkdir -p \"$3\"; if [ ! -s \"$2\" ]; then rm -f \"$2.tmp.jpeg\"; if ! nice -n 10 ffmpeg -hide_banner -loglevel error -y -ss 0.5 -i \"$1\" -frames:v 1 -vf \"scale='min($4,iw)':'min($4,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2:flags=fast_bilinear,format=yuvj420p\" -q:v 3 -update 1 \"$2.tmp.jpeg\" || [ ! -s \"$2.tmp.jpeg\" ]; then rm -f \"$2.tmp.jpeg\"; nice -n 10 ffmpeg -hide_banner -loglevel error -y -i \"$1\" -frames:v 1 -vf \"scale='min($4,iw)':'min($4,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2:flags=fast_bilinear,format=yuvj420p\" -q:v 3 -update 1 \"$2.tmp.jpeg\"; fi && mv \"$2.tmp.jpeg\" \"$2\"; fi", "live-wallpaper-thumbnail", thumbnailJob.path, thumbnailJob.target, cacheDir, String(thumbnailJob.width)];
        thumbnailWorker.running = true;
    }
    function rendererFailureMessage(exitCode) {
        var diagnostic = String(rendererError.text || "").trim();
        if (diagnostic !== "") {
            var lines = diagnostic.split(/\r?\n/).filter(line => {
                return line.trim() !== "";
            });
            if (lines.length > 0) {
                var detail = lines[lines.length - 1].trim();
                if (detail.length > 180)
                    detail = detail.substring(0, 177) + "…";

                return "Native video renderer failed: " + detail;
            }
        }
        return "Native video renderer exited unexpectedly (exit code " + exitCode + ")";
    }
    function reportFailure(path, message, generation) {
        var failureGeneration = Number(generation || 0);
        if (!path || path !== desiredPath || failureGeneration !== desiredGeneration)
            return;

        errorMessage = message;
        readyTimeout.stop();
        playbackFailed(path, message, failureGeneration);
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
    function requestRendererStart() {
        if (!desiredPath)
            return;

        if (rendererStopExpected) {
            startAfterExit = true;
            return;
        }
        if (renderer.running && !rendererStopExpected) {
            writeRendererRequest();
            return;
        }
        if (rendererLaunchPending) {
            writeRendererRequest();
            return;
        }
        if (rendererPrepared) {
            launchRendererNow();
            return;
        }
        startAfterCleanup = true;
        if (!rendererCleanup.running) {
            rendererCleanup.command = cleanupRendererCommand();
            rendererCleanup.running = true;
        }
    }
    function requestThumbnail(path, modified, priority, requestToken) {
        return requestImage(path, modified, priority, requestToken, thumbnailPath(path, modified), thumbnailWidth);
    }
    function shutdownForReload() {
        rendererPidFile.reload();
        var expectedPid = rendererPidFile.loaded ? rendererPidFile.text().trim() : "";
        browsing = false;
        thumbnailQueue = [];
        desiredPath = "";
        desiredGeneration = 0;
        activePath = "";
        playbackReadyState = false;
        readyTimeout.stop();
        requestSerial += 1;
        stopRenderer();
        if (thumbnailWorker.running)
            thumbnailStopRequested = true;

        if (thumbnailWorker.running)
            thumbnailWorker.running = false;

        if (expectedPid !== "")
            Quickshell.execDetached(["sh", "-c", "pid=\"$3\"; if [ -e \"/proc/$pid/exe\" ]; then exe=$(readlink \"/proc/$pid/exe\" 2>/dev/null || true); cmd=$(tr '\\0' ' ' < \"/proc/$pid/cmdline\" 2>/dev/null || true); case \"$exe:$cmd\" in */quickshell:*\"$2\"*) kill -CONT \"$pid\" 2>/dev/null || true; kill \"$pid\" 2>/dev/null || true ;; esac; fi; current=$(cat \"$1\" 2>/dev/null || true); [ \"$current\" = \"$pid\" ] && rm -f \"$1\"", "native-video-renderer-reload-stop", rendererPidPath, rendererEntryPath, expectedPid]);
    }
    function stop() {
        desiredPath = "";
        desiredGeneration = 0;
        activePath = "";
        errorMessage = "";
        playbackReadyState = false;
        readyTimeout.stop();
        requestSerial += 1;
        stopRenderer();
    }
    function stopRenderer() {
        startAfterCleanup = false;
        startAfterExit = false;
        rendererLaunchPending = false;
        if (renderer.running) {
            rendererStopExpected = true;
            renderer.running = false;
            rendererStopTimeout.restart();
        } else {
            rendererStopExpected = false;
            rendererStopTimeout.stop();
        }
    }
    function thumbnailKnown(path, modified) {
        return knownThumbnails[thumbnailPath(path, modified)] === true;
    }
    function thumbnailPath(path, modified) {
        return cacheDir + "/" + WallpaperService.stableHash(String(path) + "|" + modifiedKey(modified)) + ".jpg";
    }
    function writeRendererRequest() {
        if (!desiredPath)
            return;

        rendererRequestFile.setText(JSON.stringify({
            "generation": desiredGeneration,
            "path": desiredPath,
            "paused": WallpaperPlaybackPolicy.shouldPause,
            "serial": requestSerial,
            "session": rendererSessionToken
        }) + "\n");
    }

    Component.onDestruction: shutdownForReload()
}
