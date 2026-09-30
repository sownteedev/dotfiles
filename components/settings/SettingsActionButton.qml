import "../../"
import ".."
import QtQuick

Rectangle {
    id: root

    property string iconName: ""
    property bool iconOnly: false
    property int iconSize: 20
    property bool primary: false
    property bool spinning: false
    property string text: ""
    property int textPixelSize: Md3.typeScale.labelLarge.size
    property int textWeight: Md3.typeScale.labelLarge.weight
    property string tooltipText: ""

    signal clicked

    Accessible.name: tooltipText !== "" ? tooltipText : text
    Accessible.role: Accessible.Button
    activeFocusOnTab: false
    border.color: "transparent"
    border.width: 1
    color: primary ? Config.md3.primary : Config.md3.surface_container_high
    implicitHeight: 48
    implicitWidth: iconOnly ? implicitHeight : content.implicitWidth + 34
    opacity: enabled ? 1 : Md3.state.disabledContent
    radius: iconOnly ? Md3.shape.full : Md3.shape.large
    z: mouse.containsMouse ? 1 : 0

    Behavior on color {
        Md3ColorAnimation {
            role: "state"
        }
    }
    Behavior on opacity {
        Md3NumberAnimation {
            role: "state"
        }
    }

    Accessible.onPressAction: {
        if (root.enabled)
            root.clicked();
    }
    Keys.onReturnPressed: event => {
        root.clicked();
        event.accepted = true;
    }
    Keys.onSpacePressed: event => {
        root.clicked();
        event.accepted = true;
    }

    Rectangle {
        anchors.fill: parent
        color: Config.alpha(root.primary ? Config.md3.on_primary : Config.md3.on_surface, mouse.pressed ? Md3.state.pressed : mouse.containsMouse ? Md3.state.hover : 0)
        radius: root.radius

        Behavior on color {
            Md3ColorAnimation {
                role: "state"
            }
        }
    }
    Row {
        id: content

        anchors.centerIn: parent
        spacing: Math.max(10, Math.round(root.iconSize * 0.5))

        Item {
            id: iconSlot

            anchors.verticalCenter: parent.verticalCenter
            height: root.iconSize
            visible: root.spinning || (root.iconName !== "")
            width: root.iconSize

            Md3Icon {
                anchors.centerIn: parent
                color: root.primary ? Config.md3.on_primary : Config.md3.on_surface_variant
                name: root.iconName
                size: root.iconSize
                visible: !root.spinning && root.iconName !== ""
            }
            AnimatedSpinner {
                id: actionSpinner

                anchors.centerIn: parent
                color: root.primary ? Config.md3.on_primary : Config.md3.primary
                height: Math.max(18, root.iconSize - 2)
                lineWidth: 2.2
                running: root.spinning && root.visible
                visible: root.spinning
                width: Math.max(18, root.iconSize - 2)
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: root.primary ? Config.md3.on_primary : Config.md3.on_surface_variant
            font.family: Config.fontName
            font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
            font.pixelSize: root.textPixelSize
            font.weight: root.textWeight
            text: root.text
            visible: !root.iconOnly && text !== ""
        }
    }
    MouseArea {
        id: mouse

        anchors.fill: parent
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled
        hoverEnabled: true

        onClicked: root.clicked()
    }
    Md3ToolTip {
        id: actionToolTip

        text: root.tooltipText !== "" ? root.tooltipText : root.text
        visible: (root.iconOnly || root.tooltipText !== "") && mouse.containsMouse && actionToolTip.text !== ""
        x: Math.round((root.width - width) / 2)
        y: root.height + Md3.spacing.xs
    }
}
