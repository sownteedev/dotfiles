pragma ComponentBehavior: Bound
import "../../"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    required property string currentValue
    property int iconSize: 15
    readonly property int selectedIndex: tabs.findIndex(tab => tab.value === currentValue)
    required property var tabs

    signal selected(string value)

    Accessible.role: Accessible.PageTabList
    border.color: Config.alpha(Config.md3.outline, 0.08)
    border.width: 1
    color: Config.alpha(Config.md3.on_surface, 0.03)
    implicitHeight: 40
    implicitWidth: 390
    radius: Md3.shape.full

    Rectangle {
        id: indicator

        color: Config.md3.primary_container
        height: parent.height - 8
        radius: Md3.shape.full
        visible: root.selectedIndex >= 0
        width: (parent.width - 8 - Math.max(0, root.tabs.length - 1) * 6) / Math.max(1, root.tabs.length)
        x: 4 + Math.max(0, root.selectedIndex) * (width + 6)
        y: 4

        Behavior on x {
            NumberAnimation {
                duration: Config.animationDuration(190)
                easing.type: Easing.OutCubic
            }
        }
    }
    RowLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 6

        Repeater {
            model: root.tabs

            delegate: Rectangle {
                id: tabChip

                required property var modelData
                readonly property bool selected: root.currentValue === modelData.value

                Accessible.name: modelData.label
                Accessible.role: Accessible.PageTab
                Accessible.selected: selected
                Layout.fillHeight: true
                Layout.fillWidth: true
                activeFocusOnTab: true
                color: !selected && tabMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.07) : "transparent"
                radius: Md3.shape.full

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animationDuration(120)
                    }
                }

                Accessible.onPressAction: root.selected(modelData.value)
                Keys.onReturnPressed: root.selected(modelData.value)
                Keys.onSpacePressed: root.selected(modelData.value)

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        height: root.iconSize
                        layer.enabled: true
                        source: Quickshell.iconPath(tabChip.modelData.icon)
                        width: root.iconSize

                        layer.effect: ColorOverlay {
                            color: tabChip.selected ? Config.md3.on_primary_container : Config.md3.on_surface_variant
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        color: tabChip.selected ? Config.md3.on_primary_container : Config.md3.on_surface_variant
                        font.family: Config.fontName
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        text: tabChip.modelData.label
                    }
                }
                MouseArea {
                    id: tabMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: root.selected(tabChip.modelData.value)
                }
            }
        }
    }
}
