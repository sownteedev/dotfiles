import QtQuick
import QtQuick.Layouts
import "../../"
import "../../components"

ColumnLayout {
    id: root

    property string actionIcon: ""
    property alias echoMode: input.echoMode
    property bool editable: true
    property int fieldHeight: 56

    // Customization aliases
    property alias horizontalAlignment: input.horizontalAlignment
    property alias inputItem: input
    property string label: ""
    property alias passwordCharacter: input.passwordCharacter
    property string placeholder: ""
    property color placeholderColor: Config.alpha(Config.md3.on_surface_variant, 0.3)
    property bool showLabel: true
    property alias text: input.text
    property alias verticalAlignment: input.verticalAlignment

    signal actionClicked

    Layout.minimumWidth: 0
    spacing: 8

    Text {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        color: Config.alpha(Config.md3.on_surface, 0.85)
        elide: Text.ElideRight
        font.family: Config.fontName
        font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
        font.pixelSize: Md3.typeScale.labelLarge.size
        font.weight: Md3.typeScale.labelLarge.emphasizedWeight
        lineHeight: Md3.typeScale.labelLarge.lineHeight
        lineHeightMode: Text.FixedHeight
        renderType: Text.NativeRendering
        text: root.label
        visible: root.showLabel && text !== ""
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: root.fieldHeight
            border.color: input.activeFocus ? Config.alpha(Config.md3.primary, 0.52) : Config.alpha(Config.md3.outline, 0.22)
            border.width: 1
            color: Config.md3.surface_container_low
            radius: Md3.shape.medium

            Behavior on border.color {
                ColorAnimation {
                    duration: Config.animationDuration(Md3.motion.short3)
                }
            }

            TextInput {
                id: input

                Accessible.description: root.placeholder
                Accessible.name: root.label !== "" ? root.label : root.placeholder
                Accessible.role: Accessible.EditableText
                activeFocusOnTab: root.editable
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                clip: true
                color: Config.md3.on_surface
                enabled: root.editable
                font.family: Config.fontName
                font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
                font.pixelSize: Md3.typeScale.bodyLarge.size
                font.weight: Font.Medium
                verticalAlignment: TextInput.AlignVCenter
            }
            Text {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                color: root.placeholderColor
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
