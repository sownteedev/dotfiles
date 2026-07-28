import "../../"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    default property alias contentData: body.data
    property color accentColor: Config.md3.secondary
    property string note: ""
    property string title: ""

    color: Config.alpha(Config.md3.on_surface, 0.035)
    implicitHeight: body.implicitHeight + 32
    radius: 16
    clip: true

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 4
        color: root.accentColor
        opacity: 0.8
    }

    ColumnLayout {
        id: body

        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 16
        anchors.topMargin: 16
        anchors.bottomMargin: 16
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
