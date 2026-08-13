import QtQuick
import QtQuick.Layouts
import "../../"

Rectangle {
    id: root

    readonly property real clampedValue: clampValue(value)
    property real dragValue: 0.0
    readonly property bool dragging: sliderMouse.pressed
    property color highlightColor: Config.md3.primary
    property bool isMuted: false
    property color peakColor: Config.md3.secondary
    property real peakValue: 0.0
    property real pendingValue: 0.0
    property bool pendingValueDirty: false
    property bool showCenterTick: false
    property bool showPeak: false
    property bool showThumbOnHover: false
    property real thumbSize: 10
    property real trackHeight: 8
    property int updateInterval: 16
    property real hoverTrackHeight: trackHeight
    property real value: 0.0
    readonly property real visualValue: dragging ? dragValue : clampedValue

    signal sliderMoved(real value)

    function clampValue(nextValue) {
        return Math.max(0, Math.min(1, Number(nextValue) || 0));
    }
    function discardPendingValue() {
        updateTimer.stop();
        pendingValueDirty = false;
    }
    function emitPendingValue() {
        if (!pendingValueDirty)
            return;

        var nextValue = pendingValue;
        pendingValueDirty = false;
        sliderMoved(nextValue);
    }
    function updateFromPointer(pointerX) {
        var nextValue = clampValue(pointerX / Math.max(1, sliderMouse.width));
        dragValue = nextValue;
        pendingValue = nextValue;
        pendingValueDirty = true;

        if (!updateTimer.running)
            updateTimer.start();
    }

    Layout.fillWidth: true
    color: "transparent"
    height: 24

    Rectangle {
        id: track

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        color: Config.alpha(Config.md3.on_surface, 0.1)
        height: sliderMouse.containsMouse ? root.hoverTrackHeight : root.trackHeight
        radius: height / 2

        Behavior on height {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.top: parent.top
            color: root.isMuted ? Config.md3.outline : root.showPeak ? Config.alpha(root.highlightColor, 0.38) : root.highlightColor
            radius: parent.radius
            width: track.width * root.visualValue

            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.top: parent.top
            color: root.peakColor
            radius: parent.radius
            visible: root.showPeak && !root.isMuted && width > 0
            width: parent.width * root.visualValue * Math.pow(Math.max(0, Math.min(1, root.peakValue)), 0.55)

            Behavior on color {
                ColorAnimation {
                    duration: 100
                }
            }
            Behavior on width {
                NumberAnimation {
                    duration: 48
                    easing.type: Easing.OutQuad
                }
            }
        }
        Rectangle {
            anchors.centerIn: parent
            color: Config.alpha(Config.md3.on_surface, 0.5)
            height: 14
            radius: 1
            visible: root.showCenterTick
            width: 3
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            color: root.isMuted ? Config.md3.outline : root.highlightColor
            height: width
            radius: width / 2
            visible: root.showThumbOnHover
            width: sliderMouse.containsMouse ? root.thumbSize : 0
            x: Math.max(0, Math.min(parent.width - width, parent.width * root.visualValue - width / 2))

            Behavior on width {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
    MouseArea {
        id: sliderMouse

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        preventStealing: true

        onCanceled: root.discardPendingValue()
        onPositionChanged: mouse => {
            if (pressed)
                root.updateFromPointer(mouse.x);
        }
        onPressed: mouse => {
            root.dragValue = root.clampedValue;
            root.updateFromPointer(mouse.x);
        }
        onReleased: {
            updateTimer.stop();
            root.emitPendingValue();
        }
    }
    Timer {
        id: updateTimer

        interval: root.updateInterval
        repeat: false

        onTriggered: root.emitPendingValue()
    }
}
