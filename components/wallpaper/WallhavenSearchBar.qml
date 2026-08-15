import "../../"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    property alias text: searchInput.text

    signal accepted

    function focusInput() {
        searchInput.forceActiveFocus();
    }

    implicitHeight: 42

    RowLayout {
        anchors.fill: parent
        spacing: 8

        TextField {
            id: searchInput

            Layout.fillHeight: true
            Layout.fillWidth: true
            color: Config.md3.on_surface
            font.family: Config.fontName
            font.pixelSize: 15
            leftPadding: 15
            placeholderText: qsTr("Search tags or wallpaper ID…")
            placeholderTextColor: Config.md3.on_surface_variant
            rightPadding: 15
            selectByMouse: true

            background: Rectangle {
                border.color: searchInput.activeFocus ? Config.alpha(Config.md3.primary, 0.62) : "transparent"
                border.width: 1
                color: searchInput.activeFocus ? Config.alpha(Config.md3.primary_container, 0.28) : Config.alpha(Config.md3.on_surface, 0.045)
                radius: 13

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
            }

            onAccepted: root.accepted()
        }
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 42
            color: searchMouse.pressed ? Config.md3.primary : (searchMouse.containsMouse ? Config.alpha(Config.md3.primary, 0.88) : Config.md3.primary_container)
            radius: 13

            IconImage {
                anchors.centerIn: parent
                height: 17
                layer.enabled: true
                source: Quickshell.iconPath("system-search-symbolic")
                width: 17

                layer.effect: ColorOverlay {
                    color: searchMouse.containsMouse || searchMouse.pressed ? Config.md3.on_primary : Config.md3.on_primary_container
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
}
