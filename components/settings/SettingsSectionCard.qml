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
    color: Config.alpha(Config.md3.on_surface, 0.035)
    implicitHeight: body.implicitHeight + (compact ? 24 : 32)
    radius: compact ? 15 : 16

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

        anchors.bottomMargin: root.compact ? 12 : 16
        anchors.fill: parent
        anchors.leftMargin: root.compact ? 18 : 20
        anchors.rightMargin: root.compact ? 14 : 16
        anchors.topMargin: root.compact ? 12 : 16
        spacing: root.compact ? 12 : 16

        ColumnLayout {
            Layout.fillWidth: true
            spacing: root.compact ? 3 : 5

            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: root.compact ? 17 : 18
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
