import QtQuick
import QtQuick.Controls.Basic
import "../../"

ToolTip {
    id: root

    property real cornerRadius: Md3.shape.small
    property int maximumTextWidth: 0
    property bool plainText: false

    bottomPadding: Md3.spacing.xs
    delay: Md3.motion.medium3
    leftPadding: Md3.spacing.sm
    rightPadding: Md3.spacing.sm
    timeout: 3000
    topPadding: Md3.spacing.xs
    width: maximumTextWidth > 0 ? Math.min(implicitWidth, maximumTextWidth + leftPadding + rightPadding) : implicitWidth

    background: Rectangle {
        border.color: Config.alpha(Config.md3.outline_variant, 0.72)
        border.width: 1
        color: Config.md3.surface_container_highest
        radius: root.cornerRadius
    }
    contentItem: Text {
        color: Config.md3.on_surface
        font.family: Config.fontName
        font.letterSpacing: Md3.typeScale.bodySmall.letterSpacing
        font.pixelSize: Md3.typeScale.bodySmall.size
        font.weight: Md3.typeScale.bodySmall.weight
        text: root.text
        textFormat: root.plainText ? Text.PlainText : Text.AutoText
        wrapMode: root.maximumTextWidth > 0 ? Text.Wrap : Text.NoWrap
    }
}
