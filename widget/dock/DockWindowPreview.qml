import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../"
import "../../components"

Item {
    id: root

    readonly property real cornerRadius: previewSurface.radius
    readonly property bool hovered: previewHover.hovered
    property string iconName: "application-x-executable"
    readonly property Item regionItem: previewSurface
    property bool shown: false
    property var windows: []

    signal windowActivated(string windowId)
    signal windowCloseRequested(string windowId)

    implicitHeight: 156
    implicitWidth: Math.min(920, windows.length > 0 ? (windows.length * 224 - 8 + 16) : 0)
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.96
    transformOrigin: Item.Bottom
    visible: shown || opacity > 0.01

    Behavior on opacity {
        NumberAnimation {
            duration: Config.animationDuration(130)
            easing.type: Easing.OutCubic
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Config.animationDuration(170)
            easing.type: Easing.OutBack
        }
    }

    ShellShadow {
        active: root.visible
        cornerRadius: previewSurface.radius
        target: previewSurface
    }
    Rectangle {
        id: previewSurface

        anchors.fill: parent
        border.color: Config.alpha(Config.md3.outline_variant, Config.lightTheme ? 0.46 : 0.3)
        border.width: 1
        color: Config.alpha(Config.md3.surface_container, Config.lightTheme ? 0.97 : 0.94)
        radius: 22

        HoverHandler {
            id: previewHover
        }
        ListView {
            id: previewList

            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.top: parent.top
            anchors.topMargin: 8
            boundsBehavior: Flickable.StopAtBounds
            clip: contentWidth > width
            interactive: contentWidth > width
            model: root.windows
            orientation: ListView.Horizontal
            spacing: 8

            delegate: Rectangle {
                id: windowCard

                required property var modelData

                Accessible.name: modelData.title
                Accessible.role: Accessible.Button
                border.color: modelData.isFocused ? Config.md3.primary : windowCardHover.hovered ? Config.alpha(Config.md3.primary, 0.7) : Config.alpha(Config.md3.outline_variant, 0.4)
                border.width: modelData.isFocused || windowCardHover.hovered ? 2 : 1
                color: previewMouse.pressed ? Config.alpha(Config.md3.primary, 0.16) : windowCardHover.hovered ? Config.alpha(Config.md3.surface_container_highest, 0.96) : Config.alpha(Config.md3.surface_container_high, 0.82)
                height: previewList.height
                radius: 16
                scale: previewMouse.pressed ? 0.975 : windowCardHover.hovered ? 1.018 : 1
                transformOrigin: Item.Center
                width: 216

                Behavior on border.color {
                    ColorAnimation {
                        duration: Config.animationDuration(110)
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Config.animationDuration(110)
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Config.animationDuration(100)
                        easing.type: Easing.OutCubic
                    }
                }

                HoverHandler {
                    id: windowCardHover
                }
                Rectangle {
                    id: thumbnailSlot

                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    color: windowCardHover.hovered ? Config.alpha(Config.md3.primary_container, 0.38) : Config.alpha(Config.md3.surface_container_highest, 0.86)
                    height: 92
                    radius: 12

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animationDuration(120)
                        }
                    }

                    IconImage {
                        id: windowIcon

                        anchors.centerIn: parent
                        height: 42
                        mipmap: true
                        opacity: 0.9
                        scale: windowCardHover.hovered ? 1.08 : 1
                        smooth: true
                        source: Quickshell.iconPath(root.iconName || "application-x-executable")
                        width: 42

                        Behavior on scale {
                            NumberAnimation {
                                duration: Config.animationDuration(140)
                                easing.type: Easing.OutBack
                            }
                        }
                    }
                }
                Column {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 9
                    anchors.left: parent.left
                    anchors.leftMargin: 11
                    anchors.right: parent.right
                    anchors.rightMargin: 11
                    spacing: 2

                    Text {
                        color: Config.md3.on_surface
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        text: windowCard.modelData.title
                        width: parent.width
                    }
                    Text {
                        color: Config.md3.on_surface_variant
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        text: windowCard.modelData.workspaceLabel
                        width: parent.width
                    }
                }
                MouseArea {
                    id: previewMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.windowActivated(String(windowCard.modelData.id || ""))
                }
                Rectangle {
                    id: closeButton

                    Accessible.name: qsTr("Close %1").arg(windowCard.modelData.title)
                    Accessible.role: Accessible.Button
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.top: parent.top
                    anchors.topMargin: 14
                    color: closeMouse.pressed ? Config.md3.error : closeMouse.containsMouse ? Config.alpha(Config.md3.error, 0.92) : Config.alpha(Config.md3.error_container, 0.94)
                    height: 28
                    opacity: windowCardHover.hovered ? 1 : 0
                    radius: height / 2
                    scale: windowCardHover.hovered ? 1 : 0.82
                    visible: windowCardHover.hovered || opacity > 0.01
                    width: 28
                    z: 3

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animationDuration(100)
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Config.animationDuration(110)
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Config.animationDuration(130)
                            easing.type: Easing.OutBack
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        color: closeMouse.pressed || closeMouse.containsMouse ? Config.md3.on_error : Config.md3.on_error_container
                        font.family: Config.fontName
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        text: "×"
                    }
                    MouseArea {
                        id: closeMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true

                        onClicked: mouse => {
                            mouse.accepted = true;
                            root.windowCloseRequested(String(windowCard.modelData.id || ""));
                        }
                    }
                }
            }
        }
    }
}
