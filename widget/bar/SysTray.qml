import "../../"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

RowLayout {
    id: root

    required property var parentWindow

    spacing: 32

    Repeater {
        model: SystemTray.items

        delegate: MouseArea {
            id: itemArea

            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            height: 24
            hoverEnabled: true
            width: 24

            onClicked: mouse => {
                if (modelData.hasMenu)
                    menuPopupLoader.active = !menuPopupLoader.active;
                else
                    modelData.activate();
            }

            // PopupWindow is created only when the tray item is clicked.
            LazyLoader {
                id: menuPopupLoader

                active: false

                PopupWindow {
                    id: menuPopup

                    anchor.edges: Edges.Bottom | Edges.Left
                    // ONLY set anchor.item (setting anchor.window unsets anchor.item, causing positioning/crash issues)
                    anchor.item: itemArea
                    anchor.margins.left: -30
                    anchor.margins.top: 30
                    color: "transparent"
                    grabFocus: true
                    implicitHeight: layout.implicitHeight + 20 + 12 + 10 // Content height + margins + padding + top arrow space
                    implicitWidth: 240
                    visible: true

                    // Auto-destroy the window when focus is lost (dismissOnOutsideClick via grabFocus)
                    onVisibleChanged: {
                        if (!visible)
                            menuPopupLoader.active = false;
                    }

                    QsMenuOpener {
                        id: menuOpener

                        menu: modelData.hasMenu ? modelData.menu : null
                    }
                    Rectangle {
                        id: bgRect

                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.top: parent.top
                        anchors.topMargin: 16 // Room for the top arrow inside window boundaries
                        border.color: Config.alpha(Config.md3.on_surface, 0.08)
                        border.width: 1
                        color: Config.md3.surface_container
                        layer.enabled: true
                        radius: 12

                        layer.effect: DropShadow {
                            color: "#60000000"
                            horizontalOffset: 0
                            radius: 8
                            samples: 17
                            verticalOffset: 4
                        }

                        ColumnLayout {
                            id: layout

                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4

                            Repeater {
                                model: modelData.hasMenu ? menuOpener.children : null

                                delegate: Rectangle {
                                    id: entryItem

                                    Layout.fillWidth: true
                                    color: modelData.isSeparator ? "transparent" : (entryMouse.containsMouse ? Config.md3.surface_container_high : "transparent")
                                    implicitHeight: modelData.isSeparator ? 8 : 34
                                    radius: 8

                                    // Separator line
                                    Rectangle {
                                        anchors.centerIn: parent
                                        color: Config.alpha(Config.md3.on_surface, 0.08)
                                        height: 1
                                        visible: modelData.isSeparator
                                        width: parent.width
                                    }

                                    // Non-separator content
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 10
                                        visible: !modelData.isSeparator

                                        // Checkbox/Radio indicator
                                        Rectangle {
                                            border.color: Config.alpha(Config.md3.on_surface, 0.3)
                                            border.width: 1
                                            color: "transparent"
                                            height: 14
                                            radius: modelData.buttonType === 2 ? 7 : 3 // 2 is Radio (circle), otherwise checkbox
                                            visible: modelData.buttonType === 1 || modelData.buttonType === 2
                                            width: 14

                                            Rectangle {
                                                anchors.centerIn: parent
                                                color: Config.md3.primary
                                                height: 8
                                                radius: modelData.buttonType === 2 ? 4 : 2
                                                visible: modelData.checkState === 2 // Checked state in Qt
                                                width: 8
                                            }
                                        }

                                        // Icon if exists
                                        IconImage {
                                            height: 16
                                            layer.enabled: true
                                            source: modelData.icon && modelData.icon.toString() !== "" ? modelData.icon : Quickshell.iconPath("application-x-executable")
                                            visible: modelData.icon !== ""
                                            width: 16

                                            layer.effect: ColorOverlay {
                                                color: Config.md3.on_surface
                                            }
                                        }

                                        // Label text
                                        Text {
                                            Layout.fillWidth: true
                                            color: entryMouse.containsMouse ? Config.md3.on_surface : Config.alpha(Config.md3.on_surface, 0.9)
                                            elide: Text.ElideRight
                                            font.family: Config.fontName
                                            font.pixelSize: 14
                                            font.weight: Font.Medium
                                            text: modelData.text || ""
                                        }
                                    }
                                    MouseArea {
                                        id: entryMouse

                                        anchors.fill: parent
                                        cursorShape: modelData.isSeparator ? Qt.ArrowCursor : Qt.PointingHandCursor
                                        hoverEnabled: true

                                        onClicked: {
                                            if (!modelData.isSeparator) {
                                                modelData.triggered();
                                                menuPopupLoader.active = false;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 1. The Arrow Triangle (rotated square) - placed outside bgRect to avoid layer clipping!
                    Rectangle {
                        id: arrowTriangle

                        border.color: Config.alpha(Config.md3.on_surface, 0.08)
                        border.width: 1
                        color: Config.md3.surface_container
                        height: 12
                        rotation: 45
                        width: 12
                        x: bgRect.x + 36 - width / 2
                        y: bgRect.y - height / 2
                    }

                    // 2. The Border Cover (hides the card's top border and the triangle's bottom half)
                    Rectangle {
                        color: Config.md3.surface_container
                        height: 6
                        width: 20
                        x: bgRect.x + 36 - width / 2
                        y: bgRect.y
                    }
                }
            }
            IconImage {
                anchors.fill: parent
                opacity: itemArea.containsMouse ? 1 : 0.75
                source: modelData.icon && modelData.icon.toString() !== "" ? modelData.icon : Quickshell.iconPath("application-x-executable")

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }
        }
    }
}
