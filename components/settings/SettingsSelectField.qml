import ".."
import "../../"
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets

ColumnLayout {
    id: root

    property color accentColor: Config.md3.primary
    property string label: ""
    property string placeholder: ""
    property color valueBadgeColor: "transparent"
    property string valueText: ""

    signal clicked(var sourceItem)

    function activate() {
        if (!enabled)
            return;

        clicked(fieldFrame);
    }

    spacing: 8

    Text {
        color: Config.alpha(Config.md3.on_surface, 0.85)
        font.family: Config.fontName
        font.pixelSize: 14
        font.weight: Font.DemiBold
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
        Layout.preferredHeight: 44
        activeFocusOnTab: root.enabled
        border.color: activeFocus ? Config.alpha(root.accentColor, 0.7) : "transparent"
        border.width: 1
        color: fieldMouse.pressed ? Config.alpha(root.accentColor, 0.17) : fieldMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.075) : Config.alpha(Config.md3.on_surface, 0.05)
        opacity: root.enabled ? 1 : 0.45
        radius: 12

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

        Accessible.onPressAction: root.activate()
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
                root.activate();
                event.accepted = true;
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 15
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
                color: root.valueText === "" ? Config.alpha(Config.md3.on_surface, 0.38) : Config.md3.on_surface
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.Medium
                renderType: Text.NativeRendering
                text: root.valueText === "" ? root.placeholder : root.valueText
            }
            IconImage {
                Layout.preferredHeight: 16
                Layout.preferredWidth: 16
                layer.enabled: true
                source: Quickshell.iconPath("pan-down-symbolic")

                layer.effect: ColorOverlay {
                    color: Config.alpha(Config.md3.on_surface, 0.58)
                }
            }
        }
        MouseArea {
            id: fieldMouse

            anchors.fill: parent
            cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: root.enabled
            hoverEnabled: true

            onClicked: {
                fieldFrame.forceActiveFocus();
                root.activate();
            }
        }
    }
}
