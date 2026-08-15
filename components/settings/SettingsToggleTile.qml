import "../../"
import ".."
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property bool checked: false
    property string label: ""
    property string note: ""

    signal toggled(bool checked)

    function requestToggle() {
        if (!enabled)
            return;
        checked = !checked;
        toggled(checked);
    }

    Accessible.checked: checked
    Accessible.name: label
    Accessible.role: Accessible.CheckBox
    Layout.fillWidth: true
    activeFocusOnTab: enabled
    border.color: activeFocus ? Config.alpha(Config.md3.primary, 0.7) : "transparent"
    border.width: 1
    color: tileMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.075) : Config.alpha(Config.md3.on_surface, 0.045)
    implicitHeight: note === "" ? 54 : 64
    opacity: enabled ? 1 : 0.45
    radius: 14

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
    Behavior on opacity {
        NumberAnimation {
            duration: 120
        }
    }

    Accessible.onPressAction: requestToggle()
    Keys.onReturnPressed: event => {
        requestToggle();
        event.accepted = true;
    }
    Keys.onSpacePressed: event => {
        requestToggle();
        event.accepted = true;
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.DemiBold
                text: root.label
            }
            Text {
                Layout.fillWidth: true
                color: Config.alpha(Config.md3.on_surface, 0.46)
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 11
                text: root.note
                visible: text !== ""
            }
        }
        ToggleSwitch {
            Accessible.ignored: true
            checked: root.checked
            interactive: false
        }
    }
    MouseArea {
        id: tileMouse

        anchors.fill: parent
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled
        hoverEnabled: true

        onClicked: {
            root.forceActiveFocus();
            root.requestToggle();
        }
    }
}
