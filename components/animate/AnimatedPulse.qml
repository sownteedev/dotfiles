import QtQuick
import Quickshell
import "../../"

Item {
    id: root

    property real centerX: width / 2
    property real centerY: height / 2
    property color color: Config.md3.primary
    property real endRadius: Math.hypot(Math.max(centerX, width - centerX), Math.max(centerY, height - centerY))
    property bool hasPulses: false
    property var pulses: []
    property bool running: false
    property real startRadius: Math.min(width, height) * 0.32

    function addPulse() {
        root.pulses.push({
            progress: 0
        });
        root.hasPulses = true;
        pulseCanvas.requestPaint();
    }

    Timer {
        interval: 850
        repeat: true
        running: root.running && root.visible && root.width > 0 && root.height > 0

        onTriggered: root.addPulse()
    }
    Timer {
        interval: 33
        repeat: true
        running: root.visible && root.width > 0 && root.height > 0 && (root.running || root.hasPulses)

        onTriggered: {
            var p = root.pulses;
            for (var i = p.length - 1; i >= 0; i--) {
                p[i].progress += 0.0075;
                if (p[i].progress >= 1) {
                    p.splice(i, 1);
                }
            }
            root.hasPulses = (p.length > 0);
            pulseCanvas.requestPaint();
        }
    }
    Canvas {
        id: pulseCanvas

        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var startRadius = Math.max(0, root.startRadius);
            var endRadius = Math.max(startRadius, root.endRadius);
            if (endRadius <= 0)
                return;

            var p = root.pulses;
            if (!p)
                return;

            for (var i = 0; i < p.length; i++) {
                var progress = Math.max(0, Math.min(1, p[i].progress));
                var easedProgress = progress;
                var alpha = Math.pow(1 - progress, 1.1);
                var radius = startRadius + (endRadius - startRadius) * easedProgress;

                ctx.beginPath();
                ctx.arc(root.centerX, root.centerY, radius, 0, 2 * Math.PI);
                ctx.lineWidth = 2 + 8 * alpha;
                ctx.strokeStyle = Config.alpha(root.color, alpha * 0.22);
                ctx.stroke();
            }
        }
    }

    onCenterXChanged: pulseCanvas.requestPaint()
    onCenterYChanged: pulseCanvas.requestPaint()
    onEndRadiusChanged: pulseCanvas.requestPaint()
    onRunningChanged: {
        if (running)
            addPulse();
    }
    onStartRadiusChanged: pulseCanvas.requestPaint()
}
