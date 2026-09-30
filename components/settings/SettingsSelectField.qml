import ".."
import "../../"
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    property color accentColor: Config.md3.primary
    property int fieldHeight: 56
    property string label: ""
    property color labelColor: Config.md3.on_surface
    property int labelFontPixelSize: 14
    property int labelFontWeight: Font.DemiBold
    property string placeholder: ""
    property color valueBadgeColor: "transparent"
    property int valueFontPixelSize: 15
    property string valueText: ""

    signal clicked(var sourceItem)

    function activate() {
        if (!enabled)
            return;

        clicked(fieldFrame);
    }

    spacing: Md3.spacing.xs

    Text {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        color: root.labelColor
        elide: Text.ElideRight
        font.family: Config.fontName
        font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
        font.pixelSize: root.labelFontPixelSize
        font.weight: root.labelFontWeight
        lineHeight: Md3.typeScale.labelLarge.lineHeight
        lineHeightMode: Text.FixedHeight
        renderType: Text.NativeRendering
        text: root.label
        visible: text !== ""
    }
    Rectangle {
        id: fieldFrame

        Accessible.description: root.label
        Accessible.name: qsTr("%1: %2").arg(root.label).arg(root.valueText)
        Accessible.role: Accessible.ComboBox
        Layout.fillWidth: true
        Layout.preferredHeight: root.fieldHeight
        activeFocusOnTab: false
        border.color: fieldMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.56) : Config.alpha(Config.md3.outline, 0.22)
        border.width: 1
        color: Config.md3.surface_container_low
        opacity: root.enabled ? 1 : Md3.state.disabledContent
        radius: Md3.shape.medium

        Behavior on border.color {
            ColorAnimation {
                duration: Config.animationDuration(Md3.motion.short3)
            }
        }

        Accessible.onPressAction: root.activate()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
                root.activate();
                event.accepted = true;
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: Config.md3.on_surface
            opacity: fieldMouse.pressed ? Md3.state.pressed : fieldMouse.containsMouse ? Md3.state.hover : 0
            radius: Math.max(0, fieldFrame.radius - 1)

            Behavior on opacity {
                NumberAnimation {
                    duration: Config.animationDuration(Md3.motion.short2)
                    easing.type: Md3.motion.standard
                }
            }
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 15
            spacing: 10

            Rectangle {
                Layout.preferredHeight: 10
                Layout.preferredWidth: 10
                color: root.valueBadgeColor
                radius: 5
                visible: root.valueBadgeColor.a > 0
            }
            Text {
                Layout.fillWidth: true
                color: root.valueText === "" ? Config.alpha(Config.md3.on_surface, 0.38) : Config.md3.on_surface
                elide: Text.ElideRight
                font.family: Config.fontName
                font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
                font.pixelSize: root.valueFontPixelSize
                font.weight: Font.Medium
                renderType: Text.NativeRendering
                text: root.valueText === "" ? root.placeholder : root.valueText
            }
            Md3Icon {
                Layout.preferredHeight: 20
                Layout.preferredWidth: 20
                color: Config.md3.on_surface_variant
                name: "expand_more"
                size: 20
            }
        }
        MouseArea {
            id: fieldMouse

            anchors.fill: parent
            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: root.enabled
            hoverEnabled: true

            onClicked: root.activate()
        }
    }
}
