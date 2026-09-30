import "../../"
import ".."
import QtQuick
import QtQuick.Layouts
import "../common"

Md3ToolTip {
    id: root

    property string description: ""
    property string shortcut: ""
    required property string title

    cornerRadius: Md3.shape.medium
    margins: Md3.spacing.xs
    maximumTextWidth: 300
    timeout: 5000

    contentItem: ColumnLayout {
        spacing: Md3.spacing.xxs

        RowLayout {
            Layout.fillWidth: true
            spacing: Md3.spacing.xs

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                color: Config.md3.on_surface
                elide: Text.ElideRight
                font.family: Config.fontName
                font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
                font.pixelSize: Md3.typeScale.labelLarge.size
                font.weight: Md3.typeScale.labelLarge.weight
                text: root.title
            }
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: 20
                Layout.preferredWidth: shortcutLabel.implicitWidth + Md3.spacing.sm
                color: Config.md3.secondary_container
                radius: Md3.shape.extraSmall
                visible: root.shortcut !== ""

                Text {
                    id: shortcutLabel

                    anchors.centerIn: parent
                    color: Config.md3.on_secondary_container
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.labelSmall.letterSpacing
                    font.pixelSize: Md3.typeScale.labelSmall.size
                    font.weight: Md3.typeScale.labelSmall.weight
                    text: root.shortcut
                }
            }
        }
        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            color: Config.md3.on_surface_variant
            font.family: Config.fontName
            font.letterSpacing: Md3.typeScale.bodySmall.letterSpacing
            font.pixelSize: Md3.typeScale.bodySmall.size
            font.weight: Md3.typeScale.bodySmall.weight
            lineHeight: Md3.typeScale.bodySmall.lineHeight
            lineHeightMode: Text.FixedHeight
            text: root.description
            visible: text !== ""
            wrapMode: Text.Wrap
        }
    }
}
