import "../../"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property color accentColor: Config.md3.secondary
    property bool compact: false
    default property alias contentData: body.data
    property string note: ""
    property string title: ""

    clip: true
    color: Config.alpha(Config.md3.on_surface, 0.04)
    implicitHeight: body.implicitHeight + (compact ? 28 : 36)
    radius: 18

    ColumnLayout {
        id: body

        anchors.bottomMargin: root.compact ? 14 : 18
        anchors.fill: parent
        anchors.leftMargin: root.compact ? 16 : 20
        anchors.rightMargin: root.compact ? 16 : 20
        anchors.topMargin: root.compact ? 14 : 18
        spacing: root.compact ? 14 : 18

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                Layout.preferredHeight: 36
                Layout.preferredWidth: 36
                color: Config.alpha(root.accentColor, 0.13)
                radius: 11

                Rectangle {
                    anchors.centerIn: parent
                    border.color: root.accentColor
                    border.width: 2
                    color: "transparent"
                    height: 14
                    radius: 4
                    width: 14
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

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
        }
    }
}
