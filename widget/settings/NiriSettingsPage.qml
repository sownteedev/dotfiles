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
    readonly property string pageSource: {
        switch (activeSection) {
        case 0:
            return "NiriKeybindsPage.qml";
        case 1:
            return "NiriLayoutPage.qml";
        case 2:
            return "NiriInputPage.qml";
        case 3:
            return "NiriAnimationsPage.qml";
        case 4:
            return "NiriBehaviorPage.qml";
        case 5:
            return "NiriRulesPage.qml";
        case 6:
            return "NiriConfigFilesPage.qml";
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

    Loader {
        id: pageLoader

        active: root.visible && root.pageSource !== ""
        anchors.fill: parent
        asynchronous: false
        source: root.pageSource
        visible: status === Loader.Ready
    }
}
