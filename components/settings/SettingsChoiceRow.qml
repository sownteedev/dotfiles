import "../../"
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property string label: ""
    property string note: ""
    property var options: []
    property string value: ""

    signal selected(string value)

    function moveSelection(offset) {
        if (!enabled || options.length === 0)
            return;
        var current = 0;
        for (var i = 0; i < options.length; ++i) {
            if (String(options[i].value) === value) {
                current = i;
                break;
            }
        }
        var next = (current + offset + options.length) % options.length;
        value = String(options[next].value);
        selected(value);
    }

    Accessible.name: label
    Accessible.role: Accessible.Grouping
    activeFocusOnTab: enabled
    spacing: 8

    Keys.onLeftPressed: event => {
        moveSelection(-1);
        event.accepted = true;
    }
    Keys.onRightPressed: event => {
        moveSelection(1);
        event.accepted = true;
    }

    Text {
        Layout.fillWidth: true
        color: Config.md3.on_surface
        font.family: Config.fontName
        font.pixelSize: 15
        font.weight: Font.DemiBold
        text: root.label
    }
    Text {
        Layout.fillWidth: true
        color: Config.alpha(Config.md3.on_surface, 0.44)
        font.family: Config.fontName
        font.pixelSize: 12
        text: root.note
        visible: text !== ""
        wrapMode: Text.Wrap
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: root.options

            delegate: Rectangle {
                id: optionButton

                readonly property bool active: root.value === String(modelData.value)
                required property var modelData

                Accessible.checked: active
                Accessible.name: String(optionButton.modelData.label)
                Accessible.role: Accessible.RadioButton
                Layout.fillWidth: true
                border.color: Config.alpha(optionButton.active ? Config.md3.primary : Config.md3.on_surface, optionButton.active ? 0.36 : 0.07)
                border.width: 1
                color: optionButton.active ? Config.alpha(Config.md3.primary, 0.17) : (optionMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.07) : Config.alpha(Config.md3.on_surface, 0.035))
                implicitHeight: 42
                radius: 11

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

                Accessible.onPressAction: {
                    root.value = String(optionButton.modelData.value);
                    root.selected(root.value);
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    color: optionButton.active ? Config.md3.primary : Config.alpha(Config.md3.on_surface, 0.72)
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: optionButton.active ? Font.DemiBold : Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    text: optionButton.modelData.label
                    verticalAlignment: Text.AlignVCenter
                }
                MouseArea {
                    id: optionMouse

                    anchors.fill: parent
                    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: root.enabled
                    hoverEnabled: true

                    onClicked: {
                        root.value = String(optionButton.modelData.value);
                        root.selected(root.value);
                    }
                }
            }
        }
    }
}
