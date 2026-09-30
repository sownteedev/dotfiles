import "../../"
import ".."
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property bool checked: false
    property string label: ""
    property string note: ""
    property bool updateCheckedInternally: true

    signal toggled(bool checked)

    function requestToggle() {
        if (!enabled)
            return;
        var nextChecked = !checked;
        if (updateCheckedInternally)
            checked = nextChecked;
        toggled(nextChecked);
    }

    Accessible.checked: checked
    Accessible.description: note
    Accessible.name: label
    Accessible.role: Accessible.CheckBox
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    activeFocusOnTab: false
    border.color: "transparent"
    border.width: 0
    color: "transparent"
    implicitHeight: Math.max(56, labelBlock.implicitHeight + 24)
    implicitWidth: 0
    opacity: enabled ? 1 : Md3.state.disabledContent
    radius: Md3.shape.medium

    Behavior on border.color {
        ColorAnimation {
            duration: Config.animationDuration(Md3.motion.short3)
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Config.animationDuration(Md3.motion.short2)
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
        Layout.minimumWidth: 0
        anchors.fill: parent
        anchors.leftMargin: Md3.spacing.xxs
        anchors.rightMargin: Md3.spacing.xxs
        spacing: Md3.spacing.md

        SettingsLabelBlock {
            id: labelBlock

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            headline: root.label
            supportingText: root.note
        }
        ToggleSwitch {
            id: toggleControl

            Accessible.ignored: true
            checked: root.checked
            hovered: {
                var pointer = toggleControl.mapFromItem(tileMouse, tileMouse.mouseX, tileMouse.mouseY);
                return tileMouse.containsMouse && pointer.x >= 0 && pointer.x < toggleControl.width && pointer.y >= 0 && pointer.y < toggleControl.height;
            }
            interactive: false
            pressed: tileMouse.pressed && hovered
        }
    }
    MouseArea {
        id: tileMouse

        anchors.fill: parent
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled
        hoverEnabled: true

        onClicked: {
            root.focus = false;
            root.requestToggle();
        }
    }
}
