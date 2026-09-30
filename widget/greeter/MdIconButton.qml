pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic

Button {
    id: root

    required property string accessibleName
    property color containerColor: GreeterTheme.withAlpha(GreeterTheme.surfaceContainerHigh, 0.8)
    property color contentColor: GreeterTheme.surfaceText
    property bool destructive: false
    required property string iconGlyph
    property bool pill: false
    property real scaleFactor: 1

    Accessible.name: accessibleName
    activeFocusOnTab: false
    implicitHeight: Math.round(48 * root.scaleFactor)
    implicitWidth: pill ? Math.round(84 * root.scaleFactor) : implicitHeight

    background: Rectangle {
        border.color: root.destructive ? GreeterTheme.withAlpha(GreeterTheme.error, root.hovered ? 0.6 : 0.35) : root.hovered ? GreeterTheme.withAlpha(GreeterTheme.primary, 0.5) : GreeterTheme.withAlpha(GreeterTheme.outlineVariant, 0.35)
        border.width: 1
        color: root.down ? (root.destructive ? GreeterTheme.withAlpha(GreeterTheme.error, 0.26) : GreeterTheme.withAlpha(GreeterTheme.primary, 0.24)) : root.hovered ? (root.destructive ? GreeterTheme.withAlpha(GreeterTheme.error, 0.16) : GreeterTheme.withAlpha(GreeterTheme.primary, 0.14)) : root.containerColor
        radius: height / 2

        Behavior on border.color {
            ColorAnimation {
                duration: 140
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
    }
    contentItem: Text {
        color: root.destructive ? GreeterTheme.error : root.contentColor
        font.family: "Symbols Nerd Font"
        font.pixelSize: Math.round(20 * root.scaleFactor)
        horizontalAlignment: Text.AlignHCenter
        text: root.iconGlyph
        verticalAlignment: Text.AlignVCenter
    }
}
