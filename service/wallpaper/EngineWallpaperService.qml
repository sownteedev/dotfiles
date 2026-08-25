pragma Singleton
import "../../"
import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel

QtObject {
    id: root

    readonly property bool active: player.running
    property string activePath: ""
    property bool availabilityKnown: false
    property Process availabilityQuery: Process {
        property bool launchPending: false
        property string queriedAssetsDir: ""

        command: ["sh", "-c", "command -v linux-wallpaperengine >/dev/null 2>&1 && test -d \"$1\"", "engine-wallpaper-availability", queriedAssetsDir]

        onExited: (exitCode, exitStatus) => {
            if (queriedAssetsDir !== Config.wallpaperEngineAssetsDir) {
                root.checkAvailability();
                return;
            }
            root.available = exitCode === 0;
            root.availabilityKnown = true;
            if (root.available && root.desiredPath)
                root.requestStart();
            else if (!root.available && root.desiredPath)
                root.reportFailure(root.desiredPath, "Install linux-wallpaperengine and Wallpaper Engine assets", root.desiredGeneration);
        }
        onRunningChanged: {
            if (!running && launchPending) {
                launchPending = false;
                root.available = false;
                root.availabilityKnown = true;
                if (root.desiredPath)
                    root.reportFailure(root.desiredPath, "Could not start the Wallpaper Engine availability check", root.desiredGeneration);
            }
        }
        onStarted: launchPending = false
    }
    property bool available: false
    property bool browsing: false
    readonly property string cacheDir: Config.cacheRoot + "/wallpaper-engine"
    property Timer cleanupRestart: Timer {
        interval: 60
        repeat: false

        onTriggered: {
            if (ownedProcessStopper.running) {
                restart();
                return;
            }
            root.cleanupRestartPending = false;
            ownedProcessStopper.running = true;
        }
    }
    property bool cleanupRestartPending: false
    property Connections configConnections: Connections {
        function onWallpaperEngineAssetsDirPathChanged() {
            root.available = false;
            root.availabilityKnown = false;
            root.checkAvailability();
        }

        target: Config
    }
    property int desiredGeneration: 0
    property string desiredPath: ""
    property string errorMessage: ""
    property var knownPreviewThumbnails: ({})
    property string launchedScreenSignature: ""
    property FolderListModel legacyWorkshopWatcher: FolderListModel {
        folder: root.browsing ? "file://" + Config.legacyWallpaperEngineWorkshopDir : ""
        showDirs: true
        showFiles: false

        onCountChanged: {
            if (root.browsing)
                root.scan();
        }
    }
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
    readonly property string pidPath: cacheDir + "/linux-wallpaperengine.pid"
    property bool playbackReadyState: false
    property Process player: Process {
        stderr: StdioCollector {
            id: playerError
        }
        stdout: StdioCollector {
            id: playerOutput
        }

        onExited: (exitCode, exitStatus) => {
            var exitedPath = root.startedPath;
            root.activePath = "";
            root.playbackReadyState = false;
            root.validatedFramePath = "";
            root.readyTimer.stop();
            if (root.readyProbe.running)
                root.readyProbe.running = false;
            if (root.policyRestarting && root.desiredPath) {
                if (!root.rendererRestartLaunching) {
                    root.rendererRestartLaunching = true;
                    Qt.callLater(root.requestStart);
                } else {
                    root.policyRestarting = false;
                    root.rendererRestartLaunching = false;
                    root.reportFailure(exitedPath, "Wallpaper Engine restart failed", root.startedGeneration);
                }
                return;
            }
            if (root.desiredPath && root.desiredPath !== exitedPath && !root.startAfterCleanup)
                Qt.callLater(root.requestStart);
            else if (root.desiredPath && root.desiredPath === exitedPath && !root.startAfterCleanup)
                root.reportFailure(exitedPath, root.rendererFailureMessage(exitCode, exitStatus), root.startedGeneration);
        }
        onStarted: {
            root.activePath = root.startedPath;
            root.errorMessage = "";
            root.syncPolicyPause();
            if (!WallpaperPlaybackPolicy.shouldPause) {
                root.readyTimer.restart();
                root.startReadyProbe();
            }
        }
    }
    property Connections policyConnections: Connections {
        function onShouldPauseChanged() {
            root.syncPolicyPause();
            if (WallpaperPlaybackPolicy.shouldPause) {
                if (!root.playbackReadyState) {
                    root.readyTimer.stop();
                    if (root.readyProbe.running)
                        root.readyProbe.running = false;
                }
                return;
            }
            if (root.player.running && !root.playbackReadyState) {
                root.readyTimer.restart();
                root.startReadyProbe();
            }
            if (root.powerRestartPending || root.screenRestartPending)
                root.rendererRestartDebounce.restart();
        }
        function onTargetFpsChanged() {
            if (!root.player.running)
                return;
            root.powerRestartPending = true;
            if (!WallpaperPlaybackPolicy.shouldPause)
                root.rendererRestartDebounce.restart();
        }

        target: WallpaperPlaybackPolicy
    }
    property Process policyPauseController: Process {
        onExited: (exitCode, exitStatus) => {
            if (root.policyPausePending) {
                root.policyPausePending = false;
                root.syncPolicyPause();
            } else if (exitCode !== 0 && root.player.running) {
                root.policyPauseRetry.restart();
            }
        }
    }
    property bool policyPausePending: false
    property Timer policyPauseRetry: Timer {
        interval: 120
        repeat: false

        onTriggered: root.syncPolicyPause()
    }
    property Timer policyRestartFinish: Timer {
        interval: 850
        repeat: false

        onTriggered: {
            root.policyRestarting = false;
            root.rendererRestartLaunching = false;
        }
    }
    property bool policyRestarting: false
    property bool powerRestartPending: false
    readonly property string previewCacheDir: cacheDir + "/previews"
    property FolderListModel previewCacheModel: FolderListModel {
        folder: root.browsing ? "file://" + root.previewCacheDir : ""
        nameFilters: ["*.jpg"]
        showDirs: false
        showFiles: true

        onCountChanged: root.indexPreviewCache()
        onStatusChanged: {
            if (status === FolderListModel.Ready)
                root.indexPreviewCache();
        }
    }
    property Timer previewCachePruneTimer: Timer {
        interval: 1600
        repeat: false

        onTriggered: {
            if (previewCachePruner.running)
                return;
            previewCachePruner.requestJson = JSON.stringify({
                "max_bytes": 67108864,
                "max_files": 256,
                "path": root.previewCacheDir
            });
            previewCachePruner.running = true;
        }
    }
    property Process previewCachePruner: Process {
        property string requestJson: "{}"

        command: ["python3", "-u", Config.quickshellDir + "/scripts/wallpaper_workshop.py", "prune-preview-cache"]
        stdinEnabled: true

        onStarted: {
            write(requestJson + "\n");
            requestJson = "{}";
        }
    }
    readonly property int previewCoverWidth: 2560
    property var previewThumbnailJob: null
    property var previewThumbnailQueue: []
    property bool previewThumbnailStopRequested: false
    readonly property int previewThumbnailWidth: 960
    property Process previewThumbnailWorker: Process {
        onExited: (exitCode, exitStatus) => {
            var completedJob = root.previewThumbnailJob;
            root.previewThumbnailJob = null;
            var stopped = root.previewThumbnailStopRequested;
            root.previewThumbnailStopRequested = false;
            if (!stopped && completedJob && exitCode === 0) {
                var updated = Object.assign({}, root.knownPreviewThumbnails);
                updated[completedJob.target] = true;
                root.knownPreviewThumbnails = updated;
                root.previewThumbnailReady(completedJob.path, completedJob.target, Number(completedJob.requestToken || 0));
                root.previewCachePruneTimer.restart();
            } else if (!stopped && completedJob) {
                console.warn("[EngineWallpaperService] Could not create static preview for", completedJob.path);
            }
            root.processNextPreviewThumbnail();
        }
    }
    property string readyFramePath: ""
    property Process readyProbe: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 || !root.player.running || root.startedPath !== root.desiredPath)
                return;

            root.validatedFramePath = root.readyFramePath;
            root.cacheRenderedPreview(root.startedPath, root.validatedFramePath);
            if (root.playbackReadyState)
                root.playbackReady(root.startedPath, root.validatedFramePath, root.startedGeneration);
            else
                root.markReady(root.startedPath, root.validatedFramePath);
        }
    }
    readonly property string readyProbeScript: Config.quickshellDir + "/scripts/wallpaper_frame_probe.py"
    property Timer readyTimer: Timer {
        interval: 1600
        repeat: false

        onTriggered: {
            if (root.playbackReadyState || !root.player.running || root.startedPath !== root.desiredPath)
                return;
            if (WallpaperPlaybackPolicy.shouldPause)
                return;
            root.markReady(root.startedPath, "");
        }
    }
    property Timer rendererRestartDebounce: Timer {
        interval: 250
        repeat: false

        onTriggered: root.processPendingRendererRestart()
    }
    property bool rendererRestartLaunching: false
    property bool rescanPending: false
    property Timer scanDebounce: Timer {
        interval: 80
        repeat: false

        onTriggered: root.startScan()
    }
    property Process scanner: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text || "[]");
                    root.wallpapers = Array.isArray(parsed) ? parsed : [];
                } catch (error) {
                    root.wallpapers = [];
                    console.warn("[EngineWallpaperService] Invalid scanner output:", error);
                }
            }
        }

        onExited: {
            if (root.browsing && root.rescanPending) {
                root.rescanPending = false;
                root.scanDebounce.restart();
            }
        }
    }
    readonly property string scannerPath: Config.quickshellDir + "/scripts/wallpaper_engine_scan.py"
    readonly property bool scanning: scanner.running || scanDebounce.running
    property Connections screenConnections: Connections {
        function onScreensChanged() {
            root.screenRestartPending = true;
            if (!WallpaperPlaybackPolicy.shouldPause)
                root.rendererRestartDebounce.restart();
        }

        target: Quickshell
    }
    property bool screenRestartPending: false
    property bool startAfterCleanup: false
    property int startedGeneration: 0
    property string startedPath: ""
    property string validatedFramePath: ""
    property var wallpapers: []
    property FolderListModel workshopWatcher: FolderListModel {
        folder: root.browsing ? "file://" + Config.wallpaperEngineWorkshopDir : ""
        showDirs: true
        showFiles: false

        onCountChanged: {
            if (root.browsing)
                root.scan();
        }
    }

    signal playbackFailed(string sourcePath, string message, int generation)
    signal playbackReady(string sourcePath, string framePath, int generation)
    signal previewThumbnailReady(string sourcePath, string thumbnailPath, int requestToken)

    function beginBrowsing() {
        browsing = true;
        refresh();
    }
    function cacheRenderedPreview(path, framePath) {
        if (!path || !framePath)
            return;

        var target = renderedPreviewPath(path);
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\"; cp -f -- \"$2\" \"$3.tmp\" && mv -f -- \"$3.tmp\" \"$3\"", "engine-rendered-preview", previewCacheDir, framePath, target]);
        previewCachePruneTimer.restart();
    }
    function checkAvailability() {
        if (availabilityQuery.running)
            return;
        availabilityKnown = false;
        availabilityQuery.queriedAssetsDir = Config.wallpaperEngineAssetsDir;
        availabilityQuery.launchPending = true;
        availabilityQuery.running = true;
    }
    function currentScreenSignature() {
        var names = [];
        for (var i = 0; i < Quickshell.screens.length; ++i)
            names.push(String(Quickshell.screens[i].name || ""));
        names.sort();
        return names.join("\n");
    }
    function endBrowsing() {
        browsing = false;
        rescanPending = false;
        scanDebounce.stop();
        var requiredTarget = "";
        if (WallpaperService.isTransitionPending && WallpaperService.currentMode === "video" && WallpaperService.isEngineVideo && WallpaperService.pendingEnginePreviewSource)
            requiredTarget = previewCoverPath(WallpaperService.pendingEnginePreviewSource, WallpaperService.selectedModified);
        var retainedQueue = [];
        for (var i = 0; i < previewThumbnailQueue.length; ++i) {
            if (requiredTarget !== "" && previewThumbnailQueue[i].target === requiredTarget)
                retainedQueue.push(previewThumbnailQueue[i]);
        }
        previewThumbnailQueue = retainedQueue;
        if (previewThumbnailWorker.running && previewThumbnailJob && previewThumbnailJob.target !== requiredTarget) {
            previewThumbnailStopRequested = true;
            previewThumbnailWorker.running = false;
        }
        if (scanner.running)
            scanner.running = false;
    }
    function indexPreviewCache() {
        var indexed = {};
        for (var i = 0; i < previewCacheModel.count; ++i) {
            var path = String(previewCacheModel.get(i, "filePath") || "");
            if (path.startsWith("file://"))
                path = decodeURIComponent(path.substring(7));
            if (path)
                indexed[path] = true;
        }
        knownPreviewThumbnails = indexed;
    }
    function isEnginePath(path) {
        if (!path)
            return false;
        var sourcePath = String(path);
        return sourcePath.indexOf(Config.wallpaperEngineWorkshopDir) === 0 || sourcePath.indexOf(Config.legacyWallpaperEngineWorkshopDir) === 0;
    }
    function launchDesired() {
        if (!available || !desiredPath || player.running)
            return;

        startedPath = desiredPath;
        startedGeneration = desiredGeneration;
        launchedScreenSignature = currentScreenSignature();
        screenRestartPending = false;
        playbackReadyState = false;
        validatedFramePath = "";
        var currentFrame = String(Config.wallpaper || "");
        var nextSlot = currentFrame === cacheDir + "/render-frame-1.jpg" ? 0 : 1;
        readyFramePath = cacheDir + "/render-frame-" + String(nextSlot) + ".jpg";
        // Capture early so a usable frame can reveal the renderer immediately.
        // Invalid startup frames no longer block the short live-renderer grace.
        var screenshotDelayFrames = Math.max(24, Math.round(WallpaperPlaybackPolicy.targetFps * 0.8));
        var args = ["linux-wallpaperengine", "--silent", "--fps", String(WallpaperPlaybackPolicy.targetFps), "--layer", "background", "--no-fullscreen-pause", "--screenshot", readyFramePath, "--screenshot-delay", String(screenshotDelayFrames), "--assets-dir", Config.wallpaperEngineAssetsDir];
        for (var i = 0; i < Quickshell.screens.length; ++i) {
            args.push("--screen-root", Quickshell.screens[i].name, "--bg", startedPath, "--scaling", "fill", "--clamp", "border");
        }
        if (Quickshell.screens.length === 0)
            args.push(startedPath);

        player.command = ["sh", "-c", "mkdir -p \"$1\"; rm -f \"$3\"; printf '%s' \"$$\" > \"$2\"; shift 3; exec \"$@\"", "engine-wallpaper-player", cacheDir, pidPath, readyFramePath].concat(args);
        player.running = true;
        pidFile.reload();
    }
    function markReady(path, framePath) {
        if (playbackReadyState || !path || path !== startedPath)
            return;
        if (currentScreenSignature() !== launchedScreenSignature) {
            screenRestartPending = true;
            rendererRestartDebounce.restart();
            return;
        }

        playbackReadyState = true;
        readyTimer.stop();
        playbackReady(path, framePath || "", startedGeneration);
        if (policyRestarting)
            policyRestartFinish.restart();
    }
    function play(path, generation) {
        if (!path)
            return;
        desiredPath = path;
        desiredGeneration = Number(generation || 0);
        errorMessage = "";
        if (!availabilityKnown || !available) {
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
    function previewCoverKnown(path, modified) {
        if (!previewNeedsConversion(path))
            return true;
        return knownPreviewThumbnails[previewCoverPath(path, modified)] === true;
    }
    function previewCoverPath(path, modified) {
        return previewImagePath(path, modified, "cover", previewCoverWidth);
    }
    function previewImagePath(path, modified, variant, width) {
        return previewCacheDir + "/" + WallpaperService.stableHash("video-preview-v3|" + String(variant) + "|" + String(width) + "|" + String(path) + "|" + String(modified || "0")) + ".jpg";
    }
    function previewNeedsConversion(path) {
        var p = String(path || "").split("?")[0].toLowerCase();
        return p.endsWith(".gif") || p.endsWith(".mp4") || p.endsWith(".webm") || p.endsWith(".mkv") || p.endsWith(".avi") || p.endsWith(".mov");
    }
    function previewThumbnailKnown(path, modified) {
        if (!previewNeedsConversion(path))
            return true;
        return knownPreviewThumbnails[previewThumbnailPath(path, modified)] === true;
    }
    function previewThumbnailPath(path, modified) {
        return previewImagePath(path, modified, "thumbnail", previewThumbnailWidth);
    }
    function processNextPreviewThumbnail() {
        if (previewThumbnailWorker.running || previewThumbnailJob || previewThumbnailQueue.length === 0)
            return;

        previewThumbnailJob = previewThumbnailQueue[0];
        previewThumbnailQueue = previewThumbnailQueue.slice(1);
        previewThumbnailWorker.command = ["sh", "-c", "mkdir -p \"$3\"; if [ ! -s \"$2\" ]; then rm -f \"$2.tmp.jpeg\"; if ! nice -n 10 ffmpeg -hide_banner -loglevel error -y -ss 0.5 -i \"$1\" -frames:v 1 -vf \"scale='min($4,iw)':'min($4,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2:flags=fast_bilinear,format=yuvj420p\" -q:v 3 -update 1 \"$2.tmp.jpeg\" || [ ! -s \"$2.tmp.jpeg\" ]; then rm -f \"$2.tmp.jpeg\"; nice -n 10 ffmpeg -hide_banner -loglevel error -y -i \"$1\" -frames:v 1 -vf \"scale='min($4,iw)':'min($4,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2:flags=fast_bilinear,format=yuvj420p\" -q:v 3 -update 1 \"$2.tmp.jpeg\"; fi && mv \"$2.tmp.jpeg\" \"$2\"; fi", "engine-preview-thumbnail", previewThumbnailJob.path, previewThumbnailJob.target, previewCacheDir, String(previewThumbnailJob.width)];
        previewThumbnailWorker.running = true;
    }
    function processPendingRendererRestart() {
        if (WallpaperPlaybackPolicy.shouldPause)
            return;

        var screensChanged = currentScreenSignature() !== launchedScreenSignature;
        if (!screensChanged)
            screenRestartPending = false;
        if (!screensChanged && !powerRestartPending)
            return;
        if (!player.running) {
            powerRestartPending = false;
            if (!startAfterCleanup)
                requestStart();
            return;
        }
        if (policyRestarting && !screensChanged) {
            rendererRestartDebounce.restart();
            return;
        }

        screenRestartPending = false;
        powerRestartPending = false;
        restartRenderer();
    }
    function projectForPath(path) {
        for (var i = 0; i < wallpapers.length; ++i) {
            if (wallpapers[i].path === path)
                return wallpapers[i];
        }
        return null;
    }
    function refresh() {
        checkAvailability();
        scan();
    }
    function renderedPreviewKnown(path) {
        return knownPreviewThumbnails[renderedPreviewPath(path)] === true;
    }
    function renderedPreviewPath(path) {
        return previewCacheDir + "/rendered-" + WallpaperService.stableHash(String(path || "")) + ".jpg";
    }
    function rendererFailureMessage(exitCode, exitStatus) {
        var errorText = String(playerError.text || "").trim();
        var outputText = String(playerOutput.text || "").trim();
        var diagnosticText = errorText || outputText;
        if (diagnosticText !== "") {
            var diagnosticLines = diagnosticText.split(/\r?\n/).filter(line => line.trim() !== "");
            var logStart = Math.max(0, diagnosticLines.length - 12);
            console.warn("[EngineWallpaperService] Renderer failed:", diagnosticLines.slice(logStart).join("\n"));
            if (diagnosticLines.length > 0) {
                var detail = diagnosticLines[diagnosticLines.length - 1].trim();
                if (detail.length > 180)
                    detail = detail.substring(0, 177) + "…";
                return qsTr("Wallpaper Engine could not render this wallpaper: %1").arg(detail);
            }
        }
        console.warn("[EngineWallpaperService] Renderer exited without diagnostics:", exitCode, exitStatus);
        return qsTr("Wallpaper Engine could not render this wallpaper (exit code %1)").arg(exitCode);
    }
    function reportFailure(path, message, generation) {
        var failureGeneration = Number(generation || 0);
        if (!path || path !== desiredPath || failureGeneration !== desiredGeneration)
            return;
        errorMessage = message;
        playbackFailed(path, message, failureGeneration);
    }
    function requestPreviewCover(path, modified, priority, requestToken) {
        return requestPreviewImage(path, modified, priority, requestToken, previewCoverPath(path, modified), previewCoverWidth);
    }
    function requestPreviewImage(path, modified, priority, requestToken, target, width) {
        if (!previewNeedsConversion(path))
            return path;

        if (knownPreviewThumbnails[target] === true) {
            Qt.callLater(() => root.previewThumbnailReady(path, target, Number(requestToken || 0)));
            return target;
        }
        if (previewThumbnailJob && previewThumbnailJob.path === path && previewThumbnailJob.target === target) {
            previewThumbnailJob.requestToken = Number(requestToken || 0);
            return target;
        }
        for (var i = 0; i < previewThumbnailQueue.length; ++i) {
            if (previewThumbnailQueue[i].path === path && previewThumbnailQueue[i].target === target) {
                if (priority && i > 0) {
                    var queuedJob = previewThumbnailQueue[i];
                    queuedJob.requestToken = Number(requestToken || 0);
                    previewThumbnailQueue = [queuedJob].concat(previewThumbnailQueue.slice(0, i), previewThumbnailQueue.slice(i + 1));
                } else
                    previewThumbnailQueue[i].requestToken = Number(requestToken || 0);
                return target;
            }
        }
        var job = {
            "path": path,
            "requestToken": Number(requestToken || 0),
            "target": target,
            "width": Number(width)
        };
        previewThumbnailQueue = priority ? [job].concat(previewThumbnailQueue) : previewThumbnailQueue.concat([job]);
        processNextPreviewThumbnail();
        return target;
    }
    function requestPreviewThumbnail(path, modified, priority, requestToken) {
        return requestPreviewImage(path, modified, priority, requestToken, previewThumbnailPath(path, modified), previewThumbnailWidth);
    }
    function requestStart() {
        if (!available || !desiredPath || player.running)
            return;
        startAfterCleanup = true;
        stopOwnedProcess();
    }
    function restartRenderer() {
        if (!player.running)
            return;

        policyRestartFinish.stop();
        policyRestarting = true;
        rendererRestartLaunching = false;
        playbackReadyState = false;
        player.running = false;
    }
    function scan() {
        if (!browsing)
            return;
        if (scanner.running) {
            rescanPending = true;
            return;
        }
        scanDebounce.restart();
    }
    function shutdownForReload() {
        pidFile.reload();
        var expectedPid = pidFile.loaded ? pidFile.text().trim() : "";
        browsing = false;
        previewThumbnailQueue = [];
        desiredPath = "";
        startAfterCleanup = false;
        if (previewThumbnailWorker.running)
            previewThumbnailStopRequested = true;
        if (previewThumbnailWorker.running)
            previewThumbnailWorker.running = false;
        if (scanner.running)
            scanner.running = false;
        if (readyProbe.running)
            readyProbe.running = false;
        if (player.running)
            player.running = false;
        if (expectedPid !== "")
            Quickshell.execDetached(["sh", "-c", "pid=\"$3\"; if [ -e \"/proc/$pid/exe\" ]; then exe=$(readlink \"/proc/$pid/exe\" 2>/dev/null || true); cmd=$(tr '\\0' ' ' < \"/proc/$pid/cmdline\" 2>/dev/null || true); case \"$exe:$cmd\" in */linux-wallpaperengine:*\"$2/render-frame-\"*) kill -CONT \"$pid\" 2>/dev/null || true; kill \"$pid\" 2>/dev/null || true ;; esac; fi; current=$(cat \"$1\" 2>/dev/null || true); [ \"$current\" = \"$pid\" ] && rm -f \"$1\"", "engine-wallpaper-reload-stop", pidPath, cacheDir, expectedPid]);
    }
    function startReadyProbe() {
        if (!player.running || !readyFramePath)
            return;

        if (readyProbe.running)
            readyProbe.running = false;
        readyProbe.command = ["python3", readyProbeScript, readyFramePath, "4.8"];
        readyProbe.running = true;
    }
    function startScan() {
        if (!browsing)
            return;
        if (scanner.running) {
            rescanPending = true;
            return;
        }
        rescanPending = false;
        scanner.command = ["python3", scannerPath, Config.wallpaperEngineWorkshopDir, Config.legacyWallpaperEngineWorkshopDir];
        scanner.running = true;
    }
    function stop() {
        desiredPath = "";
        activePath = "";
        errorMessage = "";
        startAfterCleanup = false;
        playbackReadyState = false;
        policyRestarting = false;
        rendererRestartLaunching = false;
        powerRestartPending = false;
        screenRestartPending = false;
        policyPauseRetry.stop();
        rendererRestartDebounce.stop();
        policyRestartFinish.stop();
        readyTimer.stop();
        readyFramePath = "";
        validatedFramePath = "";
        if (readyProbe.running)
            readyProbe.running = false;
        if (player.running)
            player.running = false;
        stopOwnedProcess();
    }
    function stopOwnedProcess() {
        ownedProcessStopper.command = ["sh", "-c", "pid=$(cat \"$1\" 2>/dev/null || true); if [ -n \"$pid\" ] && [ -e \"/proc/$pid/exe\" ]; then exe=$(readlink \"/proc/$pid/exe\" 2>/dev/null || true); cmd=$(tr '\\0' ' ' < \"/proc/$pid/cmdline\" 2>/dev/null || true); case \"$exe:$cmd\" in */linux-wallpaperengine:*\"$2/render-frame-\"*) kill -CONT \"$pid\" 2>/dev/null || true; kill \"$pid\" 2>/dev/null || true ;; esac; fi; rm -f \"$1\"", "engine-wallpaper-stop", pidPath, cacheDir];
        cleanupRestartPending = true;
        if (ownedProcessStopper.running)
            ownedProcessStopper.running = false;
        cleanupRestart.restart();
    }
    function syncPolicyPause() {
        if (!player.running)
            return;
        if (policyPauseController.running) {
            policyPausePending = true;
            return;
        }

        policyPauseController.command = ["sh", "-c", "pid=$(cat \"$1\" 2>/dev/null || true); [ -n \"$pid\" ] || exit 1; exe=$(readlink \"/proc/$pid/exe\" 2>/dev/null || true); case \"$exe\" in */linux-wallpaperengine) kill -\"$2\" \"$pid\" ;; *) exit 1 ;; esac", "engine-wallpaper-policy", pidPath, WallpaperPlaybackPolicy.shouldPause ? "STOP" : "CONT"];
        policyPauseController.running = true;
    }

    Component.onDestruction: shutdownForReload()
}
