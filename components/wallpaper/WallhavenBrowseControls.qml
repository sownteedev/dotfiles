import "../../"
import "../../service"
import QtQuick

Rectangle {
    id: root

    property string openMenu: ""
    property string popupMenu: ""
    property real popupX: 0

    signal searchRequested

    function closePopup() {
        openMenu = "";
        popupUnload.restart();
    }
    function openPopup(name, button) {
        if (openMenu === name) {
            closePopup();
            return;
        }
        popupUnload.stop();
        var point = button.mapToItem(root, 0, 0);
        var width = popupWidth(name);
        popupX = Math.max(0, Math.min(root.width - width, point.x));
        popupMenu = name;
        openMenu = name;
    }
    function popupWidth(name) {
        if (name === "resolution")
            return 520;

        if (name === "ratio")
            return 418;

        if (name === "color")
            return 330;

        return 368;
    }
    function resetFilters() {
        WallhavenService.categories = "111";
        WallhavenService.purity = "111";
        WallhavenService.resolutionMode = "atleast";
        WallhavenService.atleast = "";
        WallhavenService.resolutions = "";
        WallhavenService.ratios = "";
        WallhavenService.colors = "";
        WallhavenService.sorting = "toplist";
        WallhavenService.order = "desc";
        WallhavenService.topRange = "1M";
        scheduleSearch();
    }
    function scheduleSearch() {
        searchDebounce.restart();
    }

    color: Config.alpha(Config.md3.on_surface, 0.045)
    implicitHeight: 42
    radius: 13
    z: openMenu === "" ? 0 : 100

    Timer {
        id: searchDebounce

        interval: 220
        repeat: false

        onTriggered: root.searchRequested()
    }
    Timer {
        id: popupUnload

        interval: 170
        repeat: false

        onTriggered: {
            if (root.openMenu === "")
                root.popupMenu = "";
        }
    }
    WallhavenFilterToolbar {
        id: toolbar

        anchors.fill: parent
        anchors.margins: 4
        openMenu: root.openMenu

        onFilterChanged: root.scheduleSearch()
        onPopupRequested: (name, button) => {
            return root.openPopup(name, button);
        }
        onResetRequested: root.resetFilters()
    }
    WallhavenFilterPopup {
        id: filterPopup

        expanded: root.openMenu !== ""
        height: implicitHeight
        menu: root.popupMenu
        width: implicitWidth
        x: root.popupX
        y: root.height + 8
        z: 200

        onCloseRequested: root.closePopup()
        onFilterChanged: root.scheduleSearch()
        onHotRequested: {
            root.closePopup();
            WallhavenService.openPage("https://wallhaven.cc/hot");
        }
    }
}
