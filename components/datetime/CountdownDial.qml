import QtQuick
import "../../"
import "../"

Item {
    id: root

    readonly property color accentColor: completed ? Config.md3.secondary : Config.md3.primary
    property bool completed: false
    property bool hasStarted: false
    property real progress: 0
    property real remainingMilliseconds: 0
    property bool running: false
    readonly property string stateLabel: completed ? "Finished" : (running ? "Counting down" : (hasStarted ? "Paused" : "Ready"))
    property real totalMilliseconds: 0

    function formatTime(milliseconds) {
        var totalSeconds = Math.ceil(milliseconds / 1000);
        var hours = Math.floor(totalSeconds / 3600);
        var minutes = Math.floor((totalSeconds % 3600) / 60);
        var seconds = totalSeconds % 60;
        if (hours > 0) {
            return String(hours).padStart(2, "0") + ":" + String(minutes).padStart(2, "0") + ":" + String(seconds).padStart(2, "0");
        }
        return String(minutes).padStart(2, "0") + ":" + String(seconds).padStart(2, "0");
    }

    AnimatedPulse {
        anchors.fill: parent
        color: root.accentColor
        running: root.running
    }
    Canvas {
        id: ringCanvas

        property bool isCompleted: root.completed
        property real ringProgress: root.progress
        property color stateColor: root.accentColor

        anchors.fill: parent
        antialiasing: true

        Behavior on ringProgress {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutCubic
            }
        }

        onHeightChanged: requestPaint()
        onIsCompletedChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var centerX = width / 2;
            var centerY = height / 2;
            var lineWidth = 10;
            var radius = Math.min(width, height) / 2 - 24;
            var startAngle = -Math.PI / 2;
            var endAngle = startAngle + Math.PI * 2 * ringProgress;
            var ringColor = stateColor;

            ctx.beginPath();
            ctx.arc(centerX, centerY, radius, 0, Math.PI * 2);
            ctx.lineWidth = lineWidth;
            ctx.lineCap = "round";
            ctx.strokeStyle = Config.alpha(Config.md3.on_surface, 0.075);
            ctx.stroke();

            if (ringProgress > 0) {
                ctx.beginPath();
                ctx.arc(centerX, centerY, radius, startAngle, endAngle);
                ctx.lineWidth = 20;
                ctx.lineCap = "round";
                ctx.strokeStyle = Config.alpha(ringColor, 0.13);
                ctx.stroke();

                ctx.beginPath();
                ctx.arc(centerX, centerY, radius, startAngle, endAngle);
                ctx.lineWidth = lineWidth;
                ctx.lineCap = "round";
                ctx.strokeStyle = ringColor;
                ctx.stroke();

                var dotX = centerX + Math.cos(endAngle) * radius;
                var dotY = centerY + Math.sin(endAngle) * radius;
                ctx.beginPath();
                ctx.arc(dotX, dotY, 4, 0, Math.PI * 2);
                ctx.fillStyle = ringColor;
                ctx.fill();
            }
        }
        onRingProgressChanged: requestPaint()
        onStateColorChanged: requestPaint()
        onWidthChanged: requestPaint()
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 36
        border.color: Config.alpha(root.accentColor, 0.11)
        border.width: 1
        color: Config.alpha(Config.md3.surface_container, 0.48)
        radius: width / 2

        Rectangle {
            anchors.fill: parent
            anchors.margins: 9
            border.color: Config.alpha(Config.md3.on_surface, 0.035)
            border.width: 1
            color: "transparent"
            radius: width / 2
        }
        Column {
            anchors.centerIn: parent
            spacing: 13

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: Config.alpha(Config.md3.on_surface, 0.48)
                font.capitalization: Font.AllUppercase
                font.family: Config.fontName
                font.letterSpacing: 2.2
                font.pixelSize: 11
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
                text: "Countdown"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: root.completed ? root.accentColor : Config.md3.on_surface
                font.family: Config.fontName
                font.features: {
                    "tnum": 1
                }
                font.letterSpacing: 3
                font.pixelSize: root.totalMilliseconds >= 3600000 ? 50 : 62
                font.weight: Font.ExtraBold
                renderType: Text.NativeRendering
                text: root.formatTime(root.remainingMilliseconds)
            }
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                border.color: Config.alpha(root.accentColor, 0.2)
                border.width: 1
                color: Config.alpha(root.accentColor, 0.105)
                height: 30
                radius: 15
                width: statusRow.implicitWidth + 24

                Row {
                    id: statusRow

                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.accentColor
                        height: 7
                        radius: 4
                        width: 7
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.accentColor
                        font.family: Config.fontName
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                        text: root.stateLabel
                    }
                }
            }
        }
    }
}
