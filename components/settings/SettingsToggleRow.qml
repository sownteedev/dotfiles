import "../../"
import ".."
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property bool checked: false
    property string label: ""
    property string note: ""

    signal toggled(bool checked)

    Layout.fillWidth: true
    spacing: 14

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        Text {
            Layout.fillWidth: true
            color: Config.md3.on_surface
            font.family: Config.fontName
            font.pixelSize: 15
            font.weight: Font.DemiBold
            text: root.label
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
        accessibleName: root.label
        checked: root.checked

        onToggled: checked => root.toggled(checked)
    }
}
