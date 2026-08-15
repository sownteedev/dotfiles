pragma Singleton
import "../../"
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string backendReadyPath: ""
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
            if (generation === root.videoTransitionGeneration && root.isTransitionPending && root.selectedMode === "video" && root.isEngineVideo && sourcePath === root.selectedPath) {
                root.backendReadyPath = sourcePath;
                if (framePath)
                    root.stageVideoFrame(framePath, true);
                else if (root.fallbackVideoThumbnail && !root.pendingVideoThumbnail)
                    root.stageVideoThumbnail(root.fallbackVideoThumbnail, true);
                root.tryFinishVideoTransition();
            }
        }
        function onPreviewThumbnailReady(sourcePath, thumbnailPath, requestToken) {
            if (requestToken === root.videoTransitionGeneration && root.isTransitionPending && root.selectedMode === "video" && root.isEngineVideo && sourcePath === root.pendingEnginePreviewSource) {
                root.pendingEnginePreviewSource = "";
                root.prepareVideoTheme(thumbnailPath, root.selectedModified);
            }
        }

        target: EngineWallpaperService
    }
    property string fallbackVideoThumbnail: ""
    property bool initialThemeChecked: false
    property bool isEngineVideo: false
    property bool isTransitionPending: false
    property var lastStableState: ({
            "version": 2,
            "path": Config.defaultWallpaper,
            "mode": "static",
            "backend": "static",
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
            if (generation === root.videoTransitionGeneration)
                root.handleVideoFailure(sourcePath, message);
        }
        function onPlaybackReady(sourcePath, framePath, generation) {
            if (generation === root.videoTransitionGeneration && root.isTransitionPending && root.selectedMode === "video" && !root.isEngineVideo && sourcePath === root.selectedPath) {
                root.backendReadyPath = sourcePath;
                if (framePath)
                    root.stageVideoFrame(framePath, true);
                else if (root.fallbackVideoThumbnail && !root.pendingVideoThumbnail)
                    root.stageVideoThumbnail(root.fallbackVideoThumbnail, true);
                root.tryFinishVideoTransition();
            }
        }
        function onThumbnailReady(sourcePath, thumbnailPath, requestToken) {
            var expectedPath = "";
            var isValid = false;

            if (root.selectedMode === "video" && !root.isEngineVideo) {
                expectedPath = LiveWallpaperService.thumbnailPath(root.selectedPath, root.selectedModified);
                isValid = true;
            }

            if (!isValid || thumbnailPath !== expectedPath || root.isTransitionPending && requestToken !== root.videoTransitionGeneration)
                return;

            root.fallbackVideoThumbnail = thumbnailPath;
            if (root.isTransitionPending && !root.pendingVideoThumbnail)
                root.stageVideoThumbnail(thumbnailPath, false);
            if (root.isTransitionPending && !root.videoQuickThemeReady && !root.pendingVideoThemeSource)
                root.prepareVideoTheme(thumbnailPath, root.selectedModified);
        }

        target: LiveWallpaperService
    }
    property bool liveRevealActive: false
    property Timer liveRevealFinish: Timer {
        id: liveRevealFinish

        onTriggered: {
            root.liveRevealActive = false;
        }
    }
    property string pendingEnginePreviewSource: ""
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
            if (requestToken === root.videoTransitionGeneration && root.selectedMode === "video" && root.isTransitionPending && sourcePath === root.pendingVideoThemeSource) {
                root.pendingVideoThemeSource = "";
                root.pendingVideoSystemThemePath = thumbnailPath;
                // The cached Quickshell palette is already animating. Let that
                // settle before generating GTK/Qt/application themes.
                root.videoQuickThemeSettle.restart();
            }
        }

        target: WallpaperPreviewService
    }
    property string previewPath: ""
    readonly property bool ready: StateManager.wallpaperLoaded
    property Connections screenConnections: Connections {
        function onScreensChanged() {
            root.updateVideoCoverReadiness();
        }

        target: Quickshell
    }
    readonly property string selectedBackend: selectedMode === "video" ? (isEngineVideo ? "engine" : "live") : "static"
    property string selectedMode: LiveWallpaperService.isLivePath(Config.wallpaper) ? "video" : "static"
    property string selectedModified: "0"
    property string selectedPath: Config.wallpaper
    readonly property string statePath: Config.cacheRoot + "/quickshell_wallpaper.txt"
    property FileView stateReader: FileView {
        atomicWrites: true
        blockLoading: true
        blockWrites: true
        path: root.statePath
        // This file is owned by WallpaperService. Watching our own writes can
        // re-enter a half-transitioned state and could leave the
        // service in "static" mode while mpvpaper was already playing.
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
                    root.tryFinishVideoTransition();
                } else {
                    console.warn("[WallpaperService] Video cover has not loaded yet, waiting for the transition deadline");
                }
            }
        }
    }
    property Timer videoQuickThemeFallback: Timer {
        interval: 4500
        repeat: false

        onTriggered: {
            if (!root.isTransitionPending || root.selectedMode !== "video" || root.videoQuickThemeReady)
                return;
            console.warn("[WallpaperService] Video palette preparation timed out, continuing with the available theme source");
            root.pendingEnginePreviewSource = "";
            root.pendingVideoThemeSource = "";
            root.videoQuickThemeSettle.stop();
            root.videoQuickThemeReady = true;
            var source = root.pendingVideoSystemThemePath || root.fallbackVideoThumbnail || root.pendingVideoThumbnail;
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
            if (!root.isTransitionPending || root.selectedMode !== "video")
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

    function apply(path, mode, modified, backendOverride, preserveRollback) {
        if (!path)
            return;

        var nextMode = mode === "video" ? "video" : "static";
        var nextModified = LiveWallpaperService.modifiedKey(modified);
        if (nextMode === selectedMode && String(path) === String(selectedPath) && nextModified === selectedModified) {
            // Selecting the current wallpaper is a commit of the selector
            // preview, not a renderer restart. stop() followed immediately by
            // play() is asynchronous and can otherwise make the old process
            // exit look like a crash when both paths are identical.
            cancelPreview();
            WallpaperPreviewService.cancel();
            return;
        }
        if (nextMode === "video") {
            if (preserveRollback !== true)
                transitionRollbackState = cloneState(lastStableState);
        } else {
            transitionRollbackState = null;
        }
        selectedPath = path;
        selectedMode = nextMode;
        selectedModified = nextModified;
        var nextIsEngine = nextMode === "video" && (backendOverride === "engine" ? true : backendOverride === "live" ? false : EngineWallpaperService.isEnginePath(path));
        isEngineVideo = nextIsEngine;
        ThemeService.setExpectedSource(themeIdentity());
        if (nextMode === "video") {
            videoTransitionGeneration += 1;
            cancelPreview();
            WallpaperPreviewService.cancel();
            staticRevealDelay.stop();
            liveRevealActive = true;
            root.isTransitionPending = true;
            root.backendReadyPath = "";
            root.fallbackVideoThumbnail = "";
            root.lastVideoFrame = "";
            root.pendingEnginePreviewSource = "";
            root.pendingVideoSystemThemePath = "";
            root.pendingVideoThemeSource = "";
            root.pendingVideoThumbnail = "";
            root.videoQuickThemeReady = false;
            root.videoQuickThemeSettle.stop();
            root.videoQuickThemeFallback.restart();
            if (WallpaperPlaybackPolicy.shouldPause)
                root.videoTransitionDeadline.stop();
            else
                root.videoTransitionDeadline.restart();
            root.resetVideoCoverReadiness();

            // Both renderers are stopped before the new one is launched. The
            // opaque desktop cover remains visible while the new frame loads.
            LiveWallpaperService.stop();
            EngineWallpaperService.stop();

            if (nextIsEngine) {
                var project = EngineWallpaperService.projectForPath(path) || {};
                var preview = project.preview || "";
                root.fallbackVideoThumbnail = preview || Config.wallpaper;
                if (preview) {
                    // The Workshop preview is already available locally. Use
                    // it as the temporary desktop cover while the renderer
                    // starts. BackdropService deliberately waits for the
                    // validated full-screen frame because this preview can be
                    // square or use a different crop.
                    root.stageVideoThumbnail(preview, false);
                    if (EngineWallpaperService.previewNeedsConversion(preview)) {
                        root.pendingEnginePreviewSource = preview;
                        var engineThumbnail = EngineWallpaperService.requestPreviewThumbnail(preview, selectedModified, true, videoTransitionGeneration);
                        if (EngineWallpaperService.previewThumbnailKnown(preview, selectedModified)) {
                            root.pendingEnginePreviewSource = "";
                            root.prepareVideoTheme(engineThumbnail, selectedModified);
                        }
                    } else {
                        root.prepareVideoTheme(preview, selectedModified);
                    }
                }

                EngineWallpaperService.play(path, videoTransitionGeneration);
            } else {
                var liveThumbnail = LiveWallpaperService.requestThumbnail(path, selectedModified, true, videoTransitionGeneration);
                root.fallbackVideoThumbnail = liveThumbnail;
                if (LiveWallpaperService.thumbnailKnown(path, selectedModified))
                    root.stageVideoThumbnail(liveThumbnail, false);
                LiveWallpaperService.play(path, videoTransitionGeneration);
            }
            return;
        }
        liveRevealActive = false;
        isTransitionPending = false;
        backendReadyPath = "";
        fallbackVideoThumbnail = "";
        lastVideoFrame = "";
        pendingEnginePreviewSource = "";
        pendingVideoSystemThemePath = "";
        pendingVideoThemeSource = "";
        pendingVideoThumbnail = "";
        videoQuickThemeReady = false;
        videoQuickThemeFallback.stop();
        videoQuickThemeSettle.stop();
        videoTransitionDeadline.stop();
        resetVideoCoverReadiness();
        liveRevealFinish.stop();
        if (LiveWallpaperService.active || LiveWallpaperService.desiredPath !== "" || EngineWallpaperService.active || EngineWallpaperService.desiredPath !== "") {
            // Show the new static image immediately while it safely covers the
            // old renderer. The video processes are stopped underneath it.
            liveRevealActive = true;
            stageStatic(path);
            LiveWallpaperService.stop();
            EngineWallpaperService.stop();
            staticRevealDelay.restart();
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
            "version": 2,
            "path": selectedPath,
            "mode": selectedMode,
            "backend": selectedBackend,
            "modified": selectedModified,
            "thumbnail": thumbnailPath || "",
            "frame": lastVideoFrame || ""
        };
    }
    function currentThemeSource() {
        if (selectedMode === "video")
            return lastVideoFrame || fallbackVideoThumbnail || pendingVideoThumbnail || "";
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
    function handleVideoFailure(sourcePath, message) {
        if (selectedMode !== "video" || sourcePath !== selectedPath)
            return;

        var previous = isTransitionPending ? cloneState(transitionRollbackState) : null;
        var restorePreviousVideo = previous && previous.mode === "video" && previous.path && previous.path !== sourcePath;
        var rollback = staticRollbackState(previous || lastStableState);
        console.warn("[WallpaperService] Wallpaper playback failed:", message);
        videoTransitionDeadline.stop();
        videoCoverReadyFallback.stop();
        videoQuickThemeFallback.stop();
        videoQuickThemeSettle.stop();
        liveRevealFinish.stop();
        backendReadyPath = "";
        isTransitionPending = false;
        WallpaperPreviewService.cancel();
        Quickshell.execDetached(["notify-send", "-a", "Wallpaper", "-u", "normal", "-h", "boolean:transient:true", "Wallpaper failed", String(message || "The renderer stopped unexpectedly")]);
        if (restorePreviousVideo) {
            transitionRollbackState = staticRollbackState(previous);
            apply(previous.path, "video", previous.modified, previous.backend, true);
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
    function loadDefaultWallpaper() {
        isTransitionPending = false;
        transitionRollbackState = null;
        backendReadyPath = "";
        videoTransitionDeadline.stop();
        videoCoverReadyFallback.stop();
        videoQuickThemeFallback.stop();
        videoQuickThemeSettle.stop();
        selectedPath = Config.defaultWallpaper;
        selectedMode = "static";
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
        var backend = state.backend === "engine" || state.mode === "engine" ? "engine" : state.backend === "live" || state.mode === "live" ? "live" : "";
        var mode = (backend !== "" || state.mode === "video" || LiveWallpaperService.isLivePath(savedPath)) ? "video" : "static";
        if (mode === "video" && backend === "")
            backend = EngineWallpaperService.isEnginePath(savedPath) ? "engine" : "live";
        if (mode === "static")
            backend = "static";
        isEngineVideo = mode === "video" && backend === "engine";
        selectedPath = savedPath;
        selectedMode = mode;
        selectedModified = String(state.modified || "0");
        lastStableState = {
            "version": 2,
            "path": selectedPath,
            "mode": selectedMode,
            "backend": backend,
            "modified": selectedModified,
            "thumbnail": String(state.thumbnail || ""),
            "frame": String(state.frame || "")
        };
        ThemeService.setExpectedSource(themeIdentity());
        liveRevealActive = false;
        backendReadyPath = "";
        fallbackVideoThumbnail = "";
        lastVideoFrame = "";
        pendingEnginePreviewSource = "";
        pendingVideoSystemThemePath = "";
        pendingVideoThemeSource = "";
        pendingVideoThumbnail = "";
        videoQuickThemeReady = false;
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

            if (state.thumbnail) {
                fallbackVideoThumbnail = String(state.thumbnail);
            }
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
                LiveWallpaperService.requestThumbnail(selectedPath, selectedModified, true, videoTransitionGeneration);
                LiveWallpaperService.play(selectedPath, videoTransitionGeneration);
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
    function prepareVideoTheme(path, modified) {
        if (!path || selectedMode !== "video" || !isTransitionPending || videoQuickThemeReady)
            return;

        pendingVideoThemeSource = path;
        WallpaperPreviewService.accept(path, modified, true, videoTransitionGeneration);
    }
    function previewStatic(path) {
        if (!previewActive || !path)
            return;
        previewPath = path;
    }
    function resetVideoCoverReadiness() {
        coverReadyScreens = {};
        videoCoverReady = false;
        videoCoverReadyFallback.stop();
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
        if (wallpaperChanged && updateTheme && !videoQuickThemeReady && !pendingVideoThemeSource)
            prepareVideoTheme(thumbnailPath, selectedModified);
        ensureInitialTheme();
        videoCoverReadyFallback.restart();
        tryFinishVideoTransition();
    }
    function staticRollbackState(state) {
        if (state && state.mode === "static" && state.path) {
            return {
                "version": 2,
                "path": String(state.path),
                "mode": "static",
                "backend": "static",
                "modified": String(state.modified || "0"),
                "thumbnail": "",
                "frame": ""
            };
        }
        var cover = state && (state.frame || state.thumbnail) ? String(state.frame || state.thumbnail) : lastVideoFrame || fallbackVideoThumbnail || Config.defaultWallpaper;
        return {
            "version": 2,
            "path": cover || Config.defaultWallpaper,
            "mode": "static",
            "backend": "static",
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
        if (selectedMode !== "video" || backendReadyPath !== selectedPath || !pendingVideoThumbnail || !videoCoverReady || !videoQuickThemeReady)
            return;

        backendReadyPath = "";
        videoTransitionDeadline.stop();
        videoCoverReadyFallback.stop();
        videoQuickThemeFallback.stop();
        videoQuickThemeSettle.stop();
        isTransitionPending = false;
        saveState(fallbackVideoThumbnail || pendingVideoThumbnail);
        transitionRollbackState = null;
        liveRevealActive = true;
        liveRevealFinish.interval = 420;
        liveRevealFinish.restart();
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
            tryFinishVideoTransition();
        }
    }
}
