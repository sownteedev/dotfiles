import "../../"
import ".."
import "../../service"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    readonly property color activeStatusColor: Config.lightTheme ? "#256d35" : "#81c784"
    readonly property bool filterMatches: root.matchesFilter(root.modelData, root.filterQuery)
    property string filterQuery: ""
    property string kind: "service"
    readonly property var modelData: {
        try {
            return JSON.parse(root.payload || "{}");
        } catch (error) {
            return {};
        }
    }
    required property string payload
    readonly property bool serviceManageable: root.modelData.manageable === true
    readonly property bool startupEnabled: ["enabled", "enabled-runtime"].indexOf(root.modelData.startup) >= 0
    readonly property bool startupToggleAvailable: ["enabled", "enabled-runtime", "disabled"].indexOf(root.modelData.startup) >= 0
    readonly property bool statusActive: root.kind === "startup" ? root.modelData.enabled === true : root.modelData.state === "active"

    signal actionRequested(string action)
    signal toggleRequested(bool enabled)

    function matchesFilter(item, queryText) {
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
    function memoryText(value) {
        var bytes = Number(value || 0);
        if (!bytes)
            return "";
        if (bytes >= 1024 * 1024 * 1024)
            return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GiB";
        return (bytes / (1024 * 1024)).toFixed(0) + " MiB";
    }
    function normalize(value) {
        var text = String(value || "").toLowerCase();
        if (text.normalize)
            text = text.normalize("NFD");
        return text.replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9]+/g, " ").trim();
    }

    Layout.fillWidth: true
    Layout.maximumHeight: root.filterMatches ? 68 : 0
    Layout.minimumHeight: 0
    Layout.preferredHeight: root.filterMatches ? 68 : 0
    color: Config.alpha(Config.md3.on_surface, 0.04)
    implicitHeight: root.filterMatches ? 68 : 0
    radius: Md3.shape.medium
    visible: root.filterMatches

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Md3.spacing.sm
        anchors.rightMargin: Md3.spacing.xs
        spacing: Md3.spacing.sm

        SettingsLabelBlock {
            Layout.fillWidth: true
            emphasized: true
            headline: root.modelData.name || root.modelData.file || ""
            supportingMaximumLineCount: 1
            supportingText: root.kind === "startup" ? (root.modelData.scope || "") + "  ·  " + (root.modelData.exec || "") : (root.modelData.description || root.modelData.subState || "") + (root.memoryText(root.modelData.memory) !== "" ? "  ·  " + root.memoryText(root.modelData.memory) : "")
        }
        Rectangle {
            color: root.statusActive ? Config.alpha(root.activeStatusColor, 0.16) : Config.alpha(Config.md3.on_surface, 0.08)
            implicitHeight: 28
            implicitWidth: statusText.implicitWidth + 18
            radius: Md3.shape.full

            Text {
                id: statusText

                anchors.centerIn: parent
                color: root.statusActive ? root.activeStatusColor : Config.md3.on_surface_variant
                font.family: Config.fontName
                font.pixelSize: Md3.typeScale.labelMedium.size
                font.weight: Md3.typeScale.labelMedium.weight
                text: root.kind === "startup" ? (root.modelData.enabled ? qsTr("On") : qsTr("Off")) : root.modelData.state || qsTr("Unknown")
            }
        }
        RowLayout {
            spacing: 4
            visible: root.kind === "user" || root.kind === "system"

            SettingsActionButton {
                enabled: root.serviceManageable && !DiagnosticsService.mutationBusy && root.modelData.state !== "active"
                iconName: "media-playback-start-symbolic"
                iconOnly: true
                tooltipText: qsTr("Start")

                onClicked: root.actionRequested("start")
            }
            SettingsActionButton {
                destructive: true
                enabled: root.serviceManageable && !DiagnosticsService.mutationBusy && root.modelData.state === "active"
                iconName: "media-playback-stop-symbolic"
                iconOnly: true
                tooltipText: qsTr("Stop")

                onClicked: root.actionRequested("stop")
            }
            SettingsActionButton {
                enabled: root.serviceManageable && !DiagnosticsService.mutationBusy
                iconName: "view-refresh-symbolic"
                iconOnly: true
                tooltipText: qsTr("Restart")

                onClicked: root.actionRequested("restart")
            }
            SettingsActionButton {
                enabled: root.serviceManageable && root.startupToggleAvailable && !DiagnosticsService.mutationBusy
                iconName: root.startupEnabled ? "toggle_on" : "toggle_off"
                iconOnly: true
                primary: root.startupEnabled
                tooltipText: !root.startupToggleAvailable ? qsTr("Startup cannot be toggled (%1)").arg(root.modelData.startup || "unknown") : root.kind === "system" ? (root.startupEnabled ? qsTr("Disable at boot") : qsTr("Enable at boot")) : (root.startupEnabled ? qsTr("Disable at login") : qsTr("Enable at login"))

                onClicked: root.actionRequested(root.startupEnabled ? "disable" : "enable")
            }
        }
        SettingsActionButton {
            enabled: !DiagnosticsService.mutationBusy && root.kind === "startup" && ["user", "system"].indexOf(root.modelData.scope) >= 0
            iconName: root.modelData.enabled ? "toggle_on" : "toggle_off"
            iconOnly: true
            primary: root.modelData.enabled === true
            tooltipText: root.modelData.enabled ? qsTr("Disable at login") : qsTr("Enable at login")
            visible: root.kind === "startup"

            onClicked: root.toggleRequested(!root.modelData.enabled)
        }
    }
}
