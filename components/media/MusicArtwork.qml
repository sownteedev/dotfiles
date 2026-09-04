import "../../"
import "../../service"
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Widgets
import Quickshell.Io

Item {
    id: root

    property bool cavaConsumerAcquired: false
    readonly property bool cavaConsumerActive: player !== null && onScreen
    property bool componentReady: false
    readonly property bool onScreen: visible && (Window.window?.visible ?? false)
    property var player: null
    readonly property bool playing: MediaService.playing
    property real vinylSize: Math.max(10, Math.min(root.width, root.height) - (CavaService.available ? visualizerPadding : 0))

    // Calculate sizes to leave room for visualizer
    readonly property real visualizerPadding: 80

    function syncCavaConsumer() {
        if (!componentReady || cavaConsumerActive === cavaConsumerAcquired)
            return;

        if (cavaConsumerActive)
            CavaService.acquire();
        else
            CavaService.release();
        cavaConsumerAcquired = cavaConsumerActive;

        if (cavaConsumerActive)
            visualizerCanvas.requestPaint();
    }

    implicitHeight: 190
    implicitWidth: 250

    Behavior on vinylSize {
        NumberAnimation {
            duration: 350
            easing.type: Easing.OutCubic
        }
    }

    Component.onCompleted: {
        componentReady = true;
        syncCavaConsumer();
    }
    Component.onDestruction: {
        componentReady = false;
        if (cavaConsumerAcquired) {
            CavaService.release();
            cavaConsumerAcquired = false;
        }
    }
    onCavaConsumerActiveChanged: syncCavaConsumer()

    // Visualizer Ring — reads from shared CavaService (no local cava process)
    Item {
        id: visualizerRing

        readonly property int numBars: 48

        anchors.centerIn: parent
        height: width
        opacity: CavaService.levelScale
        visible: CavaService.available
        width: root.vinylSize

        Canvas {
            id: visualizerCanvas

            anchors.centerIn: parent
            antialiasing: true
            height: Math.max(root.width, root.height) + 60
            width: Math.max(root.width, root.height) + 60

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                var rawBars = CavaService.bars;
                var numBars = visualizerRing.numBars;
                if (!rawBars || rawBars.length === 0 || numBars === 0)
                    return;

                var cx = width / 2;
                var cy = height / 2;
                var baseRadius = (visualizerRing.width / 2) + 4;
                var maxAmplitude = (visualizerPadding / 2) + 10;

                var points = [];
                for (var i = 0; i < numBars; i++) {
                    var angle = (i / numBars) * Math.PI * 2 - Math.PI / 2;
                    var rawLevel = (rawBars.length > i) ? Number(rawBars[i] || 0) * CavaService.levelScale : 0;
                    var level = Math.min(1.2, Math.pow(rawLevel, 0.6) * 1.5);
                    var radius = baseRadius + (level * maxAmplitude);
                    points.push({
                        x: cx + Math.cos(angle) * radius,
                        y: cy + Math.sin(angle) * radius
                    });
                }

                if (points.length < 2)
                    return;

                ctx.beginPath();
                ctx.lineWidth = 6;

                var strokeGrad = ctx.createLinearGradient(0, 0, width, height);
                strokeGrad.addColorStop(0, Config.alpha(Config.md3.primary, 0.9));
                strokeGrad.addColorStop(1, Config.alpha(Config.md3.tertiary, 0.9));
                ctx.strokeStyle = strokeGrad;

                ctx.lineCap = "round";
                ctx.lineJoin = "round";

                var pLast = points[numBars - 1];
                var p0 = points[0];
                var startX = (pLast.x + p0.x) / 2;
                var startY = (pLast.y + p0.y) / 2;

                ctx.moveTo(startX, startY);

                for (var i = 0; i < numBars; i++) {
                    var pCurrent = points[i];
                    var pNext = points[(i + 1) % numBars];
                    var midX = (pCurrent.x + pNext.x) / 2;
                    var midY = (pCurrent.y + pNext.y) / 2;

                    ctx.quadraticCurveTo(pCurrent.x, pCurrent.y, midX, midY);
                }

                ctx.closePath();

                var fillGrad = ctx.createLinearGradient(0, 0, width, height);
                fillGrad.addColorStop(0, Config.alpha(Config.md3.primary, 0.15));
                fillGrad.addColorStop(1, Config.alpha(Config.md3.tertiary, 0.15));
                ctx.fillStyle = fillGrad;

                ctx.fill();
                ctx.stroke();
            }

            Connections {
                function onFrameRevisionChanged() {
                    visualizerCanvas.requestPaint();
                }

                enabled: root.cavaConsumerActive
                target: CavaService
            }
        }
    }

    // Outer vinyl ring
    Rectangle {
        anchors.centerIn: parent
        border.color: Config.alpha(Config.md3.on_surface, 0.15)
        border.width: 1
        color: "#111111" // Dark vinyl color
        height: width
        radius: width / 2
        width: root.vinylSize

        // Spin animation
        RotationAnimator on rotation {
            id: spinAnim

            duration: 8000
            from: 0
            loops: Animation.Infinite
            running: root.playing && root.onScreen && !Config.shellLowPowerMode && !Config.shellReducedMotion
            to: 360
        }

        // Grooves effect (subtle concentric circles)
        Rectangle {
            anchors.centerIn: parent
            border.color: "#222222"
            border.width: 1
            color: "transparent"
            height: width
            radius: width / 2
            width: parent.width * 0.85
        }
        Rectangle {
            anchors.centerIn: parent
            border.color: "#1a1a1a"
            border.width: 1
            color: "transparent"
            height: width
            radius: width / 2
            width: parent.width * 0.7
        }

        // The actual artwork acting as the center label
        ClippingRectangle {
            id: artworkClip

            anchors.centerIn: parent
            height: width
            radius: width / 2
            width: parent.width * 0.65 // Artwork covers the inner part of the vinyl

            Image {
                id: artworkImage

                anchors.fill: parent
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectCrop
                source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                sourceSize: Qt.size(Math.max(320, width * 2), Math.max(320, height * 2))
            }
            Rectangle {
                anchors.fill: parent
                color: Config.md3.surface_container
                visible: artworkImage.status !== Image.Ready

                IconImage {
                    anchors.centerIn: parent
                    implicitHeight: implicitWidth
                    implicitWidth: Math.min(48, parent.width * 0.5)
                    opacity: 0.58
                    source: Quickshell.iconPath("audio-x-generic-symbolic")
                }
            }

            // The center hole of the vinyl record
            Rectangle {
                anchors.centerIn: parent
                border.color: Config.alpha(Config.md3.on_surface, 0.2)
                border.width: 1
                color: Config.md3.background // See-through to background
                height: width
                radius: width / 2
                width: parent.width * 0.15
            }
        }
    }
}
