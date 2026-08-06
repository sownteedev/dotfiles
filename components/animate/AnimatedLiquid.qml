import QtQuick
import "../../"

Item {
    id: root

    property bool active: false
    property color color: Config.md3.primary
    property real fillProgress: active ? 1.1 : -0.1
    property real wavePhase: 0

    Behavior on fillProgress {
        NumberAnimation {
            duration: 600
            easing.type: Easing.InOutQuad
        }
    }

    Timer {
        interval: 33
        repeat: true
        running: root.visible && root.width > 0 && root.height > 0 && (root.active || (root.fillProgress > -0.1 && root.fillProgress < 1.1))

        onTriggered: {
            root.wavePhase += 0.15;
            liquidCanvas.requestPaint();
        }
    }
    Canvas {
        id: liquidCanvas

        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            // If completely empty, draw nothing
            if (root.fillProgress <= -0.05)
                return;

            // If completely full, draw a solid rectangle (the button's mask will clip it)
            if (root.fillProgress >= 1.05) {
                ctx.fillStyle = root.color;
                ctx.fillRect(0, 0, width, height);
                return;
            }

            var fillHeight = height * (1.0 - root.fillProgress);
            var waveAmplitude = 4 + (1.0 - Math.abs(root.fillProgress - 0.5) * 2) * 3; // Waves are higher in the middle
            var waveLength = width * 0.8;

            ctx.fillStyle = root.color;
            ctx.beginPath();
            ctx.moveTo(0, height);
            ctx.lineTo(0, fillHeight);

            for (var x = 0; x <= width; x += 2) {
                var y = fillHeight + Math.sin((x / waveLength) * Math.PI * 2 + root.wavePhase) * waveAmplitude;
                ctx.lineTo(x, y);
            }

            ctx.lineTo(width, height);
            ctx.closePath();
            ctx.fill();

            // Draw a second, slightly offset and more transparent wave for depth
            ctx.fillStyle = Config.alpha(root.color, 0.5);
            ctx.beginPath();
            ctx.moveTo(0, height);
            ctx.lineTo(0, fillHeight);

            for (var x2 = 0; x2 <= width; x2 += 2) {
                var y2 = fillHeight + Math.sin((x2 / waveLength) * Math.PI * 2 + root.wavePhase * 1.3 + Math.PI / 1.5) * (waveAmplitude * 1.2);
                ctx.lineTo(x2, y2);
            }

            ctx.lineTo(width, height);
            ctx.closePath();
            ctx.fill();
        }
    }
}
