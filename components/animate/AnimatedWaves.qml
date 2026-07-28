import QtQuick
import Quickshell
import "../../"

Item {
    id: root
    property bool running: true
    property color color: Config.md3.primary
    property real wavePhase: 0

    Timer {
        interval: 40
        running: root.running
        repeat: true
        onTriggered: {
            root.wavePhase += 0.06;
            bgWave.requestPaint();
        }
    }

    Canvas {
        id: bgWave
        anchors.fill: parent
        
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var centerY = height * 0.65;
            
            // Back Wave
            ctx.beginPath();
            ctx.moveTo(0, height);
            for (var x = 0; x <= width; x += 15) {
                var y = centerY + Math.sin(x * 0.01 - root.wavePhase) * 25;
                ctx.lineTo(x, y);
            }
            ctx.lineTo(width, height);
            ctx.closePath();
            ctx.fillStyle = Config.alpha(root.color, 0.04);
            ctx.fill();

            // Front Wave
            ctx.beginPath();
            ctx.moveTo(0, height);
            for (var x = 0; x <= width; x += 15) {
                var y = centerY + 15 + Math.sin(x * 0.013 - root.wavePhase * 1.3) * 35;
                ctx.lineTo(x, y);
            }
            ctx.lineTo(width, height);
            ctx.closePath();
            ctx.fillStyle = Config.alpha(root.color, 0.07);
            ctx.fill();
        }
    }
}
