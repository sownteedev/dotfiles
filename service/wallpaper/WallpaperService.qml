pragma Singleton
import "../../"
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string backendReadyPath: ""
    property string committedVideoCover: ""
    property Connections configConnections: Connections {
        function onMatugenEnabledChanged() {
            root.cancelPreview();
            WallpaperPreviewService.cancel();
            var sourceKey = root.themeIdentity();
            ThemeService.setExpectedSource(sourceKey);
            var source = root.currentThemeSource();
            if (Config.matugenEnabled && StateManager.wallpaperLoaded && ThemeService.modeResolved && source)
                ThemeService.generate(source, ThemeService.colorMode, true, sourceKey);
        }

        target: Config
    }
    property var coverReadyScreens: ({})
    readonly property string currentMode: selectedMode
    readonly property string currentWallpaper: selectedPath
    readonly property string displayWallpaper: previewActive && previewPath ? previewPath : Config.wallpaper
    property Connections engineConnections: Connections {
        function onPlaybackFailed(sourcePath, message, generation) {
            if (generation === root.videoTransitionGeneration)
                root.handleVideoFailure(sourcePath, message);
        }
        function onPlaybackReady(sourcePath, framePath, generation) {
            if (generation !== root.videoTransitionGeneration || root.selectedMode !== "video" || !root.isEngineVideo || sourcePath !== root.selectedPath)
                return;

            if (framePath) {
                root.rememberVideoFrame(framePath, true);
                if (!root.isTransitionPending) {
                    root.saveState(root.persistedVideoThumbnail());
                    return;
                }
            }
            if (!root.isTransitionPending)
                return;

            root.backendReadyPath = sourcePath;
            if (!framePath && root.fallbackVideoThumbnail && !root.pendingVideoThumbnail)
                root.stageVideoThumbnail(root.fallbackVideoThumbnail, true);
            root.tryFinishVideoTransition();
        }
        function onPreviewThumbnailReady(sourcePath, thumbnailPath, requestToken) {
            var expectedCover = EngineWallpaperService.previewCoverPath(sourcePath, root.selectedModified);
            if (requestToken !== root.videoTransitionGeneration || root.selectedMode !== "video" || !root.isEngineVideo || sourcePath !== root.pendingEnginePreviewSource || thumbnailPath !== expectedCover)
                return;

            root.pendingEnginePreviewSource = "";
            root.fallbackVideoThumbnail = thumbnailPath;
            if (root.isTransitionPending && !root.committedVideoCover)
                root.stageVideoThumbnail(thumbnailPath, false);
            if (!root.videoQuickThemeReady && !root.pendingVideoThemeSource)
                root.prepareVideoTheme(root.committedVideoCover || thumbnailPath, root.selectedModified);
            if (!root.isTransitionPending)
                root.saveState(thumbnailPath);
        }
        function onProjectResolved(sourcePath, project, requestToken) {
            var pending = root.pendingProjectResolution;
            if (!pending || Number(pending.requestToken || 0) !== requestToken || String(pending.path || "") !== sourcePath)
                return;

            root.pendingProjectResolution = null;
            if (pending.kind === "restore") {
                root.restoreSavedWallpaper(pending.state, project);
                root.ensureInitialTheme();
            } else {
                root.applyResolved(pending.path, pending.mode, pending.modified, pending.backendOverride, pending.preserveRollback, pending.rendererOverride, project);
            }
        }

        target: EngineWallpaperService
    }
    property string fallbackVideoThumbnail: ""
    property bool initialThemeChecked: false
    property bool isEngineVideo: false
    property bool isTransitionPending: false
    property var lastStableState: ({
            "version": 3,
            "path": Config.defaultWallpaper,
            "mode": "static",
            "backend": "static",
            "renderer": "",
            "modified": "0",
            "thumbnail": "",
            "frame": ""
        })
    property string lastVideoFrame: ""
    property bool legacyStateAttempted: false
    property Process legacyStateLoader: Process {
        command: ["cat", root.legacyStatePath]

        stdout: StdioCollector {
            id: legacyStateOutput
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && legacyStateOutput.text.trim() !== "") {
                root.loadSavedWallpaper(legacyStateOutput.text);
                if (!root.pendingProjectResolution)
                    root.stateReader.setText(JSON.stringify(root.lastStableState) + "\n");
            } else {
                root.loadDefaultWallpaper();
            }
            root.ensureInitialTheme();
        }
    }
    readonly property string legacyStatePath: Config.homeDir + "/.cache/quickshell/quickshell_wallpaper.txt"
    property Connections liveConnections: Connections {
        function onPlaybackFailed(sourcePath, message, generation) {
            if (generation === root.videoTransitionGeneration && sourcePath === root.selectedRendererPath)
                root.handleVideoFailure(root.selectedPath, message);
        }
        function onPlaybackReady(sourcePath, framePath, generation) {
            if (generation !== root.videoTransitionGeneration || root.selectedMode !== "video" || root.isEngineVideo || sourcePath !== root.selectedRendererPath)
                return;

            if (framePath) {
                root.rememberVideoFrame(framePath, true);
                if (!root.isTransitionPending) {
                    root.saveState(root.persistedVideoThumbnail());
                    return;
                }
            }
            if (!root.isTransitionPending)
                return;

            root.backendReadyPath = root.selectedPath;
            if (!framePath && root.fallbackVideoThumbnail && !root.pendingVideoThumbnail)
                root.stageVideoThumbnail(root.fallbackVideoThumbnail, true);
            root.tryFinishVideoTransition();
        }
        function onThumbnailReady(sourcePath, thumbnailPath, requestToken) {
            var expectedPath = "";
            var isValid = false;

            if (root.selectedMode === "video" && !root.isEngineVideo) {
                expectedPath = LiveWallpaperService.coverPath(root.selectedRendererPath, root.selectedModified);
                isValid = true;
            }

            if (!isValid || thumbnailPath !== expectedPath || requestToken !== root.videoTransitionGeneration)
                return;

            root.fallbackVideoThumbnail = thumbnailPath;
            if (root.isTransitionPending && !root.committedVideoCover)
                root.stageVideoThumbnail(thumbnailPath, false);
            if (!root.videoQuickThemeReady && !root.pendingVideoThemeSource)
                root.prepareVideoTheme(root.committedVideoCover || thumbnailPath, root.selectedModified);
            if (!root.isTransitionPending)
                root.saveState(thumbnailPath);
        }

        target: LiveWallpaperService
    }
    property bool liveRevealActive: false
    property Timer liveRevealFinish: Timer {
        id: liveRevealFinish

        onTriggered: {
            root.liveRevealActive = false;
            var renderedFrame = root.lastVideoFrame;
            if (root.selectedMode === "video" && renderedFrame) {
                Qt.callLater(() => {
                    if (!root.liveRevealActive && !root.isTransitionPending && root.selectedMode === "video" && root.lastVideoFrame === renderedFrame)
                        Config.wallpaper = renderedFrame;
                });
            }
        }
    }
    property string pendingEnginePreviewSource: ""
    property var pendingProjectResolution: null
    property string pendingVideoSystemThemePath: ""
    property string pendingVideoThemeSource: ""
    property string pendingVideoThumbnail: ""
    property Connections playbackPolicyConnections: Connections {
        function onShouldPauseChanged() {
            if (!root.isTransitionPending || root.selectedMode !== "video")
                return;
            if (WallpaperPlaybackPolicy.shouldPause)
                root.videoTransitionDeadline.stop();
            else
                root.videoTransitionDeadline.restart();
        }

        target: WallpaperPlaybackPolicy
    }
    property bool previewActive: false
    property Connections previewConnections: Connections {
        function onThemeSourceReady(sourcePath, thumbnailPath, requestToken) {
            if (root.selectedMode === "static" && root.selectedPath === sourcePath) {
                root.applyTheme(thumbnailPath);
                return;
            }
            if (requestToken === root.videoTransitionGeneration && root.selectedMode === "video" && sourcePath === root.pendingVideoThemeSource) {
                root.pendingVideoThemeSource = "";
                root.pendingVideoSystemThemePath = thumbnailPath;
                root.videoPaletteReady = true;
                root.videoPaletteRevealFallback.stop();
                // The cached Quickshell palette is already animating. Let that
                // settle before generating GTK/Qt/application themes.
                root.videoQuickThemeSettle.restart();
                root.tryFinishVideoTransition();
            }
        }

        target: WallpaperPreviewService
    }
    property string previewPath: ""
    readonly property bool ready: StateManager.wallpaperLoaded
    property Connections screenConnections: Connections {
        function onScreensChanged() {
            root.updateVideoCoverReadiness();
            root.updateStaticTransitionReadiness();
        }

        target: Quickshell
    }
    readonly property string selectedBackend: selectedMode === "video" ? (isEngineVideo ? "engine" : "live") : "static"
    property string selectedMode: LiveWallpaperService.isLivePath(Config.wallpaper) ? "video" : "static"
    property string selectedModified: "0"
    property string selectedPath: Config.wallpaper
    property string selectedRendererPath: selectedMode === "video" ? selectedPath : ""
    property bool startupVideoRestore: true
    readonly property string statePath: Config.cacheRoot + "/quickshell_wallpaper.txt"
    property FileView stateReader: FileView {
        atomicWrites: true
        blockLoading: true
        blockWrites: true
        path: root.statePath
        // This file is owned by WallpaperService. Watching our own writes can
        // re-enter a half-transitioned state and could leave the
        // service in "static" mode while the video renderer was active.
        watchChanges: false

        onLoadFailed: {
            if (root.statePath !== root.legacyStatePath && !root.legacyStateAttempted) {
                root.legacyStateAttempted = true;
                root.legacyStateLoader.running = true;
                return;
            }
            root.loadDefaultWallpaper();
            root.ensureInitialTheme();
        }
        onLoadedChanged: {
            if (loaded) {
                root.loadSavedWallpaper();
                root.ensureInitialTheme();
            }
        }
        onSaveFailed: error => console.warn("[WallpaperService] Could not save wallpaper state:", error)
    }
    property var staticReadyScreens: ({})
    property Timer staticRevealDelay: Timer {
        interval: 220
        repeat: false

        onTriggered: {
            if (LiveWallpaperService.active || EngineWallpaperService.active) {
                restart();
                return;
            }
            root.liveRevealActive = false;
        }
    }
    property Timer staticTransitionFallback: Timer {
        interval: Math.max(1400, Config.wallpaperTransitionDuration + 900)
        repeat: false

        onTriggered: {
            if (!root.staticTransitionPending)
                return;
            console.warn("[WallpaperService] Static wallpaper transition timed out, stopping the previous renderer");
            root.finishStaticTransition();
        }
    }
    property bool staticTransitionPending: false
    property Connections themeConnections: Connections {
        function onModeResolvedChanged() {
            root.ensureInitialTheme();
        }
        function onSystemModeChanged(mode) {
            root.cancelPreview();
            WallpaperPreviewService.cancel();
            var sourceKey = root.themeIdentity();
            ThemeService.setExpectedSource(sourceKey);
            var source = root.currentThemeSource();
            if (StateManager.wallpaperLoaded && source)
                ThemeService.generate(source, mode, true, sourceKey);
        }
        function onThemeFileResolvedChanged() {
            root.ensureInitialTheme();
        }

        target: ThemeService
    }
    property var transitionRollbackState: null
    property bool videoCoverReady: false
    property Timer videoCoverReadyFallback: Timer {
        interval: 2800
        repeat: false

        onTriggered: {
            if (root.isTransitionPending && root.pendingVideoThumbnail) {
                if (Object.keys(root.coverReadyScreens).length > 0) {
                    console.warn("[WallpaperService] Some screens did not report the video cover ready, continuing with the loaded cover");
                    root.videoCoverReady = true;
                    root.startDeferredVideoRenderer();
                    root.tryFinishVideoTransition();
                } else {
                    console.warn("[WallpaperService] Video cover has not loaded yet, waiting for the transition deadline");
                }
            }
        }
    }
    property bool videoPaletteReady: false
    property Timer videoPaletteRevealFallback: Timer {
        interval: 320
        repeat: false

        onTriggered: {
            if (!root.isTransitionPending || root.selectedMode !== "video" || root.videoPaletteReady)
                return;
            root.videoPaletteReady = true;
            root.tryFinishVideoTransition();
        }
    }
    property Timer videoQuickThemeFallback: Timer {
        interval: 4500
        repeat: false

        onTriggered: {
            if (root.selectedMode !== "video" || root.videoQuickThemeReady)
                return;
            console.warn("[WallpaperService] Video palette preparation timed out, continuing with the available theme source");
            if (root.videoRendererStartPending) {
                root.videoRendererStartPending = false;
                root.liveRevealActive = true;
                root.launchSelectedVideoRenderer();
            }
            root.pendingVideoThemeSource = "";
            root.videoQuickThemeSettle.stop();
            root.videoQuickThemeReady = true;
            var source = root.pendingVideoSystemThemePath || root.committedVideoCover || root.lastVideoFrame || root.fallbackVideoThumbnail || root.pendingVideoThumbnail;
            root.pendingVideoSystemThemePath = "";
            if (source)
                root.applyTheme(source);
            root.tryFinishVideoTransition();
        }
    }
    property bool videoQuickThemeReady: false
    property Timer videoQuickThemeSettle: Timer {
        interval: 320
        repeat: false

        onTriggered: {
            if (root.selectedMode !== "video")
                return;
            var source = root.pendingVideoSystemThemePath;
            root.pendingVideoSystemThemePath = "";
            root.videoQuickThemeReady = true;
            root.videoQuickThemeFallback.stop();
            if (source)
                root.applyTheme(source);
            root.tryFinishVideoTransition();
        }
    }
    property bool videoRendererStartPending: false
    property Timer videoTransitionDeadline: Timer {
        interval: 12000
        repeat: false

        onTriggered: {
            if (WallpaperPlaybackPolicy.shouldPause)
                return;
            if (root.isTransitionPending && root.selectedMode === "video")
                root.handleVideoFailure(root.selectedPath, "The wallpaper renderer did not become ready in time");
        }
    }
    property int videoTransitionGeneration: 0

    function apply(path, mode, modified, backendOverride, preserveRollback, rendererOverride) {
        if (!path)
            return;

        startupVideoRestore = false;
        var nextMode = mode === "video" ? "video" : "static";
        pendingProjectResolution = null;
        if (nextMode === "video" && backendOverride !== "engine" && EngineWallpaperService.isEnginePath(path) && !rendererOverride) {
            var cachedProject = EngineWallpaperService.projectForPath(path);
            if (!cachedProject) {
                videoTransitionGeneration += 1;
                pendingProjectResolution = {
                    "backendOverride": backendOverride,
                    "kind": "apply",
                    "mode": mode,
                    "modified": modified,
                    "path": String(path),
                    "preserveRollback": preserveRollback,
                    "rendererOverride": rendererOverride,
                    "requestToken": videoTransitionGeneration
                };
                EngineWallpaperService.requestProject(path, videoTransitionGeneration);
                return;
            }
        }
        applyResolved(path, mode, modified, backendOverride, preserveRollback, rendererOverride, EngineWallpaperService.projectForPath(path));
    }
    function applyResolved(path, mode, modified, backendOverride, preserveRollback, rendererOverride, projectOverride) {
        if (!path)
            return;

        var nextMode = mode === "video" ? "video" : "static";
        var nextModified = LiveWallpaperService.modifiedKey(modified);
        var isWorkshopPath = nextMode === "video" && EngineWallpaperService.isEnginePath(path);
        var nativeWorkshopVideo = isWorkshopPath && EngineWallpaperService.isNativeVideoProject(path, projectOverride);
        var nextIsEngine = nextMode === "video" && (backendOverride === "engine" ? true : backendOverride === "live" ? false : isWorkshopPath && !nativeWorkshopVideo);
        var nextRendererPath = "";
        if (nextMode === "video") {
            if (nextIsEngine)
                nextRendererPath = String(path);
            else if (isWorkshopPath)
                nextRendererPath = String(rendererOverride || EngineWallpaperService.nativeVideoSource(path, projectOverride));
            else
                nextRendererPath = String(rendererOverride || path);
        }
        if (nextMode === selectedMode && String(path) === String(selectedPath) && nextModified === selectedModified && nextIsEngine === isEngineVideo && nextRendererPath === selectedRendererPath) {
            // Selecting the current wallpaper is a commit of the selector
            // preview, not a renderer restart. stop() followed immediately by
            // play() is asynchronous and can otherwise make the old process
            // exit look like a crash when both paths are identical.
            cancelPreview();
            WallpaperPreviewService.cancel();
            return;
        }
        var rendererWasActive = LiveWallpaperService.active || EngineWallpaperService.active;
        var previewCover = previewActive && previewPath ? String(previewPath) : "";
        var outgoingCover = previewCover || String(Config.wallpaper || Config.defaultWallpaper);
        resetStaticTransition();
        if (nextMode === "video") {
            if (preserveRollback !== true)
                transitionRollbackState = cloneState(lastStableState);
        } else {
            transitionRollbackState = null;
        }
        selectedPath = path;
        selectedMode = nextMode;
        selectedModified = nextModified;
        selectedRendererPath = nextRendererPath;
        isEngineVideo = nextIsEngine;
        ThemeService.setExpectedSource(themeIdentity());
        if (nextMode === "video") {
            videoTransitionGeneration += 1;
            staticRevealDelay.stop();
            liveRevealFinish.stop();
            // During video-to-video changes, leave the old renderer fully
            // visible until the incoming cover has actually been decoded.
            liveRevealActive = previewCover !== "" || !rendererWasActive;
            root.isTransitionPending = true;
            root.backendReadyPath = "";
            root.committedVideoCover = previewCover;
            root.fallbackVideoThumbnail = "";
            root.lastVideoFrame = "";
            root.pendingEnginePreviewSource = "";
            root.pendingVideoSystemThemePath = "";
            root.pendingVideoThemeSource = "";
            root.pendingVideoThumbnail = "";
            root.videoPaletteReady = !Config.matugenEnabled;
            root.videoPaletteRevealFallback.stop();
            root.videoQuickThemeReady = false;
            root.videoRendererStartPending = rendererWasActive;
            root.videoQuickThemeSettle.stop();
            root.videoQuickThemeFallback.restart();
            if (WallpaperPlaybackPolicy.shouldPause)
                root.videoTransitionDeadline.stop();
            else
                root.videoTransitionDeadline.restart();
            root.resetVideoCoverReadiness();
            root.stageVideoThumbnail(outgoingCover, false);
            cancelPreview();
            WallpaperPreviewService.cancel();
            if (root.committedVideoCover)
                root.prepareVideoTheme(root.committedVideoCover, selectedModified);

            if (nextIsEngine) {
                var project = EngineWallpaperService.projectForPath(path) || {};
                var preview = project.preview || "";
                if (preview) {
                    if (EngineWallpaperService.previewNeedsConversion(preview)) {
                        root.pendingEnginePreviewSource = preview;
                        var engineCover = EngineWallpaperService.requestPreviewCover(preview, selectedModified, true, videoTransitionGeneration);
                        if (EngineWallpaperService.previewCoverKnown(preview, selectedModified)) {
                            root.pendingEnginePreviewSource = "";
                            root.fallbackVideoThumbnail = engineCover;
                            if (!root.committedVideoCover)
                                root.stageVideoThumbnail(engineCover, false);
                            if (!root.videoQuickThemeReady && !root.pendingVideoThemeSource)
                                root.prepareVideoTheme(engineCover, selectedModified);
                        }
                    } else {
                        root.fallbackVideoThumbnail = preview;
                        if (!root.committedVideoCover)
                            root.stageVideoThumbnail(preview, false);
                        if (!root.videoQuickThemeReady && !root.pendingVideoThemeSource)
                            root.prepareVideoTheme(preview, selectedModified);
                    }
                }
            } else {
                var liveCover = LiveWallpaperService.requestCover(selectedRendererPath, selectedModified, true, videoTransitionGeneration);
                if (LiveWallpaperService.coverKnown(selectedRendererPath, selectedModified)) {
                    root.fallbackVideoThumbnail = liveCover;
                    if (!root.committedVideoCover)
                        root.stageVideoThumbnail(liveCover, false);
                    if (!root.videoQuickThemeReady && !root.pendingVideoThemeSource)
                        root.prepareVideoTheme(liveCover, selectedModified);
                }
            }
            if (!root.videoRendererStartPending)
                root.launchSelectedVideoRenderer();
            return;
        }
        videoRendererStartPending = false;
        liveRevealActive = false;
        isTransitionPending = false;
        backendReadyPath = "";
        committedVideoCover = "";
        fallbackVideoThumbnail = "";
        lastVideoFrame = "";
        pendingEnginePreviewSource = "";
        pendingVideoSystemThemePath = "";
        pendingVideoThemeSource = "";
        pendingVideoThumbnail = "";
        videoPaletteReady = false;
        videoPaletteRevealFallback.stop();
        videoQuickThemeReady = false;
        videoQuickThemeFallback.stop();
        videoQuickThemeSettle.stop();
        videoTransitionDeadline.stop();
        resetVideoCoverReadiness();
        liveRevealFinish.stop();
        if (LiveWallpaperService.active || LiveWallpaperService.desiredPath !== "" || EngineWallpaperService.active || EngineWallpaperService.desiredPath !== "") {
            // Keep the old renderer visible underneath the new static image.
            // Wallpaper.qml fades the image in, then reports every screen ready
            // before the renderer is stopped.
            liveRevealActive = true;
            staticTransitionPending = true;
            staticReadyScreens = {};
            staticTransitionFallback.restart();
            stageStatic(path);
            return;
        }
        commitStatic(path);
    }
    function applyTheme(path) {
        ThemeService.generate(path, ThemeService.colorMode, false, themeIdentity());
    }
    function beginPreview() {
        previewPath = "";
        previewActive = true;
    }
    function cancelPreview() {
        previewActive = false;
        previewPath = "";
    }
    function cloneState(state) {
        if (!state)
            return null;
        try {
            return JSON.parse(JSON.stringify(state));
        } catch (error) {
            return state;
        }
    }
    function commitStatic(path) {
        if (!path)
            return;

        stageStatic(path);
        LiveWallpaperService.stop();
        EngineWallpaperService.stop();
    }
    function currentScreenNames() {
        var names = [];
        for (var i = 0; i < Quickshell.screens.length; ++i)
            names.push(String(Quickshell.screens[i].name || ""));
        return names;
    }
    function currentState(thumbnailPath) {
        return {
            "version": 3,
            "path": selectedPath,
            "mode": selectedMode,
            "backend": selectedBackend,
            "renderer": selectedMode === "video" ? selectedRendererPath : "",
            "modified": selectedModified,
            "thumbnail": thumbnailPath || "",
            "frame": lastVideoFrame || ""
        };
    }
    function currentThemeSource() {
        if (selectedMode === "video")
            return committedVideoCover || lastVideoFrame || fallbackVideoThumbnail || pendingVideoThumbnail || "";
        return selectedPath || Config.wallpaper || Config.defaultWallpaper;
    }
    function ensureInitialTheme() {
        if (initialThemeChecked || !StateManager.wallpaperLoaded || !ThemeService.themeFileResolved || !ThemeService.modeResolved)
            return;

        var sourceKey = themeIdentity();
        ThemeService.setExpectedSource(sourceKey);
        if (ThemeService.themeAvailable) {
            initialThemeChecked = true;
            return;
        }
        var source = currentThemeSource();
        if (!source)
            return;
        initialThemeChecked = true;
        ThemeService.generate(source, ThemeService.colorMode, true, sourceKey);
    }
    function finishStaticTransition() {
        if (!staticTransitionPending)
            return;

        resetStaticTransition();
        LiveWallpaperService.stop();
        EngineWallpaperService.stop();
        staticRevealDelay.restart();
    }
    function handleVideoFailure(sourcePath, message) {
        if (selectedMode !== "video" || sourcePath !== selectedPath)
            return;

        var previous = isTransitionPending ? cloneState(transitionRollbackState) : null;
        var restorePreviousVideo = previous && previous.mode === "video" && previous.path && previous.path !== sourcePath;
        var rollback = staticRollbackState(previous || lastStableState);
        console.warn("[WallpaperService] Wallpaper playback failed:", message);
        videoTransitionDeadline.stop();
        videoCoverReadyFallback.stop();
        videoPaletteRevealFallback.stop();
        videoQuickThemeFallback.stop();
        videoQuickThemeSettle.stop();
        liveRevealFinish.stop();
        backendReadyPath = "";
        isTransitionPending = false;
        committedVideoCover = "";
        WallpaperPreviewService.cancel();
        Quickshell.execDetached(["notify-send", "-a", "Wallpaper", "-u", "normal", "-h", "boolean:transient:true", "Wallpaper failed", String(message || "The renderer stopped unexpectedly")]);
        if (restorePreviousVideo) {
            transitionRollbackState = staticRollbackState(previous);
            apply(previous.path, "video", previous.modified, previous.backend, true, previous.renderer);
            if (previous.thumbnail)
                fallbackVideoThumbnail = String(previous.thumbnail);
            if (previous.frame)
                stageVideoFrame(String(previous.frame), false);
            else if (previous.thumbnail)
                stageVideoThumbnail(String(previous.thumbnail), false);
            return;
        }
        apply(rollback.path, "static", rollback.modified);
    }
    function handleWallpaperLoadError(sourcePath) {
        var path = String(sourcePath || "").replace(/^file:\/\//, "");
        if (selectedMode === "video" && path === String(pendingVideoThumbnail || "").replace(/^file:\/\//, "")) {
            if (path === String(Config.defaultWallpaper).replace(/^file:\/\//, "")) {
                handleVideoFailure(selectedPath, "Could not load the fallback wallpaper cover");
                return;
            }
            console.warn("[WallpaperService] Could not load video cover, using the default wallpaper while the renderer starts:", path);
            if (String(lastVideoFrame).replace(/^file:\/\//, "") === path)
                lastVideoFrame = "";
            if (String(fallbackVideoThumbnail).replace(/^file:\/\//, "") === path)
                fallbackVideoThumbnail = Config.defaultWallpaper;
            if (transitionRollbackState && transitionRollbackState.mode === "static" && String(transitionRollbackState.path || "").replace(/^file:\/\//, "") === path)
                transitionRollbackState = staticRollbackState(null);
            pendingEnginePreviewSource = "";
            pendingVideoThemeSource = "";
            committedVideoCover = "";
            resetVideoCoverReadiness();
            stageVideoThumbnail(Config.defaultWallpaper, false);
            if (!videoQuickThemeReady)
                prepareVideoTheme(Config.defaultWallpaper, "0");
            return;
        }
        if (selectedMode !== "static" || path !== String(selectedPath || "").replace(/^file:\/\//, ""))
            return;
        if (selectedPath === Config.defaultWallpaper) {
            console.warn("[WallpaperService] Default wallpaper could not be loaded:", selectedPath);
            return;
        }
        Quickshell.execDetached(["notify-send", "-a", "Wallpaper", "-u", "normal", "-h", "boolean:transient:true", "Wallpaper missing", "Using the default wallpaper instead"]);
        apply(Config.defaultWallpaper, "static", "0");
    }
    function launchSelectedVideoRenderer() {
        if (!isTransitionPending || selectedMode !== "video")
            return;

        if (isEngineVideo) {
            LiveWallpaperService.stop();
            EngineWallpaperService.play(selectedPath, videoTransitionGeneration);
        } else {
            EngineWallpaperService.stop();
            if (!selectedRendererPath) {
                Qt.callLater(() => root.handleVideoFailure(root.selectedPath, "The Wallpaper Engine video project has no supported media file"));
                return;
            }
            LiveWallpaperService.play(selectedRendererPath, videoTransitionGeneration);
        }
    }
    function loadDefaultWallpaper() {
        resetStaticTransition();
        isTransitionPending = false;
        videoRendererStartPending = false;
        transitionRollbackState = null;
        backendReadyPath = "";
        committedVideoCover = "";
        videoTransitionDeadline.stop();
        videoCoverReadyFallback.stop();
        videoPaletteReady = false;
        videoPaletteRevealFallback.stop();
        videoQuickThemeFallback.stop();
        videoQuickThemeSettle.stop();
        selectedPath = Config.defaultWallpaper;
        selectedRendererPath = "";
        selectedMode = "static";
        startupVideoRestore = false;
        selectedModified = "0";
        isEngineVideo = false;
        ThemeService.setExpectedSource(themeIdentity());
        Config.wallpaper = Config.defaultWallpaper;
        lastStableState = currentState("");
        stateReader.setText(JSON.stringify(lastStableState) + "\n");
        LiveWallpaperService.stop();
        EngineWallpaperService.stop();
        StateManager.wallpaperLoaded = true;
    }
    function loadSavedWallpaper(rawText) {
        if (rawText === undefined && !stateReader.loaded)
            return;

        var state = parseState(rawText === undefined ? stateReader.text() : rawText);
        var savedPath = state ? String(state.path || "") : "";
        if (!state || !savedPath) {
            loadDefaultWallpaper();
            return;
        }
        var savedBackend = state.backend === "engine" || state.mode === "engine" ? "engine" : state.backend === "live" || state.mode === "live" ? "live" : "";
        var savedMode = (savedBackend !== "" || state.mode === "video" || LiveWallpaperService.isLivePath(savedPath)) ? "video" : "static";
        var savedRenderer = String(state.renderer || "");
        // A persisted engine backend is already enough to restore a scene.
        // Resolving project.json here delays startup and briefly exposes the
        // default wallpaper before the saved cover can be restored.
        if (savedMode === "video" && savedBackend !== "engine" && EngineWallpaperService.isEnginePath(savedPath) && !LiveWallpaperService.isLivePath(savedRenderer)) {
            var cachedProject = EngineWallpaperService.projectForPath(savedPath);
            if (!cachedProject) {
                videoTransitionGeneration += 1;
                pendingProjectResolution = {
                    "kind": "restore",
                    "path": savedPath,
                    "requestToken": videoTransitionGeneration,
                    "state": state
                };
                EngineWallpaperService.requestProject(savedPath, videoTransitionGeneration);
                return;
            }
        }
        restoreSavedWallpaper(state, EngineWallpaperService.projectForPath(savedPath));
    }
    function markStaticTransitionReady(path, screenName) {
        if (!staticTransitionPending || selectedMode !== "static")
            return;

        var readyPath = String(path || "").replace(/^file:\/\//, "");
        var expectedPath = String(selectedPath || "").replace(/^file:\/\//, "");
        if (!readyPath || readyPath !== expectedPath)
            return;

        var reportedScreen = String(screenName || "");
        var currentScreens = currentScreenNames();
        if (currentScreens.indexOf(reportedScreen) < 0)
            return;

        var nextScreens = {};
        for (var key in staticReadyScreens) {
            if (currentScreens.indexOf(key) >= 0)
                nextScreens[key] = true;
        }
        nextScreens[reportedScreen] = true;
        staticReadyScreens = nextScreens;
        updateStaticTransitionReadiness();
    }
    function markVideoCoverReady(thumbnailPath, screenName) {
        if (!isTransitionPending || selectedMode !== "video" || !pendingVideoThumbnail)
            return;

        var readyPath = String(thumbnailPath || "").replace(/^file:\/\//, "");
        var expectedPath = String(pendingVideoThumbnail || "").replace(/^file:\/\//, "");
        if (!readyPath || readyPath !== expectedPath)
            return;

        var reportedScreen = String(screenName || "");
        var currentScreens = currentScreenNames();
        if (currentScreens.indexOf(reportedScreen) < 0)
            return;

        var nextScreens = {};
        for (var key in coverReadyScreens) {
            if (currentScreens.indexOf(key) >= 0)
                nextScreens[key] = true;
        }
        nextScreens[reportedScreen] = true;
        coverReadyScreens = nextScreens;
        updateVideoCoverReadiness();
    }
    function parseState(rawText) {
        var text = String(rawText || "").trim();
        if (!text)
            return null;

        if (text.startsWith("{")) {
            try {
                return JSON.parse(text);
            } catch (error) {
                console.warn("[WallpaperService] Invalid wallpaper state:", error);
                return null;
            }
        }
        return {
            "path": text,
            "mode": LiveWallpaperService.isLivePath(text) ? "live" : "static",
            "modified": "0"
        };
    }
    function persistedVideoThumbnail() {
        if (fallbackVideoThumbnail)
            return fallbackVideoThumbnail;
        if (lastStableState && lastStableState.mode === "video" && String(lastStableState.path || "") === String(selectedPath || "")) {
            var savedThumbnail = String(lastStableState.thumbnail || "");
            if (savedThumbnail && !EngineWallpaperService.previewNeedsConversion(savedThumbnail))
                return savedThumbnail;
        }
        return "";
    }
    function prepareVideoTheme(path, modified) {
        if (!path || selectedMode !== "video" || videoQuickThemeReady)
            return;

        pendingVideoThemeSource = path;
        WallpaperPreviewService.accept(path, modified, true, videoTransitionGeneration);
    }
    function previewStatic(path) {
        if (!previewActive || !path)
            return;
        previewPath = path;
    }
    function rememberVideoFrame(framePath, updateTheme) {
        if (!framePath)
            return;

        lastVideoFrame = framePath;
        if (updateTheme && !videoQuickThemeReady && !pendingVideoThemeSource)
            prepareVideoTheme(framePath, selectedModified);
    }
    function resetStaticTransition() {
        staticTransitionPending = false;
        staticReadyScreens = {};
        staticTransitionFallback.stop();
    }
    function resetVideoCoverReadiness() {
        coverReadyScreens = {};
        videoCoverReady = false;
        videoCoverReadyFallback.stop();
    }
    function restoreSavedWallpaper(state, projectOverride) {
        var savedPath = String(state.path || "");
        resetStaticTransition();
        var backend = state.backend === "engine" || state.mode === "engine" ? "engine" : state.backend === "live" || state.mode === "live" ? "live" : "";
        var mode = (backend !== "" || state.mode === "video" || LiveWallpaperService.isLivePath(savedPath)) ? "video" : "static";
        var nativeWorkshopVideo = mode === "video" && EngineWallpaperService.isNativeVideoProject(savedPath, projectOverride);
        var savedRenderer = String(state.renderer || "");
        if (nativeWorkshopVideo)
            savedRenderer = EngineWallpaperService.nativeVideoSource(savedPath, projectOverride) || savedRenderer;
        if (mode === "video" && nativeWorkshopVideo)
            backend = "live";
        else if (mode === "video" && backend === "")
            backend = EngineWallpaperService.isEnginePath(savedPath) ? "engine" : "live";
        if (mode === "static")
            backend = "static";
        isEngineVideo = mode === "video" && backend === "engine";
        selectedPath = savedPath;
        selectedMode = mode;
        selectedModified = String(state.modified || "0");
        selectedRendererPath = mode !== "video" ? "" : isEngineVideo ? savedPath : savedRenderer || (EngineWallpaperService.isEnginePath(savedPath) ? "" : savedPath);
        startupVideoRestore = mode === "video";
        lastStableState = {
            "version": 3,
            "path": selectedPath,
            "mode": selectedMode,
            "backend": backend,
            "renderer": selectedRendererPath,
            "modified": selectedModified,
            "thumbnail": String(state.thumbnail || ""),
            "frame": String(state.frame || "")
        };
        ThemeService.setExpectedSource(themeIdentity());
        liveRevealActive = false;
        backendReadyPath = "";
        committedVideoCover = "";
        fallbackVideoThumbnail = "";
        lastVideoFrame = "";
        pendingEnginePreviewSource = "";
        pendingVideoSystemThemePath = "";
        pendingVideoThemeSource = "";
        pendingVideoThumbnail = "";
        videoPaletteReady = mode === "video";
        videoPaletteRevealFallback.stop();
        videoQuickThemeReady = false;
        videoRendererStartPending = false;
        videoQuickThemeFallback.stop();
        videoQuickThemeSettle.stop();
        resetVideoCoverReadiness();

        if (mode === "video") {
            videoTransitionGeneration += 1;
            liveRevealActive = true;
            isTransitionPending = true;
            transitionRollbackState = staticRollbackState(lastStableState);
            if (WallpaperPlaybackPolicy.shouldPause)
                videoTransitionDeadline.stop();
            else
                videoTransitionDeadline.restart();
            // colors.json already belongs to the persisted wallpaper. Do not
            // hold startup playback behind a palette that is already loaded.
            videoQuickThemeReady = true;
            var isEngine = backend === "engine";

            var savedThumbnail = state.thumbnail ? String(state.thumbnail) : "";
            if (savedThumbnail && !EngineWallpaperService.previewNeedsConversion(savedThumbnail))
                fallbackVideoThumbnail = savedThumbnail;
            // Prefer the last renderer frame at startup. Engine frames reach
            // this state only after wallpaper_frame_probe has validated them,
            // and EngineWallpaperService writes the next launch into the
            // opposite slot, so this full-screen cover remains intact until
            // the new renderer is ready. Fall back to the smaller Workshop
            // preview only on the first launch, before a frame exists.
            var restoredFrame = state.frame ? String(state.frame) : "";
            var restoredCover = restoredFrame || fallbackVideoThumbnail;
            if (restoredCover) {
                Config.wallpaper = restoredCover;
                pendingVideoThumbnail = restoredCover;
                lastVideoFrame = restoredFrame;
            }

            if (isEngine) {
                LiveWallpaperService.stop();
                EngineWallpaperService.play(selectedPath, videoTransitionGeneration);
            } else {
                EngineWallpaperService.stop();
                if (!selectedRendererPath) {
                    Qt.callLater(() => root.handleVideoFailure(root.selectedPath, "The Wallpaper Engine video project has no supported media file"));
                } else {
                    LiveWallpaperService.requestCover(selectedRendererPath, selectedModified, true, videoTransitionGeneration);
                    LiveWallpaperService.play(selectedRendererPath, videoTransitionGeneration);
                }
            }
        } else {
            isTransitionPending = false;
            transitionRollbackState = null;
            Config.wallpaper = selectedPath;
            LiveWallpaperService.stop();
            EngineWallpaperService.stop();
        }
        StateManager.wallpaperLoaded = true;
    }
    function saveState(thumbnailPath) {
        var state = currentState(thumbnailPath);
        lastStableState = cloneState(state);
        stateReader.setText(JSON.stringify(state) + "\n");
    }
    function stableHash(value) {
        var text = String(value || "");
        var hash = 2166136261;
        for (var i = 0; i < text.length; ++i) {
            hash ^= text.charCodeAt(i);
            hash = (hash + (hash << 1) + (hash << 4) + (hash << 7) + (hash << 8) + (hash << 24)) >>> 0;
        }
        return ("00000000" + hash.toString(16)).slice(-8);
    }
    function stageStatic(path) {
        if (!path)
            return;

        Config.wallpaper = path;
        cancelPreview();
        saveState("");
        WallpaperPreviewService.accept(path, selectedModified);
    }
    function stageVideoFrame(framePath, updateTheme) {
        if (!framePath)
            return;
        lastVideoFrame = framePath;
        stageVideoThumbnail(framePath, updateTheme);
    }
    function stageVideoThumbnail(thumbnailPath, updateTheme) {
        if (selectedMode !== "video" || !thumbnailPath)
            return;

        if (pendingVideoThumbnail !== thumbnailPath)
            resetVideoCoverReadiness();
        pendingVideoThumbnail = thumbnailPath;
        var wallpaperChanged = Config.wallpaper !== thumbnailPath;
        if (wallpaperChanged)
            Config.wallpaper = thumbnailPath;
        liveRevealActive = true;
        if (wallpaperChanged && updateTheme && !videoQuickThemeReady && !pendingVideoThemeSource)
            prepareVideoTheme(thumbnailPath, selectedModified);
        ensureInitialTheme();
        videoCoverReadyFallback.restart();
        tryFinishVideoTransition();
    }
    function startDeferredVideoRenderer() {
        if (!videoRendererStartPending || !videoCoverReady || !isTransitionPending || selectedMode !== "video")
            return;

        videoRendererStartPending = false;
        launchSelectedVideoRenderer();
    }
    function staticRollbackState(state) {
        if (state && state.mode === "static" && state.path) {
            return {
                "version": 3,
                "path": String(state.path),
                "mode": "static",
                "backend": "static",
                "renderer": "",
                "modified": String(state.modified || "0"),
                "thumbnail": "",
                "frame": ""
            };
        }
        var cover = state && (state.frame || state.thumbnail) ? String(state.frame || state.thumbnail) : lastVideoFrame || fallbackVideoThumbnail || Config.defaultWallpaper;
        return {
            "version": 3,
            "path": cover || Config.defaultWallpaper,
            "mode": "static",
            "backend": "static",
            "renderer": "",
            "modified": "0",
            "thumbnail": "",
            "frame": ""
        };
    }
    function themeIdentity() {
        var identity = selectedMode + "|" + selectedBackend + "|" + String(selectedPath || "") + "|" + String(selectedModified || "0");
        return "v1-" + stableHash("theme-source|" + identity) + "-" + stableHash(identity + "|theme-source");
    }
    function tryFinishVideoTransition() {
        if (selectedMode !== "video" || backendReadyPath !== selectedPath || (pendingVideoThumbnail !== "" && !videoCoverReady))
            return;
        if (!videoPaletteReady) {
            if (!videoPaletteRevealFallback.running)
                videoPaletteRevealFallback.restart();
            return;
        }

        backendReadyPath = "";
        videoTransitionDeadline.stop();
        videoCoverReadyFallback.stop();
        videoPaletteRevealFallback.stop();
        isTransitionPending = false;
        saveState(persistedVideoThumbnail() || pendingVideoThumbnail);
        committedVideoCover = "";
        transitionRollbackState = null;
        liveRevealActive = true;
        // Video transitions use a short capped fade so the cover cannot linger
        // when the general wallpaper duration is configured very high.
        liveRevealFinish.interval = Math.max(380, Math.min(440, Config.wallpaperTransitionDuration + 80));
        liveRevealFinish.restart();
    }
    function updateStaticTransitionReadiness() {
        if (!staticTransitionPending || selectedMode !== "static")
            return;

        var names = currentScreenNames();
        var nextScreens = {};
        var allReady = names.length > 0;
        for (var i = 0; i < names.length; ++i) {
            var name = names[i];
            if (staticReadyScreens[name] === true)
                nextScreens[name] = true;
            else
                allReady = false;
        }
        staticReadyScreens = nextScreens;
        if (allReady)
            finishStaticTransition();
    }
    function updateVideoCoverReadiness() {
        if (!isTransitionPending || selectedMode !== "video")
            return;
        var names = currentScreenNames();
        var nextScreens = {};
        var allReady = names.length > 0;
        for (var i = 0; i < names.length; ++i) {
            var name = names[i];
            if (coverReadyScreens[name] === true)
                nextScreens[name] = true;
            else
                allReady = false;
        }
        coverReadyScreens = nextScreens;
        if (allReady) {
            videoCoverReady = true;
            videoCoverReadyFallback.stop();
            startDeferredVideoRenderer();
            tryFinishVideoTransition();
        }
    }
}
