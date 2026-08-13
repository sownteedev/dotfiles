pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "../../"

Item {
    id: root

    readonly property color accentColor: completed ? Config.md3.secondary : Config.md3.primary
    property real animatedProgress: completed ? 1 : progress
    property bool completed: false
    property bool hasStarted: false
    property real progress: 0
    property real remainingMilliseconds: 0
    readonly property real ringRadius: Math.max(1, Math.min(width, height) / 2 - 18 * visualScale)
    readonly property real ringWidth: Math.max(6, Math.round(8 * visualScale))
    property bool running: false
    readonly property string stateLabel: completed ? qsTr("Finished") : running ? qsTr("Counting down") : hasStarted ? qsTr("Paused") : qsTr("Ready")
    readonly property real timeContentWidth: Math.max(110, Math.min(width, height) - 82 * visualScale)
    property real totalMilliseconds: 0
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

    Accessible.name: qsTr("%1, %2").arg(formatTime(remainingMilliseconds)).arg(stateLabel)
    Accessible.role: Accessible.StaticText

    Behavior on animatedProgress {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: Math.max(8, Math.round(11 * root.visualScale))
        border.color: Config.alpha(root.accentColor, 0.12)
        border.width: 1
        color: Config.alpha(Config.md3.surface_container, 0.34)
        radius: width / 2

        Rectangle {
            anchors.fill: parent
            anchors.margins: Math.max(8, Math.round(12 * root.visualScale))
            border.color: Config.alpha(Config.md3.on_surface, 0.035)
            border.width: 1
            color: Config.alpha(Config.md3.surface, 0.12)
            radius: width / 2
        }
    }
    Repeater {
        model: 12

        delegate: Rectangle {
            id: tick

            required property int index

            readonly property bool major: index % 3 === 0

            Accessible.ignored: true
            color: Config.alpha(root.accentColor, major ? 0.42 : 0.18)
            height: Math.max(3, Math.round((major ? 7 : 4) * root.visualScale))
            radius: width / 2
            width: Math.max(1, Math.round((major ? 2 : 1.4) * root.visualScale))
            x: root.width / 2 - width / 2
            y: root.height / 2 - root.ringRadius - height / 2

            transform: Rotation {
                angle: tick.index * 30
                origin.x: tick.width / 2
                origin.y: root.height / 2 - tick.y
            }
        }
    }
    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            strokeColor: Config.alpha(Config.md3.on_surface, 0.085)
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
            strokeColor: Config.alpha(root.accentColor, 0.13)
            strokeWidth: root.ringWidth * 2.35

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.ringRadius
                radiusY: root.ringRadius
                startAngle: -90
                sweepAngle: 360 * root.animatedProgress
            }
        }
        ShapePath {
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            strokeColor: root.accentColor
            strokeWidth: root.ringWidth

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.ringRadius
                radiusY: root.ringRadius
                startAngle: -90
                sweepAngle: 360 * root.animatedProgress
            }
        }
    }
    Rectangle {
        readonly property real angle: -Math.PI / 2 + Math.PI * 2 * root.animatedProgress

        Accessible.ignored: true
        color: root.accentColor
        height: Math.max(8, Math.round(10 * root.visualScale))
        radius: width / 2
        visible: root.animatedProgress > 0.002 && root.animatedProgress < 0.998
        width: height
        x: root.width / 2 + Math.cos(angle) * root.ringRadius - width / 2
        y: root.height / 2 + Math.sin(angle) * root.ringRadius - height / 2

        Rectangle {
            anchors.centerIn: parent
            color: Config.md3.on_primary
            height: Math.max(2, Math.round(3 * root.visualScale))
            radius: width / 2
            width: height
        }
    }
    Column {
        anchors.centerIn: parent
        spacing: Math.max(7, Math.round(10 * root.visualScale))

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Config.alpha(Config.md3.on_surface, 0.5)
            font.capitalization: Font.AllUppercase
            font.family: Config.fontName
            font.letterSpacing: 2 * root.visualScale
            font.pixelSize: Math.max(9, Math.round(10 * root.visualScale))
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
            text: root.completed ? qsTr("Time's up") : qsTr("Remaining")
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.completed ? root.accentColor : Config.md3.on_surface
            font.family: Config.fontName
            font.features: {
                "tnum": 1
            }
            font.letterSpacing: 1.1 * root.visualScale
            font.pixelSize: root.totalMilliseconds >= 3600000 ? 43 : 54
            font.weight: Font.ExtraBold
            fontSizeMode: Text.Fit
            height: Math.max(42, Math.round(62 * root.visualScale))
            horizontalAlignment: Text.AlignHCenter
            minimumPixelSize: root.totalMilliseconds >= 3600000 ? 20 : 26
            renderType: Text.NativeRendering
            text: root.formatTime(root.remainingMilliseconds)
            verticalAlignment: Text.AlignVCenter
            width: root.timeContentWidth
            wrapMode: Text.NoWrap
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            border.color: Config.alpha(root.accentColor, 0.18)
            border.width: 1
            color: Config.alpha(root.accentColor, 0.085)
            height: Math.max(25, Math.round(28 * root.visualScale))
            radius: height / 2
            width: statusRow.implicitWidth + Math.round(20 * root.visualScale)

            Row {
                id: statusRow

                anchors.centerIn: parent
                spacing: Math.max(6, Math.round(7 * root.visualScale))

                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    height: Math.max(7, Math.round(8 * root.visualScale))
                    width: height

                    Rectangle {
                        anchors.centerIn: parent
                        color: root.accentColor
                        height: parent.height
                        radius: width / 2
                        width: parent.width
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        color: "transparent"
                        border.color: root.accentColor
                        border.width: 1
                        height: parent.height
                        radius: width / 2
                        visible: root.running
                        width: parent.width

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: root.running

                            OpacityAnimator {
                                duration: 520
                                from: 0.7
                                to: 0.08
                            }
                            OpacityAnimator {
                                duration: 520
                                from: 0.08
                                to: 0.7
                            }
                        }
                        SequentialAnimation on scale {
                            loops: Animation.Infinite
                            running: root.running

                            ScaleAnimator {
                                duration: 520
                                from: 1
                                to: 1.8
                            }
                            ScaleAnimator {
                                duration: 520
                                from: 1.8
                                to: 1
                            }
                        }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    color: root.accentColor
                    font.family: Config.fontName
                    font.pixelSize: Math.max(10, Math.round(12 * root.visualScale))
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                    text: root.stateLabel
                }
            }
        }
    }
}
