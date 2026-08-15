import "../../"
import "../../service"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    property string openMenu: ""

    signal filterChanged
    signal popupRequested(string name, var button)
    signal resetRequested

    function bitEnabled(bits, index) {
        return String(bits || "000").charAt(index) === "1";
    }
    function ratioLabel() {
        return WallhavenService.ratios === "" ? qsTr("Any ratio") : WallhavenService.ratios.replace("x", ":");
    }
    function resolutionLabel() {
        var value = WallhavenService.resolutionMode === "exact" ? WallhavenService.resolutions : WallhavenService.atleast;
        if (value === "")
            return qsTr("Any resolution");

        return (WallhavenService.resolutionMode === "exact" ? "= " : "≥ ") + value.replace("x", "×");
    }
    function sortLabel() {
        var labels = {
            "relevance": qsTr("Relevance"),
            "date_added": qsTr("Date added"),
            "random": qsTr("Random"),
            "views": qsTr("Most viewed"),
            "favorites": qsTr("Most favorited"),
            "toplist": qsTr("Toplist")
        };
        return labels[WallhavenService.sorting] || qsTr("Toplist");
    }
    function toggleBit(propertyName, index) {
        var value = String(WallhavenService[propertyName] || "000");
        if (value.length !== 3)
            value = "111";

        if (propertyName === "purity" && index === 2 && Config.wallhavenApiKey.trim() === "")
            return;

        var replacement = value.charAt(index) === "1" ? "0" : "1";
        var next = value.substring(0, index) + replacement + value.substring(index + 1);
        if (next === "000")
            return;

        WallhavenService[propertyName] = next;
        filterChanged();
    }
    function toggleOrder() {
        WallhavenService.order = WallhavenService.order === "asc" ? "desc" : "asc";
        filterChanged();
    }

    implicitHeight: 36

    Flickable {
        id: filterFlickable

        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        contentHeight: height
        contentWidth: filterLayout.width
        interactive: contentWidth > width

        RowLayout {
            id: filterLayout

            height: parent.height
            spacing: 6
            width: Math.max(implicitWidth, filterFlickable.width)

            Repeater {
                model: [qsTr("General"), qsTr("Anime"), qsTr("People")]

                delegate: WallhavenChoiceButton {
                    required property int index
                    required property string modelData

                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    Layout.minimumWidth: implicitWidth
                    Layout.preferredHeight: 34
                    accentColor: Config.md3.primary_container
                    fontPixelSize: 12
                    label: modelData
                    selected: root.bitEnabled(WallhavenService.categories, index)
                    selectedTextColor: Config.md3.on_primary_container

                    onClicked: root.toggleBit("categories", index)
                }
            }
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 20
                Layout.preferredWidth: 1
                color: Config.alpha(Config.md3.outline, 0.24)
            }
            Repeater {
                model: [qsTr("SFW"), qsTr("Sketchy"), qsTr("NSFW")]

                delegate: WallhavenChoiceButton {
                    readonly property bool available: index !== 2 || Config.wallhavenApiKey.trim() !== ""
                    required property int index
                    required property string modelData

                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    Layout.minimumWidth: implicitWidth
                    Layout.preferredHeight: 34
                    accentColor: index === 2 ? Config.md3.error_container : Config.md3.tertiary_container
                    enabled: available
                    fontPixelSize: 12
                    label: modelData
                    selected: available && root.bitEnabled(WallhavenService.purity, index)
                    selectedTextColor: index === 2 ? Config.md3.on_error_container : Config.md3.on_tertiary_container

                    onClicked: root.toggleBit("purity", index)
                }
            }
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 20
                Layout.preferredWidth: 1
                color: Config.alpha(Config.md3.outline, 0.24)
            }
            WallhavenFilterButton {
                id: resolutionButton

                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.minimumWidth: implicitWidth
                Layout.preferredHeight: 34
                active: WallhavenService.atleast !== "" || WallhavenService.resolutions !== ""
                expanded: root.openMenu === "resolution"
                fontPixelSize: 12
                label: root.resolutionLabel()

                onClicked: root.popupRequested("resolution", resolutionButton)
            }
            WallhavenFilterButton {
                id: ratioButton

                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.minimumWidth: implicitWidth
                Layout.preferredHeight: 34
                active: WallhavenService.ratios !== ""
                expanded: root.openMenu === "ratio"
                fontPixelSize: 12
                label: root.ratioLabel()

                onClicked: root.popupRequested("ratio", ratioButton)
            }
            WallhavenFilterButton {
                id: colorButton

                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.minimumWidth: implicitWidth
                Layout.preferredHeight: 34
                active: WallhavenService.colors !== ""
                expanded: root.openMenu === "color"
                fontPixelSize: 12
                label: WallhavenService.colors === "" ? qsTr("Any color") : qsTr("Color")
                swatchColor: WallhavenService.colors === "" ? "transparent" : "#" + WallhavenService.colors

                onClicked: root.popupRequested("color", colorButton)
            }
            WallhavenFilterButton {
                id: sortButton

                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.minimumWidth: implicitWidth
                Layout.preferredHeight: 34
                active: WallhavenService.sorting !== "toplist" || WallhavenService.topRange !== "1M"
                expanded: root.openMenu === "sort"
                fontPixelSize: 12
                label: root.sortLabel()

                onClicked: root.popupRequested("sort", sortButton)
            }
            Rectangle {
                Accessible.name: WallhavenService.order === "asc" ? qsTr("Ascending order") : qsTr("Descending order")
                Accessible.role: Accessible.Button
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 34
                Layout.preferredWidth: 38
                activeFocusOnTab: true
                border.color: activeFocus ? Config.alpha(Config.md3.primary, 0.72) : "transparent"
                border.width: 1
                color: orderMouse.containsMouse || activeFocus ? Config.md3.secondary_container : "transparent"
                radius: 9

                Keys.onReturnPressed: root.toggleOrder()
                Keys.onSpacePressed: root.toggleOrder()

                Text {
                    anchors.centerIn: parent
                    color: orderMouse.containsMouse ? Config.md3.on_secondary_container : Config.md3.on_surface_variant
                    font.family: Config.fontName
                    font.pixelSize: 17
                    text: WallhavenService.order === "asc" ? "↑" : "↓"
                }
                MouseArea {
                    id: orderMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.toggleOrder()
                }
            }
            WallhavenFilterButton {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.minimumWidth: implicitWidth
                Layout.preferredHeight: 34
                accentColor: Config.md3.error_container
                active: Config.wallhavenShowNsfw
                fontPixelSize: 12
                iconName: Config.wallhavenShowNsfw ? "view-reveal-symbolic" : "view-conceal-symbolic"
                label: Config.wallhavenShowNsfw ? qsTr("NSFW visible") : qsTr("NSFW blurred")
                visible: Config.wallhavenApiKey.trim() !== "" && root.bitEnabled(WallhavenService.purity, 2)

                onClicked: Config.wallhavenShowNsfw = !Config.wallhavenShowNsfw
            }
            WallhavenFilterButton {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.minimumWidth: implicitWidth
                Layout.preferredHeight: 34
                fontPixelSize: 12
                iconName: "edit-clear-symbolic"
                label: qsTr("Reset")

                onClicked: root.resetRequested()
            }
        }
    }
}
