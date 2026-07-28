import QtQuick
import "../../"

Item {
    id: root

    // Array of possible colors for confetti pieces
    property var colors: [Config.md3.primary, Config.md3.secondary, Config.md3.tertiary, Config.md3.error, Config.md3.primary_container, Config.md3.secondary_container]
    property int confettiCount: 80
    property var particles: []
    property bool running: true

    function resetParticle(p, fullReset) {
        p.x = Math.random(); // 0 to 1
        p.y = fullReset ? (Math.random() - 1.0) : -0.1; // Start slightly above top
        p.w = (Math.random() * 8) + 6; // Width 6-14px
        p.h = (Math.random() * 12) + 8; // Height 8-20px
        p.vx = (Math.random() - 0.5) * 0.002; // Horizontal drift
        p.vy = (Math.random() * 0.003) + 0.002; // Falling speed
        p.rot = Math.random() * Math.PI * 2; // Initial rotation
        p.rotSpeed = (Math.random() - 0.5) * 0.2; // Spin speed
        p.flip = Math.random() * Math.PI * 2; // Initial 3D flip
        p.flipSpeed = (Math.random() - 0.5) * 0.2; // 3D flip speed
        p.color = root.colors[Math.floor(Math.random() * root.colors.length)];
        return p;
    }

    Component.onCompleted: {
        var newParticles = [];
        for (var i = 0; i < root.confettiCount; i++) {
            newParticles.push(resetParticle({}, true));
        }
        root.particles = newParticles;
    }

    Timer {
        interval: 33
        repeat: true
        running: root.running && root.width > 0

        onTriggered: {
            var p = root.particles;
            for (var i = 0; i < p.length; i++) {
                p[i].x += p[i].vx;
                p[i].y += p[i].vy;
                p[i].rot += p[i].rotSpeed;
                p[i].flip += p[i].flipSpeed;

                // Add some sway (wind effect)
                p[i].x += Math.sin(p[i].y * 10) * 0.001;

                if (p[i].y > 1.1) {
                    resetParticle(p[i], false);
                }
            }
            confettiCanvas.requestPaint();
        }
    }
    Canvas {
        id: confettiCanvas

        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var p = root.particles;
            if (!p || p.length === 0)
                return;

            for (var i = 0; i < p.length; i++) {
                var px = p[i].x * width;
                var py = p[i].y * height;

                // Skip if completely off screen to save rendering
                if (px < -20 || px > width + 20 || py < -20 || py > height + 20)
                    continue;

                ctx.save();
                ctx.translate(px, py);
                ctx.rotate(p[i].rot);
                // Simulate 3D spin by scaling X
                var flipScale = Math.cos(p[i].flip);
                ctx.scale(flipScale, 1.0);

                ctx.fillStyle = p[i].color;
                // Add shading based on 3D flip to make it look realistic
                if (flipScale < 0) {
                    ctx.fillStyle = Config.alpha(p[i].color, 0.7); // Darker on back side
                }

                ctx.fillRect(-p[i].w / 2, -p[i].h / 2, p[i].w, p[i].h);
                ctx.restore();
            }
        }
    }
}
