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

    Layout.alignment: Qt.AlignTop
    Layout.fillWidth: true
    color: Config.alpha(Config.md3.on_surface, 0.04)
    implicitHeight: body.implicitHeight + (compact ? 24 : 30)
    radius: 18

    ColumnLayout {
        id: body

        anchors.bottomMargin: root.compact ? 12 : 15
        anchors.fill: parent
        anchors.leftMargin: root.compact ? 16 : 20
        anchors.rightMargin: root.compact ? 16 : 20
        anchors.topMargin: root.compact ? 12 : 15
        spacing: root.compact ? 12 : 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 15

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 38
                Layout.preferredWidth: 38
                color: Config.alpha(root.accentColor, 0.13)
                radius: 11

                transform: Translate {
                    y: -2
                }

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
                Layout.alignment: Qt.AlignVCenter
                Layout.fillWidth: true
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    font.family: Config.fontName
                    font.pixelSize: 17
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
