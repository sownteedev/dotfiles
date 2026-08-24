import "../../"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    property alias text: searchInput.text

    signal accepted

    function focusInput() {
        searchInput.forceActiveFocus();
    }

    implicitHeight: 40

    TextField {
        id: searchInput

        anchors.fill: parent
        color: Config.md3.on_surface
        font.family: Config.fontName
        font.pixelSize: 13
        leftPadding: 40
        placeholderText: qsTr("Search Wallhaven…")
        placeholderTextColor: Config.alpha(Config.md3.on_surface_variant, 0.72)
        rightPadding: 42
        selectByMouse: true

        background: Rectangle {
            border.color: searchInput.activeFocus ? Config.alpha(Config.md3.primary, 0.54) : Config.alpha(Config.md3.outline, 0.1)
            border.width: 1
            color: searchInput.activeFocus ? Config.alpha(Config.md3.primary_container, 0.18) : Config.alpha(Config.md3.on_surface, 0.025)
            radius: 13

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }
        }

        onAccepted: root.accepted()
    }
    IconImage {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        height: 15
        layer.enabled: true
        source: Quickshell.iconPath("system-search-symbolic")
        width: 15

        layer.effect: ColorOverlay {
            color: searchInput.activeFocus ? Config.md3.primary : Config.md3.on_surface_variant
        }
    }
    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        color: searchMouse.pressed ? Config.md3.primary_container : (searchMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent")
        height: 30
        radius: 10
        width: 30

        IconImage {
            anchors.centerIn: parent
            height: 14
            layer.enabled: true
            source: Quickshell.iconPath("arrow-right-symbolic", "system-search-symbolic")
            width: 14

            layer.effect: ColorOverlay {
                color: searchMouse.containsMouse || searchMouse.pressed ? Config.md3.primary : Config.md3.on_surface_variant
            }
        }
        MouseArea {
            id: searchMouse

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: root.accepted()
        }
    }
}
