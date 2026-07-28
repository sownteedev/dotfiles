import "../../"
import ".."
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    default property alias contentData: details.data
    property color accentColor: Config.md3.primary
    property bool checked: false
    property int contentPadding: 20
    property int detailsSpacing: 16
    property string note: ""
    property string title: ""
    property bool toggleVisible: true
    readonly property bool expanded: !toggleVisible || checked

    signal toggled(bool checked)

    clip: true
    color: Config.alpha(Config.md3.on_surface, 0.04)
    implicitHeight: content.implicitHeight + root.contentPadding * 2
    radius: 18

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.contentPadding
        spacing: root.expanded && details.children.length > 0 ? 20 : 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            Rectangle {
                Layout.preferredHeight: 38
                Layout.preferredWidth: 38
                color: Config.alpha(root.accentColor, 0.13)
                radius: 11

                Rectangle {
                    anchors.centerIn: parent
                    border.color: root.accentColor
                    border.width: 2
                    color: "transparent"
                    height: 15
                    radius: 4
                    width: 15
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    text: root.title
                }

                Text {
                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.on_surface, 0.45)
                    font.family: Config.fontName
                    font.pixelSize: 12
                    text: root.note
                    visible: text !== ""
                    wrapMode: Text.Wrap
                }
            }

            ToggleSwitch {
                accessibleName: root.title
                checked: root.checked
                visible: root.toggleVisible
                onToggled: (checked) => root.toggled(checked)
            }
        }

        ColumnLayout {
            id: details

            Layout.fillWidth: true
            spacing: root.detailsSpacing
            enabled: root.expanded
            opacity: root.expanded ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }
        }
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }
}
