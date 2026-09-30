import "../../"
import ".."
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ColumnLayout {
    id: root

    property var items: []
    property alias query: searchInput.text
    readonly property var results: {
        var value = normalize(searchInput.text);
        if (value === "")
            return [];

        var terms = value.split(/\s+/).filter(function (term) {
            return term !== "";
        });
        var scored = [];
        for (var i = 0; i < root.items.length; ++i) {
            var item = root.items[i];
            var title = normalize(item.title);
            var group = normalize(item.group);
            var keywords = normalize(item.keywords);
            var haystack = title + " " + group + " " + keywords;
            var matches = terms.every(function (term) {
                return haystack.indexOf(term) !== -1;
            });
            if (!matches)
                continue;

            var score = 0;
            if (title === value)
                score += 1000;
            if (title.indexOf(value) === 0)
                score += 500;
            for (var termIndex = 0; termIndex < terms.length; ++termIndex) {
                var term = terms[termIndex];
                if (title.indexOf(term) !== -1)
                    score += 100;
                else if (group.indexOf(term) !== -1)
                    score += 50;
                else
                    score += 10;
            }
            scored.push({
                "item": item,
                "score": score
            });
        }

        scored.sort(function (left, right) {
            return right.score - left.score;
        });
        return scored.slice(0, 8).map(function (entry) {
            return entry.item;
        });
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
    function normalize(value) {
        var text = String(value || "").toLowerCase();
        if (text.normalize)
            text = text.normalize("NFD");
        return text.replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]+/g, " ").trim();
    }

    Layout.fillWidth: true
    spacing: Md3.spacing.xs

    onQueryChanged: selectedIndex = 0
    onResultsChanged: selectedIndex = Math.max(0, Math.min(selectedIndex, results.length - 1))

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        border.color: searchInput.activeFocus ? Config.md3.primary : Config.md3.outline_variant
        border.width: 1
        color: Config.md3.surface_container_high
        radius: Md3.shape.full

        Behavior on border.color {
            ColorAnimation {
                duration: Config.animationDuration(Md3.motion.short3)
            }
        }

        Md3Icon {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            color: Config.md3.on_surface_variant
            name: "search"
            size: 22
        }
        TextInput {
            id: searchInput

            activeFocusOnTab: true
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 52
            anchors.right: clearButton.visible ? clearButton.left : parent.right
            anchors.rightMargin: 10
            anchors.top: parent.top
            clip: true
            color: Config.md3.on_surface
            font.family: Config.fontName
            font.pixelSize: Md3.typography.bodyLarge
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
            text: qsTr("Search settings")
            verticalAlignment: Text.AlignVCenter
            visible: searchInput.text === ""
        }
        Md3Icon {
            id: clearButton

            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            color: Config.alpha(Config.md3.on_surface, clearMouse.containsMouse ? 0.92 : 0.62)
            name: "close"
            size: 20
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
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 0

        Popup {
            id: resultsPopup

            closePolicy: Popup.NoAutoClose
            focus: false
            height: Math.min(Math.max(64, resultsColumn.implicitHeight + 16), 8 * 52 + 16)
            padding: 8
            popupType: Popup.Item
            visible: searchInput.text.trim() !== ""
            width: root.width
            x: 0
            y: 0
            z: 100

            background: Rectangle {
                border.color: Config.alpha(Config.md3.outline_variant, 0.44)
                border.width: 1
                color: Config.md3.surface_container_high
                radius: Md3.shape.large
            }
            contentItem: Flickable {
                id: resultsFlickable

                boundsBehavior: Flickable.StopAtBounds
                clip: true
                contentHeight: resultsColumn.implicitHeight
                contentWidth: width
                flickableDirection: Flickable.VerticalFlick
                interactive: contentHeight > height

                ColumnLayout {
                    id: resultsColumn

                    spacing: 3
                    width: resultsFlickable.width

                    Repeater {
                        model: root.results

                        delegate: Rectangle {
                            id: resultButton

                            required property int index
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            color: resultMouse.containsMouse || root.selectedIndex === resultButton.index ? Config.md3.secondary_container : "transparent"
                            radius: Md3.shape.medium

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
                                    font.pixelSize: Md3.typography.bodyMedium
                                    font.weight: Font.Medium
                                    text: resultButton.modelData.title
                                    width: parent.width
                                }
                                Text {
                                    color: Config.md3.on_surface_variant
                                    elide: Text.ElideRight
                                    font.family: Config.fontName
                                    font.pixelSize: Md3.typography.labelSmall
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
                        text: qsTr("No matching settings")
                        visible: root.results.length === 0
                    }
                }
            }
        }
    }
}
