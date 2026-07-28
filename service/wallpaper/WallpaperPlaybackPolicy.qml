pragma Singleton
import "../../"
import Qt.labs.folderlistmodel
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland

QtObject {
    id: root

    readonly property bool fullscreen: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.fullscreen : false
    readonly property string lockMarkerName: "quickshell-wallpaper-lock.active"
    readonly property string lockMarkerPath: runtimeDir + "/" + lockMarkerName
    property FolderListModel lockWatcher: FolderListModel {
        folder: "file://" + root.runtimeDir
        nameFilters: [root.lockMarkerName]
        showDirs: false
        showFiles: true
        showHidden: true
    }
    readonly property bool locked: lockWatcher.count > 0
    readonly property bool onBattery: UPower.onBattery
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property bool shouldPause: (Config.wallpaperPauseOnLock && locked) || (Config.wallpaperPauseOnFullscreen && fullscreen)
    readonly property int targetFps: onBattery ? Math.min(Math.max(1, Config.wallpaperBatteryFps), Math.max(1, Config.wallpaperEngineFps)) : Math.max(1, Config.wallpaperEngineFps)
}
