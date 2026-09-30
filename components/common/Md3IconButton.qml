import QtQuick
import "../../"
import ".."

Item {
    id: root

    property bool checkable: false
    property bool checked: false
    property real containerSize: 40
    property string containerStyle: "standard"
    readonly property color contentColor: {
        if (!enabled)
            return Config.alpha(Config.md3.on_surface, Md3.state.disabledContent);
        if (containerStyle === "filled")
            return Config.md3.on_primary;
        if (containerStyle === "tonal" || checked)
            return Config.md3.on_secondary_container;
        return Config.md3.on_surface_variant;
    }
    property bool filledWhenChecked: true
    property string iconName: ""
    property real iconSize: 24
    readonly property color restingContainerColor: {
        if (!enabled)
            return Config.alpha(Config.md3.on_surface, Md3.state.disabledContainer);
        if (containerStyle === "filled")
            return Config.md3.primary;
        if (containerStyle === "tonal" || checked)
            return Config.md3.secondary_container;
        return "transparent";
    }
    property string tooltipText: ""

    signal clicked

    Accessible.checkable: checkable
    Accessible.checked: checked
    Accessible.name: tooltipText
    Accessible.role: Accessible.Button
    activeFocusOnTab: false
    implicitHeight: 48
    implicitWidth: 48

    Accessible.onPressAction: {
        if (root.enabled)
            root.clicked();
    }
    Keys.onReturnPressed: event => {
        if (root.enabled)
            root.clicked();
        event.accepted = true;
    }
    Keys.onSpacePressed: event => {
        if (root.enabled)
            root.clicked();
        event.accepted = true;
    }

    Rectangle {
        anchors.centerIn: parent
        border.color: root.containerStyle === "outlined" ? (pointer.containsMouse ? Config.md3.on_surface_variant : Config.md3.outline) : "transparent"
        border.width: root.containerStyle === "outlined" ? 1 : 0
        color: root.restingContainerColor
        height: Math.max(0, Math.min(root.containerSize, root.width, root.height))
        radius: Md3.shape.full
        scale: pointer.pressed ? 0.92 : 1
        width: height

        Behavior on color {
            Md3ColorAnimation {
                role: "state"
            }
        }
        Behavior on scale {
            Md3NumberAnimation {
                role: "microSpatial"
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Config.alpha(root.contentColor, pointer.pressed ? Md3.state.pressed : pointer.containsMouse ? Md3.state.hover : 0)
            radius: parent.radius

            Behavior on color {
                Md3ColorAnimation {
                    role: "state"
                }
            }
        }
        Md3Icon {
            anchors.centerIn: parent
            color: root.contentColor
            filled: root.filledWhenChecked && root.checked
            name: root.iconName
            size: root.iconSize

            Behavior on color {
                Md3ColorAnimation {
                    role: "state"
                }
            }
        }
    }
    MouseArea {
        id: pointer

        anchors.fill: parent
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled
        hoverEnabled: true

        onClicked: root.clicked()
    }
    Md3ToolTip {
        text: root.tooltipText
        visible: root.visible && root.enabled && root.tooltipText !== "" && pointer.containsMouse
    }
}
