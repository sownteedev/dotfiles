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
        command: ["sh", "-c", "command -v linux-wallpaperengine >/dev/null 2>&1 && test -d \"$1\"", "engine-wallpaper-availability", Config.wallpaperEngineAssetsDir]

        onExited: (exitCode, exitStatus) => {
            root.available = exitCode === 0;
            root.availabilityKnown = true;
            if (root.available && root.desiredPath)
                root.requestStart();
            else if (!root.available && root.desiredPath)
                root.reportFailure(root.desiredPath, "Install linux-wallpaperengine and Wallpaper Engine assets");
        }
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
    property string desiredPath: ""
    property string errorMessage: ""
    property string launchedScreenSignature: ""
    property var knownPreviewThumbnails: ({})
    property FolderListModel legacyWorkshopWatcher: FolderListModel {
        folder: "file://" + Config.legacyWallpaperEngineWorkshopDir
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
    readonly property string pidPath: cacheDir + "/linux-wallpaperengine.pid"
    property bool playbackReadyState: false
    property Process player: Process {
        onExited: (exitCode, exitStatus) => {
            var exitedPath = root.startedPath;
            root.activePath = "";
            root.playbackReadyState = false;
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
                    root.reportFailure(exitedPath, "Wallpaper Engine restart failed");
                }
                return;
            }
            if (root.desiredPath && root.desiredPath !== exitedPath && !root.startAfterCleanup)
                Qt.callLater(root.requestStart);
            else if (root.desiredPath && root.desiredPath === exitedPath && !root.startAfterCleanup)
                root.reportFailure(exitedPath, "Wallpaper Engine stopped unexpectedly");
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
        folder: "file://" + root.previewCacheDir
        nameFilters: ["*.jpg"]
        showDirs: false
        showFiles: true

        onCountChanged: root.indexPreviewCache()
        onStatusChanged: {
            if (status === FolderListModel.Ready)
                root.indexPreviewCache();
        }
    }
    property var previewThumbnailJob: null
    property var previewThumbnailQueue: []
    property Process previewThumbnailWorker: Process {
        onExited: (exitCode, exitStatus) => {
            var completedJob = root.previewThumbnailJob;
            root.previewThumbnailJob = null;
            if (completedJob && exitCode === 0) {
                var updated = Object.assign({}, root.knownPreviewThumbnails);
                updated[completedJob.target] = true;
                root.knownPreviewThumbnails = updated;
                root.previewThumbnailReady(completedJob.path, completedJob.target);
            } else if (completedJob) {
                console.warn("[EngineWallpaperService] Could not create static preview for", completedJob.path);
            }
            root.processNextPreviewThumbnail();
        }
    }
    property string readyFramePath: ""
    property Process readyProbe: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && root.player.running && root.startedPath === root.desiredPath)
                root.markReady(root.startedPath, root.readyFramePath);
        }
    }
    readonly property string readyProbeScript: Config.quickshellDir + "/scripts/wallpaper_frame_probe.py"
    property Timer readyTimer: Timer {
        interval: 8000
        repeat: false

        onTriggered: {
            if (!root.player.running || root.startedPath !== root.desiredPath)
                return;
            if (WallpaperPlaybackPolicy.shouldPause)
                return;
            root.reportFailure(root.startedPath, "Wallpaper Engine did not become ready");
        }
    }
    property Timer rendererRestartDebounce: Timer {
        interval: 250
        repeat: false

        onTriggered: root.processPendingRendererRestart()
    }
    property bool rendererRestartLaunching: false
    property bool rescanPending: false
    property Connections screenConnections: Connections {
        function onScreensChanged() {
            root.screenRestartPending = true;
            if (!WallpaperPlaybackPolicy.shouldPause)
                root.rendererRestartDebounce.restart();
        }

        target: Quickshell
    }
    property bool screenRestartPending: false
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
    property bool startAfterCleanup: false
    property string startedPath: ""
    property var wallpapers: []
    property FolderListModel workshopWatcher: FolderListModel {
        folder: "file://" + Config.wallpaperEngineWorkshopDir
        showDirs: true
        showFiles: false

        onCountChanged: {
            if (root.browsing)
                root.scan();
        }
    }

    signal playbackReady(string sourcePath, string framePath)
    signal playbackFailed(string sourcePath, string message)
    signal previewThumbnailReady(string sourcePath, string thumbnailPath)

    function beginBrowsing() {
        browsing = true;
        refresh();
    }
    function checkAvailability() {
        availabilityKnown = false;
        if (availabilityQuery.running)
            availabilityQuery.running = false;
        availabilityQuery.running = true;
    }
    function endBrowsing() {
        browsing = false;
        rescanPending = false;
        scanDebounce.stop();
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
        for (var knownPath in knownPreviewThumbnails) {
            if (knownPreviewThumbnails[knownPath] === true)
                indexed[knownPath] = true;
        }
        knownPreviewThumbnails = indexed;
    }
    function isEnginePath(path) {
        if (!path)
            return false;
        var sourcePath = String(path);
        return sourcePath.indexOf(Config.wallpaperEngineWorkshopDir) === 0 || sourcePath.indexOf(Config.legacyWallpaperEngineWorkshopDir) === 0;
    }
    function currentScreenSignature() {
        var names = [];
        for (var i = 0; i < Quickshell.screens.length; ++i)
            names.push(String(Quickshell.screens[i].name || ""));
        names.sort();
        return names.join("\n");
    }
    function launchDesired() {
        if (!available || !desiredPath || player.running)
            return;

        startedPath = desiredPath;
        launchedScreenSignature = currentScreenSignature();
        screenRestartPending = false;
        playbackReadyState = false;
        var currentFrame = String(Config.wallpaper || "");
        var nextSlot = currentFrame === cacheDir + "/render-frame-1.jpg" ? 0 : 1;
        readyFramePath = cacheDir + "/render-frame-" + String(nextSlot) + ".jpg";
        // linux-wallpaperengine counts --screenshot-delay in frames, not
        // seconds. Two frames captured several projects before their shaders
        // had initialized, producing black/noisy lock-screen backdrops.
        var screenshotDelayFrames = Math.max(45, Math.round(WallpaperPlaybackPolicy.targetFps * 2));
        var args = ["linux-wallpaperengine", "--silent", "--fps", String(WallpaperPlaybackPolicy.targetFps), "--layer", "background", "--no-fullscreen-pause", "--screenshot", readyFramePath, "--screenshot-delay", String(screenshotDelayFrames), "--assets-dir", Config.wallpaperEngineAssetsDir];
        for (var i = 0; i < Quickshell.screens.length; ++i) {
            args.push("--screen-root", Quickshell.screens[i].name, "--bg", startedPath, "--scaling", "fill", "--clamp", "border");
        }
        if (Quickshell.screens.length === 0)
            args.push(startedPath);

        player.command = ["sh", "-c", "mkdir -p \"$1\"; rm -f \"$3\"; printf '%s' \"$$\" > \"$2\"; shift 3; exec \"$@\"", "engine-wallpaper-player", cacheDir, pidPath, readyFramePath].concat(args);
        player.running = true;
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
        playbackReady(path, framePath || "");
        if (policyRestarting)
            policyRestartFinish.restart();
    }
    function play(path) {
        if (!path)
            return;
        desiredPath = path;
        errorMessage = "";
        if (!availabilityKnown || !available) {
            checkAvailability();
            return;
        }
        if (player.running) {
            if (startedPath === desiredPath) {
                if (playbackReadyState) {
                    var runningPath = startedPath;
                    var runningFrame = readyFramePath;
                    Qt.callLater(() => {
                        if (root.player.running && root.startedPath === runningPath)
                            root.playbackReady(runningPath, runningFrame);
                    });
                }
                return;
            }
            player.running = false;
        }
        requestStart();
    }
    function previewNeedsConversion(path) {
        return String(path || "").split("?")[0].toLowerCase().endsWith(".gif");
    }
    function previewThumbnailKnown(path, modified) {
        if (!previewNeedsConversion(path))
            return true;
        return knownPreviewThumbnails[previewThumbnailPath(path, modified)] === true;
    }
    function previewThumbnailPath(path, modified) {
        return previewCacheDir + "/" + WallpaperService.stableHash(String(path) + "|" + String(modified || "0")) + ".jpg";
    }
    function processNextPreviewThumbnail() {
        if (previewThumbnailWorker.running || previewThumbnailJob || previewThumbnailQueue.length === 0)
            return;

        previewThumbnailJob = previewThumbnailQueue[0];
        previewThumbnailQueue = previewThumbnailQueue.slice(1);
        previewThumbnailWorker.command = ["sh", "-c", "mkdir -p \"$3\"; if [ ! -s \"$2\" ]; then ffmpeg -hide_banner -loglevel error -y -ss 0.5 -i \"$1\" -frames:v 1 -vf 'scale=960:-2:force_original_aspect_ratio=decrease' \"$2.tmp.jpg\" && mv \"$2.tmp.jpg\" \"$2\"; fi", "engine-preview-thumbnail", previewThumbnailJob.path, previewThumbnailJob.target, previewCacheDir];
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
    function requestPreviewThumbnail(path, modified, priority) {
        if (!previewNeedsConversion(path))
            return path;

        var target = previewThumbnailPath(path, modified);
        if (knownPreviewThumbnails[target] === true) {
            Qt.callLater(() => root.previewThumbnailReady(path, target));
            return target;
        }
        if (previewThumbnailJob && previewThumbnailJob.path === path && previewThumbnailJob.target === target)
            return target;
        for (var i = 0; i < previewThumbnailQueue.length; ++i) {
            if (previewThumbnailQueue[i].path === path && previewThumbnailQueue[i].target === target) {
                if (priority && i > 0) {
                    var queuedJob = previewThumbnailQueue[i];
                    previewThumbnailQueue = [queuedJob].concat(previewThumbnailQueue.slice(0, i), previewThumbnailQueue.slice(i + 1));
                }
                return target;
            }
        }
        var job = {
            "path": path,
            "target": target
        };
        previewThumbnailQueue = priority ? [job].concat(previewThumbnailQueue) : previewThumbnailQueue.concat([job]);
        processNextPreviewThumbnail();
        return target;
    }
    function requestStart() {
        if (!available || !desiredPath || player.running)
            return;
        startAfterCleanup = true;
        stopOwnedProcess();
    }
    function reportFailure(path, message) {
        if (!path || path !== desiredPath)
            return;
        errorMessage = message;
        playbackFailed(path, message);
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
}
