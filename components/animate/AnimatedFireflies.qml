import QtQuick
import "../../"

Item {
    id: root

    property color color: "#e6ff00" // Default to a yellowish green glow
    property var fireflies: []
    property int fireflyCount: 25
    property bool running: true

    Component.onCompleted: {
        var newFireflies = [];
        for (var i = 0; i < root.fireflyCount; i++) {
            newFireflies.push({
                x: Math.random() // 0 to 1
                ,
                y: Math.random() // 0 to 1
                ,
                tx: Math.random() // target X
                ,
                ty: Math.random() // target Y
                ,
                speed: (Math.random() * 0.0005) + 0.0002,
                size: Math.random() * 1.5 + 1.0,
                glowPhase: Math.random() * Math.PI * 2,
                glowSpeed: (Math.random() * 0.05) + 0.02
            });
        }
        root.fireflies = newFireflies;
    }

    Timer {
        interval: 33
        repeat: true
        running: root.running && root.width > 0

        onTriggered: {
            var f = root.fireflies;
            for (var i = 0; i < f.length; i++) {
                // Move towards target smoothly
                var dx = f[i].tx - f[i].x;
                var dy = f[i].ty - f[i].y;
                var dist = Math.sqrt(dx * dx + dy * dy);

                if (dist < 0.05) {
                    // Reached target, pick a new one nearby
                    f[i].tx = f[i].x + (Math.random() - 0.5) * 0.4;
                    f[i].ty = f[i].y + (Math.random() - 0.5) * 0.4;

                    // Keep in bounds
                    if (f[i].tx < 0)
                        f[i].tx = 0;
                    if (f[i].tx > 1)
                        f[i].tx = 1;
                    if (f[i].ty < 0)
                        f[i].ty = 0;
                    if (f[i].ty > 1)
                        f[i].ty = 1;
                }

                f[i].x += dx * f[i].speed * 10;
                f[i].y += dy * f[i].speed * 10;

                f[i].glowPhase += f[i].glowSpeed;
            }
            fireflyCanvas.requestPaint();
        }
    }
    Canvas {
        id: fireflyCanvas

        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var f = root.fireflies;
            if (!f || f.length === 0)
                return;

            for (var i = 0; i < f.length; i++) {
                var px = f[i].x * width;
                var py = f[i].y * height;

                // Pulsing glow alpha
                var alpha = 0.2 + ((Math.sin(f[i].glowPhase) + 1) / 2) * 0.8;

                // Draw inner core
                ctx.beginPath();
                ctx.arc(px, py, f[i].size, 0, 2 * Math.PI);
                ctx.fillStyle = Config.alpha(root.color, alpha);
                ctx.fill();

                // Draw outer glow (halo)
                ctx.beginPath();
                ctx.arc(px, py, f[i].size * 4, 0, 2 * Math.PI);

                // Create radial gradient for glow
                var gradient = ctx.createRadialGradient(px, py, 0, px, py, f[i].size * 4);
                gradient.addColorStop(0, Config.alpha(root.color, alpha * 0.6));
                gradient.addColorStop(1, "transparent");

                ctx.fillStyle = gradient;
                ctx.fill();
            }
        }
    }
}
