import "../../"
import ".."
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    property color accentColor: Config.md3.primary
    property string iconName: "video-display-symbolic"
    property string label: ""
    property bool showChevron: true
    property string value: ""

    signal activated(var sourceItem)

    function activate() {
        if (!enabled)
            return;

        forceActiveFocus();
        activated(root);
    }

    Accessible.name: qsTr("%1: %2").arg(label).arg(value)
    Accessible.role: Accessible.ComboBox
    Layout.fillWidth: true
    activeFocusOnTab: enabled
    border.color: activeFocus ? Config.alpha(accentColor, 0.56) : Config.alpha(Config.md3.on_surface, tileMouse.containsMouse ? 0.12 : 0.07)
    border.width: 1
    color: tileMouse.pressed ? Config.alpha(accentColor, 0.17) : tileMouse.containsMouse ? Config.alpha(accentColor, 0.10) : Config.alpha(Config.md3.on_surface, 0.035)
    implicitHeight: 78
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

    Accessible.onPressAction: activate()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
            activate();
            event.accepted = true;
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 11

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: 38
            Layout.preferredWidth: 38
            color: Config.alpha(root.accentColor, 0.14)
            radius: 12

            IconImage {
                anchors.centerIn: parent
                height: 20
                layer.enabled: true
                source: Quickshell.iconPath(root.iconName)
                width: 20

                layer.effect: ColorOverlay {
                    color: root.accentColor
                }
            }
        }
        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            spacing: 3

            Text {
                Layout.fillWidth: true
                color: Config.alpha(Config.md3.on_surface, 0.58)
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 12
                font.weight: Font.Medium
                renderType: Text.NativeRendering
                text: root.label
            }
            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 15
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
                text: root.value
            }
        }
        IconImage {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: 16
            Layout.preferredWidth: 16
            layer.enabled: true
            source: Quickshell.iconPath("pan-down-symbolic")
            visible: root.showChevron

            layer.effect: ColorOverlay {
                color: Config.alpha(Config.md3.on_surface, 0.52)
            }
        }
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
