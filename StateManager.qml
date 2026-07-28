import QtQuick
pragma Singleton

QtObject {
    id: root

    property var controlLeftPanel: null
    property var controlLeftPanelLoader: null
    property var controlPanel: null
    property var controlPanelLoader: null
    property bool keyboardFocusRequested: false
    property bool leftPanelOpenPending: false
    property int rightPanelTabPending: -2
    property var settingsHubLoader: null
    property bool settingsHubOpenPending: false
    property bool wallpaperLoaded: false
    property Connections controlLeftLoaderConnections

    controlLeftLoaderConnections: Connections {
        function onActiveChanged() {
            if (!target.active || !root.leftPanelOpenPending || !target.item)
                return ;

            root.leftPanelOpenPending = false;
            target.item.showControl();
        }

        target: root.controlLeftPanelLoader
    }

    property Connections controlRightLoaderConnections

    controlRightLoaderConnections: Connections {
        function onActiveChanged() {
            if (!target.active || root.rightPanelTabPending === -2 || !target.item)
                return ;

            var requestedTab = root.rightPanelTabPending;
            root.rightPanelTabPending = -2;
            root.openControlPanel(target.item, requestedTab);
        }

        target: root.controlPanelLoader
    }

    property Connections settingsHubLoaderConnections

    settingsHubLoaderConnections: Connections {
        function onActiveChanged() {
            if (!target.active || !root.settingsHubOpenPending || !target.item)
                return;

            root.settingsHubOpenPending = false;
            target.item.openSettings();
        }

        target: root.settingsHubLoader
    }

    function openControlPanel(panel, tab) {
        if (!panel)
            return ;

        if (tab >= 0)
            panel.switchTab(tab);

        panel.showControl();
    }

    function showControlPanel(tab) {
        if (!controlPanelLoader)
            return ;

        var requestedTab = tab === undefined ? -1 : tab;
        if (controlPanelLoader.active && controlPanelLoader.item) {
            openControlPanel(controlPanelLoader.item, requestedTab);
            return ;
        }
        rightPanelTabPending = requestedTab;
        controlPanelLoader.loading = true;
    }

    function hideSettingsHub() {
        if (settingsHubLoader && settingsHubLoader.active && settingsHubLoader.item)
            settingsHubLoader.item.closeSettings();
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

    function toggleControlLeftPanel() {
        if (!controlLeftPanelLoader)
            return ;

        if (controlLeftPanelLoader.active && controlLeftPanel && controlLeftPanel.active) {
            controlLeftPanel.hideControl();
            return ;
        }
        if (controlLeftPanelLoader.active && controlLeftPanelLoader.item) {
            controlLeftPanelLoader.item.showControl();
            return ;
        }
        leftPanelOpenPending = true;
        controlLeftPanelLoader.loading = true;
    }

    function toggleControlPanel(tab) {
        var requestedTab = tab === undefined ? -1 : tab;
        if (controlPanelLoader && controlPanelLoader.active && controlPanel) {
            if (controlPanel.active && (requestedTab < 0 || controlPanel.activeTab === requestedTab)) {
                controlPanel.hideControl();
                return ;
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

}
