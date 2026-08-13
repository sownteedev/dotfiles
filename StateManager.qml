pragma Singleton
import QtQuick
import Quickshell
import "service"

QtObject {
    id: root

    property Connections controlLeftLoaderConnections: Connections {
        function onActiveChanged() {
            root.syncControlLeftLoader();
        }
        function onItemChanged() {
            root.syncControlLeftLoader();
        }
        function onLoadingChanged() {
            if (target && !target.loading && !target.active) {
                root.leftPanelOpenPending = false;
                root.leftEdgeCompletionPending = false;
                root.leftEdgeGestureActive = false;
                root.leftPanelScreenPending = null;
            }
        }

        target: root.controlLeftPanelLoader
    }
    property var controlLeftPanel: null
    property var controlLeftPanelLoader: null
    property var controlPanel: null
    property var controlPanelLoader: null
    property Connections controlRightLoaderConnections: Connections {
        function onActiveChanged() {
            root.syncControlRightLoader();
        }
        function onItemChanged() {
            root.syncControlRightLoader();
        }
        function onLoadingChanged() {
            if (target && !target.loading && !target.active) {
                root.rightPanelTabPending = -2;
                root.rightEdgeCompletionPending = false;
                root.rightEdgeGestureActive = false;
                root.rightPanelScreenPending = null;
            }
        }

        target: root.controlPanelLoader
    }
    property bool keyboardFocusRequested: false
    property bool leftEdgeCompletionOpen: false
    property bool leftEdgeCompletionPending: false
    property bool leftEdgeGestureActive: false
    property real leftEdgeGestureProgress: 0
    property bool leftPanelOpenPending: false
    property var leftPanelScreenPending: null
    property var lockscreenLoader: null
    property bool rightEdgeCompletionOpen: false
    property bool rightEdgeCompletionPending: false
    property bool rightEdgeGestureActive: false
    property real rightEdgeGestureProgress: 0
    property var rightPanelScreenPending: null
    property int rightPanelTabPending: -2
    property bool sessionLocked: false
    property var settingsHubLoader: null
    property Connections settingsHubLoaderConnections: Connections {
        function onActiveChanged() {
            root.syncSettingsHubLoader();
        }
        function onItemChanged() {
            root.syncSettingsHubLoader();
        }
        function onLoadingChanged() {
            if (target && !target.loading && !target.active)
                root.settingsHubOpenPending = false;
        }

        target: root.settingsHubLoader
    }
    property bool settingsHubOpenPending: false
    property bool wallpaperLoaded: false

    function assignPanelScreen(panel, requestedScreen) {
        if (panel && requestedScreen && panel.screen !== requestedScreen)
            panel.screen = requestedScreen;
    }
    function beginControlLeftEdgeDrag(screen) {
        if (!controlLeftPanelLoader)
            return;

        var targetScreen = resolvePanelScreen(screen);
        leftPanelScreenPending = targetScreen;
        if (controlLeftPanel && controlLeftPanel.active) {
            if (!panelIsOnScreen(controlLeftPanel, targetScreen)) {
                assignPanelScreen(controlLeftPanel, targetScreen);
                controlLeftPanel.showControl();
            }
            return;
        }
        leftEdgeCompletionPending = false;
        leftEdgeGestureActive = true;
        leftEdgeGestureProgress = 0;
        controlLeftPanelLoader.active = true;
        syncControlLeftLoader();
    }
    function beginControlRightEdgeDrag(screen) {
        if (!controlPanelLoader)
            return;

        var targetScreen = resolvePanelScreen(screen);
        rightPanelScreenPending = targetScreen;
        if (controlPanel && controlPanel.active) {
            if (!panelIsOnScreen(controlPanel, targetScreen)) {
                assignPanelScreen(controlPanel, targetScreen);
                controlPanel.showControl();
            }
            return;
        }
        rightEdgeCompletionPending = false;
        rightEdgeGestureActive = true;
        rightEdgeGestureProgress = 0;
        controlPanelLoader.active = true;
        syncControlRightLoader();
    }
    function finishControlLeftEdgeDrag(shouldOpen) {
        if (!leftEdgeGestureActive)
            return;

        leftEdgeGestureActive = false;
        if (controlLeftPanelLoader && controlLeftPanelLoader.item) {
            controlLeftPanelLoader.item.finishEdgeDrag(shouldOpen);
        } else {
            leftEdgeCompletionOpen = shouldOpen;
            leftEdgeCompletionPending = true;
        }
    }
    function finishControlRightEdgeDrag(shouldOpen) {
        if (!rightEdgeGestureActive)
            return;

        rightEdgeGestureActive = false;
        if (controlPanelLoader && controlPanelLoader.item) {
            controlPanelLoader.item.finishEdgeDrag(shouldOpen);
        } else {
            rightEdgeCompletionOpen = shouldOpen;
            rightEdgeCompletionPending = true;
        }
    }
    function hideSettingsHub() {
        if (settingsHubLoader && settingsHubLoader.active && settingsHubLoader.item)
            settingsHubLoader.item.closeSettings();
    }
    function lockScreen() {
        if (!lockscreenLoader || sessionLocked || lockscreenLoader.active || lockscreenLoader.loading)
            return;

        // Session locking is security-sensitive: instantiate it immediately
        // instead of waiting for an asynchronous panel-style open animation.
        lockscreenLoader.active = true;
    }
    function openControlPanel(panel, tab, screen) {
        if (!panel)
            return;

        assignPanelScreen(panel, screen);
        if (tab >= 0)
            panel.switchTab(tab);

        panel.showControl();
    }
    function panelIsOnScreen(panel, screen) {
        if (!panel || !panel.screen || !screen)
            return false;
        return panel.screen === screen || String(panel.screen.name || "") === String(screen.name || "");
    }
    function resolvePanelScreen(requestedScreen) {
        if (requestedScreen)
            return requestedScreen;

        var focusedName = WorkspaceService.focusedOutputName;
        for (var i = 0; i < Quickshell.screens.length; ++i) {
            if (focusedName !== "" && String(Quickshell.screens[i].name || "") === focusedName)
                return Quickshell.screens[i];
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }
    function showControlPanel(tab, screen) {
        if (!controlPanelLoader)
            return;

        var requestedTab = tab === undefined ? -1 : tab;
        rightPanelScreenPending = resolvePanelScreen(screen);
        if (controlPanelLoader.active && controlPanelLoader.item) {
            openControlPanel(controlPanelLoader.item, requestedTab, rightPanelScreenPending);
            return;
        }
        rightPanelTabPending = requestedTab;
        controlPanelLoader.loading = true;
    }
    function showSettingsHub() {
        if (!settingsHubLoader)
            return;
        if (settingsHubLoader.active && settingsHubLoader.item) {
            settingsHubLoader.item.openSettings();
            return;
        }
        settingsHubOpenPending = true;
        settingsHubLoader.loading = true;
    }
    function syncControlLeftLoader() {
        if (!controlLeftPanelLoader || !controlLeftPanelLoader.active || !controlLeftPanelLoader.item)
            return;

        var panel = controlLeftPanelLoader.item;
        assignPanelScreen(panel, leftPanelScreenPending);
        if (leftEdgeGestureActive) {
            panel.beginEdgeDrag();
            panel.updateEdgeDrag(leftEdgeGestureProgress);
            return;
        }
        if (leftEdgeCompletionPending) {
            var shouldOpen = leftEdgeCompletionOpen;
            leftEdgeCompletionPending = false;
            panel.beginEdgeDrag();
            panel.updateEdgeDrag(leftEdgeGestureProgress);
            panel.finishEdgeDrag(shouldOpen);
            return;
        }
        if (leftPanelOpenPending) {
            leftPanelOpenPending = false;
            panel.showControl();
        }
    }
    function syncControlRightLoader() {
        if (!controlPanelLoader || !controlPanelLoader.active || !controlPanelLoader.item)
            return;

        var panel = controlPanelLoader.item;
        assignPanelScreen(panel, rightPanelScreenPending);
        if (rightEdgeGestureActive) {
            panel.beginEdgeDrag();
            panel.updateEdgeDrag(rightEdgeGestureProgress);
            return;
        }
        if (rightEdgeCompletionPending) {
            var shouldOpen = rightEdgeCompletionOpen;
            rightEdgeCompletionPending = false;
            panel.beginEdgeDrag();
            panel.updateEdgeDrag(rightEdgeGestureProgress);
            panel.finishEdgeDrag(shouldOpen);
            return;
        }
        if (rightPanelTabPending !== -2) {
            var requestedTab = rightPanelTabPending;
            rightPanelTabPending = -2;
            openControlPanel(panel, requestedTab, rightPanelScreenPending);
        }
    }
    function syncSettingsHubLoader() {
        if (!settingsHubLoader || !settingsHubLoader.active || !settingsHubOpenPending || !settingsHubLoader.item)
            return;

        settingsHubOpenPending = false;
        settingsHubLoader.item.openSettings();
    }
    function toggleControlLeftPanel(screen) {
        if (!controlLeftPanelLoader)
            return;

        var targetScreen = resolvePanelScreen(screen);
        leftPanelScreenPending = targetScreen;
        if (controlLeftPanelLoader.active && controlLeftPanel && controlLeftPanel.active) {
            if (panelIsOnScreen(controlLeftPanel, targetScreen))
                controlLeftPanel.hideControl();
            else {
                assignPanelScreen(controlLeftPanel, targetScreen);
                controlLeftPanel.showControl();
            }
            return;
        }
        if (controlLeftPanelLoader.active && controlLeftPanelLoader.item) {
            assignPanelScreen(controlLeftPanelLoader.item, targetScreen);
            controlLeftPanelLoader.item.showControl();
            return;
        }
        leftPanelOpenPending = true;
        controlLeftPanelLoader.loading = true;
    }
    function toggleControlPanel(tab, screen) {
        var requestedTab = tab === undefined ? -1 : tab;
        var targetScreen = resolvePanelScreen(screen);
        if (controlPanelLoader && controlPanelLoader.active && controlPanel) {
            if (controlPanel.active && panelIsOnScreen(controlPanel, targetScreen) && (requestedTab < 0 || controlPanel.activeTab === requestedTab)) {
                controlPanel.hideControl();
                return;
            }
        }
        showControlPanel(requestedTab, targetScreen);
    }
    function toggleSettingsHub() {
        if (settingsHubLoader && settingsHubLoader.active && settingsHubLoader.item && settingsHubLoader.item.active) {
            settingsHubLoader.item.closeSettings();
            return;
        }
        showSettingsHub();
    }
    function updateControlLeftEdgeDrag(progress) {
        if (!leftEdgeGestureActive)
            return;
        leftEdgeGestureProgress = Math.max(0, Math.min(1, progress));
        if (controlLeftPanelLoader && controlLeftPanelLoader.item)
            controlLeftPanelLoader.item.updateEdgeDrag(leftEdgeGestureProgress);
    }
    function updateControlRightEdgeDrag(progress) {
        if (!rightEdgeGestureActive)
            return;
        rightEdgeGestureProgress = Math.max(0, Math.min(1, progress));
        if (controlPanelLoader && controlPanelLoader.item)
            controlPanelLoader.item.updateEdgeDrag(rightEdgeGestureProgress);
    }
}
