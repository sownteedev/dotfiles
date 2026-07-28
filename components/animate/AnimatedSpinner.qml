import QtQuick
import "../../"

Item {
    id: root

    property color color: Config.md3.primary

    // Internal state for spinning
    property real currentAngle: 0
    property real lineWidth: 3.0

    // Properties
    property bool running: true

    Timer {
        interval: 16 // roughly 60fps
        repeat: true
        running: root.running && root.visible

        onTriggered: {
            root.currentAngle += 0.15;
            if (root.currentAngle >= Math.PI * 2) {
                root.currentAngle -= Math.PI * 2;
            }
            spinnerCanvas.requestPaint();
        }
    }
    Canvas {
        id: spinnerCanvas

        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var centerX = width / 2;
            var centerY = height / 2;
            var radius = Math.min(width, height) / 2 - root.lineWidth;

            ctx.save();
            ctx.translate(centerX, centerY);
            ctx.rotate(root.currentAngle);

            // Draw a spinning fading arc (like a meteor trail)
            ctx.beginPath();
            ctx.arc(0, 0, radius, 0, Math.PI * 1.5, false);

            // Create a conical gradient for the tail effect
            var gradient = ctx.createConicalGradient(0, 0, 0);
            gradient.addColorStop(0.0, Config.alpha(root.color, 0.0));
            gradient.addColorStop(0.5, Config.alpha(root.color, 0.5));
            gradient.addColorStop(1.0, root.color);

            ctx.lineWidth = root.lineWidth;
            ctx.strokeStyle = gradient;
            ctx.lineCap = "round";
            ctx.stroke();

            ctx.restore();
        }
    }
}
