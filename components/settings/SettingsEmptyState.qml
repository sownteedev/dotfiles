import "../../"
import ".."
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property color accentColor: Config.md3.on_surface_variant
    property string iconName: "search"
    property string text: ""

    implicitHeight: 88

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 40
            Layout.preferredWidth: 40
            color: Config.alpha(root.accentColor, 0.12)
            radius: Md3.shape.full

            Md3Icon {
                anchors.centerIn: parent
                color: root.accentColor
                name: root.iconName
                size: 21
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            color: Config.md3.on_surface_variant
            font.family: Config.fontName
            font.pixelSize: Md3.typeScale.bodyMedium.size
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            text: root.text
        }
    }
}
