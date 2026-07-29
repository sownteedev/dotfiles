//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma IconTheme WhiteSur

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "service"
import "widget/bar"
import "widget/capture"
import "widget/desktop"
import "widget/notification"
import "widget/osd"
import "widget/polkit"
import "components"

ShellRoot {
    id: root

    function hideLazyWindow(loader, methodName) {
        if (loader.active && loader.item && loader.item[methodName])
            loader.item[methodName]();
    }
    function showLazyWindow(loader, methodName) {
        if (loader.active) {
            if (loader.item && loader.item[methodName])
                loader.item[methodName]();

            return;
        }
        if (loader.loading)
            return;

        var handler = function handler() {
            if (loader.active && loader.item) {
                if (loader.item[methodName])
                    loader.item[methodName]();

                loader.activeChanged.disconnect(handler);
            }
        };
        loader.activeChanged.connect(handler);
        loader.loading = true;
    }
    function toggleLazyWindow(loader, openMethod, closeMethod, isOpen) {
        if (loader.active && loader.item && isOpen(loader.item))
            loader.item[closeMethod]();
        else
            showLazyWindow(loader, openMethod);
    }

    settings.watchFiles: true

    Component.onCompleted: {
        BackdropService.generate();
        StateManager.controlPanelLoader = controlRightLoader;
        StateManager.controlLeftPanelLoader = controlLeftLoader;
        StateManager.lockscreenLoader = lockscreenLoader;
        StateManager.settingsHubLoader = settingsHubLoader;
    }

    Backdrop {
    }
    Desktop {
    }
    Variants {
        model: Quickshell.screens

        delegate: Component {
            EdgeTrigger {
                required property var modelData

                edgeSide: Qt.LeftEdge
                screen: modelData

                onTriggered: {
                    if (!controlLeftLoader.item || !controlLeftLoader.item.active)
                        StateManager.toggleControlLeftPanel();
                }
            }
        }
    }
    Variants {
        model: Quickshell.screens

        delegate: Component {
            EdgeTrigger {
                required property var modelData

                edgeSide: Qt.RightEdge
                screen: modelData

                onTriggered: {
                    if (!controlRightLoader.item || !controlRightLoader.item.active)
                        StateManager.showControlPanel();
                }
            }
        }
    }
    Variants {
        model: Quickshell.screens

        delegate: Component {
            Bar {
                required property var modelData

                screen: modelData
            }
        }
    }
    Variants {
        model: Quickshell.screens

        delegate: Component {
            LazyLoader {
                required property var modelData

                activeAsync: CaptureService.screenshotEditorVisible && (CaptureService.screenshotEditorScreenName === "" || CaptureService.screenshotEditorScreenName === modelData.name)

                ScreenshotEditor {
                    screen: modelData
                }
            }
        }
    }
    Variants {
        model: Quickshell.screens

        delegate: Component {
            OSD {
                required property var modelData

                screen: modelData
            }
        }
    }
    Variants {
        model: Quickshell.screens

        delegate: Component {
            NotificationPopups {
                required property var modelData

                screen: modelData
            }
        }
    }
    Variants {
        model: Quickshell.screens

        delegate: Component {
            ScreenshotNotificationPopup {
                required property var modelData

                screen: modelData
            }
        }
    }
    LazyLoader {
        id: powerLoader

        active: false
        source: Qt.resolvedUrl("widget/power/Power.qml")
    }
    LazyLoader {
        id: wallpaperSelectorLoader

        active: false
        source: Qt.resolvedUrl("widget/desktop/SelectWallpaper.qml")
    }
    LazyLoader {
        id: launcherLoader

        active: false
        source: Qt.resolvedUrl("widget/launcher/Launcher.qml")
    }
    LazyLoader {
        id: controlLeftLoader

        active: false
        source: Qt.resolvedUrl("widget/control/left/ControlLeft.qml")
    }
    LazyLoader {
        id: controlRightLoader

        active: false
        source: Qt.resolvedUrl("widget/control/right/ControlRight.qml")
    }
    LazyLoader {
        id: settingsHubLoader

        active: false
        source: Qt.resolvedUrl("widget/settings/SettingsHub.qml")
    }
    LazyLoader {
        id: lockscreenLoader

        active: false
        source: Qt.resolvedUrl("widget/lockscreen/Lockscreen.qml")
    }
    LazyLoader {
        id: polkitDialogLoader

        active: PolkitService.active

        PolkitDialog {
            flow: PolkitService.flow
        }
    }
    Connections {
        function onDismissed() {
            Qt.callLater(() => {
                return powerLoader.active = false;
            });
        }

        target: powerLoader.item
    }
    Connections {
        function onDismissed() {
            Qt.callLater(() => {
                return wallpaperSelectorLoader.active = false;
            });
        }

        target: wallpaperSelectorLoader.item
    }
    Connections {
        function onDismissed() {
            Qt.callLater(() => {
                return launcherLoader.active = false;
            });
        }

        target: launcherLoader.item
    }
    Connections {
        function onDismissed() {
            Qt.callLater(() => {
                return controlLeftLoader.active = false;
            });
        }

        target: controlLeftLoader.item
    }
    Connections {
        function onDismissed() {
            Qt.callLater(() => {
                return controlRightLoader.active = false;
            });
        }

        target: controlRightLoader.item
    }
    Connections {
        function onDismissed() {
            Qt.callLater(() => {
                return settingsHubLoader.active = false;
            });
        }

        target: settingsHubLoader.item
    }
    Connections {
        function onDismissed() {
            Qt.callLater(() => {
                return lockscreenLoader.active = false;
            });
        }

        target: lockscreenLoader.item
    }
    IpcHandler {
        function hide() {
            root.hideLazyWindow(powerLoader, "closeMenu");
        }
        function show() {
            root.showLazyWindow(powerLoader, "openMenu");
        }
        function toggle() {
            root.toggleLazyWindow(powerLoader, "openMenu", "closeMenu", item => {
                return item.visible && item.menuOpen;
            });
        }

        target: "power"
    }
    IpcHandler {
        function hide() {
            root.hideLazyWindow(wallpaperSelectorLoader, "closeSelector");
        }
        function refreshTheme() {
            WallpaperService.applyTheme(WallpaperService.displayWallpaper);
        }
        function show() {
            root.showLazyWindow(wallpaperSelectorLoader, "openSelector");
        }
        function status(): string {
            return JSON.stringify({
                "mode": WallpaperService.currentMode,
                "selectedPath": WallpaperService.currentWallpaper,
                "displayPath": WallpaperService.displayWallpaper,
                "engineProjects": EngineWallpaperService.wallpapers.length,
                "engineScanning": EngineWallpaperService.scanning,
                "available": LiveWallpaperService.available,
                "availabilityKnown": LiveWallpaperService.availabilityKnown,
                "availabilityQueryRunning": LiveWallpaperService.availabilityQuery.running,
                "desiredPath": LiveWallpaperService.desiredPath,
                "activePath": LiveWallpaperService.activePath,
                "running": LiveWallpaperService.active,
                "error": LiveWallpaperService.errorMessage
            });
        }
        function toggle() {
            root.toggleLazyWindow(wallpaperSelectorLoader, "openSelector", "closeSelector", item => {
                return item.visible;
            });
        }

        target: "wallpaper"
    }
    IpcHandler {
        function hide() {
            root.hideLazyWindow(launcherLoader, "closeLauncher");
        }
        function show() {
            root.showLazyWindow(launcherLoader, "openLauncher");
        }
        function toggle() {
            root.toggleLazyWindow(launcherLoader, "openLauncher", "closeLauncher", item => {
                return item.visible && item.active;
            });
        }

        target: "launcher"
    }
    IpcHandler {
        function hide() {
            root.hideLazyWindow(settingsHubLoader, "closeSettings");
        }
        function show() {
            root.showLazyWindow(settingsHubLoader, "openSettings");
        }
        function status(): string {
            return JSON.stringify({
                "active": settingsHubLoader.active,
                "loading": settingsHubLoader.loading,
                "hasItem": settingsHubLoader.item !== null,
                "visible": settingsHubLoader.item ? settingsHubLoader.item.visible : false,
                "open": settingsHubLoader.item ? settingsHubLoader.item.active : false
            });
        }
        function toggle() {
            root.toggleLazyWindow(settingsHubLoader, "openSettings", "closeSettings", item => {
                return item.visible && item.active;
            });
        }

        target: "settings"
    }
    IpcHandler {
        function lock() {
            StateManager.lockScreen();
        }
        function show() {
            StateManager.lockScreen();
        }
        function status(): string {
            return JSON.stringify({
                "active": lockscreenLoader.active,
                "loading": lockscreenLoader.loading,
                "locked": StateManager.sessionLocked
            });
        }

        // Toggle intentionally never unlocks an active session. Unlocking is
        // only possible through the PAM flow inside the lock surface.
        function toggle() {
            StateManager.lockScreen();
        }

        target: "lockscreen"
    }
    IpcHandler {
        function screenshot() {
            CaptureService.screenshot();
        }
        function stopRecording() {
            CaptureService.stopRecording();
        }
        function toggleRecording() {
            CaptureService.toggleRecording();
        }

        target: "capture"
    }
    NotificationServer {
        id: globalNotificationManager

        actionsSupported: true

        onNotification: n => {
            n.tracked = true;
            NotificationHistory.add(n);
        }
    }
}
