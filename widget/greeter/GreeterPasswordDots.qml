import QtQuick

Item {
    id: root

    property bool active: false
    property int characterCount: 0
    property color cursorColor: GreeterTheme.primary
    property color dotColor: GreeterTheme.surfaceText
    property bool error: false

    clip: true

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        x: Math.min(0, root.width - implicitWidth)

        Behavior on x {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        Repeater {
            model: 64

            Item {
                required property int index

                height: 24
                opacity: index < root.characterCount ? 1 : 0
                width: index < root.characterCount ? 19 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutQuart
                    }
                }
                Behavior on width {
                    NumberAnimation {
                        duration: 170
                        easing.type: Easing.OutQuart
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    color: root.error ? GreeterTheme.error : root.dotColor
                    height: 14
                    radius: 7
                    width: 14

                    Behavior on color {
                        ColorAnimation {
                            duration: 160
                        }
                    }
                }
            }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            color: root.error ? GreeterTheme.error : root.cursorColor
            height: 21
            opacity: root.active ? 1 : 0
            radius: 1
            visible: root.active
            width: 2

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                running: root.active

                NumberAnimation {
                    duration: 500
                    easing.type: Easing.InOutSine
                    to: 0.25
                }
                NumberAnimation {
                    duration: 500
                    easing.type: Easing.InOutSine
                    to: 1
                }
            }
        }
    }
}
