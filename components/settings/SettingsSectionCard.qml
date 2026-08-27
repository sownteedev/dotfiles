import "../../"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    property color accentColor: Config.md3.secondary
    property bool compact: false
    default property alias contentData: body.data
    property string iconName: "preferences-system-symbolic"
    property string note: ""
    property bool showHeader: true
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
            visible: root.showHeader

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 42
                Layout.preferredWidth: 42
                color: Config.alpha(root.accentColor, 0.14)
                radius: 13

                IconImage {
                    anchors.centerIn: parent
                    height: 21
                    layer.enabled: true
                    source: Quickshell.iconPath(root.iconName)
                    width: 21

                    layer.effect: ColorOverlay {
                        color: root.accentColor
                    }
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
