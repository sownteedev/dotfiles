import "../../"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property color accentColor: Config.md3.secondary
    default property alias contentData: body.data
    property string note: ""
    property string title: ""

    clip: true
    color: Config.alpha(Config.md3.on_surface, 0.035)
    implicitHeight: body.implicitHeight + 32
    radius: 16

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.top: parent.top
        color: root.accentColor
        opacity: 0.8
        width: 4
    }
    ColumnLayout {
        id: body

        anchors.bottomMargin: 16
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 16
        anchors.topMargin: 16
        spacing: 16

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 18
                font.weight: Font.Bold
                text: root.title
            }
            Text {
                Layout.fillWidth: true
                color: Config.alpha(Config.md3.on_surface, 0.55)
                font.family: Config.fontName
                font.pixelSize: 13
                text: root.note
                visible: text !== ""
                wrapMode: Text.Wrap
            }
        }
    }
}
