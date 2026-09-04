import "../../"
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    readonly property real clampedOpacity: Math.max(0.1, Math.min(1, Number(selectedOpacity) || 1))
    readonly property real normalizedOpacity: (clampedOpacity - 0.1) / 0.9
    property real selectedOpacity: 1
    property bool showValueLabel: true
    property real visualProgress: normalizedOpacity

    signal opacityChangeFinished
    signal opacityChangeStarted
    signal opacitySelected(real opacityValue)

    function changeOpacity(amount) {
        opacityChangeStarted();
        opacitySelected(Math.max(0.1, Math.min(1, clampedOpacity + amount)));
        opacityChangeFinished();
    }
    function selectOpacityAt(mouseX) {
        var ratio = Math.max(0, Math.min(1, mouseX / Math.max(1, opacityTrack.width)));
        opacitySelected(0.1 + ratio * 0.9);
    }

    implicitHeight: 32
    implicitWidth: showValueLabel ? 170 : 120
    spacing: showValueLabel ? 8 : 0

    Behavior on visualProgress {
        enabled: !opacityPointer.pressed

        NumberAnimation {
            duration: 100
            easing.type: Easing.OutCubic
        }
    }

    Text {
        Layout.preferredWidth: visible ? 42 : 0
        color: Config.md3.on_surface_variant
        font.family: Config.fontName
        font.pixelSize: 12
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.clampedOpacity * 100) + "%"
        visible: root.showValueLabel
    }
    Item {
        id: opacityTrack

        Layout.fillWidth: true
        Layout.preferredHeight: 30

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            border.color: Config.alpha(Config.md3.on_surface, 0.14)
            border.width: 1
            height: 8
            radius: 4

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    color: Config.alpha(Config.md3.tertiary, 0.1)
                    position: 0
                }
                GradientStop {
                    color: Config.md3.tertiary
                    position: 1
                }
            }
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            border.color: Config.md3.background
            border.width: 2
            color: Config.md3.tertiary
            height: 16
            radius: 8
            scale: opacityPointer.pressed ? 1.18 : 1
            width: 16
            x: Math.max(0, Math.min(parent.width - width, parent.width * root.visualProgress - width / 2))

            Behavior on scale {
                NumberAnimation {
                    duration: 100
                }
            }
        }
        MouseArea {
            id: opacityPointer

            Accessible.name: qsTr("Opacity")
            Accessible.role: Accessible.Slider
            activeFocusOnTab: true
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            Keys.onLeftPressed: event => {
                root.changeOpacity(-0.05);
                event.accepted = true;
            }
            Keys.onRightPressed: event => {
                root.changeOpacity(0.05);
                event.accepted = true;
            }
            onCanceled: root.opacityChangeFinished()
            onPositionChanged: mouse => {
                if (pressed)
                    root.selectOpacityAt(mouse.x);
            }
            onPressed: mouse => {
                root.opacityChangeStarted();
                root.selectOpacityAt(mouse.x);
            }
            onReleased: root.opacityChangeFinished()
            onWheel: wheel => {
                root.changeOpacity(wheel.angleDelta.y > 0 ? 0.05 : -0.05);
                wheel.accepted = true;
            }
        }
    }
}
