import "../../"
import ".."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root

    property color accentColor: Config.md3.primary
    property bool compact: false
    property string emptyText: ""
    required property string kind
    property alias model: list.model
    property string note: ""
    readonly property bool scrolling: list.moving || scrollBar.pressed
    required property string title

    signal actionRequested(string name, string action)
    signal toggleRequested(string path, bool enabled)

    Layout.fillHeight: true
    Layout.fillWidth: true
    Layout.minimumHeight: 0
    Layout.minimumWidth: 0
    Layout.preferredHeight: 1
    spacing: Md3.spacing.xxs

    SettingsLabelBlock {
        Layout.fillWidth: true
        emphasized: true
        headline: root.title
        headlineColor: root.accentColor
        headlineSize: Md3.typeScale.titleMedium.size + 2
        supportingText: root.compact ? "" : root.note
    }
    Rectangle {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.minimumHeight: 0
        Layout.preferredHeight: 1
        clip: true
        color: Config.md3.surface_container_low
        radius: Md3.shape.large

        ListView {
            id: list

            anchors.fill: parent
            anchors.margins: Md3.spacing.xxs
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            flickableDirection: Flickable.VerticalFlick
            interactive: true
            reuseItems: true
            spacing: Md3.spacing.sm

            ScrollBar.vertical: ScrollBar {
                id: scrollBar

                policy: list.contentHeight > list.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }
            delegate: StartupServiceRow {
                id: serviceRow

                height: 68
                kind: root.kind
                width: Math.max(0, list.width - scrollBar.width - Md3.spacing.xxs)

                onActionRequested: action => root.actionRequested(serviceRow.modelData.name, action)
                onToggleRequested: enabled => root.toggleRequested(serviceRow.modelData.path, enabled)
            }
        }
        SettingsEmptyState {
            accentColor: root.accentColor
            anchors.centerIn: parent
            height: implicitHeight
            scale: Math.min(1, parent.height / implicitHeight)
            text: root.emptyText
            visible: list.count === 0
            width: parent.width
        }
    }
}
