import QtQuick

Item {
    id: root

    readonly property var activeActionPage: pageLoader.status === Loader.Ready ? pageLoader.item : null
    property int activeSection: 0
    readonly property bool headerActionEnabled: Boolean(activeActionPage && activeActionPage.headerActionEnabled !== false)
    readonly property string headerActionIcon: activeActionPage ? activeActionPage.headerActionIcon || "document-save-symbolic" : "document-save-symbolic"
    readonly property string headerActionText: activeActionPage ? activeActionPage.headerActionText || "" : ""
    readonly property bool headerActionVisible: Boolean(activeActionPage && activeActionPage.headerActionVisible === true)
    readonly property bool headerResetVisible: Boolean(activeActionPage && activeActionPage.headerResetVisible === true)
    property bool pageReady: false
    readonly property string pageSource: {
        switch (activeSection) {
        case 0:
            return "GeneralSettingsPage.qml";
        case 1:
            return "WallpaperSettingsPage.qml";
        case 2:
            return "CaptureSettingsPage.qml";
        case 3:
            return "IntegrationsSettingsPage.qml";
        default:
            return "";
        }
    }

    function resetPage() {
        if (activeActionPage && activeActionPage.resetPage)
            activeActionPage.resetPage();
    }
    function triggerHeaderAction() {
        if (activeActionPage && activeActionPage.triggerHeaderAction)
            activeActionPage.triggerHeaderAction();
    }

    onPageSourceChanged: {
        pageReady = false;
        revealTimer.stop();
    }

    Timer {
        id: revealTimer

        interval: 16
        repeat: false

        onTriggered: root.pageReady = pageLoader.status === Loader.Ready
    }
    Loader {
        id: pageLoader

        active: root.visible && root.pageSource !== ""
        anchors.fill: parent
        asynchronous: true
        enabled: root.pageReady
        source: root.pageSource
        visible: root.pageReady

        onStatusChanged: {
            root.pageReady = false;
            revealTimer.stop();
            if (status === Loader.Ready)
                revealTimer.restart();
        }
    }
}
