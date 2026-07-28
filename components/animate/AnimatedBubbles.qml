import QtQuick
import Quickshell
import "../../"

Item {
    id: root
    property bool running: true
    property color color: Config.md3.primary
    property int bubbleCount: 15
    property var bubbles: []

    Component.onCompleted: {
        var newBubbles = [];
        for (var i = 0; i < root.bubbleCount; i++) {
            newBubbles.push({
                x: Math.random(),
                y: Math.random(),
                r: Math.random() * 12 + 4,
                speed: Math.random() * 0.004 + 0.0015,
                phase: Math.random() * Math.PI * 2,
                alpha: Math.random() * 0.5 + 0.2
            });
        }
        bubbles = newBubbles;
    }

    Timer {
        interval: 40
        running: root.running
        repeat: true
        onTriggered: {
            var b = root.bubbles;
            for (var i = 0; i < b.length; i++) {
                b[i].y -= b[i].speed;
                b[i].phase += 0.04;
                if (b[i].y < -0.1) {
                    b[i].y = 1.1;
                    b[i].x = Math.random();
                }
            }
            bubbleCanvas.requestPaint();
        }
    }

    Canvas {
        id: bubbleCanvas
        anchors.fill: parent
        
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var b = root.bubbles;
            for (var i = 0; i < b.length; i++) {
                var bubble = b[i];
                var bx = (bubble.x * width) + Math.sin(bubble.phase) * 20;
                var by = bubble.y * height;
                
                ctx.beginPath();
                ctx.arc(bx, by, bubble.r, 0, 2 * Math.PI);
                ctx.fillStyle = Config.alpha(root.color, bubble.alpha * 0.12);
                ctx.fill();
                ctx.lineWidth = 1.5;
                ctx.strokeStyle = Config.alpha(root.color, bubble.alpha * 0.25);
                ctx.stroke();
            }
        }
    }
}
