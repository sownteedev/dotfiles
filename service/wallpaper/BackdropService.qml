pragma Singleton
import "../../"
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property bool _generateQueued: false
    property string activeBackdrop: ""
    property string activeRequestKey: ""
    readonly property string cacheDir: Config.cacheRoot + "/backdrops"
    property Connections configConnections: Connections {
        function onWallpaperChanged() {
            if (StateManager.wallpaperLoaded)
                root.scheduleGenerate();
        }

        target: Config
    }
    property string generatedBackdrop: ""
    property bool generationCanCreate: true
    property string generationIdentity: ""
    property bool generationPending: false
    property string generationRequestKey: ""
    property int generationSerial: 0
    property string generationSource: ""
    property Timer generationStart: Timer {
        interval: 60
        repeat: false

        onTriggered: root.startPendingGeneration()
    }
    property Process generator: Process {
        property int jobSerial: 0

        stdout: StdioCollector {
            onStreamFinished: {
                if (generator.jobSerial === root.generationSerial)
                    root.generatedBackdrop = text.trim();
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (root.generationPending) {
                root.generationStart.restart();
                return;
            }
            if (jobSerial !== root.generationSerial)
                return;

            if (exitCode === 0 && root.generatedBackdrop !== "") {
                root.activeBackdrop = root.generatedBackdrop;
                root.activeRequestKey = root.generationRequestKey;
                root.ready = true;
            } else if (root.generationCanCreate) {
                console.warn("[BackdropService] Failed to generate cached backdrop for", root.generationSource);
            }
        }
    }
    readonly property string generatorScript: Config.quickshellDir + "/backend/python/wallpaper/backdrop_cache.py"
    property Connections globalConnections: Connections {
        function onWallpaperLoadedChanged() {
            if (StateManager.wallpaperLoaded)
                root.scheduleGenerate();
        }

        target: StateManager
    }
    property bool pendingCanCreate: true
    property string pendingIdentity: ""
    property string pendingRequestKey: ""
    property string pendingSource: ""
    property bool ready: false
    property Connections wallpaperConnections: Connections {
        function onCurrentModeChanged() {
            root.scheduleGenerate();
        }
        function onDisplayWallpaperChanged() {
            root.scheduleGenerate();
        }
        function onFallbackVideoThumbnailChanged() {
            root.scheduleGenerate();
        }
        function onLastVideoFrameChanged() {
            root.scheduleGenerate();
        }
        function onSelectedModifiedChanged() {
            root.scheduleGenerate();
        }

        target: WallpaperService
    }

    function _doGenerate() {
        _generateQueued = false;
        generate();
    }
    function canCreateCurrentBackdrop() {
        if (WallpaperService.currentMode !== "video")
            return true;
        if (!WallpaperService.isEngineVideo)
            return WallpaperService.lastVideoFrame !== "" || WallpaperService.fallbackVideoThumbnail !== "";
        return WallpaperService.lastVideoFrame !== "";
    }
    function currentIdentity(source) {
        if (WallpaperService.currentMode === "video")
            return "video|" + WallpaperService.currentWallpaper + "|" + String(WallpaperService.selectedModified || "0");
        return "";
    }
    function currentRequestKey(source, identity, canCreate) {
        return String(identity || source) + "|" + String(source) + "|" + String(canCreate);
    }
    function currentSource() {
        // Workshop previews are not guaranteed to match the monitor aspect
        // ratio. They may only be used to look up an existing per-video cache;
        // creation waits for the validated full renderer frame.
        if (WallpaperService.currentMode === "video")
            return WallpaperService.lastVideoFrame || WallpaperService.fallbackVideoThumbnail;
        return WallpaperService.displayWallpaper || Config.wallpaper;
    }
    function generate() {
        if (!StateManager.wallpaperLoaded)
            return;

        var source = currentSource();
        if (source === "")
            return;
        var identity = currentIdentity(source);
        var canCreate = canCreateCurrentBackdrop();
        var requestKey = currentRequestKey(source, identity, canCreate);
        if (requestKey === activeRequestKey && ready)
            return;
        if (requestKey === pendingRequestKey && (generationPending || generator.running))
            return;

        pendingSource = source;
        pendingIdentity = identity;
        pendingCanCreate = canCreate;
        pendingRequestKey = requestKey;
        generationPending = true;
        generationStart.restart();
    }
    function scheduleGenerate() {
        if (!_generateQueued) {
            _generateQueued = true;
            Qt.callLater(_doGenerate);
        }
    }
    function startPendingGeneration() {
        if (!generationPending)
            return;

        if (generator.running) {
            generationStart.restart();
            return;
        }
        generationPending = false;
        generationSource = pendingSource;
        generationIdentity = pendingIdentity;
        generationCanCreate = pendingCanCreate;
        generationRequestKey = pendingRequestKey;
        ++generationSerial;
        generatedBackdrop = "";
        generator.jobSerial = generationSerial;
        generator.command = ["python3", generatorScript, generationSource, cacheDir, generationIdentity, generationCanCreate ? "true" : "false"];
        generator.running = true;
    }

    Component.onCompleted: {
        if (StateManager.wallpaperLoaded)
            generate();
    }
}
