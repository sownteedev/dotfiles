pragma Singleton
import "../../"
import ".."
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland

QtObject {
    id: root

    readonly property bool captureOverlayVisible: CaptureService.screenshotEditorVisible
    readonly property bool fullscreen: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.fullscreen : false
    readonly property bool locked: StateManager.sessionLocked
    readonly property bool onBattery: UPower.onBattery
    readonly property bool shouldPause: captureOverlayVisible || (Config.wallpaperPauseOnLock && locked) || (Config.wallpaperPauseOnFullscreen && fullscreen)
    readonly property int targetFps: onBattery ? Math.min(Math.max(1, Config.wallpaperBatteryFps), Math.max(1, Config.wallpaperEngineFps)) : Math.max(1, Config.wallpaperEngineFps)
}
