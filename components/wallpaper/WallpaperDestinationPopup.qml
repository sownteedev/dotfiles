pragma ComponentBehavior: Bound
import ".."
import "../.."
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Popup {
    id: root

    property bool greetdAvailable: true

    signal destinationSelected(string destination)

    function openFor(anchorItem) {
        if (!anchorItem || !parent)
            return;
        var point = anchorItem.mapToItem(parent, 0, 0);
        x = Math.max(10, Math.min(point.x + anchorItem.width - width, parent.width - width - 10));
        y = Math.max(10, point.y - height - 8);
        open();
    }

    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    focus: true
    modal: false
    padding: 8
    parent: Overlay.overlay
    width: 220

    background: Item {
        id: popupBackground

        ShellShadow {
            cornerRadius: popupSurface.radius
            target: popupSurface
        }
        Rectangle {
            id: popupSurface

            anchors.fill: parent
            border.color: Config.alpha(Config.md3.outline_variant, Config.lightTheme ? 0.46 : 0.32)
            border.width: 1
            color: Config.alpha(Config.md3.surface_container_high, Config.lightTheme ? 0.98 : 0.96)
            radius: 16
        }
    }
    contentItem: ColumnLayout {
        spacing: 4

        Repeater {
            model: [
                {
                    "destination": "desktop",
                    "icon": "preferences-desktop-wallpaper-symbolic",
                    "label": qsTr("Set wallpaper")
                },
                {
                    "destination": "greetd",
                    "icon": "avatar-default-symbolic",
                    "label": qsTr("Set Greetd")
                },
                {
                    "destination": "both",
                    "icon": "view-dual-symbolic",
                    "label": qsTr("Set both")
                }
            ]

            delegate: Rectangle {
                id: destinationRow

                readonly property bool available: modelData.destination === "desktop" || root.greetdAvailable
                required property var modelData

                Accessible.name: modelData.label
                Accessible.role: Accessible.Button
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                color: available && destinationMouse.pressed ? Config.alpha(Config.md3.primary_container, 0.9) : (available && destinationMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent")
                opacity: available ? 1 : 0.38
                radius: 11

                Behavior on color {
                    ColorAnimation {
                        duration: 110
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 11

                    IconImage {
                        Layout.preferredHeight: 19
                        Layout.preferredWidth: 19
                        layer.enabled: true
                        source: Quickshell.iconPath(destinationRow.modelData.icon)

                        layer.effect: ColorOverlay {
                            color: destinationRow.modelData.destination === "desktop" ? Config.md3.primary : Config.md3.on_surface_variant
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        text: destinationRow.modelData.label
                    }
                    Text {
                        color: Config.md3.on_surface_variant
                        font.family: Config.fontName
                        font.pixelSize: 11
                        text: qsTr("Video only")
                        visible: !destinationRow.available
                    }
                }
                MouseArea {
                    id: destinationMouse

                    anchors.fill: parent
                    cursorShape: destinationRow.available ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: destinationRow.available
                    hoverEnabled: true

                    onClicked: {
                        root.close();
                        root.destinationSelected(destinationRow.modelData.destination);
                    }
                }
            }
        }
    }
}
