import "../../"
import QtQuick
import QtQuick.Controls.Basic

ToolTip {
    id: root

    property string description: ""
    property string shortcut: ""
    required property string title

    bottomPadding: 9
    delay: 320
    leftPadding: 11
    margins: 8
    rightPadding: 11
    timeout: 5000
    topPadding: 9

    background: Rectangle {
        border.color: Config.alpha(Config.md3.outline_variant, 0.5)
        border.width: 1
        color: Config.md3.surface_container_highest
        radius: 11
    }
    contentItem: Column {
        spacing: 4

        Row {
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 12
                font.weight: Font.DemiBold
                text: root.title
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                color: Config.alpha(Config.md3.primary, 0.14)
                height: 20
                radius: 6
                visible: root.shortcut !== ""
                width: shortcutLabel.implicitWidth + 12

                Text {
                    id: shortcutLabel

                    anchors.centerIn: parent
                    color: Config.md3.primary
                    font.family: Config.fontName
                    font.pixelSize: 10
                    font.weight: Font.Bold
                    text: root.shortcut
                }
            }
        }
        Text {
            color: Config.md3.on_surface_variant
            font.family: Config.fontName
            font.pixelSize: 11
            lineHeight: 1.12
            text: root.description
            visible: text !== ""
            width: Math.min(300, implicitWidth)
            wrapMode: Text.Wrap
        }
    }
}
