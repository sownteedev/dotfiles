import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    readonly property bool contentMoving: startupSection.scrolling || userSection.scrolling || systemSection.scrolling
    readonly property bool headerActionEnabled: false
    readonly property bool headerActionVisible: false
    readonly property var matchingStartupEntries: root.matchingEntries(DiagnosticsService.startupApps)
    readonly property var matchingSystemEntries: root.matchingEntries(DiagnosticsService.systemServices)
    readonly property var matchingUserEntries: root.matchingEntries(DiagnosticsService.userServices)
    property int modelsRevision: 0
    property Timer refreshTimer: Timer {
        interval: 3000
        repeat: true
        running: root.visible && !root.contentMoving

        onTriggered: DiagnosticsService.refresh()
    }
    property alias searchQuery: searchInput.text

    function itemMatches(item, queryText) {
        var query = root.normalize(queryText);
        if (query === "")
            return true;

        var searchable = [item.name, item.file, item.description, item.exec, item.scope, item.path, item.state, item.subState, item.startup, item.enabled === true ? "on enabled active" : "off disabled inactive", item.manageable === true ? "manageable" : ""].join(" ");
        var tokens = query.split(" ");
        var normalizedSearchable = root.normalize(searchable);
        for (var tokenIndex = 0; tokenIndex < tokens.length; ++tokenIndex) {
            if (tokens[tokenIndex] !== "" && normalizedSearchable.indexOf(tokens[tokenIndex]) < 0)
                return false;
        }
        return true;
    }
    function matchingEntries(source) {
        var modelRevision = root.modelsRevision;
        var matches = [];
        for (var index = 0; index < source.count; ++index) {
            var entry = source.get(index);
            var payload = String(entry.payload || "");
            var item = {};
            try {
                item = JSON.parse(payload || "{}");
            } catch (error) {
                item = {};
            }
            if (root.itemMatches(item, root.searchQuery))
                matches.push({
                    "payload": payload,
                    "stableKey": String(entry.stableKey || item.name || item.path || "")
                });
        }
        return matches;
    }
    function normalize(value) {
        var text = String(value || "").toLowerCase();
        if (text.normalize)
            text = text.normalize("NFD");
        return text.replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]+/g, " ").trim();
    }
    function refresh() {
        DiagnosticsService.refresh();
    }
    function syncFilteredModel(model, entries) {
        var keys = {};
        for (var entry of entries)
            keys[entry.stableKey] = true;
        for (var index = model.count - 1; index >= 0; --index) {
            if (!keys[model.get(index).stableKey])
                model.remove(index);
        }
        for (var index = 0; index < entries.length; ++index) {
            var entry = entries[index];
            var existingIndex = index;
            while (existingIndex < model.count && model.get(existingIndex).stableKey !== entry.stableKey)
                ++existingIndex;
            if (existingIndex === model.count) {
                model.insert(index, entry);
            } else {
                if (existingIndex !== index)
                    model.move(existingIndex, index, 1);
                if (model.get(index).payload !== entry.payload)
                    model.setProperty(index, "payload", entry.payload);
            }
        }
    }
    function syncServiceModels() {
        root.syncFilteredModel(filteredStartupApps, root.matchingStartupEntries);
        root.syncFilteredModel(filteredUserServices, root.matchingUserEntries);
        root.syncFilteredModel(filteredSystemServices, root.matchingSystemEntries);
    }

    Component.onCompleted: root.refresh()
    onMatchingStartupEntriesChanged: Qt.callLater(root.syncServiceModels)
    onMatchingSystemEntriesChanged: Qt.callLater(root.syncServiceModels)
    onMatchingUserEntriesChanged: Qt.callLater(root.syncServiceModels)

    ListModel {
        id: filteredStartupApps
    }
    ListModel {
        id: filteredUserServices
    }
    ListModel {
        id: filteredSystemServices
    }
    Connections {
        function onDataChanged() {
            ++root.modelsRevision;
        }
        function onModelReset() {
            ++root.modelsRevision;
        }
        function onRowsInserted() {
            ++root.modelsRevision;
        }
        function onRowsMoved() {
            ++root.modelsRevision;
        }
        function onRowsRemoved() {
            ++root.modelsRevision;
        }

        target: DiagnosticsService.startupApps
    }
    Connections {
        function onDataChanged() {
            ++root.modelsRevision;
        }
        function onModelReset() {
            ++root.modelsRevision;
        }
        function onRowsInserted() {
            ++root.modelsRevision;
        }
        function onRowsMoved() {
            ++root.modelsRevision;
        }
        function onRowsRemoved() {
            ++root.modelsRevision;
        }

        target: DiagnosticsService.userServices
    }
    Connections {
        function onDataChanged() {
            ++root.modelsRevision;
        }
        function onModelReset() {
            ++root.modelsRevision;
        }
        function onRowsInserted() {
            ++root.modelsRevision;
        }
        function onRowsMoved() {
            ++root.modelsRevision;
        }
        function onRowsRemoved() {
            ++root.modelsRevision;
        }

        target: DiagnosticsService.systemServices
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: root.height < 480 ? Md3.spacing.xs : Md3.spacing.sm

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            border.color: searchInput.activeFocus ? Config.alpha(Config.md3.primary, 0.72) : Config.alpha(Config.md3.outline, 0.28)
            border.width: searchInput.activeFocus ? 2 : 1
            color: searchInput.activeFocus ? Config.alpha(Config.md3.primary_container, 0.12) : Config.md3.surface_container_low
            radius: Md3.shape.full

            Behavior on border.color {
                ColorAnimation {
                    duration: Config.animationDuration(Md3.motion.short3)
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Config.animationDuration(Md3.motion.short3)
                }
            }

            Md3Icon {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                color: searchInput.activeFocus ? Config.md3.primary : Config.md3.on_surface_variant
                name: "system-search-symbolic"
                size: 22
            }
            TextInput {
                id: searchInput

                activeFocusOnTab: true
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.leftMargin: 54
                anchors.right: clearButton.visible ? clearButton.left : parent.right
                anchors.rightMargin: clearButton.visible ? 8 : 18
                anchors.top: parent.top
                clip: true
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
                font.pixelSize: Md3.typeScale.bodyLarge.size
                font.weight: Font.Medium
                selectByMouse: true
                verticalAlignment: TextInput.AlignVCenter
            }
            Text {
                anchors.fill: searchInput
                color: Config.alpha(Config.md3.on_surface_variant, 0.68)
                elide: Text.ElideRight
                font: searchInput.font
                text: qsTr("Search apps and services")
                verticalAlignment: Text.AlignVCenter
                visible: searchInput.text === ""
            }
            Md3Icon {
                id: clearButton

                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                color: clearMouse.containsMouse ? Config.md3.on_surface : Config.md3.on_surface_variant
                name: "edit-clear-symbolic"
                size: 20
                visible: searchInput.text !== ""

                MouseArea {
                    id: clearMouse

                    anchors.fill: parent
                    anchors.margins: -9
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: searchInput.clear()
                }
            }
        }
        StartupServiceList {
            id: startupSection

            accentColor: Config.md3.primary
            compact: root.height < 720
            emptyText: root.searchQuery.trim() === "" ? qsTr("No startup applications found") : qsTr("No matching startup applications")
            kind: "startup"
            model: filteredStartupApps
            note: qsTr("Desktop entries launched with your user session")
            title: qsTr("Startup Apps")

            onToggleRequested: (path, enabled) => DiagnosticsService.startupAction(path, enabled)
        }
        StartupServiceList {
            id: userSection

            accentColor: Config.md3.secondary
            compact: root.height < 720
            emptyText: root.searchQuery.trim() === "" ? qsTr("No user services found") : qsTr("No matching user services")
            kind: "user"
            model: filteredUserServices
            note: qsTr("User systemd services; changes apply without administrator access")
            title: qsTr("User Services")

            onActionRequested: (name, action) => DiagnosticsService.serviceAction(name, action, "user")
        }
        StartupServiceList {
            id: systemSection

            accentColor: Config.md3.tertiary
            compact: root.height < 720
            emptyText: root.searchQuery.trim() === "" ? qsTr("No system services found") : qsTr("No matching system services")
            kind: "system"
            model: filteredSystemServices
            note: qsTr("Administrator authorization may be required. Stopping services can affect networking or your desktop session.")
            title: qsTr("System Services")

            onActionRequested: (name, action) => DiagnosticsService.serviceAction(name, action, "system")
        }
    }
}
