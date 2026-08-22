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
import "widget/idle"
import "widget/lockscreen"
import "widget/notification"
import "widget/osd"
import "widget/polkit"
import "components"

ShellRoot {
    id: root

    property var lazyOpenRequests: ({})

    function clearLazyOpenRequest(loader) {
        if (!loader || !loader.objectName)
            return;
        var request = lazyOpenRequests[loader.objectName];
        if (!request)
            return;

        try {
            loader.activeChanged.disconnect(request.activeHandler);
        } catch (error) {}
        try {
            loader.loadingChanged.disconnect(request.loadingHandler);
        } catch (error) {}
        var requests = Object.assign({}, lazyOpenRequests);
        delete requests[loader.objectName];
        lazyOpenRequests = requests;
    }
    function hideLazyWindow(loader, methodName) {
        clearLazyOpenRequest(loader);
        if (loader.active && loader.item && loader.item[methodName]) {
            loader.item[methodName]();
            return;
        }
        if (loader.loading) {
            loader.loading = false;
            return;
        }
    }
    function scheduleLazyUnload(loader, dismissedItem) {
        Qt.callLater(function () {
            if (!loader.active || loader.item !== dismissedItem)
                return;

            // A window may be reopened between `dismissed` and this deferred
            // cleanup. Never destroy the newly reopened instance.
            if (dismissedItem && dismissedItem.visible)
                return;
            root.clearLazyOpenRequest(loader);
            loader.active = false;
        });
    }
    function showLazyWindow(loader, methodName) {
        if (loader.active) {
            if (loader.item && loader.item[methodName])
                loader.item[methodName]();

            return;
        }
        if (loader.loading)
            return;

        clearLazyOpenRequest(loader);
        var activeHandler = function activeHandler() {
            if (loader.active && loader.item) {
                if (loader.item[methodName])
                    loader.item[methodName]();
                root.clearLazyOpenRequest(loader);
            }
        };
        var loadingHandler = function loadingHandler() {
            if (!loader.loading && !loader.active)
                root.clearLazyOpenRequest(loader);
        };
        var requests = Object.assign({}, lazyOpenRequests);
        requests[loader.objectName] = {
            "activeHandler": activeHandler,
            "loadingHandler": loadingHandler
        };
        lazyOpenRequests = requests;
        loader.activeChanged.connect(activeHandler);
        loader.loadingChanged.connect(loadingHandler);
        loader.loading = true;
    }
    function toggleLazyWindow(loader, openMethod, closeMethod, isOpen) {
        if (loader.active && loader.item && isOpen(loader.item))
            loader.item[closeMethod]();
        else if (loader.loading)
            hideLazyWindow(loader, closeMethod);
        else
            showLazyWindow(loader, openMethod);
    }

    settings.watchFiles: true

    Component.onCompleted: {
        BackdropService.generate();
        DisplayHotplugService.start();
        StateManager.controlPanelLoader = controlRightLoader;
        StateManager.controlLeftPanelLoader = controlLeftLoader;
        StateManager.lockscreenLoader = lockscreenLoader;
        StateManager.settingsHubLoader = settingsHubLoader;
    }
    Component.onDestruction: {
        if (StateManager.controlPanelLoader === controlRightLoader)
            StateManager.controlPanelLoader = null;
        if (StateManager.controlLeftPanelLoader === controlLeftLoader)
            StateManager.controlLeftPanelLoader = null;
        if (StateManager.lockscreenLoader === lockscreenLoader)
            StateManager.lockscreenLoader = null;
        if (StateManager.settingsHubLoader === settingsHubLoader)
            StateManager.settingsHubLoader = null;
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

                onDragFinished: shouldOpen => StateManager.finishControlLeftEdgeDrag(shouldOpen)
                onDragMoved: progress => StateManager.updateControlLeftEdgeDrag(progress)
                onDragStarted: StateManager.beginControlLeftEdgeDrag(modelData)
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

                onDragFinished: shouldOpen => StateManager.finishControlRightEdgeDrag(shouldOpen)
                onDragMoved: progress => StateManager.updateControlRightEdgeDrag(progress)
                onDragStarted: StateManager.beginControlRightEdgeDrag(modelData)
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
                readonly property bool requested: CaptureService.screenshotEditorVisible && (CaptureService.screenshotEditorScreenName === "" || CaptureService.screenshotEditorScreenName === modelData.name)

                function syncRequestedState() {
                    if (requested) {
                        if (!active && !loading)
                            loading = true;
                    } else if (active) {
                        active = false;
                    } else if (loading) {
                        loading = false;
                    }
                }

                Component.onCompleted: syncRequestedState()
                onRequestedChanged: syncRequestedState()

                ScreenshotEditor {
                    screen: modelData
                }
            }
        }
    }
    Variants {
        model: Quickshell.screens

        delegate: Component {
            IdleDimOverlay {
                required property var modelData

                screen: modelData
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
        objectName: "powerLoader"
        source: Qt.resolvedUrl("widget/power/Power.qml")
    }
    LazyLoader {
        id: wallpaperSelectorLoader

        active: false
        objectName: "wallpaperSelectorLoader"
        source: Qt.resolvedUrl("widget/desktop/SelectWallpaper.qml")
    }
    LazyLoader {
        id: launcherLoader

        active: false
        objectName: "launcherLoader"
        source: Qt.resolvedUrl("widget/launcher/Launcher.qml")
    }
    LazyLoader {
        id: controlLeftLoader

        active: false
        objectName: "controlLeftLoader"
        source: Qt.resolvedUrl("widget/control/left/ControlLeft.qml")
    }
    LazyLoader {
        id: controlRightLoader

        active: false
        objectName: "controlRightLoader"
        source: Qt.resolvedUrl("widget/control/right/ControlRight.qml")
    }
    LazyLoader {
        id: settingsHubLoader

        active: false
        objectName: "settingsHubLoader"
        source: Qt.resolvedUrl("widget/settings/SettingsHub.qml")
    }
    LazyLoader {
        id: lockscreenLoader

        active: false
        objectName: "lockscreenLoader"
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
            root.scheduleLazyUnload(powerLoader, target);
        }

        target: powerLoader.item
    }
    Connections {
        function onDismissed() {
            root.scheduleLazyUnload(wallpaperSelectorLoader, target);
        }

        target: wallpaperSelectorLoader.item
    }
    Connections {
        function onDismissed() {
            root.scheduleLazyUnload(launcherLoader, target);
        }

        target: launcherLoader.item
    }
    Connections {
        function onDismissed() {
            root.scheduleLazyUnload(controlLeftLoader, target);
        }

        target: controlLeftLoader.item
    }
    Connections {
        function onDismissed() {
            root.scheduleLazyUnload(controlRightLoader, target);
        }

        target: controlRightLoader.item
    }
    Connections {
        function onDismissed() {
            root.scheduleLazyUnload(settingsHubLoader, target);
        }

        target: settingsHubLoader.item
    }
    Connections {
        function onDismissed() {
            root.scheduleLazyUnload(lockscreenLoader, target);
        }

        target: lockscreenLoader.item
    }
    IpcHandler {
        function hide(): bool {
            IdleDimService.hide();
            return true;
        }
        function show(): bool {
            IdleDimService.show();
            return true;
        }
        function status(): string {
            return JSON.stringify({
                "active": IdleDimService.active
            });
        }

        target: "idleDim"
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
            WallpaperService.applyTheme(WallpaperService.currentThemeSource());
        }
        function show() {
            root.showLazyWindow(wallpaperSelectorLoader, "openSelector");
        }
        function status(): string {
            var selectedBackend = WallpaperService.selectedBackend;
            var runningBackend = EngineWallpaperService.active ? "engine" : LiveWallpaperService.active ? "live" : "";
            return JSON.stringify({
                "mode": WallpaperService.currentMode,
                "themeMode": ThemeService.colorMode,
                "activeThemeMode": ThemeService.activeMode,
                "themeSource": ThemeService.activeSource,
                "expectedThemeSource": ThemeService.expectedSource,
                "themeSynchronized": ThemeService.themeAvailable,
                "selectedBackend": selectedBackend,
                "runningBackend": runningBackend,
                "transitionPending": WallpaperService.isTransitionPending,
                "selectedPath": WallpaperService.currentWallpaper,
                "displayPath": WallpaperService.displayWallpaper,
                "engineProjects": EngineWallpaperService.wallpapers.length,
                "engineScanning": EngineWallpaperService.scanning,
                "available": selectedBackend === "engine" ? EngineWallpaperService.available : selectedBackend === "live" ? LiveWallpaperService.available : true,
                "availabilityKnown": selectedBackend === "engine" ? EngineWallpaperService.availabilityKnown : selectedBackend === "live" ? LiveWallpaperService.availabilityKnown : true,
                "availabilityQueryRunning": selectedBackend === "engine" ? EngineWallpaperService.availabilityQuery.running : selectedBackend === "live" ? LiveWallpaperService.availabilityQuery.running : false,
                "desiredPath": selectedBackend === "engine" ? EngineWallpaperService.desiredPath : selectedBackend === "live" ? LiveWallpaperService.desiredPath : "",
                "activePath": runningBackend === "engine" ? EngineWallpaperService.activePath : runningBackend === "live" ? LiveWallpaperService.activePath : "",
                "running": runningBackend !== "",
                "error": selectedBackend === "engine" ? EngineWallpaperService.errorMessage : selectedBackend === "live" ? LiveWallpaperService.errorMessage : "",
                "live": {
                    "available": LiveWallpaperService.available,
                    "active": LiveWallpaperService.active,
                    "playbackReady": LiveWallpaperService.playbackReadyState,
                    "desiredPath": LiveWallpaperService.desiredPath,
                    "activePath": LiveWallpaperService.activePath,
                    "error": LiveWallpaperService.errorMessage
                },
                "engine": {
                    "available": EngineWallpaperService.available,
                    "active": EngineWallpaperService.active,
                    "playbackReady": EngineWallpaperService.playbackReadyState,
                    "restarting": EngineWallpaperService.policyRestarting,
                    "desiredPath": EngineWallpaperService.desiredPath,
                    "activePath": EngineWallpaperService.activePath,
                    "error": EngineWallpaperService.errorMessage
                }
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
        function lock(): bool {
            StateManager.lockScreen();
            return true;
        }
        function retryFace(): bool {
            IdleDimService.retryFaceAuthentication();
            return true;
        }
        function show(): bool {
            StateManager.lockScreen();
            return true;
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
        function toggle(): bool {
            StateManager.lockScreen();
            return true;
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
        imageSupported: true
        keepOnReload: false
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            NotificationHistory.add(n);
            if (!QuickSettingsService.effectiveDndActive)
                LockscreenNotificationService.show(n);
            if (n.transient && QuickSettingsService.effectiveDndActive) {
                Qt.callLater(function () {
                    if (n && n.tracked)
                        n.expire();
                });
            }
        }
    }
    Connections {
        function onEffectiveDndActiveChanged() {
            if (QuickSettingsService.effectiveDndActive)
                LockscreenNotificationService.clear();
        }

        target: QuickSettingsService
    }
}
