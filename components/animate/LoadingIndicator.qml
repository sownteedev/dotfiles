import QtQuick
import "../../"

Item {
    id: root

    property bool animated: true
    property color color: Config.md3.primary

    implicitHeight: 48
    implicitWidth: 48

    Timer {
        id: animTimer

        property real time: 0

        interval: 33
        repeat: true
        running: root.animated && root.visible && root.width > 0 && root.height > 0

        onTriggered: {
            time += 0.12;
            canvas.requestPaint();
        }
    }
    Canvas {
        id: canvas

        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var cx = width / 2;
            var cy = height / 2;
            var r = Math.min(cx, cy) - 4;

            var time = animTimer.time;

            // Draw outer wobbly ring
            ctx.beginPath();
            for (var i = 0; i <= Math.PI * 2 + 0.1; i += 0.1) {
                var wobble = Math.sin(i * 3 + time) * 1.5 + Math.cos(i * 5 - time * 0.8) * 1.0;
                var currR = r + wobble;
                var x = cx + Math.cos(i) * currR;
                var y = cy + Math.sin(i) * currR;
                if (i === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            ctx.closePath();
            ctx.lineWidth = 4;
            ctx.strokeStyle = Config.alpha(root.color, 0.4);
            ctx.stroke();

            // Draw inner wobbly solid shape
            ctx.beginPath();
            var innerR = r - 8;
            for (var j = 0; j <= Math.PI * 2 + 0.1; j += 0.1) {
                var wobbleInner = Math.sin(j * 4 - time * 1.2) * 2.0 + Math.cos(j * 2 + time * 1.5) * 1.5;
                var currRInner = innerR + wobbleInner;
                var xInner = cx + Math.cos(j) * currRInner;
                var yInner = cy + Math.sin(j) * currRInner;
                if (j === 0)
                    ctx.moveTo(xInner, yInner);
                else
                    ctx.lineTo(xInner, yInner);
            }
            ctx.closePath();
            ctx.fillStyle = root.color;
            ctx.fill();
        }
    }
}
