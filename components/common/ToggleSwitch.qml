import QtQuick
import "../../"

Rectangle {
    id: root

    property string accessibleName: ""
    property bool checked: false
    property color checkedColor: Config.md3.primary
    property bool interactive: true
    property color thumbCheckedColor: Config.md3.on_primary
    property real thumbMargin: 2
    property color thumbUncheckedColor: Config.md3.outline
    property color uncheckedColor: Config.md3.surface_container_high

    signal toggled(bool checked)

    function requestToggle() {
        if (enabled && interactive)
            toggled(!checked);
    }

    Accessible.checked: checked
    Accessible.name: accessibleName
    Accessible.role: Accessible.CheckBox
    activeFocusOnTab: enabled && interactive
    border.color: activeFocus ? Config.alpha(Config.md3.primary, 0.75) : Config.alpha(Config.md3.on_surface, 0.1)
    border.width: 1
    color: checked ? checkedColor : uncheckedColor
    implicitHeight: 20
    implicitWidth: 40
    opacity: enabled ? 1 : 0.42
    radius: height / 2

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

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        color: root.checked ? root.thumbCheckedColor : root.thumbUncheckedColor
        height: width
        radius: width / 2
        width: parent.height - root.thumbMargin * 2
        x: root.checked ? root.width - width - root.thumbMargin : root.thumbMargin

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
        Behavior on x {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled && root.interactive

        onClicked: {
            root.forceActiveFocus();
            root.requestToggle();
        }
    }
}
