import "../../"
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets

ColumnLayout {
    id: root

    property var items: []
    property alias query: searchInput.text
    readonly property var results: {
        var value = searchInput.text.trim().toLowerCase();
        if (value === "")
            return [];

        var matches = [];
        for (var i = 0; i < root.items.length; ++i) {
            var item = root.items[i];
            var haystack = (String(item.title || "") + " " + String(item.group || "") + " " + String(item.keywords || "")).toLowerCase();
            if (haystack.indexOf(value) !== -1)
                matches.push(item);
            if (matches.length >= 6)
                break;
        }
        return matches;
    }
    property int selectedIndex: 0

    signal selected(int page, int section)

    function activateResult(index) {
        if (index < 0 || index >= results.length)
            return;
        var result = results[index];
        selected(result.page, result.section);
        searchInput.text = "";
    }

    Layout.fillWidth: true
    spacing: 6

    onQueryChanged: selectedIndex = 0
    onResultsChanged: selectedIndex = Math.max(0, Math.min(selectedIndex, results.length - 1))

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        border.color: searchInput.activeFocus ? Config.alpha(Config.md3.primary, 0.55) : Config.alpha(Config.md3.on_surface, 0.06)
        border.width: 1
        color: Config.alpha(Config.md3.on_surface, 0.045)
        radius: 13

        Behavior on border.color {
            ColorAnimation {
                duration: 140
            }
        }

        IconImage {
            anchors.left: parent.left
            anchors.leftMargin: 13
            anchors.verticalCenter: parent.verticalCenter
            height: 17
            layer.enabled: true
            source: Quickshell.iconPath("system-search-symbolic")
            width: 17

            layer.effect: ColorOverlay {
                color: Config.alpha(Config.md3.on_surface, 0.55)
            }
        }
        TextInput {
            id: searchInput

            activeFocusOnTab: true
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 40
            anchors.right: clearButton.visible ? clearButton.left : parent.right
            anchors.rightMargin: 10
            anchors.top: parent.top
            color: Config.md3.on_surface
            font.family: Config.fontName
            font.pixelSize: 14
            selectByMouse: true
            verticalAlignment: TextInput.AlignVCenter

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Down && root.results.length > 0) {
                    root.selectedIndex = (root.selectedIndex + 1) % root.results.length;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up && root.results.length > 0) {
                    root.selectedIndex = (root.selectedIndex - 1 + root.results.length) % root.results.length;
                    event.accepted = true;
                } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.results.length > 0) {
                    root.activateResult(root.selectedIndex);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape && text !== "") {
                    text = "";
                    event.accepted = true;
                }
            }
        }
        Text {
            anchors.fill: searchInput
            color: Config.alpha(Config.md3.on_surface, 0.4)
            font: searchInput.font
            text: "Search settings"
            verticalAlignment: Text.AlignVCenter
            visible: searchInput.text === ""
        }
        Text {
            id: clearButton

            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            color: Config.alpha(Config.md3.on_surface, clearMouse.containsMouse ? 0.9 : 0.55)
            font.family: Config.fontName
            font.pixelSize: 19
            text: "×"
            visible: searchInput.text !== ""

            MouseArea {
                id: clearMouse

                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true

                onClicked: searchInput.text = ""
            }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 3
        visible: searchInput.text.trim() !== ""

        Repeater {
            model: root.results

            delegate: Rectangle {
                id: resultButton

                required property int index
                required property var modelData

                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: resultMouse.containsMouse || root.selectedIndex === resultButton.index ? Config.alpha(Config.md3.primary, 0.11) : "transparent"
                radius: 12

                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 13
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1

                    Text {
                        color: Config.md3.on_surface
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        text: resultButton.modelData.title
                        width: parent.width
                    }
                    Text {
                        color: Config.alpha(Config.md3.on_surface, 0.44)
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 11
                        text: resultButton.modelData.group
                        width: parent.width
                    }
                }
                MouseArea {
                    id: resultMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.activateResult(resultButton.index)
                    onEntered: root.selectedIndex = resultButton.index
                }
            }
        }
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 12
            color: Config.alpha(Config.md3.on_surface, 0.42)
            font.family: Config.fontName
            font.pixelSize: 12
            text: "No matching settings"
            visible: root.results.length === 0
        }
    }
}
