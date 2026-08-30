pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "../../"

Item {
    id: root

    readonly property color accentColor: completed ? Config.md3.secondary : Config.md3.primary
    property real animatedProgress: 0
    property bool completed: false
    property bool hasStarted: false
    readonly property bool idle: !preparing && !running && !hasStarted && !completed
    property real preparationProgress: 0
    property bool preparing: false
    property real progress: 0
    readonly property color progressColor: preparing ? Config.md3.on_surface : accentColor
    property real remainingMilliseconds: 0
    readonly property real ringRadius: Math.max(1, Math.min(width, height) / 2 - 18 * visualScale)
    readonly property real ringWidth: Math.max(5, Math.round(7 * visualScale))
    property bool running: false
    readonly property string stateLabel: completed ? qsTr("Finished") : preparing ? qsTr("Starting") : running ? qsTr("Counting down") : hasStarted ? qsTr("Paused") : qsTr("Ready")
    readonly property real timeContentWidth: Math.max(110, Math.min(width, height) - 82 * visualScale)
    property real totalMilliseconds: 0
    readonly property real visibleProgress: preparing ? preparationProgress : idle ? 0 : animatedProgress
    readonly property real visualScale: Responsive.clamp(Math.min(width, height) / 280, 0.72, 1)

    function formatTime(milliseconds) {
        var totalSeconds = Math.ceil(milliseconds / 1000);
        var hours = Math.floor(totalSeconds / 3600);
        var minutes = Math.floor((totalSeconds % 3600) / 60);
        var seconds = totalSeconds % 60;
        if (hours > 0)
            return String(hours).padStart(2, "0") + ":" + String(minutes).padStart(2, "0") + ":" + String(seconds).padStart(2, "0");
        return String(minutes).padStart(2, "0") + ":" + String(seconds).padStart(2, "0");
    }
    function syncAnimatedProgress(continueRunning) {
        progressAnimation.stop();
        animatedProgress = completed ? 1 : Math.max(0, Math.min(1, progress));
        if (!continueRunning || remainingMilliseconds <= 0 || totalMilliseconds <= 0)
            return;

        progressAnimation.from = animatedProgress;
        progressAnimation.to = 0;
        progressAnimation.duration = Math.max(1, Math.round(remainingMilliseconds));
        progressAnimation.restart();
    }

    Accessible.name: qsTr("%1, %2").arg(formatTime(remainingMilliseconds)).arg(stateLabel)
    Accessible.role: Accessible.StaticText

    Component.onCompleted: syncAnimatedProgress(running)
    onCompletedChanged: syncAnimatedProgress(running)
    onProgressChanged: {
        if (!running) {
            syncAnimatedProgress(false);
            return;
        }

        var visualRemaining = animatedProgress * Math.max(1, totalMilliseconds);
        if (Math.abs(visualRemaining - remainingMilliseconds) > 800)
            syncAnimatedProgress(true);
    }
    onRunningChanged: syncAnimatedProgress(running)
    onTotalMillisecondsChanged: {
        if (!running)
            syncAnimatedProgress(false);
    }

    NumberAnimation {
        id: progressAnimation

        easing.type: Easing.Linear
        property: "animatedProgress"
        target: root
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.max(7, Math.round(9 * root.visualScale))
        border.color: Config.alpha(Config.md3.on_surface, root.preparing ? 0.16 : 0.1)
        border.width: 1
        color: Config.alpha(Config.md3.surface_container, 0.58)
        radius: width / 2

        Rectangle {
            anchors.fill: parent
            anchors.margins: Math.max(7, Math.round(10 * root.visualScale))
            border.color: Config.alpha(Config.md3.on_surface, 0.045)
            border.width: 1
            color: Config.alpha(Config.md3.surface, 0.28)
            radius: width / 2
        }
    }
    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            strokeColor: Config.alpha(Config.md3.on_surface, 0.11)
            strokeWidth: root.ringWidth

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.ringRadius
                radiusY: root.ringRadius
                startAngle: -90
                sweepAngle: 360
            }
        }
        ShapePath {
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            strokeColor: Config.alpha(root.progressColor, root.visibleProgress > 0 ? 0.13 : 0)
            strokeWidth: root.ringWidth * 2.2

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.ringRadius
                radiusY: root.ringRadius
                startAngle: -90
                sweepAngle: 360 * root.visibleProgress
            }
        }
        ShapePath {
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            strokeColor: root.progressColor
            strokeWidth: root.ringWidth

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.ringRadius
                radiusY: root.ringRadius
                startAngle: -90
                sweepAngle: 360 * root.visibleProgress
            }
        }
    }
    Rectangle {
        readonly property real angle: -Math.PI / 2 + Math.PI * 2 * root.visibleProgress

        Accessible.ignored: true
        color: root.progressColor
        height: Math.max(8, Math.round(10 * root.visualScale))
        radius: width / 2
        visible: root.visibleProgress > 0.002 && root.visibleProgress < 0.998
        width: height
        x: root.width / 2 + Math.cos(angle) * root.ringRadius - width / 2
        y: root.height / 2 + Math.sin(angle) * root.ringRadius - height / 2

        Rectangle {
            anchors.centerIn: parent
            color: Config.md3.surface
            height: Math.max(2, Math.round(3 * root.visualScale))
            radius: width / 2
            width: height
        }
    }
    Column {
        anchors.centerIn: parent
        spacing: Math.max(4, Math.round(6 * root.visualScale))

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Config.alpha(Config.md3.on_surface, 0.5)
            font.capitalization: Font.AllUppercase
            font.family: Config.fontName
            font.letterSpacing: 2 * root.visualScale
            font.pixelSize: Math.max(9, Math.round(10 * root.visualScale))
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
            text: root.completed ? qsTr("Time's up") : root.preparing ? qsTr("Starting") : root.idle ? qsTr("Ready") : qsTr("Remaining")
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.completed ? root.accentColor : Config.md3.on_surface
            font.family: Config.fontName
            font.features: {
                "tnum": 1
            }
            font.letterSpacing: 1.1 * root.visualScale
            font.pixelSize: root.totalMilliseconds >= 3600000 ? 46 : 58
            font.weight: Font.ExtraBold
            fontSizeMode: Text.Fit
            height: Math.max(46, Math.round(68 * root.visualScale))
            horizontalAlignment: Text.AlignHCenter
            minimumPixelSize: root.totalMilliseconds >= 3600000 ? 20 : 26
            renderType: Text.NativeRendering
            text: root.formatTime(root.remainingMilliseconds)
            verticalAlignment: Text.AlignVCenter
            width: root.timeContentWidth
            wrapMode: Text.NoWrap
        }
    }
}
