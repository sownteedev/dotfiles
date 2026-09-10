import QtQuick
import QtQuick.Controls.Basic
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "../../"
import "../../components"

Item {
    id: root

    readonly property real cornerRadius: previewSurface.radius
    readonly property bool hovered: previewHover.hovered
    property string iconName: "application-x-executable"
    property bool isMonochrome: false
    readonly property Item regionItem: previewSurface
    property bool shown: false
    property var windows: []

    signal windowActivated(string windowId)
    signal windowCloseRequested(string windowId)

    implicitHeight: 140
    implicitWidth: Math.min(860, windows.length > 0 ? (windows.length * 208 - 8 + 20) : 0)
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

            anchors.fill: parent
            anchors.margins: 10
            boundsBehavior: Flickable.StopAtBounds
            clip: contentWidth > width
            interactive: contentWidth > width
            model: root.windows
            orientation: ListView.Horizontal
            spacing: 8

            delegate: Button {
                id: windowCard

                required property var modelData

                Accessible.description: modelData.isFocused ? qsTr("Active window") : qsTr("Switch to this window")
                Accessible.name: modelData.title + ", " + modelData.workspaceLabel
                Accessible.role: Accessible.Button
                height: previewList.height
                hoverEnabled: true
                padding: 0
                width: 200

                background: Rectangle {
                    border.color: windowCard.visualFocus ? Config.md3.primary : windowCard.modelData.isFocused ? Config.alpha(Config.md3.primary, 0.55) : Config.alpha(Config.md3.outline_variant, 0.25)
                    border.width: 1
                    color: Config.md3.surface_container_high
                    radius: 14

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Config.animationDuration(120)
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        color: Config.md3.primary
                        opacity: windowCard.down ? 0.16 : windowCard.hovered || windowCard.visualFocus ? 0.1 : windowCard.modelData.isFocused ? 0.05 : 0
                        radius: 13

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Config.animationDuration(120)
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
                contentItem: Item {
                    IconImage {
                        id: previewIcon

                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.top: parent.top
                        anchors.topMargin: 12
                        height: 40
                        layer.enabled: root.isMonochrome
                        mipmap: true
                        source: Quickshell.iconPath(root.iconName || "application-x-executable")
                        width: 40

                        layer.effect: ColorOverlay {
                            color: Config.md3.on_surface
                        }
                    }
                    Column {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.margins: 12
                        anchors.right: parent.right
                        spacing: 5

                        Text {
                            id: windowTitle

                            color: Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            text: windowCard.modelData.title
                            textFormat: Text.PlainText
                            width: parent.width
                        }
                        Item {
                            height: workspaceText.implicitHeight
                            width: parent.width

                            Text {
                                id: workspaceText

                                anchors.left: parent.left
                                anchors.right: focusMarker.left
                                anchors.rightMargin: 8
                                color: Config.md3.on_surface_variant
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.pixelSize: 11
                                text: windowCard.modelData.workspaceLabel
                                textFormat: Text.PlainText
                            }
                            Rectangle {
                                id: focusMarker

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                color: Config.md3.primary
                                height: 4
                                opacity: windowCard.modelData.isFocused ? 1 : 0
                                radius: 2
                                width: 16
                            }
                        }
                    }
                }

                onClicked: root.windowActivated(String(windowCard.modelData.id || ""))

                Md3ToolTip {
                    delay: 500
                    text: windowCard.modelData.title
                    visible: windowCard.hovered && !closeButton.hovered && windowTitle.truncated
                    x: Math.round((windowCard.width - width) / 2)
                    y: -height - 7
                }
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
                Button {
                    id: closeButton

                    Accessible.name: qsTr("Close %1").arg(windowCard.modelData.title)
                    Accessible.role: Accessible.Button
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    height: 28
                    hoverEnabled: true
                    padding: 0
                    width: 28
                    z: 3

                    background: Rectangle {
                        border.color: Config.md3.error
                        border.width: closeButton.visualFocus ? 1 : 0
                        color: closeButton.down ? Config.md3.error : closeButton.hovered || closeButton.visualFocus ? Config.md3.error_container : Config.md3.surface_container_highest
                        radius: height / 2

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(100)
                            }
                        }
                    }
                    contentItem: Item {
                        Repeater {
                            model: [45, -45]

                            Rectangle {
                                required property int modelData

                                anchors.centerIn: parent
                                color: closeButton.down ? Config.md3.on_error : closeButton.hovered || closeButton.visualFocus ? Config.md3.on_error_container : Config.md3.on_surface_variant
                                height: 2
                                radius: 1
                                rotation: modelData
                                width: 11
                            }
                        }
                    }

                    onClicked: root.windowCloseRequested(String(windowCard.modelData.id || ""))

                    Md3ToolTip {
                        delay: 500
                        text: qsTr("Close window")
                        visible: closeButton.hovered || closeButton.visualFocus
                        x: Math.round((closeButton.width - width) / 2)
                        y: -height - 7
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }
    }

    component Md3ToolTip: ToolTip {
        id: tooltip

        bottomPadding: 8
        leftPadding: 11
        margins: 8
        rightPadding: 11
        timeout: 3200
        topPadding: 8

        background: Rectangle {
            border.color: Config.alpha(Config.md3.on_surface, 0.08)
            border.width: 1
            color: Config.md3.surface_container_highest
            radius: 10
        }
        contentItem: Text {
            color: Config.md3.on_surface
            font.family: Config.fontName
            font.pixelSize: 12
            font.weight: Font.Medium
            text: tooltip.text
            textFormat: Text.PlainText
            width: Math.min(280, implicitWidth)
            wrapMode: Text.Wrap
        }
    }
}
