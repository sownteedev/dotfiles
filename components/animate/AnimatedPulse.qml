import QtQuick
import Quickshell
import "../../"

Item {
    id: root
    property bool running: false
    property color color: Config.md3.primary
    
    property var pulses: []
    property bool hasPulses: false
    
    Timer {
        interval: 1200 // 1.2s per pulse
        running: root.running
        repeat: true
        onTriggered: {
            var p = root.pulses;
            p.push({ scale: 0.9, alpha: 1.0 });
            root.hasPulses = true;
        }
    }
    
    Timer {
        interval: 33
        running: root.running || root.hasPulses
        repeat: true
        onTriggered: {
            var p = root.pulses;
            for (var i = p.length - 1; i >= 0; i--) {
                p[i].scale += 0.006;
                p[i].alpha -= 0.015;
                if (p[i].alpha <= 0) {
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
        anchors.margins: -100 
        
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            
            var centerX = width / 2;
            var centerY = height / 2;
            
            // pulseCanvas is expanded by 100 on all sides, so its width is parent.width + 200.
            // Base radius of the dial is half of the original parent's width.
            var baseRadius = (Math.min(width, height) - 200) / 2;
            if (baseRadius <= 0) return;
            
            var p = root.pulses;
            if (!p) return;
            
            for (var i = 0; i < p.length; i++) {
                ctx.beginPath();
                ctx.arc(centerX, centerY, baseRadius * p[i].scale, 0, 2 * Math.PI);
                ctx.lineWidth = 12 * p[i].alpha;
                ctx.strokeStyle = Config.alpha(root.color, p[i].alpha * 0.4);
                ctx.stroke();
            }
        }
    }
}
