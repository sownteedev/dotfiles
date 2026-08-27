pragma ComponentBehavior: Bound

import "../../"
import QtQuick

Rectangle {
    id: root

    property string actionText: ""
    readonly property color foregroundColor: tone === "primary" ? Config.md3.on_primary : tone === "error" ? Config.md3.on_error_container : Config.md3.on_surface
    property var shortcutKeys: []
    property string tone: "neutral"

    signal clicked

    function backgroundColor() {
        if (tone === "primary")
            return pointer.pressed ? Config.md3.primary_container : pointer.containsMouse ? Config.alpha(Config.md3.primary, 0.88) : Config.md3.primary;

        if (tone === "error")
            return pointer.pressed ? Config.md3.error_container : pointer.containsMouse ? Config.alpha(Config.md3.error_container, 0.9) : Config.alpha(Config.md3.error_container, 0.68);

        return Config.alpha(Config.md3.on_surface, pointer.pressed ? 0.14 : pointer.containsMouse ? 0.09 : 0.055);
    }

    Accessible.name: actionText + ", " + shortcutKeys.join(" plus ")
    Accessible.role: Accessible.Button
    activeFocusOnTab: enabled
    border.color: activeFocus ? Config.alpha(tone === "primary" ? Config.md3.on_primary : tone === "error" ? Config.md3.error : Config.md3.primary, 0.74) : Config.alpha(Config.md3.outline_variant, tone === "neutral" ? 0.2 : 0.12)
    border.width: 1
    color: backgroundColor()
    implicitHeight: 40
    implicitWidth: shortcutContent.implicitWidth + 18
    opacity: enabled ? 1 : 0.42
    radius: 12
    scale: pointer.pressed ? 0.97 : 1

    Behavior on border.color {
        ColorAnimation {
            duration: 130
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: 130
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: 120
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: 110
            easing.type: Easing.OutCubic
        }
    }

    Accessible.onPressAction: {
        if (root.enabled)
            root.clicked();
    }
    Keys.onReturnPressed: event => {
        root.clicked();
        event.accepted = true;
    }
    Keys.onSpacePressed: event => {
        root.clicked();
        event.accepted = true;
    }

    Row {
        id: shortcutContent

        anchors.centerIn: parent
        spacing: 8

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Repeater {
                model: root.shortcutKeys

                delegate: Item {
                    id: keycap

                    required property string modelData

                    height: 27
                    width: Math.max(25, keyLabel.implicitWidth + 13)

                    Rectangle {
                        anchors.bottom: parent.bottom
                        color: Config.alpha(root.foregroundColor, root.tone === "primary" ? 0.24 : 0.16)
                        height: 25
                        radius: 7
                        width: parent.width
                    }
                    Rectangle {
                        border.color: Config.alpha(root.foregroundColor, root.tone === "primary" ? 0.34 : 0.24)
                        border.width: 1
                        color: Config.alpha(root.foregroundColor, root.tone === "primary" ? 0.13 : 0.08)
                        height: 25
                        radius: 7
                        width: parent.width
                        y: pointer.pressed ? 2 : 0

                        Behavior on y {
                            NumberAnimation {
                                duration: 80
                                easing.type: Easing.OutCubic
                            }
                        }

                        Text {
                            id: keyLabel

                            anchors.centerIn: parent
                            color: root.foregroundColor
                            font.family: Config.fontName
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            text: keycap.modelData
                        }
                    }
                }
            }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            color: Config.alpha(root.foregroundColor, 0.2)
            height: 18
            width: 1
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: root.foregroundColor
            font.family: Config.fontName
            font.pixelSize: 13
            font.weight: Font.DemiBold
            text: root.actionText
        }
    }
    MouseArea {
        id: pointer

        anchors.fill: parent
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled
        hoverEnabled: true

        onClicked: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            root.clicked();
        }
    }
}
