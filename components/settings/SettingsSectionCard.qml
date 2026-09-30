import "../../"
import ".."
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property color accentColor: Config.md3.secondary
    property bool compact: false
    default property alias contentData: body.data
    property real contentSpacing: compact ? Md3.spacing.sm : Md3.spacing.md
    readonly property real headerOffset: headerOutside && showHeader ? sectionHeading.implicitHeight + Md3.spacing.sm : 0
    property bool headerOutside: false
    property string iconName: "preferences-system-symbolic"
    property string note: ""
    property bool showHeader: true
    property string title: ""

    Layout.alignment: Qt.AlignTop
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    color: headerOutside ? "transparent" : Config.md3.surface_container_low
    implicitHeight: body.implicitHeight + 2 * (compact ? Md3.spacing.sm : Md3.spacing.md) + headerOffset
    implicitWidth: 0
    radius: Md3.shape.large

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: root.headerOffset
        color: Config.md3.surface_container_low
        radius: root.radius
        visible: root.headerOutside
    }
    SettingsLabelBlock {
        id: sectionHeading

        anchors.left: parent.left
        anchors.leftMargin: Md3.spacing.xxs
        anchors.right: parent.right
        anchors.rightMargin: Md3.spacing.xxs
        anchors.top: parent.top
        emphasized: true
        headline: root.title
        headlineColor: root.accentColor
        headlineRole: "titleMedium"
        headlineSize: Md3.typeScale.titleMedium.size + 2
        supportingText: root.note
        visible: root.headerOutside && root.showHeader
    }
    ColumnLayout {
        id: body

        anchors.bottomMargin: root.compact ? Md3.spacing.sm : Md3.spacing.md
        anchors.fill: parent
        anchors.leftMargin: root.compact ? Md3.spacing.md : Md3.spacing.md + Md3.spacing.xxs
        anchors.rightMargin: root.compact ? Md3.spacing.md : Md3.spacing.md + Md3.spacing.xxs
        anchors.topMargin: (root.compact ? Md3.spacing.sm : Md3.spacing.md) + root.headerOffset
        spacing: root.contentSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Md3.spacing.sm
            visible: root.showHeader && !root.headerOutside

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 44
                Layout.preferredWidth: 44
                color: Config.alpha(root.accentColor, 0.14)
                radius: Md3.shape.medium

                Md3Icon {
                    anchors.centerIn: parent
                    color: root.accentColor
                    filled: true
                    name: root.iconName
                    size: 24
                }
            }
            SettingsLabelBlock {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                emphasized: true
                headline: root.title
                supportingText: root.note
            }
        }
    }
}
