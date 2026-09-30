import "../../"
import ".."
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    property color accentColor: Config.md3.primary
    property bool checked: false
    default property alias contentData: details.data
    property int contentPadding: 20
    property int detailsSpacing: 16
    readonly property bool expanded: !toggleVisible || checked
    property bool heightAnimationEnabled: true
    property bool heightAnimationReady: false
    property string iconName: "preferences-system-symbolic"
    property string note: ""
    property string title: ""
    property bool toggleVisible: true

    signal toggled(bool checked)

    Layout.minimumWidth: 0
    clip: true
    color: Config.md3.surface_container_low
    implicitHeight: content.implicitHeight + root.contentPadding * 2
    implicitWidth: 0
    radius: Md3.shape.large

    Component.onCompleted: heightAnimationReady = true

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.margins: root.contentPadding
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 0
            spacing: Md3.spacing.sm

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 44
                Layout.preferredWidth: 44
                color: Config.alpha(root.accentColor, 0.14)
                radius: Md3.shape.medium

                Md3Icon {
                    anchors.centerIn: parent
                    color: root.accentColor
                    filled: root.checked
                    name: root.iconName
                    size: 24
                }
            }
            SettingsLabelBlock {
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                emphasized: true
                headline: root.title
                supportingText: root.note
            }
            ToggleSwitch {
                accessibleName: root.title
                checked: root.checked
                visible: root.toggleVisible

                onToggled: checked => {
                    return root.toggled(checked);
                }
            }
        }
        Item {
            id: detailsViewport

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: implicitHeight
            Layout.preferredWidth: 0
            clip: true
            enabled: root.expanded
            implicitHeight: root.expanded && details.children.length > 0 ? details.implicitHeight + 20 : 0

            Behavior on implicitHeight {
                enabled: root.heightAnimationEnabled && root.heightAnimationReady

                Md3NumberAnimation {
                    role: "transform"
                }
            }

            ColumnLayout {
                id: details

                anchors.left: parent.left
                anchors.right: parent.right
                opacity: root.expanded ? 1 : 0
                spacing: root.detailsSpacing
                y: 20

                Behavior on opacity {
                    Md3NumberAnimation {
                        role: "state"
                    }
                }
                transform: Translate {
                    y: root.expanded ? 0 : -6

                    Behavior on y {
                        Md3NumberAnimation {
                            role: "transform"
                        }
                    }
                }
            }
        }
    }
}
