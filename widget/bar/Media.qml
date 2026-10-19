import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets
import "../../"
import "../../service"

Item {
    id: root

    readonly property var activePlayer: MediaService.activePlayer
    property bool cavaConsumerAcquired: false
    readonly property bool cavaConsumerActive: hasMedia && onScreen
    property bool componentReady: false
    readonly property real contentWidth: Math.max(90, Math.min(350, maximumWidth))
    readonly property string description: displayedMedia?.description ?? ""
    property bool displayEnabled: true
    property var displayedMedia: null
    readonly property bool hasMedia: activePlayer !== null && activePlayer.trackTitle && activePlayer.trackTitle !== ""
    property real leadingSpacing: 0
    readonly property var liveMedia: hasMedia ? {
        "title": activePlayer.trackTitle,
        "description": MediaService.artist,
        "artwork": activePlayer.trackArtUrl || "",
        "playing": MediaService.playing,
        "canControl": activePlayer.canControl,
        "isLive": !activePlayer.lengthSupported || Number(activePlayer.length || 0) <= 0 || Number(activePlayer.length || 0) > 86400
    } : null
    property real maximumWidth: 350
    readonly property bool onScreen: visible && (Window.window?.visible ?? false)
    readonly property bool playing: displayedMedia?.playing ?? false
    property real revealProgress: componentReady && displayEnabled && hasMedia ? 1 : 0
    readonly property string title: displayedMedia?.title ?? ""
    property real trackArtworkOpacity: 1
    property real trackArtworkScale: 1
    property real trackMetadataOffset: 0
    property real trackMetadataOpacity: 1

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

    clip: true
    implicitHeight: 46
    implicitWidth: (contentWidth + leadingSpacing) * revealProgress
    visible: implicitWidth > 0

    Behavior on revealProgress {
        NumberAnimation {
            duration: Config.shellReducedMotion ? 0 : 280
            easing.type: Easing.OutCubic
        }
    }

    Component.onCompleted: {
        if (liveMedia)
            displayedMedia = liveMedia;
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
    onLiveMediaChanged: {
        if (liveMedia)
            displayedMedia = liveMedia;
    }

    Connections {
        function onPostTrackChanged() {
            trackChangeDebounce.restart();
        }

        enabled: !!root.activePlayer
        target: root.activePlayer
    }
    Timer {
        id: trackChangeDebounce

        interval: 16

        onTriggered: trackChangeAnimation.restart()
    }
    SequentialAnimation {
        id: trackChangeAnimation

        ParallelAnimation {
            NumberAnimation {
                duration: Config.animationDuration(90)
                easing.type: Easing.InCubic
                from: 1
                property: "trackArtworkOpacity"
                target: root
                to: 0.08
            }
            NumberAnimation {
                duration: Config.animationDuration(90)
                easing.type: Easing.InCubic
                from: 1
                property: "trackArtworkScale"
                target: root
                to: 0.72
            }
            NumberAnimation {
                duration: Config.animationDuration(80)
                easing.type: Easing.InCubic
                from: 1
                property: "trackMetadataOpacity"
                target: root
                to: 0
            }
            NumberAnimation {
                duration: Config.animationDuration(90)
                easing.type: Easing.InCubic
                from: 0
                property: "trackMetadataOffset"
                target: root
                to: 6
            }
        }
        ParallelAnimation {
            NumberAnimation {
                duration: Config.animationDuration(190)
                easing.type: Easing.OutCubic
                from: 0.08
                property: "trackArtworkOpacity"
                target: root
                to: 1
            }
            NumberAnimation {
                duration: Config.animationDuration(210)
                easing.type: Easing.OutCubic
                from: 0.72
                property: "trackArtworkScale"
                target: root
                to: 1
            }
            NumberAnimation {
                duration: Config.animationDuration(180)
                easing.type: Easing.OutCubic
                from: 0
                property: "trackMetadataOpacity"
                target: root
                to: 1
            }
            NumberAnimation {
                duration: Config.animationDuration(200)
                easing.type: Easing.OutCubic
                from: 6
                property: "trackMetadataOffset"
                target: root
                to: 0
            }
        }
    }
    RowLayout {
        id: playerContent

        enabled: root.hasMedia && root.displayEnabled
        height: root.height
        spacing: 10
        visible: root.revealProgress > 0
        width: root.contentWidth
        x: root.implicitWidth - width

        Item {
            id: artwork

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: 46
            Layout.preferredWidth: 46
            opacity: root.trackArtworkOpacity
            scale: (artworkMouse.pressed ? 0.9 : 1) * root.trackArtworkScale

            Behavior on scale {
                enabled: !trackChangeAnimation.running

                NumberAnimation {
                    duration: Config.animationDuration(150)
                    easing.type: Easing.OutCubic
                }
            }

            Canvas {
                id: visualizerCanvas

                property var pointX: []
                property var pointY: []

                anchors.centerIn: parent
                antialiasing: true
                height: parent.height + 16
                opacity: CavaService.levelScale
                visible: CavaService.available
                width: parent.width + 16

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    var bars = CavaService.bars;
                    var numBars = bars.length;
                    if (!bars || numBars === 0)
                        return;

                    var cx = width / 2;
                    var cy = height / 2;

                    if (pointX.length !== numBars) {
                        pointX = new Array(numBars);
                        pointY = new Array(numBars);
                    }
                    for (var i = 0; i < numBars; i++) {
                        var angle = (i / numBars) * Math.PI * 2 - Math.PI / 2;
                        var level = Number(bars[i] || 0) * CavaService.levelScale;
                        var radius = 16.5;
                        if (level >= 0.01) {
                            var visualLevel = Math.min(1, Math.pow(level, 0.68) * 1.28);
                            radius += 1.5 + visualLevel * 7;
                        }

                        pointX[i] = cx + Math.cos(angle) * radius;
                        pointY[i] = cy + Math.sin(angle) * radius;
                    }

                    if (pointX.length < 2)
                        return;

                    ctx.beginPath();
                    ctx.lineWidth = 2.5;

                    var strokeGrad = ctx.createLinearGradient(0, 0, width, height);
                    strokeGrad.addColorStop(0, Config.md3.primary);
                    strokeGrad.addColorStop(1, Config.md3.tertiary);
                    ctx.strokeStyle = strokeGrad;

                    ctx.lineCap = "round";
                    ctx.lineJoin = "round";

                    var startX = (pointX[numBars - 1] + pointX[0]) / 2;
                    var startY = (pointY[numBars - 1] + pointY[0]) / 2;

                    ctx.moveTo(startX, startY);

                    for (var i = 0; i < numBars; i++) {
                        var nextIndex = (i + 1) % numBars;
                        var midX = (pointX[i] + pointX[nextIndex]) / 2;
                        var midY = (pointY[i] + pointY[nextIndex]) / 2;

                        ctx.quadraticCurveTo(pointX[i], pointY[i], midX, midY);
                    }

                    ctx.closePath();

                    var fillGrad = ctx.createLinearGradient(0, 0, width, height);
                    fillGrad.addColorStop(0, Config.alpha(Config.md3.primary, 0.2));
                    fillGrad.addColorStop(1, Config.alpha(Config.md3.tertiary, 0.2));
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
            ClippingRectangle {
                id: cover

                anchors.centerIn: parent
                height: 30
                radius: width / 2
                width: 30

                Image {
                    id: coverSource

                    anchors.fill: parent
                    asynchronous: true
                    cache: false
                    fillMode: Image.PreserveAspectCrop
                    source: root.displayedMedia?.artwork ?? ""
                    sourceSize: Qt.size(60, 60)
                }
            }
            Rectangle {
                anchors.fill: cover
                color: Config.md3.surface_container
                radius: width / 2
                visible: coverSource.status !== Image.Ready

                IconImage {
                    anchors.centerIn: parent
                    implicitHeight: 17
                    implicitWidth: 17
                    source: Quickshell.iconPath("audio-x-generic-symbolic")
                }
            }
            Rectangle {
                anchors.fill: cover
                color: Config.alpha(Config.md3.background, 0.88)
                opacity: artworkMouse.containsMouse ? 1 : 0
                radius: width / 2
                visible: root.displayedMedia?.canControl ?? false

                Behavior on opacity {
                    NumberAnimation {
                        duration: 130
                        easing.type: Easing.OutCubic
                    }
                }

                Item {
                    id: playbackIcon

                    property bool playing: root.playing

                    anchors.centerIn: parent
                    height: 16
                    width: 16

                    onPlayingChanged: iconTransition.restart()

                    Rectangle {
                        color: Config.md3.on_surface
                        height: 12
                        radius: 0.8
                        visible: playbackIcon.playing
                        width: 3.5
                        x: 3
                        y: 2
                    }
                    Rectangle {
                        color: Config.md3.on_surface
                        height: 12
                        radius: 0.8
                        visible: playbackIcon.playing
                        width: 3.5
                        x: 9.5
                        y: 2
                    }
                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 1
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        text: "▶"
                        visible: !playbackIcon.playing
                    }
                    SequentialAnimation {
                        id: iconTransition

                        ParallelAnimation {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutBack
                                from: 0.72
                                property: "scale"
                                target: playbackIcon
                                to: 1
                            }
                            NumberAnimation {
                                duration: 130
                                easing.type: Easing.OutCubic
                                from: 0.35
                                property: "opacity"
                                target: playbackIcon
                                to: 1
                            }
                        }
                    }
                }
            }
            MouseArea {
                id: artworkMouse

                anchors.fill: cover
                cursorShape: root.activePlayer && root.activePlayer.canControl ? Qt.PointingHandCursor : Qt.ArrowCursor
                hoverEnabled: true
                z: 10

                onClicked: {
                    if (root.activePlayer && root.activePlayer.canControl)
                        root.activePlayer.togglePlaying();
                }
            }
        }
        Item {
            id: metadata

            property real dragOffset: 0

            Layout.fillHeight: true
            Layout.fillWidth: true
            opacity: (1 - Math.min(0.42, Math.abs(dragOffset) / 150)) * root.trackMetadataOpacity

            transform: [
                Translate {
                    x: metadata.dragOffset
                },
                Translate {
                    y: root.trackMetadataOffset
                }
            ]

            NumberAnimation {
                id: metadataReturnAnimation

                duration: 190
                easing.type: Easing.OutCubic
                property: "dragOffset"
                target: metadata
                to: 0
            }
            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    color: Config.md3.on_surface
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    maximumLineCount: 1
                    text: root.title
                }
                Row {
                    id: artistLine

                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Config.md3.on_surface_variant
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        maximumLineCount: 1
                        text: root.description
                        width: Math.min(implicitWidth, Math.max(0, artistLine.width - (liveBadge.visible ? liveBadge.width + artistLine.spacing : 0)))
                    }
                    Rectangle {
                        id: liveBadge

                        anchors.verticalCenter: parent.verticalCenter
                        color: Config.md3.error
                        height: 14
                        radius: 4
                        visible: root.displayedMedia?.isLive ?? false
                        width: liveBadgeText.implicitWidth + 8

                        Text {
                            id: liveBadgeText

                            anchors.centerIn: parent
                            color: Config.md3.on_error
                            font.family: Config.fontName
                            font.pixelSize: 8
                            font.weight: Font.Bold
                            text: "LIVE"
                        }
                    }
                }
            }
            MouseArea {
                id: metadataSwipe

                property real pressPosition: 0

                anchors.fill: parent
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                hoverEnabled: true
                preventStealing: true

                onCanceled: metadataReturnAnimation.restart()
                onPositionChanged: mouse => {
                    if (!pressed)
                        return;
                    var currentPosition = mapToItem(root, mouse.x, mouse.y).x;
                    metadata.dragOffset = Math.max(-80, Math.min(80, currentPosition - pressPosition));
                }
                onPressed: mouse => {
                    metadataReturnAnimation.stop();
                    pressPosition = mapToItem(root, mouse.x, mouse.y).x;
                }
                onReleased: {
                    var distance = metadata.dragOffset;
                    if (distance <= -42 && root.activePlayer && root.activePlayer.canGoNext)
                        root.activePlayer.next();
                    else if (distance >= 42 && root.activePlayer && root.activePlayer.canGoPrevious)
                        root.activePlayer.previous();
                    metadataReturnAnimation.restart();
                }
            }
        }
    }
}
