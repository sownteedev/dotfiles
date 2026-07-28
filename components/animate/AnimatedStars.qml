import QtQuick
import "../../"

Item {
    id: root
    property bool running: true
    property color color: "#ffffff"
    property int starCount: 100
    
    property var stars: []
    
    Component.onCompleted: {
        var newStars = [];
        for (var i = 0; i < root.starCount; i++) {
            newStars.push({
                x: Math.random(), // 0 to 1 relative to width
                y: Math.random(), // 0 to 1 relative to height
                size: Math.random() * 1.5 + 0.5, // 0.5 to 2.0 radius
                speed: (Math.random() * 0.001) + 0.0002,
                twinkleSpeed: (Math.random() * 0.1) + 0.02,
                twinklePhase: Math.random() * Math.PI * 2
            });
        }
        root.stars = newStars;
    }
    
    Timer {
        interval: 33
        running: root.running && root.width > 0
        repeat: true
        onTriggered: {
            var s = root.stars;
            for (var i = 0; i < s.length; i++) {
                // Move star left and up (like moving forward in space)
                s[i].x -= s[i].speed * (s[i].size * 0.5); // Bigger stars move faster (parallax)
                s[i].y -= s[i].speed * (s[i].size * 0.5);
                s[i].twinklePhase += s[i].twinkleSpeed;
                
                // Wrap around
                if (s[i].x < 0) s[i].x = 1.0;
                if (s[i].y < 0) s[i].y = 1.0;
            }
            starCanvas.requestPaint();
        }
    }
    
    Canvas {
        id: starCanvas
        anchors.fill: parent
        
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            
            var s = root.stars;
            if (!s || s.length === 0) return;
            
            for (var i = 0; i < s.length; i++) {
                var px = s[i].x * width;
                var py = s[i].y * height;
                
                // Twinkle effect: alpha varies between 0.3 and 1.0
                var alpha = 0.3 + ((Math.sin(s[i].twinklePhase) + 1) / 2) * 0.7;
                
                ctx.beginPath();
                ctx.arc(px, py, s[i].size, 0, 2 * Math.PI);
                ctx.fillStyle = Config.alpha(root.color, alpha);
                ctx.fill();
                
                // Optional: Add a slight glow for bigger stars
                if (s[i].size > 1.2) {
                    ctx.beginPath();
                    ctx.arc(px, py, s[i].size * 2.5, 0, 2 * Math.PI);
                    ctx.fillStyle = Config.alpha(root.color, alpha * 0.2);
                    ctx.fill();
                }
            }
        }
    }
}
