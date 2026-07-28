import "." as SettingsComponents
import "../../"
import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    required property var groupData

    signal keybindEdited(string oldHeader, string newKey)

    color: Config.alpha(Config.md3.on_surface, 0.045)
    implicitHeight: content.implicitHeight + 30
    radius: 16

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.margins: 15
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 11

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredHeight: 28
                Layout.preferredWidth: 28
                color: Config.alpha(Config.md3.on_surface, 0.08)
                radius: 14

                IconImage {
                    anchors.centerIn: parent
                    height: 16
                    layer.enabled: true
                    source: Quickshell.iconPath(root.groupData.icon)
                    width: 16

                    layer.effect: ColorOverlay {
                        color: Config.md3.on_surface
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 18
                font.weight: Font.DemiBold
                text: root.groupData.name
            }
        }
        Rectangle {
            Layout.bottomMargin: 4
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Config.alpha(Config.md3.on_surface, 0.05)
        }
        Repeater {
            model: root.groupData.items || []

            delegate: RowLayout {
                required property var modelData

                Layout.fillWidth: true
                spacing: 12

                SettingsComponents.EditableKeybindPill {
                    displayKey: modelData.key
                    interactive: root.enabled
                    oldHeader: modelData.rawHeader

                    onCommitted: (oldHeader, newKey) => {
                        return root.keybindEdited(oldHeader, newKey);
                    }
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.on_surface, 0.78)
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    text: modelData.description
                }
            }
        }
    }
}
