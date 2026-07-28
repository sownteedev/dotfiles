pragma Singleton
import "../../"
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string backendReadyPath: ""
    property var coverReadyScreens: ({})
    readonly property string currentMode: selectedMode
    readonly property string currentWallpaper: selectedPath
    readonly property string displayWallpaper: previewActive && previewPath ? previewPath : Config.wallpaper
    property Connections engineConnections: Connections {
        function onPlaybackReady(sourcePath, framePath) {
            if (root.isTransitionPending && root.selectedMode === "video" && root.isEngineVideo && sourcePath === root.selectedPath) {
                root.backendReadyPath = sourcePath;
                if (framePath)
                    root.stageVideoFrame(framePath, true);
                else if (root.fallbackVideoThumbnail && !root.pendingVideoThumbnail)
                    root.stageVideoThumbnail(root.fallbackVideoThumbnail, true);
                root.tryFinishVideoTransition();
            }
        }
        function onPreviewThumbnailReady(sourcePath, thumbnailPath) {
            if (root.isTransitionPending && root.selectedMode === "video" && root.isEngineVideo && sourcePath === root.pendingEnginePreviewSource) {
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
    property string lastVideoFrame: ""
    property Connections liveConnections: Connections {
        function onPlaybackReady(sourcePath, framePath) {
            if (root.isTransitionPending && root.selectedMode === "video" && !root.isEngineVideo && sourcePath === root.selectedPath) {
                root.backendReadyPath = sourcePath;
                if (framePath)
                    root.stageVideoFrame(framePath, true);
                else if (root.fallbackVideoThumbnail && !root.pendingVideoThumbnail)
                    root.stageVideoThumbnail(root.fallbackVideoThumbnail, true);
                root.tryFinishVideoTransition();
            }
        }
        function onThumbnailReady(sourcePath, thumbnailPath) {
            var expectedPath = "";
            var isValid = false;

            if (root.selectedMode === "video" && !root.isEngineVideo) {
                expectedPath = LiveWallpaperService.thumbnailPath(root.selectedPath, root.selectedModified);
                isValid = true;
            }

            if (!isValid || thumbnailPath !== expectedPath)
                return;

            root.fallbackVideoThumbnail = thumbnailPath;
            root.saveState(thumbnailPath);
            if (root.isTransitionPending && !root.videoQuickThemeReady && !root.pendingVideoThemeSource)
                root.prepareVideoTheme(thumbnailPath, root.selectedModified);
            if (root.backendReadyPath === root.selectedPath && !root.pendingVideoThumbnail)
                root.stageVideoThumbnail(thumbnailPath, true);
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
    property bool previewActive: false
    property Connections previewConnections: Connections {
        function onThemeSourceReady(sourcePath, thumbnailPath) {
            if (root.selectedMode === "static" && root.selectedPath === sourcePath) {
                root.applyTheme(thumbnailPath);
                return;
            }
            if (root.selectedMode === "video" && root.isTransitionPending && sourcePath === root.pendingVideoThemeSource) {
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
    property string selectedMode: LiveWallpaperService.isLivePath(Config.wallpaper) ? "live" : "static"
    property string selectedModified: "0"
    property string selectedPath: Config.wallpaper
    readonly property string statePath: Config.homeDir + "/.cache/quickshell/quickshell_wallpaper.txt"
    property FileView stateReader: FileView {
        blockLoading: true
        path: root.statePath
        // This file is owned by WallpaperService. Watching our own asynchronous
        // writes used to reload a half-transitioned state and could leave the
        // service in "static" mode while mpvpaper was already playing.
        watchChanges: false

        onLoadFailed: {
            root.selectedPath = Config.wallpaper;
            root.selectedMode = "static";
            StateManager.wallpaperLoaded = true;
            root.ensureInitialTheme();
        }
        onLoadedChanged: {
            if (loaded) {
                root.loadSavedWallpaper();
                root.ensureInitialTheme();
            }
        }
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
        function onThemeFileResolvedChanged() {
            root.ensureInitialTheme();
        }

        target: ThemeService
    }
    property bool videoCoverReady: false
    property Timer videoCoverReadyFallback: Timer {
        interval: 2800
        repeat: false

        onTriggered: {
            if (root.isTransitionPending && root.pendingVideoThumbnail) {
                console.warn("[WallpaperService] Video cover readiness timed out, continuing with loaded fallback");
                root.videoCoverReady = true;
                root.tryFinishVideoTransition();
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
    property int videoTransitionGeneration: 0

    function apply(path, mode, modified) {
        if (!path)
            return;

        var nextMode = mode === "video" ? "video" : "static";
        selectedPath = path;
        selectedMode = nextMode;
        selectedModified = LiveWallpaperService.modifiedKey(modified);
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
            root.resetVideoCoverReadiness();

            var isEngine = EngineWallpaperService.isEnginePath(path);
            root.isEngineVideo = isEngine;
            // Both renderers are stopped before the new one is launched. The
            // opaque desktop cover remains visible while the new frame loads.
            LiveWallpaperService.stop();
            EngineWallpaperService.stop();

            if (isEngine) {
                var project = EngineWallpaperService.projectForPath(path) || {};
                var preview = project.preview || "";
                root.fallbackVideoThumbnail = preview || Config.wallpaper;
                root.saveState(root.fallbackVideoThumbnail);
                if (preview) {
                    if (EngineWallpaperService.previewNeedsConversion(preview)) {
                        root.pendingEnginePreviewSource = preview;
                        var engineThumbnail = EngineWallpaperService.requestPreviewThumbnail(preview, selectedModified, true);
                        if (EngineWallpaperService.previewThumbnailKnown(preview, selectedModified)) {
                            root.pendingEnginePreviewSource = "";
                            root.prepareVideoTheme(engineThumbnail, selectedModified);
                        }
                    } else {
                        root.prepareVideoTheme(preview, selectedModified);
                    }
                }

                EngineWallpaperService.play(path);
            } else {
                var liveThumbnail = LiveWallpaperService.requestThumbnail(path, selectedModified, true);
                root.fallbackVideoThumbnail = liveThumbnail;
                root.saveState(liveThumbnail);
                LiveWallpaperService.play(path);
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
        ThemeService.generate(path);
    }
    function beginPreview() {
        previewPath = "";
        previewActive = true;
    }
    function cancelPreview() {
        previewActive = false;
        previewPath = "";
    }
    function commitStatic(path) {
        if (!path)
            return;

        stageStatic(path);
        LiveWallpaperService.stop();
        EngineWallpaperService.stop();
    }
    function ensureInitialTheme() {
        if (initialThemeChecked || !StateManager.wallpaperLoaded || !ThemeService.themeFileResolved)
            return;

        initialThemeChecked = true;
        if (!ThemeService.themeAvailable)
            applyTheme(Config.wallpaper);
    }
    function loadSavedWallpaper() {
        if (!stateReader.loaded)
            return;

        var state = parseState(stateReader.text());
        if (!state || !state.path) {
            selectedPath = Config.wallpaper;
            selectedMode = "static";
            StateManager.wallpaperLoaded = true;
            return;
        }
        var mode = (state.mode === "engine" || state.mode === "live" || state.mode === "video" || LiveWallpaperService.isLivePath(state.path)) ? "video" : "static";
        selectedPath = state.path;
        selectedMode = mode;
        selectedModified = String(state.modified || "0");
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
            // colors.json already belongs to the persisted wallpaper. Do not
            // hold startup playback behind a palette that is already loaded.
            videoQuickThemeReady = true;
            var isEngine = EngineWallpaperService.isEnginePath(selectedPath);
            root.isEngineVideo = isEngine;

            if (state.thumbnail) {
                fallbackVideoThumbnail = String(state.thumbnail);
            }
            var restoredCover = state.frame ? String(state.frame) : fallbackVideoThumbnail;
            if (restoredCover) {
                Config.wallpaper = restoredCover;
                pendingVideoThumbnail = restoredCover;
                lastVideoFrame = state.frame ? String(state.frame) : "";
            }

            if (isEngine) {
                LiveWallpaperService.stop();
                EngineWallpaperService.play(selectedPath);
            } else {
                EngineWallpaperService.stop();
                LiveWallpaperService.requestThumbnail(selectedPath, selectedModified, true);
                LiveWallpaperService.play(selectedPath);
            }
        } else {
            isTransitionPending = false;
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

        var nextScreens = {};
        for (var key in coverReadyScreens)
            nextScreens[key] = coverReadyScreens[key];
        nextScreens[String(screenName || "default")] = true;
        coverReadyScreens = nextScreens;

        var readyCount = Object.keys(nextScreens).length;
        var expectedCount = Math.max(1, Quickshell.screens.length);
        if (readyCount >= expectedCount) {
            videoCoverReady = true;
            videoCoverReadyFallback.stop();
            tryFinishVideoTransition();
        }
    }
    function parseState(rawText) {
        var text = String(rawText || "").trim();
        if (!text)
            return null;

        if (text.startsWith("{")) {
            try {
                return JSON.parse(text);
            } catch (error) {
                console.warn("[WallpaperService] Invalid wallpaper state, using legacy path:", error);
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
        WallpaperPreviewService.accept(path, modified, true);
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
        var state = JSON.stringify({
            "path": selectedPath,
            "mode": selectedMode,
            "modified": selectedModified,
            "thumbnail": thumbnailPath || "",
            "frame": lastVideoFrame || ""
        });
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$2\" && printf '%s' \"$1\" > \"$3\"", "wallpaper-save", state, Config.homeDir + "/.cache/quickshell", statePath]);
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
        saveState(fallbackVideoThumbnail || thumbnailPath);
        if (wallpaperChanged && updateTheme && !videoQuickThemeReady && !pendingVideoThemeSource)
            prepareVideoTheme(thumbnailPath, selectedModified);
        videoCoverReadyFallback.restart();
        tryFinishVideoTransition();
    }
    function tryFinishVideoTransition() {
        if (selectedMode !== "video" || backendReadyPath !== selectedPath || !pendingVideoThumbnail || !videoCoverReady || !videoQuickThemeReady)
            return;

        backendReadyPath = "";
        videoCoverReadyFallback.stop();
        videoQuickThemeFallback.stop();
        videoQuickThemeSettle.stop();
        isTransitionPending = false;
        liveRevealActive = true;
        liveRevealFinish.interval = 420;
        liveRevealFinish.restart();
    }
}
