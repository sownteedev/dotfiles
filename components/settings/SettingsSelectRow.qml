import ".."
import "../../"
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property color accentColor: Config.md3.primary
    property real controlWidth: 156
    property string label: ""
    property string note: ""
    property bool showDivider: false
    readonly property bool stacked: width < 480
    property color valueBadgeColor: "transparent"
    property string valueText: ""

    signal clicked(var sourceItem)

    function activate() {
        if (!enabled)
            return;

        clicked(selectorButton);
    }

    Accessible.description: note
    Accessible.name: qsTr("%1: %2").arg(label).arg(valueText)
    Accessible.role: Accessible.ComboBox
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    activeFocusOnTab: false
    border.width: 0
    color: "transparent"
    implicitHeight: Math.max(56, row.implicitHeight + 24)
    implicitWidth: 0
    opacity: enabled ? 1 : Md3.state.disabledContent
    radius: Md3.shape.medium

    Behavior on opacity {
        NumberAnimation {
            duration: Config.animationDuration(Md3.motion.short2)
        }
    }

    Accessible.onPressAction: activate()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
            activate();
            event.accepted = true;
        }
    }

    GridLayout {
        id: row

        anchors.left: parent.left
        anchors.leftMargin: Md3.spacing.xxs
        anchors.right: parent.right
        anchors.rightMargin: Md3.spacing.xxs
        anchors.top: parent.top
        anchors.topMargin: 12
        columnSpacing: Md3.spacing.md
        columns: root.stacked ? 1 : 2
        rowSpacing: Md3.spacing.sm

        SettingsLabelBlock {
            id: labelBlock

            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 0
            headline: root.label
            supportingText: root.note
        }
        Rectangle {
            id: selectorButton

            readonly property bool pointerHovered: tileMouse.containsMouse && pointerPosition.x >= 0 && pointerPosition.x < width && pointerPosition.y >= 0 && pointerPosition.y < height
            readonly property point pointerPosition: selectorButton.mapFromItem(tileMouse, tileMouse.mouseX, tileMouse.mouseY)

            Layout.fillWidth: root.stacked
            Layout.maximumWidth: root.stacked ? Infinity : root.controlWidth
            Layout.minimumWidth: 0
            Layout.preferredHeight: 44
            Layout.preferredWidth: root.stacked ? 0 : root.controlWidth
            border.color: pointerHovered ? Config.alpha(Config.md3.on_surface, 0.56) : Config.alpha(Config.md3.outline, 0.22)
            border.width: 1
            color: Config.md3.surface_container_low
            radius: Md3.shape.medium

            Behavior on border.color {
                ColorAnimation {
                    duration: Config.animationDuration(Md3.motion.short3)
                }
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                color: Config.md3.on_surface
                opacity: tileMouse.pressed && selectorButton.pointerHovered ? Md3.state.pressed : selectorButton.pointerHovered ? Md3.state.hover : 0
                radius: Math.max(0, selectorButton.radius - 1)

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animationDuration(Md3.motion.short2)
                        easing.type: Md3.motion.standard
                    }
                }
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 13
                anchors.rightMargin: 11
                spacing: 8

                Rectangle {
                    Layout.preferredHeight: 8
                    Layout.preferredWidth: 8
                    color: root.valueBadgeColor
                    radius: 4
                    visible: root.valueBadgeColor.a > 0
                }
                Text {
                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.on_surface, 0.78)
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
                    font.pixelSize: Md3.typeScale.labelLarge.size
                    font.weight: Md3.typeScale.labelLarge.weight
                    horizontalAlignment: Text.AlignLeft
                    renderType: Text.NativeRendering
                    text: root.valueText
                }
                Md3Icon {
                    Layout.preferredHeight: 16
                    Layout.preferredWidth: 16
                    color: Config.md3.on_surface_variant
                    name: "expand_more"
                    size: 18
                }
            }
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        color: Config.alpha(Config.md3.outline_variant, 0.45)
        height: 1
        visible: root.showDivider
        width: parent.width
    }
    MouseArea {
        id: tileMouse

        anchors.fill: parent
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabled
        hoverEnabled: true

        onClicked: root.activate()
    }
}
