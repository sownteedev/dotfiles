import "../../"
import ".."
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property color accentColor: Config.md3.primary
    property bool actionEnabled: true
    property string actionIcon: ""
    property string actionText: ""
    property bool actionVisible: false
    default property alias contentData: details.data
    property string iconName: "application-x-executable-symbolic"
    property string note: ""
    property color statusColor: Config.md3.secondary
    property string statusIcon: ""
    property string statusText: ""
    property string title: ""

    signal actionClicked

    Accessible.name: title
    Accessible.role: Accessible.Grouping
    Layout.alignment: Qt.AlignTop
    Layout.fillWidth: true
    color: Config.md3.surface_container_low
    implicitHeight: body.implicitHeight + 2 * Md3.spacing.md
    radius: Md3.shape.large

    ColumnLayout {
        id: body

        anchors.left: parent.left
        anchors.leftMargin: Md3.spacing.md + Md3.spacing.xxs
        anchors.right: parent.right
        anchors.rightMargin: Md3.spacing.md + Md3.spacing.xxs
        anchors.top: parent.top
        anchors.topMargin: Md3.spacing.md
        spacing: Md3.spacing.md

        RowLayout {
            Layout.fillWidth: true
            spacing: Md3.spacing.sm

            Rectangle {
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
                Layout.fillWidth: true
                emphasized: true
                headline: root.title
                supportingText: root.note
            }
            Rectangle {
                Accessible.name: root.statusText
                Accessible.role: Accessible.StaticText
                Layout.preferredHeight: 38
                Layout.preferredWidth: 38
                color: Config.alpha(root.statusColor, 0.14)
                radius: Md3.shape.full
                visible: root.statusIcon !== ""

                Md3Icon {
                    anchors.centerIn: parent
                    color: root.statusColor
                    filled: true
                    name: root.statusIcon
                    size: 20
                }
                Md3ToolTip {
                    text: root.statusText
                    visible: statusMouse.containsMouse && root.statusText !== ""
                }
                MouseArea {
                    id: statusMouse

                    acceptedButtons: Qt.NoButton
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }
            SettingsActionButton {
                enabled: root.actionEnabled
                iconName: root.actionIcon
                iconOnly: true
                text: root.actionText
                visible: root.actionVisible && root.actionIcon !== ""

                onClicked: root.actionClicked()
            }
        }
        ColumnLayout {
            id: details

            Layout.fillWidth: true
            spacing: 12
            visible: children.length > 0
        }
    }
}
