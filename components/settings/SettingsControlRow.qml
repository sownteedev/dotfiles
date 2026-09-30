import "../../"
import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    default property alias contentData: controls.data
    property real controlWidth: 260
    property string label: ""
    property string note: ""
    property bool showDivider: true
    readonly property bool stacked: width < 560

    Layout.fillWidth: true
    Layout.minimumWidth: 0
    implicitHeight: row.implicitHeight + Md3.spacing.md * 2
    implicitWidth: 0

    GridLayout {
        id: row

        anchors.left: parent.left
        anchors.leftMargin: Md3.spacing.xxs
        anchors.right: parent.right
        anchors.rightMargin: Md3.spacing.xxs
        anchors.top: parent.top
        anchors.topMargin: Md3.spacing.md
        columnSpacing: Md3.spacing.lg
        columns: root.stacked ? 1 : 2
        rowSpacing: Md3.spacing.sm

        SettingsLabelBlock {
            Layout.fillWidth: true
            Layout.preferredWidth: 0
            headline: root.label
            supportingText: root.note
        }
        RowLayout {
            id: controls

            Layout.fillWidth: true
            Layout.maximumWidth: root.stacked ? Infinity : root.controlWidth
            Layout.minimumWidth: 0
            Layout.preferredWidth: root.stacked ? 0 : root.controlWidth
            spacing: Md3.spacing.xs
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        color: Config.alpha(Config.md3.outline_variant, 0.45)
        height: 1
        visible: root.showDivider
        width: parent.width
    }
}
