import QtQuick
import "../../"

Rectangle {
    id: root

    property string accessibleName: ""
    property bool animationsReady: false
    property bool checked: false
    property color checkedColor: Config.md3.primary
    property bool hovered: false
    property bool interactive: true
    property bool pressed: false
    property color thumbCheckedColor: Config.md3.on_primary
    property real thumbMargin: Math.max(2, Math.round(root.height / 8))
    property real thumbSize: Math.max(8, Math.min(root.height - root.thumbMargin * 2, root.width / 2))
    readonly property real thumbTravel: Math.max(0, root.width - root.thumbSize - root.thumbMargin * 2)
    property color thumbUncheckedColor: Config.md3.outline
    property real thumbUncheckedScale: 2 / 3
    property real trackHeight: 32
    property real trackWidth: 52
    property color uncheckedColor: Config.md3.surface_container_highest

    signal toggled(bool checked)

    function requestToggle() {
        if (enabled && interactive)
            toggled(!checked);
    }

    Accessible.checked: checked
    Accessible.name: accessibleName
    Accessible.role: Accessible.CheckBox
    activeFocusOnTab: false
    border.color: checked ? "transparent" : hovered || switchMouse.containsMouse ? Config.md3.on_surface_variant : Config.md3.outline
    border.width: 2
    color: checked ? checkedColor : uncheckedColor
    implicitHeight: trackHeight
    implicitWidth: trackWidth
    opacity: enabled ? 1 : Md3.state.disabledContent
    radius: Md3.shape.full

    Behavior on border.color {
        enabled: root.animationsReady

        Md3ColorAnimation {
            role: "state"
        }
    }
    Behavior on color {
        enabled: root.animationsReady

        Md3ColorAnimation {
            role: "state"
        }
    }
    Behavior on opacity {
        enabled: root.animationsReady

        Md3NumberAnimation {
            role: "state"
        }
    }

    Accessible.onPressAction: requestToggle()
    Component.onCompleted: Qt.callLater(function () {
        root.animationsReady = true;
    })
    Keys.onReturnPressed: event => {
        requestToggle();
        event.accepted = true;
    }
    Keys.onSpacePressed: event => {
        requestToggle();
        event.accepted = true;
    }

    Rectangle {
        anchors.fill: parent
        color: root.checked ? Config.md3.on_primary : Config.md3.on_surface
        opacity: root.pressed || switchMouse.pressed ? Md3.state.pressed : root.hovered || switchMouse.containsMouse ? Md3.state.hover : 0
        radius: root.radius

        Behavior on color {
            enabled: root.animationsReady

            Md3ColorAnimation {
                role: "state"
            }
        }
        Behavior on opacity {
            enabled: root.animationsReady

            Md3NumberAnimation {
                role: "state"
            }
        }
    }
    Item {
        id: thumbSlot

        anchors.verticalCenter: parent.verticalCenter
        height: root.thumbSize
        width: root.thumbSize
        x: root.thumbMargin + (root.checked ? root.thumbTravel : 0)

        Behavior on x {
            enabled: root.animationsReady

            Md3NumberAnimation {
                role: "transform"
            }
        }

        Rectangle {
            anchors.fill: parent
            color: root.checked ? root.thumbCheckedColor : root.thumbUncheckedColor
            radius: Md3.shape.full
            scale: root.checked ? 1 : root.thumbUncheckedScale

            Behavior on color {
                enabled: root.animationsReady

                Md3ColorAnimation {
                    role: "state"
                }
            }
            Behavior on scale {
                enabled: root.animationsReady

                Md3NumberAnimation {
                    role: "microSpatial"
                }
            }
        }
    }
    MouseArea {
        id: switchMouse

        anchors.fill: parent
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled && root.interactive
        hoverEnabled: true

        onClicked: root.requestToggle()
    }
}
