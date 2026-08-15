pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    // Legacy colors are removed

    id: configRoot

    // Weather
    // Private values are loaded from XDG_CACHE_HOME/quickshell/settings.json.
    // Keep public source defaults empty so this repository is safe to share.
    property alias apiWeather: runtimeSettings.apiWeather
    property alias audioMaxVolume: runtimeSettings.audioMaxVolume
    property alias barDensity: runtimeSettings.barDensity
    property alias barHeight: runtimeSettings.barHeight
    property alias barShowActiveClient: runtimeSettings.barShowActiveClient
    property alias barShowBattery: runtimeSettings.barShowBattery
    property alias barShowBluetooth: runtimeSettings.barShowBluetooth
    property alias barShowClock: runtimeSettings.barShowClock
    property alias barShowMedia: runtimeSettings.barShowMedia
    property alias barShowMicrophone: runtimeSettings.barShowMicrophone
    property alias barShowNetwork: runtimeSettings.barShowNetwork
    property alias barShowNotifications: runtimeSettings.barShowNotifications
    property alias barShowRecording: runtimeSettings.barShowRecording
    property alias barShowSysTray: runtimeSettings.barShowSysTray
    property alias barShowWorkspaces: runtimeSettings.barShowWorkspaces
    property var base16: ({})
    readonly property string cacheRoot: (Quickshell.env("XDG_CACHE_HOME") || homeDir + "/.cache") + "/quickshell"
    property alias caffeineAutoDisableMinutes: runtimeSettings.caffeineAutoDisableMinutes
    // Pre-defined alpha variants (0.8 opacity)
    property alias captureAutoCopyRecording: runtimeSettings.captureAutoCopyRecording
    property alias captureAutoCopyScreenshot: runtimeSettings.captureAutoCopyScreenshot
    property alias captureEditorColor: runtimeSettings.captureEditorColor
    property alias captureEditorTool: runtimeSettings.captureEditorTool
    property alias captureEditorWidth: runtimeSettings.captureEditorWidth
    property alias captureRecordingCodec: runtimeSettings.captureRecordingCodec
    readonly property string captureRecordingDir: expandHomePath(captureRecordingDirPath)
    property alias captureRecordingDirPath: runtimeSettings.captureRecordingDirPath
    property alias captureRecordingFps: runtimeSettings.captureRecordingFps
    property alias captureRecordingMicrophone: runtimeSettings.captureRecordingMicrophone
    property alias captureRecordingQuality: runtimeSettings.captureRecordingQuality
    readonly property string captureScreenshotDir: expandHomePath(captureScreenshotDirPath)
    property alias captureScreenshotDirPath: runtimeSettings.captureScreenshotDirPath
    property alias cavaEnabled: runtimeSettings.cavaEnabled
    property alias clock24h: runtimeSettings.clock24h
    // Keep the recovery wallpaper independent from a user-selected wallpaper
    // directory, which may not contain mori.jpg.
    readonly property string defaultWallpaper: dotfilesDir + "/.walls/flower-plant-petal.jpg"
    readonly property string dotfilesDir: dotfilesRoot + "/dotf"
    readonly property string dotfilesRoot: homeDir + "/Dotfiles"
    // Font
    property alias fontName: runtimeSettings.fontName
    // Paths
    readonly property string homeDir: Quickshell.env("HOME")
    property alias idleDisplayTimeout: runtimeSettings.idleDisplayTimeout
    property alias idleEnabled: runtimeSettings.idleEnabled
    property alias idleLockBeforeSleep: runtimeSettings.idleLockBeforeSleep
    property alias idleLockTimeout: runtimeSettings.idleLockTimeout
    property alias idleLockedDisplayTimeout: runtimeSettings.idleLockedDisplayTimeout
    property alias idleSuspendTimeout: runtimeSettings.idleSuspendTimeout
    property alias latLon: runtimeSettings.latLon
    property alias launcherCalculatorEnabled: runtimeSettings.launcherCalculatorEnabled
    property alias launcherCalculatorPrefix: runtimeSettings.launcherCalculatorPrefix
    property alias launcherClipboardAutoPaste: runtimeSettings.launcherClipboardAutoPaste
    property alias launcherClipboardEnabled: runtimeSettings.launcherClipboardEnabled
    property alias launcherClipboardPrefix: runtimeSettings.launcherClipboardPrefix
    property alias launcherEmojiEnabled: runtimeSettings.launcherEmojiEnabled
    property alias launcherEmojiPrefix: runtimeSettings.launcherEmojiPrefix
    property alias launcherFilesEnabled: runtimeSettings.launcherFilesEnabled
    property alias launcherFilesPrefix: runtimeSettings.launcherFilesPrefix
    property alias launcherFuzzySearch: runtimeSettings.launcherFuzzySearch
    property alias launcherMaxResults: runtimeSettings.launcherMaxResults
    readonly property string legacyWallpaperEngineWorkshopDir: homeDir + "/.steam/steam/steamapps/workshop/content/431960"
    readonly property bool lightTheme: themeLuminance > 0.58
    readonly property string liveWallFolder: expandHomePath(liveWallFolderPath)
    property alias liveWallFolderPath: runtimeSettings.liveWallFolderPath
    property alias matugenAnimateColors: runtimeSettings.matugenAnimateColors
    property alias matugenEnabled: runtimeSettings.matugenEnabled
    property alias matugenTransitionDuration: runtimeSettings.matugenTransitionDuration
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
    property alias notificationBlockedApps: runtimeSettings.notificationBlockedApps
    property alias notificationDndEnd: runtimeSettings.notificationDndEnd
    property alias notificationDndScheduleEnabled: runtimeSettings.notificationDndScheduleEnabled
    property alias notificationDndStart: runtimeSettings.notificationDndStart
    property alias notificationHistoryExcludedApps: runtimeSettings.notificationHistoryExcludedApps
    property alias notificationHistoryLimit: runtimeSettings.notificationHistoryLimit
    property alias notificationMaxVisible: runtimeSettings.notificationMaxVisible
    property alias notificationPopupDuration: runtimeSettings.notificationPopupDuration
    property alias notificationPosition: runtimeSettings.notificationPosition
    property alias notificationShowInFullscreen: runtimeSettings.notificationShowInFullscreen
    property alias notificationShowOnLock: runtimeSettings.notificationShowOnLock
    property alias osdDuration: runtimeSettings.osdDuration
    property alias osdEnabled: runtimeSettings.osdEnabled
    property alias osdPosition: runtimeSettings.osdPosition
    property alias osdShowBrightness: runtimeSettings.osdShowBrightness
    property alias osdShowMicrophone: runtimeSettings.osdShowMicrophone
    property alias osdShowVolume: runtimeSettings.osdShowVolume
    property var palette: ({})
    readonly property string quickshellDir: dotfilesRoot + "/quickshell"
    // Color
    property FileView runtimeSettingsFile: FileView {
        atomicWrites: true
        path: configRoot.runtimeSettingsPath
        printErrors: false
        watchChanges: true

        adapter: JsonAdapter {
            id: runtimeSettings

            property string apiWeather: ""
            property real audioMaxVolume: 1.0
            property string barDensity: "comfortable"
            property int barHeight: 50
            property bool barShowActiveClient: true
            property bool barShowBattery: true
            property bool barShowBluetooth: true
            property bool barShowClock: true
            property bool barShowMedia: true
            property bool barShowMicrophone: true
            property bool barShowNetwork: true
            property bool barShowNotifications: true
            property bool barShowRecording: true
            property bool barShowSysTray: true
            property bool barShowWorkspaces: true
            property int caffeineAutoDisableMinutes: 0
            property bool captureAutoCopyRecording: true
            property bool captureAutoCopyScreenshot: true
            property string captureEditorColor: "#ff3b30"
            property string captureEditorTool: "pen"
            property int captureEditorWidth: 6
            property string captureRecordingCodec: "hevc"
            property string captureRecordingDirPath: "~/Videos"
            property int captureRecordingFps: 60
            property bool captureRecordingMicrophone: false
            property string captureRecordingQuality: "high"
            property string captureScreenshotDirPath: "~/Pictures/Screenshots"
            property bool cavaEnabled: true
            property bool clock24h: true
            property string fontName: "Inter"
            property int idleDisplayTimeout: 600
            property bool idleEnabled: true
            property bool idleLockBeforeSleep: true
            property int idleLockTimeout: 600
            property int idleLockedDisplayTimeout: 60
            property int idleSuspendTimeout: 0
            property string latLon: ""
            property bool launcherCalculatorEnabled: true
            property string launcherCalculatorPrefix: "="
            property bool launcherClipboardAutoPaste: true
            property bool launcherClipboardEnabled: true
            property string launcherClipboardPrefix: "c"
            property bool launcherEmojiEnabled: true
            property string launcherEmojiPrefix: "e"
            property bool launcherFilesEnabled: true
            property string launcherFilesPrefix: "f"
            property bool launcherFuzzySearch: true
            property int launcherMaxResults: 20
            property string liveWallFolderPath: "~/Dotfiles/dotf/.walls/live"
            property bool matugenAnimateColors: true
            property bool matugenEnabled: true
            property int matugenTransitionDuration: 300
            property string notificationBlockedApps: ""
            property string notificationDndEnd: "07:00"
            property bool notificationDndScheduleEnabled: false
            property string notificationDndStart: "23:00"
            property string notificationHistoryExcludedApps: ""
            property int notificationHistoryLimit: 100
            property int notificationMaxVisible: 3
            property int notificationPopupDuration: 5000
            property string notificationPosition: "top"
            property bool notificationShowInFullscreen: true
            property bool notificationShowOnLock: false
            property int osdDuration: 2000
            property bool osdEnabled: true
            property string osdPosition: "bottom"
            property bool osdShowBrightness: true
            property bool osdShowMicrophone: true
            property bool osdShowVolume: true
            property real shellAnimationScale: 1.0
            property bool shellLowPowerMode: false
            property bool shellReducedMotion: false
            property string steamUsername: ""
            property string steamWebApiKey: ""
            property string wallFolderPath: "~/Dotfiles/dotf/.walls"
            property string wallhavenApiKey: ""
            property bool wallhavenShowNsfw: false
            property string wallhavenUsername: ""
            property int wallpaperBatteryFps: 20
            property string wallpaperEngineAssetsDirPath: "~/.local/share/Steam/steamapps/common/wallpaper_engine/assets"
            property int wallpaperEngineFps: 30
            property string wallpaperEngineWorkshopDirPath: "~/.local/share/Steam/steamapps/workshop/content/431960"
            property bool wallpaperPauseOnFullscreen: true
            property bool wallpaperPauseOnLock: true
            property int wallpaperTransitionDuration: 360
            property bool wallpaperWorkshopShowNsfw: false
        }

        onAdapterUpdated: writeAdapter()
        onFileChanged: reload()
    }
    readonly property string runtimeSettingsPath: cacheRoot + "/settings.json"
    property alias shellAnimationScale: runtimeSettings.shellAnimationScale
    property alias shellLowPowerMode: runtimeSettings.shellLowPowerMode
    property alias shellReducedMotion: runtimeSettings.shellReducedMotion
    readonly property string steamDir: homeDir + "/.local/share/Steam"
    property alias steamUsername: runtimeSettings.steamUsername
    property alias steamWebApiKey: runtimeSettings.steamWebApiKey
    readonly property real themeLuminance: md3.background.r * 0.299 + md3.background.g * 0.587 + md3.background.b * 0.114
    readonly property string wallFolder: expandHomePath(wallFolderPath)
    property alias wallFolderPath: runtimeSettings.wallFolderPath
    property alias wallhavenApiKey: runtimeSettings.wallhavenApiKey
    readonly property string wallhavenCacheFolder: cacheRoot + "/wallhaven"
    property alias wallhavenShowNsfw: runtimeSettings.wallhavenShowNsfw
    property alias wallhavenUsername: runtimeSettings.wallhavenUsername
    property string wallpaper: defaultWallpaper
    property alias wallpaperBatteryFps: runtimeSettings.wallpaperBatteryFps
    readonly property string wallpaperEngineAssetsDir: expandHomePath(wallpaperEngineAssetsDirPath)
    property alias wallpaperEngineAssetsDirPath: runtimeSettings.wallpaperEngineAssetsDirPath
    property alias wallpaperEngineFps: runtimeSettings.wallpaperEngineFps
    readonly property string wallpaperEngineWorkshopDir: expandHomePath(wallpaperEngineWorkshopDirPath)
    property alias wallpaperEngineWorkshopDirPath: runtimeSettings.wallpaperEngineWorkshopDirPath
    property alias wallpaperPauseOnFullscreen: runtimeSettings.wallpaperPauseOnFullscreen
    property alias wallpaperPauseOnLock: runtimeSettings.wallpaperPauseOnLock
    property alias wallpaperTransitionDuration: runtimeSettings.wallpaperTransitionDuration
    property alias wallpaperWorkshopShowNsfw: runtimeSettings.wallpaperWorkshopShowNsfw

    function alpha(colorVal, opacity) {
        if (colorVal === undefined || colorVal === null || String(colorVal) === "")
            return Qt.rgba(0, 0, 0, 0);

        var c = Qt.color(colorVal);
        return Qt.rgba(c.r, c.g, c.b, opacity);
    }
    function animationDuration(duration) {
        if (shellReducedMotion)
            return Math.min(80, Math.round(duration * 0.25));
        if (shellLowPowerMode)
            return Math.min(duration, Math.round(duration * 0.75));
        return Math.max(0, Math.round(duration * shellAnimationScale));
    }
    function expandHomePath(path) {
        var value = String(path || "");
        if (value === "~")
            return homeDir;

        if (value.indexOf("~/") === 0)
            return homeDir + value.substring(1);

        return value;
    }
    function updateColors(colors) {
    }
    function updateMd3(colors) {
        if (colors.md3) {
            for (var key in colors.md3) {
                if (md3.hasOwnProperty(key))
                    md3[key] = colors.md3[key];
            }
        }
        if (colors.palette)
            palette = colors.palette;

        if (colors.base16)
            base16 = colors.base16;
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", cacheRoot, wallhavenCacheFolder])
}
