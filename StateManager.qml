pragma Singleton
import QtQuick

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
    property var lockscreenLoader: null
    property bool rightEdgeCompletionOpen: false
    property bool rightEdgeCompletionPending: false
    property bool rightEdgeGestureActive: false
    property real rightEdgeGestureProgress: 0
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

    function beginControlLeftEdgeDrag() {
        if (!controlLeftPanelLoader || (controlLeftPanel && controlLeftPanel.active))
            return;

        leftEdgeCompletionPending = false;
        leftEdgeGestureActive = true;
        leftEdgeGestureProgress = 0;
        controlLeftPanelLoader.active = true;
        syncControlLeftLoader();
    }
    function beginControlRightEdgeDrag() {
        if (!controlPanelLoader || (controlPanel && controlPanel.active))
            return;

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
    function openControlPanel(panel, tab) {
        if (!panel)
            return;

        if (tab >= 0)
            panel.switchTab(tab);

        panel.showControl();
    }
    function showControlPanel(tab) {
        if (!controlPanelLoader)
            return;

        var requestedTab = tab === undefined ? -1 : tab;
        if (controlPanelLoader.active && controlPanelLoader.item) {
            openControlPanel(controlPanelLoader.item, requestedTab);
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
            openControlPanel(panel, requestedTab);
        }
    }
    function syncSettingsHubLoader() {
        if (!settingsHubLoader || !settingsHubLoader.active || !settingsHubOpenPending || !settingsHubLoader.item)
            return;

        settingsHubOpenPending = false;
        settingsHubLoader.item.openSettings();
    }
    function toggleControlLeftPanel() {
        if (!controlLeftPanelLoader)
            return;

        if (controlLeftPanelLoader.active && controlLeftPanel && controlLeftPanel.active) {
            controlLeftPanel.hideControl();
            return;
        }
        if (controlLeftPanelLoader.active && controlLeftPanelLoader.item) {
            controlLeftPanelLoader.item.showControl();
            return;
        }
        leftPanelOpenPending = true;
        controlLeftPanelLoader.loading = true;
    }
    function toggleControlPanel(tab) {
        var requestedTab = tab === undefined ? -1 : tab;
        if (controlPanelLoader && controlPanelLoader.active && controlPanel) {
            if (controlPanel.active && (requestedTab < 0 || controlPanel.activeTab === requestedTab)) {
                controlPanel.hideControl();
                return;
            }
        }
        showControlPanel(requestedTab);
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
