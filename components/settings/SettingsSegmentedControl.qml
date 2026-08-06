import QtQuick
import QtQuick.Layouts
import "../../"

Rectangle {
    id: root

    property var options: []
    property string selectedValue: ""
    property string accessibleName: ""

    signal selected(string value)

    border.color: Config.alpha(Config.md3.outline, 0.24)
    border.width: 1
    color: Config.md3.surface_container_high
    implicitHeight: 44
    radius: 14

    function moveSelection(offset) {
        if (!enabled || options.length === 0)
            return;
        var current = 0;
        for (var i = 0; i < options.length; ++i) {
            if (String(options[i].value) === selectedValue) {
                current = i;
                break;
            }
        }
        var next = (current + offset + options.length) % options.length;
        selected(String(options[next].value));
    }

    Accessible.name: accessibleName
    Accessible.role: Accessible.Grouping
    activeFocusOnTab: enabled
    Keys.onLeftPressed: event => {
        moveSelection(-1);
        event.accepted = true;
    }
    Keys.onRightPressed: event => {
        moveSelection(1);
        event.accepted = true;
    }

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

                Accessible.checked: active
                Accessible.name: String(segment.modelData.label)
                Accessible.role: Accessible.RadioButton

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
                Accessible.onPressAction: root.selected(segment.modelData.value)
            }
        }
    }
}
