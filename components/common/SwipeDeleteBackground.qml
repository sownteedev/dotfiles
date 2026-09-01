import "../.."
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    property real actionExtent: 112
    property string actionText: qsTr("Delete")
    readonly property bool armed: Math.abs(swipeOffset) >= revealDistance
    property real cornerRadius: 17
    property bool interactive: true
    property bool leading: false
    property real revealDistance: 80
    readonly property real revealProgress: Math.max(0, Math.min(1, Math.abs(swipeOffset) / Math.max(1, revealDistance)))
    required property real swipeOffset

    signal triggered

    Accessible.name: actionText
    Accessible.role: Accessible.Button
    clip: true
    visible: revealProgress > 0.005

    Rectangle {
        id: actionBackground

        anchors.fill: parent
        color: Config.md3.error
        radius: root.cornerRadius
    }
    Item {
        id: actionSlot

        anchors.bottom: parent.bottom
        anchors.left: root.leading ? parent.left : undefined
        anchors.right: root.leading ? undefined : parent.right
        anchors.top: parent.top
        clip: true
        width: Math.min(root.actionExtent, Math.abs(root.swipeOffset), parent.width)

        Row {
            anchors.centerIn: parent
            opacity: Math.min(1, 0.22 + root.revealProgress * 1.05)
            scale: 0.88 + root.revealProgress * 0.12
            spacing: 8

            transform: Translate {
                x: (root.leading ? -1 : 1) * (1 - root.revealProgress) * 10
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                color: Config.alpha(Config.md3.on_error, root.armed ? 0.2 : 0.13)
                height: 34
                radius: 17
                scale: root.armed ? 1.08 : 1
                width: 34

                Behavior on scale {
                    NumberAnimation {
                        duration: Config.animationDuration(130)
                        easing.type: Easing.OutBack
                    }
                }

                IconImage {
                    anchors.centerIn: parent
                    height: 20
                    layer.enabled: true
                    source: Quickshell.iconPath("user-trash-symbolic")
                    width: 20

                    layer.effect: ColorOverlay {
                        color: Config.md3.on_error
                    }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: Config.md3.on_error
                font.family: Config.fontName
                font.pixelSize: 15
                font.weight: Font.Bold
                text: root.actionText
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: root.interactive

            onClicked: root.triggered()
        }
    }
}
