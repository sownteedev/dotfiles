import "../../"
import ".."
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

ColumnLayout {
    id: root

    property string actionText: ""
    property bool actionVisible: false
    property bool busy: false
    property string description: ""
    property string iconName: ""
    readonly property bool showAction: actionVisible && actionText !== "" && !busy
    property string title: ""

    signal actionTriggered

    spacing: 0

    Item {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredHeight: 68
        Layout.preferredWidth: 68

        BusyIndicator {
            anchors.centerIn: parent
            height: 48
            running: root.busy
            visible: running
            width: 48
        }
        Rectangle {
            anchors.fill: parent
            border.color: Config.alpha(Config.md3.primary, 0.18)
            border.width: 1
            color: Config.alpha(Config.md3.primary, 0.1)
            radius: 22
            visible: !root.busy

            IconImage {
                anchors.centerIn: parent
                height: 30
                layer.enabled: true
                source: root.iconName === "" ? "" : Quickshell.iconPath(root.iconName)
                width: 30

                layer.effect: ColorOverlay {
                    color: Config.md3.primary
                }
            }
        }
    }
    Item {
        Layout.preferredHeight: 14
    }
    Text {
        Layout.fillWidth: true
        color: Config.md3.on_surface
        font.family: Config.fontName
        font.pixelSize: 18
        font.weight: Font.Bold
        horizontalAlignment: Text.AlignHCenter
        lineHeight: 1.15
        text: root.title
        wrapMode: Text.Wrap
    }
    Item {
        Layout.preferredHeight: 6
    }
    Text {
        Layout.fillWidth: true
        color: Config.alpha(Config.md3.on_surface, 0.56)
        font.family: Config.fontName
        font.pixelSize: 14
        horizontalAlignment: Text.AlignHCenter
        lineHeight: 1.25
        text: root.description
        wrapMode: Text.Wrap
    }
    Item {
        Layout.preferredHeight: 16
        visible: root.showAction
    }
    SettingsActionButton {
        Layout.alignment: Qt.AlignHCenter
        iconName: "list-add-symbolic"
        primary: true
        text: root.actionText
        visible: root.showAction

        onClicked: root.actionTriggered()
    }
}
