import QtQuick

Item {
    id: root

    required property bool contentReady
    required property bool exiting
    property bool started: false

    function finishEntrance() {
        started = true;
        entranceAnimation.stop();
        opacity = 1;
        scale = 1;
    }
    function reveal() {
        if (started)
            return;
        if (exiting) {
            finishEntrance();
            return;
        }
        started = true;
        entranceAnimation.start();
    }

    opacity: 0
    scale: 1.04

    Component.onCompleted: {
        if (exiting)
            finishEntrance();
    }
    onExitingChanged: {
        if (exiting)
            finishEntrance();
    }

    Timer {
        interval: 140
        running: !root.started && root.contentReady && root.visible && root.width > 0 && root.height > 0

        onTriggered: root.reveal()
    }
    Timer {
        interval: 700
        running: !root.started && root.visible && root.width > 0 && root.height > 0

        onTriggered: root.reveal()
    }
    ParallelAnimation {
        id: entranceAnimation

        paused: running && !root.visible

        OpacityAnimator {
            duration: 360
            easing.type: Easing.OutCubic
            from: 0
            target: root
            to: 1
        }
        ScaleAnimator {
            duration: 460
            easing.type: Easing.OutQuint
            from: 1.04
            target: root
            to: 1
        }
    }
}
