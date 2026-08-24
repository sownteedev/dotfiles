import QtQuick
import QtQuick.Controls.Basic

Button {
    id: root

    required property string accessibleName
    property color containerColor: GreeterTheme.withAlpha(GreeterTheme.surfaceContainerHigh, 0.9)
    property color contentColor: GreeterTheme.surfaceText
    property bool destructive: false
    required property string iconGlyph

    Accessible.name: accessibleName
    implicitHeight: 48
    implicitWidth: 48

    background: Rectangle {
        border.color: root.activeFocus ? (root.destructive ? GreeterTheme.error : GreeterTheme.primary) : root.destructive ? GreeterTheme.withAlpha(GreeterTheme.error, 0.38) : GreeterTheme.withAlpha(GreeterTheme.outlineVariant, 0.46)
        border.width: root.activeFocus ? 2 : 1
        color: root.down ? (root.destructive ? GreeterTheme.withAlpha(GreeterTheme.error, 0.24) : GreeterTheme.withAlpha(GreeterTheme.primary, 0.24)) : root.hovered ? (root.destructive ? GreeterTheme.withAlpha(GreeterTheme.error, 0.16) : GreeterTheme.withAlpha(GreeterTheme.primary, 0.14)) : root.containerColor
        radius: 16

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
    }
    contentItem: Text {
        color: root.destructive ? GreeterTheme.error : root.contentColor
        font.family: "Symbols Nerd Font"
        font.pixelSize: 20
        horizontalAlignment: Text.AlignHCenter
        text: root.iconGlyph
        verticalAlignment: Text.AlignVCenter
    }
}
