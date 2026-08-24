import QtQuick
import "../../"

Item {
    id: root

    property bool active: false
    property int characterCount: 0
    property color cursorColor: Config.md3.primary
    property color dotColor: Config.alpha(Config.md3.on_surface, 0.9)
    property real dotSize: 14
    property real dotSpacing: 5
    property bool error: false
    property color errorColor: Config.md3.error
    property bool revealed: false

    clip: true
    visible: !revealed

    Row {
        id: dotRow

        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        x: Math.min(0, root.width - implicitWidth)

        Behavior on x {
            NumberAnimation {
                duration: Config.animationDuration(140)
                easing.type: Easing.OutCubic
            }
        }

        Repeater {
            model: 64

            Item {
                required property int index

                height: Math.max(root.dotSize, 24)
                opacity: index < root.characterCount ? 1 : 0
                width: index < root.characterCount ? root.dotSize + root.dotSpacing : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animationDuration(260)
                        easing.type: Easing.OutQuart
                    }
                }
                Behavior on width {
                    NumberAnimation {
                        duration: Config.animationDuration(170)
                        easing.type: Easing.OutQuart
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    color: root.error ? root.errorColor : root.dotColor
                    height: root.dotSize
                    radius: root.dotSize / 2
                    width: root.dotSize

                    Behavior on color {
                        ColorAnimation {
                            duration: Config.animationDuration(160)
                        }
                    }
                }
            }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            color: root.error ? root.errorColor : root.cursorColor
            height: Math.max(18, root.dotSize + 7)
            opacity: root.active ? 1 : 0
            radius: 1
            visible: root.active
            width: 2

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: root.active && Config.animationDuration(500) > 0

                NumberAnimation {
                    duration: Config.animationDuration(500)
                    easing.type: Easing.InOutSine
                    to: 0.25
                }
                NumberAnimation {
                    duration: Config.animationDuration(500)
                    easing.type: Easing.InOutSine
                    to: 1
                }
            }
        }
    }
}
