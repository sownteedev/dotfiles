import QtQuick
import QtQuick.Layouts
import "../../"
import "../../components"

ColumnLayout {
    id: root

    property string actionIcon: ""
    property alias echoMode: input.echoMode
    property bool editable: true
    property int fieldHeight: 44

    // Customization aliases
    property alias horizontalAlignment: input.horizontalAlignment
    property alias inputItem: input
    property string label: ""
    property alias passwordCharacter: input.passwordCharacter
    property string placeholder: ""
    property alias text: input.text
    property alias verticalAlignment: input.verticalAlignment

    signal actionClicked

    spacing: 8

    Text {
        color: Config.alpha(Config.md3.on_surface, 0.85)
        font.family: Config.fontName
        font.pixelSize: 14
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering
        text: root.label
        visible: text !== ""
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.fieldHeight
            border.color: input.activeFocus ? Config.alpha(Config.md3.primary, 0.65) : "transparent"
            border.width: 1
            color: Config.alpha(Config.md3.on_surface, 0.05)
            radius: 12

            Behavior on border.color {
                ColorAnimation {
                    duration: 150
                }
            }

            TextInput {
                id: input

                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                clip: true
                color: Config.md3.on_surface
                enabled: root.editable
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.Medium
                verticalAlignment: TextInput.AlignVCenter
            }
            Text {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                color: Config.alpha(Config.md3.on_surface, 0.38)
                elide: Text.ElideRight
                font: input.font
                renderType: Text.NativeRendering
                text: root.placeholder
                verticalAlignment: Text.AlignVCenter
                visible: input.text === ""
            }
        }
        SettingsActionButton {
            Layout.alignment: Qt.AlignVCenter
            enabled: root.enabled && root.editable
            iconName: root.actionIcon
            visible: root.actionIcon !== ""

            onClicked: root.actionClicked()
        }
    }
}
