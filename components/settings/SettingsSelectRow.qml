import ".."
import "../../"
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    property color accentColor: Config.md3.primary
    property string label: ""
    property string note: ""
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
    activeFocusOnTab: enabled
    border.color: activeFocus ? Config.alpha(accentColor, 0.7) : "transparent"
    border.width: 1
    color: "transparent"
    implicitHeight: note === "" ? 52 : 62
    opacity: enabled ? 1 : 0.45
    radius: 10

    Behavior on border.color {
        ColorAnimation {
            duration: 130
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: 120
        }
    }

    Accessible.onPressAction: activate()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
            activate();
            event.accepted = true;
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 14

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
                renderType: Text.NativeRendering
                text: root.label
            }
            Text {
                Layout.fillWidth: true
                color: Config.alpha(Config.md3.on_surface, 0.46)
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 12
                renderType: Text.NativeRendering
                text: root.note
                visible: text !== ""
            }
        }
        Rectangle {
            id: selectorButton

            Layout.preferredHeight: 42
            Layout.preferredWidth: 148
            border.color: Config.alpha(root.activeFocus ? root.accentColor : Config.md3.on_surface, root.activeFocus ? 0.42 : 0.08)
            border.width: 1
            color: tileMouse.pressed ? Config.alpha(root.accentColor, 0.17) : tileMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.08) : Config.alpha(Config.md3.on_surface, 0.045)
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

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 13
                anchors.rightMargin: 11
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    color: Config.alpha(Config.md3.on_surface, 0.78)
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignLeft
                    renderType: Text.NativeRendering
                    text: root.valueText
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
            root.activate();
        }
    }
}
