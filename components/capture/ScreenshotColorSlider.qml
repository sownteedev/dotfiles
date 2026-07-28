import "../../"
import QtQuick

Item {
    id: root

    property color selectedColor: "#ff3b30"
    readonly property real selectedHue: selectedColor.hsvSaturation > 0.02 && selectedColor.hsvHue >= 0 ? selectedColor.hsvHue : 0

    signal colorSelected(color colorValue)

    function moveHue(amount) {
        var nextHue = selectedHue + amount;
        while (nextHue < 0)
            nextHue += 1;
        while (nextHue >= 1)
            nextHue -= 1;
        colorSelected(Qt.hsva(nextHue, 1, 1, 1));
    }
    function selectHueAt(mouseX) {
        // Hue 1 is the same red as hue 0. Keep the upper endpoint just below
        // 1 so the handle does not jump back to the left edge when released.
        var ratio = Math.max(0, Math.min(0.999999, mouseX / Math.max(1, hueTrack.width)));
        colorSelected(Qt.hsva(ratio, 1, 1, 1));
    }

    implicitHeight: 32
    implicitWidth: 360

    Rectangle {
        id: hueTrack

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        border.color: Config.alpha(Config.md3.on_surface, 0.16)
        border.width: 1
        height: 18
        radius: 9

        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                color: "#ff0000"
                position: 0
            }
            GradientStop {
                color: "#ffff00"
                position: 0.1667
            }
            GradientStop {
                color: "#00ff00"
                position: 0.3333
            }
            GradientStop {
                color: "#00ffff"
                position: 0.5
            }
            GradientStop {
                color: "#0000ff"
                position: 0.6667
            }
            GradientStop {
                color: "#ff00ff"
                position: 0.8333
            }
            GradientStop {
                color: "#ff0000"
                position: 1
            }
        }
    }
    Rectangle {
        id: hueHandle

        anchors.verticalCenter: parent.verticalCenter
        border.color: Config.alpha(Config.md3.on_surface, 0.72)
        border.width: 2
        color: Config.alpha(Config.md3.background, 0.82)
        height: 28
        radius: 7
        width: hueMouse.pressed ? 20 : 18
        x: Math.max(0, Math.min(root.width - width, hueTrack.x + hueTrack.width * root.selectedHue - width / 2))

        Behavior on width {
            NumberAnimation {
                duration: 100
                easing.type: Easing.OutCubic
            }
        }
        Behavior on x {
            enabled: !hueMouse.pressed

            NumberAnimation {
                duration: 100
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.centerIn: parent
            color: root.selectedColor
            height: 18
            radius: 3
            width: 6
        }
    }
    MouseArea {
        id: hueMouse

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true

        onPositionChanged: mouse => {
            if (pressed)
                root.selectHueAt(mouse.x - hueTrack.x);
        }
        onPressed: mouse => {
            root.selectHueAt(mouse.x - hueTrack.x);
        }
        onWheel: wheel => {
            return root.moveHue((wheel.angleDelta.y > 0 ? 1 : -1) / 90);
        }
    }
}
