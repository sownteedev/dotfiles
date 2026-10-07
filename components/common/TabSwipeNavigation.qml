import QtQuick

Item {
    id: root

    required property int count
    required property int currentIndex
    property DragHandler dragHandler: DragHandler {
        property bool committed: false

        acceptedButtons: Qt.LeftButton
        dragThreshold: 18
        enabled: root.enabled && root.count > 1
        target: null
        xAxis.enabled: true
        yAxis.enabled: false

        onActiveChanged: {
            if (active)
                committed = false;
        }
        onActiveTranslationChanged: {
            if (active && !committed && Math.abs(activeTranslation.x) >= 48) {
                committed = true;
                root.step(activeTranslation.x < 0 ? 1 : -1);
            }
        }
    }
    property bool wheelCommitted: false
    property real wheelDistance: 0
    property WheelHandler wheelHandler: WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        enabled: root.enabled && root.count > 1
        orientation: Qt.Horizontal
        target: null

        onWheel: event => {
            const delta = event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0 ? event.pixelDelta : event.angleDelta;
            if (Math.abs(delta.x) <= Math.abs(delta.y)) {
                event.accepted = false;
                return;
            }
            event.accepted = true;
            if (event.phase === Qt.ScrollBegin)
                root.resetWheel();
            if (!root.wheelCommitted && event.phase !== Qt.ScrollMomentum) {
                root.wheelDistance += delta.x;
                const threshold = event.pixelDelta.x !== 0 ? 40 : 120;
                if (Math.abs(root.wheelDistance) >= threshold) {
                    root.wheelCommitted = true;
                    root.step(root.wheelDistance < 0 ? 1 : -1);
                }
            }
            root.wheelReset.restart();
        }
    }
    property Timer wheelReset: Timer {
        interval: 220

        onTriggered: root.resetWheel()
    }

    signal requested(int index)

    function resetWheel() {
        wheelDistance = 0;
        wheelCommitted = false;
    }
    function step(direction) {
        const next = currentIndex + direction;
        if (enabled && next >= 0 && next < count)
            requested(next);
    }

    onEnabledChanged: resetWheel()
}
