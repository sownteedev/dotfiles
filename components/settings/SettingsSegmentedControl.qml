import QtQuick
import QtQuick.Layouts
import "../../"

Rectangle {
    id: root

    property var options: []
    property string selectedValue: ""

    signal selected(string value)

    border.color: Config.alpha(Config.md3.outline, 0.24)
    border.width: 1
    color: Config.md3.surface_container_high
    implicitHeight: 44
    radius: 14

    RowLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 4

        Repeater {
            model: root.options

            delegate: Rectangle {
                id: segment

                readonly property bool active: root.selectedValue === modelData.value
                required property var modelData

                Layout.fillHeight: true
                Layout.fillWidth: true
                border.color: active ? Config.alpha(Config.md3.primary, 0.5) : "transparent"
                border.width: 1
                color: active ? Config.alpha(Config.md3.primary, 0.16) : (segmentArea.containsMouse ? Config.alpha(Config.md3.on_surface, 0.07) : "transparent")
                radius: 10

                Behavior on border.color {
                    ColorAnimation {
                        duration: 150
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }

                Text {
                    anchors.centerIn: parent
                    color: segment.active ? Config.md3.primary : Config.md3.on_surface_variant
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: segment.active ? Font.DemiBold : Font.Medium
                    text: segment.modelData.label

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }
                MouseArea {
                    id: segmentArea

                    anchors.fill: parent
                    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: root.enabled
                    hoverEnabled: true

                    onClicked: root.selected(segment.modelData.value)
                }
            }
        }
    }
}
