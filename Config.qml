pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: configRoot

    // Weather
    // Private values are loaded from XDG_CACHE_HOME/quickshell/settings.json.
    // Keep public source defaults empty so this repository is safe to share.
    property string apiWeather: ""
    // Pre-defined alpha variants (0.8 opacity)
    property bool captureAutoCopyRecording: true
    property bool captureAutoCopyScreenshot: true
    property string captureEditorColor: "#ff3b30"
    property string captureEditorTool: "pen"
    property int captureEditorWidth: 6
    property string captureRecordingCodec: "hevc"
    readonly property string captureRecordingDir: expandHomePath(captureRecordingDirPath)
    property string captureRecordingDirPath: "~/Videos"
    property int captureRecordingFps: 60
    property string captureRecordingQuality: "high"
    readonly property string captureScreenshotDir: expandHomePath(captureScreenshotDirPath)
    property string captureScreenshotDirPath: "~/Pictures/Screenshots"
    property bool clock24h: true
    readonly property string dotfilesDir: dotfilesRoot + "/dotf"
    readonly property string dotfilesRoot: homeDir + "/Dotfiles"
    // Font
    property string fontName: "Inter"
    // Paths
    readonly property string homeDir: Quickshell.env("HOME")
    property string latLon: ""
    readonly property string legacyWallpaperEngineWorkshopDir: homeDir + "/.steam/steam/steamapps/workshop/content/431960"
    readonly property string liveWallFolder: expandHomePath(liveWallFolderPath)
    property string liveWallFolderPath: "~/Dotfiles/dotf/.walls/live"
    property bool matugenAnimateColors: true
    property bool matugenEnabled: true
    property int matugenTransitionDuration: 300
    property var palette: ({})
    property var base16: ({})
    property QtObject md3: QtObject {
        property color background: "#ffffff"
        property color error: "#ffffff"
        property color error_container: "#ffffff"
        property color inverse_on_surface: "#000000"
        property color inverse_primary: "#ffffff"
        property color inverse_surface: "#ffffff"
        property color on_background: "#000000"
        property color on_error: "#000000"
        property color on_error_container: "#000000"
        property color on_primary: "#000000"
        property color on_primary_container: "#000000"
        property color on_primary_fixed: "#000000"
        property color on_primary_fixed_variant: "#000000"
        property color on_secondary: "#000000"
        property color on_secondary_container: "#000000"
        property color on_secondary_fixed: "#000000"
        property color on_secondary_fixed_variant: "#000000"
        property color on_surface: "#000000"
        property color on_surface_variant: "#000000"
        property color on_tertiary: "#000000"
        property color on_tertiary_container: "#000000"
        property color on_tertiary_fixed: "#000000"
        property color on_tertiary_fixed_variant: "#000000"
        property color outline: "#ffffff"
        property color outline_variant: "#ffffff"
        property color primary: "#ffffff"
        property color primary_container: "#ffffff"
        property color primary_fixed: "#ffffff"
        property color primary_fixed_dim: "#ffffff"
        property color scrim: "#ffffff"
        property color secondary: "#ffffff"
        property color secondary_container: "#ffffff"
        property color secondary_fixed: "#ffffff"
        property color secondary_fixed_dim: "#ffffff"
        property color shadow: "#ffffff"
        property color surface: "#ffffff"
        property color surface_bright: "#ffffff"
        property color surface_container: "#ffffff"
        property color surface_container_high: "#ffffff"
        property color surface_container_highest: "#ffffff"
        property color surface_container_low: "#ffffff"
        property color surface_container_lowest: "#ffffff"
        property color surface_dim: "#ffffff"
        property color surface_variant: "#ffffff"
        property color tertiary: "#ffffff"
        property color tertiary_container: "#ffffff"
        property color tertiary_fixed: "#ffffff"
        property color tertiary_fixed_dim: "#ffffff"
    }
    readonly property string niriOutputConfig: dotfilesDir + "/.config/niri/include/outputs.kdl"
    readonly property string profileImage: expandHomePath(profileImagePath)
    property string profileImagePath: quickshellDir + "/assets/images/sownteedev.png"
    readonly property string quickshellDir: dotfilesRoot + "/quickshell"
    // Color
    property FileView runtimeSettingsFile: FileView {
        path: configRoot.runtimeSettingsPath
        printErrors: false
        watchChanges: true

        onLoadedChanged: {
            if (loaded)
                configRoot.loadRuntimeSettings();
        }
        onTextChanged: {
            if (loaded)
                configRoot.loadRuntimeSettings();
        }
    }
    readonly property string runtimeSettingsPath: (Quickshell.env("XDG_CACHE_HOME") || homeDir + "/.cache") + "/quickshell/settings.json"
    readonly property string steamDir: homeDir + "/.local/share/Steam"
    readonly property string wallFolder: expandHomePath(wallFolderPath)
    property string wallFolderPath: "~/Dotfiles/dotf/.walls"
    property string wallpaper: wallFolder + "/mori.jpg"
    property int wallpaperBatteryFps: 20
    readonly property string wallpaperEngineAssetsDir: expandHomePath(wallpaperEngineAssetsDirPath)
    property string wallpaperEngineAssetsDirPath: "~/.local/share/Steam/steamapps/common/wallpaper_engine/assets"
    property int wallpaperEngineFps: 30
    readonly property string wallpaperEngineWorkshopDir: expandHomePath(wallpaperEngineWorkshopDirPath)
    property string wallpaperEngineWorkshopDirPath: "~/.local/share/Steam/steamapps/workshop/content/431960"
    property bool wallpaperPauseOnFullscreen: true
    property bool wallpaperPauseOnLock: true
    property int wallpaperTransitionDuration: 360

    function alpha(colorVal, opacity) {
        if (colorVal === undefined || colorVal === null || String(colorVal) === "")
            return Qt.rgba(0, 0, 0, 0);

        var c = Qt.color(colorVal);
        return Qt.rgba(c.r, c.g, c.b, opacity);
    }
    function applyRuntimeSettings(settings) {
        var names = ["fontName", "latLon", "apiWeather", "wallFolderPath", "liveWallFolderPath", "wallpaperBatteryFps", "wallpaperEngineFps", "wallpaperPauseOnFullscreen", "wallpaperPauseOnLock", "wallpaperTransitionDuration", "matugenEnabled", "matugenAnimateColors", "matugenTransitionDuration", "captureScreenshotDirPath", "captureRecordingDirPath", "captureAutoCopyScreenshot", "captureAutoCopyRecording", "captureRecordingFps", "captureRecordingCodec", "captureRecordingQuality", "captureEditorTool", "captureEditorColor", "captureEditorWidth", "wallpaperEngineAssetsDirPath", "wallpaperEngineWorkshopDirPath", "profileImagePath", "clock24h"];
        for (var i = 0; i < names.length; ++i) {
            var name = names[i];
            if (settings[name] !== undefined)
                configRoot[name] = settings[name];
        }
    }
    function expandHomePath(path) {
        var value = String(path || "");
        if (value === "~")
            return homeDir;
        if (value.indexOf("~/") === 0)
            return homeDir + value.substring(1);
        return value;
    }
    function loadRuntimeSettings() {
        if (!runtimeSettingsFile.loaded)
            return;
        var text = runtimeSettingsFile.text().trim();
        if (text === "")
            return;
        try {
            applyRuntimeSettings(JSON.parse(text));
        } catch (error) {
            console.warn("[Config] Invalid runtime settings:", error);
        }
    }
    function updateColors(colors) {
        // Legacy colors are removed
    }
    function updateMd3(colors) {
        if (colors.md3) {
            for (var key in colors.md3) {
                if (md3.hasOwnProperty(key)) {
                    md3[key] = colors.md3[key];
                }
            }
        }
        if (colors.palette) {
            palette = colors.palette;
            paletteChanged();
        }
        if (colors.base16) {
            base16 = colors.base16;
            base16Changed();
        }
    }
}
