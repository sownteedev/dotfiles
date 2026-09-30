import "." as SettingsComponents
import "../../"
import ".."
import QtQuick
import Qt5Compat.GraphicalEffects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    required property var groupData

    signal keybindEdited(string oldHeader, string newKey)

    color: Config.md3.surface_container_low
    implicitHeight: content.implicitHeight + 30
    radius: Md3.shape.large

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
                color: Config.md3.secondary_container
                radius: 14

                Md3Icon {
                    anchors.centerIn: parent
                    color: Config.md3.on_secondary_container
                    filled: true
                    name: root.groupData.icon
                    size: 16
                }
            }
            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: Md3.typography.titleMedium
                font.weight: Font.DemiBold
                text: root.groupData.name
            }
        }
        Rectangle {
            Layout.bottomMargin: 4
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Config.md3.outline_variant
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
                    color: Config.md3.on_surface_variant
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: Md3.typography.bodyMedium
                    font.weight: Font.Medium
                    text: modelData.description
                }
            }
        }
    }
}
