import QtQuick
import Quickshell
import "../../"

Item {
    id: root

    property var particles: []
    property real phase: 0
    property bool running: true
    property string type: {
        var icon = weatherIcon || "";
        if (icon.includes("showers") || icon.includes("storm") || icon.includes("rain"))
            return "rain";
        if (icon.includes("snow"))
            return "snow";
        if (icon.includes("clouds") || icon.includes("overcast") || icon.includes("fog"))
            return "clouds";
        if (icon.includes("night"))
            return "stars";
        return "sun";
    }
    property string weatherIcon: "weather-clear-symbolic"

    Component.onCompleted: typeChanged()
    onTypeChanged: {
        particles = [];
        if (type === "rain") {
            for (var i = 0; i < 40; i++) {
                particles.push({
                    x: Math.random() * 1.5,
                    y: Math.random(),
                    speed: Math.random() * 0.03 + 0.02,
                    length: Math.random() * 0.05 + 0.03
                });
            }
        } else if (type === "snow") {
            for (var i = 0; i < 30; i++) {
                particles.push({
                    x: Math.random(),
                    y: Math.random(),
                    r: Math.random() * 3 + 1,
                    speed: Math.random() * 0.003 + 0.002,
                    swing: Math.random() * Math.PI * 2
                });
            }
        } else if (type === "clouds") {
            for (var i = 0; i < 6; i++) {
                particles.push({
                    x: Math.random(),
                    y: Math.random() * 0.6,
                    r: Math.random() * 150 + 50,
                    speed: Math.random() * 0.001 + 0.0005,
                    alpha: Math.random() * 0.04 + 0.02
                });
            }
        } else if (type === "stars") {
            for (var i = 0; i < 50; i++) {
                particles.push({
                    x: Math.random(),
                    y: Math.random() * 0.7,
                    r: Math.random() * 1.5 + 0.5,
                    phase: Math.random() * Math.PI * 2,
                    speed: Math.random() * 0.02 + 0.01
                });
            }
        }
        weatherCanvas.requestPaint();
    }

    Timer {
        interval: 33
        repeat: true
        running: root.running && root.visible && root.width > 0 && root.height > 0

        onTriggered: {
            root.phase += 0.02;
            var p = root.particles;

            if (root.type === "rain") {
                for (var i = 0; i < p.length; i++) {
                    p[i].y += p[i].speed;
                    p[i].x -= p[i].speed * 0.3; // Angle
                    if (p[i].y > 1.2 || p[i].x < -0.2) {
                        p[i].y = -0.2;
                        p[i].x = Math.random() * 1.5;
                    }
                }
            } else if (root.type === "snow") {
                for (var i = 0; i < p.length; i++) {
                    p[i].y += p[i].speed;
                    p[i].swing += 0.03;
                    if (p[i].y > 1.1) {
                        p[i].y = -0.1;
                        p[i].x = Math.random();
                    }
                }
            } else if (root.type === "clouds") {
                for (var i = 0; i < p.length; i++) {
                    p[i].x += p[i].speed;
                    if (p[i].x > 1.5) {
                        p[i].x = -0.5;
                        p[i].y = Math.random() * 0.6;
                    }
                }
            } else if (root.type === "stars") {
                for (var i = 0; i < p.length; i++) {
                    p[i].phase += p[i].speed;
                }
            }

            weatherCanvas.requestPaint();
        }
    }
    Canvas {
        id: weatherCanvas

        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var p = root.particles;
            var color = Config.md3.on_surface;
            var primary = Config.md3.primary;

            if (root.type === "rain") {
                ctx.strokeStyle = Config.alpha(primary, 0.2);
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                for (var i = 0; i < p.length; i++) {
                    var x = p[i].x * width;
                    var y = p[i].y * height;
                    var len = p[i].length * height;
                    ctx.moveTo(x, y);
                    ctx.lineTo(x - len * 0.3, y + len);
                }
                ctx.stroke();
            } else if (root.type === "snow") {
                ctx.fillStyle = Config.alpha(color, 0.3);
                ctx.beginPath();
                for (var i = 0; i < p.length; i++) {
                    var x = (p[i].x * width) + Math.sin(p[i].swing) * 15;
                    var y = p[i].y * height;
                    ctx.moveTo(x, y);
                    ctx.arc(x, y, p[i].r, 0, 2 * Math.PI);
                }
                ctx.fill();
            } else if (root.type === "clouds") {
                for (var i = 0; i < p.length; i++) {
                    ctx.beginPath();
                    var x = p[i].x * width;
                    var y = p[i].y * height;
                    ctx.arc(x, y, p[i].r, 0, 2 * Math.PI);
                    ctx.fillStyle = Config.alpha(color, p[i].alpha);
                    ctx.fill();
                }
            } else if (root.type === "stars") {
                for (var i = 0; i < p.length; i++) {
                    ctx.beginPath();
                    var x = p[i].x * width;
                    var y = p[i].y * height;
                    var alpha = (Math.sin(p[i].phase) + 1) * 0.5 * 0.3; // 0 to 0.3
                    ctx.arc(x, y, p[i].r, 0, 2 * Math.PI);
                    ctx.fillStyle = Config.alpha(primary, alpha);
                    ctx.fill();
                }
            } else if (root.type === "sun") {
                // Sunburst
                ctx.save();
                ctx.translate(width * 0.8, height * 0.2);
                ctx.rotate(root.phase * 0.2);
                ctx.fillStyle = Config.alpha(primary, 0.03);
                for (var i = 0; i < 12; i++) {
                    ctx.beginPath();
                    ctx.moveTo(0, 0);
                    ctx.lineTo(25, 300);
                    ctx.lineTo(-25, 300);
                    ctx.fill();
                    ctx.rotate(Math.PI * 2 / 12);
                }
                ctx.restore();

                // Inner sun
                ctx.beginPath();
                ctx.arc(width * 0.8, height * 0.2, 50, 0, Math.PI * 2);
                ctx.fillStyle = Config.alpha(primary, 0.06);
                ctx.fill();
            }
        }
    }
}
