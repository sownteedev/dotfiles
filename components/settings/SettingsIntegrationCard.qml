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
    color: Config.alpha(Config.md3.on_surface, 0.045)
    implicitHeight: body.implicitHeight + 28
    radius: 20

    ColumnLayout {
        id: body

        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.top: parent.top
        anchors.topMargin: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredHeight: 42
                Layout.preferredWidth: 42
                color: Config.alpha(root.accentColor, 0.14)
                radius: 13

                IconImage {
                    anchors.centerIn: parent
                    height: 21
                    layer.enabled: true
                    source: Quickshell.iconPath(root.iconName)
                    width: 21

                    layer.effect: ColorOverlay {
                        color: root.accentColor
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                    text: root.title
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.on_surface, 0.46)
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                    text: root.note
                    visible: text !== ""
                }
            }
            Rectangle {
                Accessible.name: root.statusText
                Accessible.role: Accessible.StaticText
                Layout.preferredHeight: 38
                Layout.preferredWidth: 38
                color: Config.alpha(root.statusColor, 0.14)
                radius: 12
                visible: root.statusIcon !== ""

                IconImage {
                    anchors.centerIn: parent
                    height: 19
                    layer.enabled: true
                    source: Quickshell.iconPath(root.statusIcon)
                    width: 19

                    layer.effect: ColorOverlay {
                        color: root.statusColor
                    }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: 7
                    color: Config.md3.surface_container_high
                    height: 30
                    radius: 9
                    visible: statusMouse.containsMouse && root.statusText !== ""
                    width: statusTooltip.implicitWidth + 18
                    z: 20

                    Text {
                        id: statusTooltip

                        anchors.centerIn: parent
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        text: root.statusText
                    }
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
