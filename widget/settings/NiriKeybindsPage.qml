import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects

ColumnLayout {
    id: root

    readonly property bool compactLayout: width < Responsive.settingsCompactContentWidth
    readonly property bool headerActionEnabled: false
    readonly property string headerActionIcon: ""
    readonly property string headerActionText: ""
    readonly property bool headerActionVisible: false
    readonly property bool headerResetVisible: false

    function groupsForColumn(column) {
        var groups = SettingsHubService.keybindGroups || [];
        var filtered = [];
        var query = keybindSearch.text.trim().toLowerCase();
        for (var i = 0; i < groups.length; i++) {
            var group = groups[i];
            if (Number(group.column) !== column)
                continue;

            if (query === "") {
                filtered.push(group);
                continue;
            }
            var items = [];
            var groupMatches = String(group.name).toLowerCase().indexOf(query) >= 0;
            for (var itemIndex = 0; itemIndex < group.items.length; itemIndex++) {
                var item = group.items[itemIndex];
                if (groupMatches || String(item.key).toLowerCase().indexOf(query) >= 0 || String(item.description).toLowerCase().indexOf(query) >= 0)
                    items.push(item);
            }
            if (items.length > 0) {
                var copy = Object.assign({}, group);
                copy.items = items;
                filtered.push(copy);
            }
        }
        return filtered;
    }

    spacing: 14

    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: 44
        Layout.preferredWidth: Math.min(560, root.width * 0.56)
        border.color: keybindSearch.activeFocus ? Config.alpha(Config.md3.primary, 0.7) : Config.alpha(Config.md3.on_surface, 0.07)
        border.width: 1
        color: Config.alpha(Config.md3.on_surface, 0.045)
        radius: 22

        IconImage {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            height: 18
            layer.enabled: true
            source: Quickshell.iconPath("system-search-symbolic")
            width: 18

            layer.effect: ColorOverlay {
                color: Config.alpha(Config.md3.on_surface, 0.48)
            }
        }
        TextInput {
            id: keybindSearch

            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: 48
            anchors.right: clearSearch.left
            anchors.rightMargin: 8
            anchors.top: parent.top
            color: Config.md3.on_surface
            font.family: Config.fontName
            font.pixelSize: 13
            verticalAlignment: TextInput.AlignVCenter

            Text {
                anchors.fill: parent
                color: Config.alpha(Config.md3.on_surface, 0.35)
                font: parent.font
                text: "Search keybinds"
                verticalAlignment: Text.AlignVCenter
                visible: parent.text === ""
            }
        }
        Text {
            id: clearSearch

            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            color: Config.alpha(Config.md3.on_surface, 0.45)
            font.family: Config.fontName
            font.pixelSize: 16
            text: "×"
            visible: keybindSearch.text !== ""

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor

                onClicked: keybindSearch.text = ""
            }
        }
    }
    Text {
        Layout.alignment: Qt.AlignHCenter
        color: Config.alpha(Config.md3.on_surface, 0.42)
        font.family: Config.fontName
        font.pixelSize: 11
        text: "Click a shortcut, press a new combination, then click elsewhere to apply"
    }
    ScrollView {
        id: keybindScroll

        Layout.fillHeight: true
        Layout.fillWidth: true
        clip: true
        contentHeight: keybindContent.implicitHeight
        contentWidth: availableWidth

        ScrollBar.horizontal: SlimScrollBar {
            policy: ScrollBar.AlwaysOff
        }
        ScrollBar.vertical: SlimScrollBar {
        }

        GridLayout {
            id: keybindContent

            columnSpacing: 14
            columns: root.compactLayout ? 1 : 2
            rowSpacing: 14
            uniformCellWidths: true
            width: keybindScroll.contentWidth

            Repeater {
                model: 2

                delegate: ColumnLayout {
                    property int columnIndex: index
                    required property int index

                    Layout.alignment: Qt.AlignTop
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 14

                    Repeater {
                        model: root.groupsForColumn(parent.columnIndex)

                        delegate: KeybindCard {
                            required property var modelData

                            Layout.fillWidth: true
                            enabled: !SettingsHubService.busy
                            groupData: modelData

                            onKeybindEdited: (oldHeader, newKey) => {
                                return SettingsHubService.saveKeybind(oldHeader, newKey);
                            }
                        }
                    }
                }
            }
        }
    }
}
