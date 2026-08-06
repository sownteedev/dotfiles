import QtQuick
import "../../"

Item {
    id: root

    property color color: Config.md3.primary
    property real currentRotation: 0
    property int rayCount: 12
    property real rotationSpeed: 0.2 // degrees per frame

    property bool running: true

    Timer {
        interval: 33
        repeat: true
        running: root.running && root.visible && root.width > 0 && root.height > 0

        onTriggered: {
            root.currentRotation += root.rotationSpeed;
            if (root.currentRotation >= 360) {
                root.currentRotation -= 360;
            }
            rayCanvas.requestPaint();
        }
    }
    Canvas {
        id: rayCanvas

        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var centerX = width / 2;
            var centerY = height / 2;
            var maxRadius = Math.max(width, height) * 1.5; // Ensure it reaches the corners

            var angleStep = (Math.PI * 2) / (root.rayCount * 2); // multiplied by 2 because we need space between rays
            var startAngle = (root.currentRotation * Math.PI) / 180;

            ctx.save();
            ctx.translate(centerX, centerY);
            ctx.rotate(startAngle);

            for (var i = 0; i < root.rayCount; i++) {
                ctx.beginPath();
                ctx.moveTo(0, 0);

                // Draw a wedge (triangle)
                var a1 = i * angleStep * 2;
                var a2 = a1 + angleStep;

                var x1 = Math.cos(a1) * maxRadius;
                var y1 = Math.sin(a1) * maxRadius;

                var x2 = Math.cos(a2) * maxRadius;
                var y2 = Math.sin(a2) * maxRadius;

                ctx.lineTo(x1, y1);
                ctx.lineTo(x2, y2);
                ctx.closePath();

                // Use a radial gradient to make the rays fade out at the edges
                var gradient = ctx.createRadialGradient(0, 0, 0, 0, 0, maxRadius);
                gradient.addColorStop(0, Config.alpha(root.color, 0.4)); // Brighter at center
                gradient.addColorStop(1, "transparent"); // Fade out

                ctx.fillStyle = gradient;
                ctx.fill();
            }

            // Draw a glowing center
            ctx.beginPath();
            ctx.arc(0, 0, Math.min(width, height) * 0.15, 0, Math.PI * 2);
            var centerGrad = ctx.createRadialGradient(0, 0, 0, 0, 0, Math.min(width, height) * 0.15);
            centerGrad.addColorStop(0, Config.alpha(root.color, 0.6));
            centerGrad.addColorStop(1, "transparent");
            ctx.fillStyle = centerGrad;
            ctx.fill();

            ctx.restore();
        }
    }
}
