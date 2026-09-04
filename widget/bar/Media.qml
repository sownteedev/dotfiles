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
    readonly property string description: MediaService.artist
    readonly property bool hasMedia: activePlayer !== null && activePlayer.trackTitle && activePlayer.trackTitle !== ""
    readonly property bool idleAnimating: !hasMedia && onScreen && !Config.shellReducedMotion && !Config.shellLowPowerMode
    property real maximumWidth: 350
    readonly property bool onScreen: visible && (Window.window?.visible ?? false)
    readonly property bool playing: MediaService.playing
    readonly property string title: MediaService.title

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

    implicitHeight: 46
    implicitWidth: hasMedia ? Math.max(90, Math.min(350, maximumWidth)) : Math.max(90, Math.min(220, maximumWidth))
    visible: implicitWidth > 0

    Behavior on implicitWidth {
        NumberAnimation {
            id: mediaWidthAnim

            duration: Config.shellReducedMotion ? 0 : 280
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

    RowLayout {
        id: playerContent

        anchors.fill: parent
        enabled: root.hasMedia
        opacity: root.hasMedia ? 1 : 0
        spacing: 10
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Config.shellReducedMotion ? 0 : 180
                easing.type: Easing.OutCubic
            }
        }
        transform: Translate {
            x: root.hasMedia ? 0 : 8

            Behavior on x {
                NumberAnimation {
                    duration: Config.shellReducedMotion ? 0 : 220
                    easing.type: Easing.OutCubic
                }
            }
        }

        Item {
            id: artwork

            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: 46
            Layout.preferredWidth: 46
            scale: artworkMouse.pressed ? 0.9 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            Canvas {
                id: visualizerCanvas

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

                    var points = [];
                    for (var i = 0; i < numBars; i++) {
                        var angle = (i / numBars) * Math.PI * 2 - Math.PI / 2;
                        var level = Number(bars[i] || 0) * CavaService.levelScale;
                        var radius = 16.5;
                        if (level >= 0.01) {
                            var visualLevel = Math.min(1, Math.pow(level, 0.68) * 1.28);
                            radius += 1.5 + visualLevel * 7;
                        }

                        points.push({
                            x: cx + Math.cos(angle) * radius,
                            y: cy + Math.sin(angle) * radius
                        });
                    }

                    if (points.length < 2)
                        return;

                    ctx.beginPath();
                    ctx.lineWidth = 2.5;

                    var strokeGrad = ctx.createLinearGradient(0, 0, width, height);
                    strokeGrad.addColorStop(0, Config.md3.primary);
                    strokeGrad.addColorStop(1, Config.md3.tertiary);
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
                    source: root.activePlayer && root.activePlayer.trackArtUrl ? root.activePlayer.trackArtUrl : ""
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
                visible: root.activePlayer && root.activePlayer.canControl

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
            opacity: 1 - Math.min(0.42, Math.abs(dragOffset) / 150)

            transform: Translate {
                x: metadata.dragOffset
            }

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
                        visible: root.activePlayer && (!root.activePlayer.lengthSupported || Number(root.activePlayer.length || 0) <= 0 || Number(root.activePlayer.length || 0) > 86400)
                        width: liveBadgeText.implicitWidth + 8

                        Text {
                            id: liveBadgeText

                            anchors.centerIn: parent
                            color: Config.md3.on_error
                            font.family: Config.fontName
                            font.pixelSize: 8
                            font.weight: Font.DemiBold
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
    RowLayout {
        id: idleContent

        anchors.fill: parent
        opacity: root.hasMedia ? 0 : 1
        spacing: 10
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Config.shellReducedMotion ? 0 : 160
                easing.type: Easing.OutCubic
            }
        }
        transform: Translate {
            x: root.hasMedia ? -8 : 0

            Behavior on x {
                NumberAnimation {
                    duration: Config.shellReducedMotion ? 0 : 200
                    easing.type: Easing.OutCubic
                }
            }
        }

        Item {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredHeight: 46
            Layout.preferredWidth: 46

            Rectangle {
                id: idleHalo

                anchors.centerIn: parent
                border.color: Config.alpha(Config.md3.primary, 0.3)
                border.width: 1
                color: Config.alpha(Config.md3.primary, 0.075)
                height: 42
                opacity: Config.shellReducedMotion ? 0.55 : 0.32
                radius: 21
                scale: Config.shellReducedMotion ? 1 : 0.88
                width: 42

                SequentialAnimation {
                    alwaysRunToEnd: false
                    loops: Animation.Infinite
                    running: root.idleAnimating

                    ParallelAnimation {
                        ScaleAnimator {
                            duration: Config.animationDuration(900)
                            easing.type: Easing.InOutSine
                            from: 0.88
                            target: idleHalo
                            to: 1.16
                        }
                        OpacityAnimator {
                            duration: Config.animationDuration(900)
                            easing.type: Easing.InOutSine
                            from: 0.32
                            target: idleHalo
                            to: 0.88
                        }
                    }
                    ParallelAnimation {
                        ScaleAnimator {
                            duration: Config.animationDuration(1100)
                            easing.type: Easing.InOutSine
                            from: 1.16
                            target: idleHalo
                            to: 0.88
                        }
                        OpacityAnimator {
                            duration: Config.animationDuration(1100)
                            easing.type: Easing.InOutSine
                            from: 0.88
                            target: idleHalo
                            to: 0.32
                        }
                    }
                }
            }
            Rectangle {
                id: idleDisc

                anchors.centerIn: parent
                color: Config.alpha(Config.md3.primary, 0.16)
                height: 30
                radius: 15
                rotation: root.idleAnimating ? -5 : 0
                scale: root.idleAnimating ? 0.96 : 1
                width: 30

                SequentialAnimation {
                    alwaysRunToEnd: false
                    loops: Animation.Infinite
                    running: root.idleAnimating

                    ParallelAnimation {
                        RotationAnimator {
                            duration: Config.animationDuration(850)
                            easing.type: Easing.InOutSine
                            from: -5
                            target: idleDisc
                            to: 5
                        }
                        ScaleAnimator {
                            duration: Config.animationDuration(850)
                            easing.type: Easing.InOutSine
                            from: 0.96
                            target: idleDisc
                            to: 1.07
                        }
                    }
                    ParallelAnimation {
                        RotationAnimator {
                            duration: Config.animationDuration(850)
                            easing.type: Easing.InOutSine
                            from: 5
                            target: idleDisc
                            to: -5
                        }
                        ScaleAnimator {
                            duration: Config.animationDuration(850)
                            easing.type: Easing.InOutSine
                            from: 1.07
                            target: idleDisc
                            to: 0.96
                        }
                    }
                }
                IconImage {
                    anchors.centerIn: parent
                    height: 17
                    layer.enabled: true
                    source: Quickshell.iconPath("audio-x-generic-symbolic")
                    width: 17

                    layer.effect: ColorOverlay {
                        color: Config.alpha(Config.md3.primary, 0.78)
                    }
                }
            }
        }
        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            spacing: 1

            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 16
                font.weight: Font.DemiBold
                text: qsTr("Nothing playing")
            }
            Text {
                Layout.fillWidth: true
                color: Config.md3.on_surface_variant
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 14
                text: qsTr("Waiting for media")
            }
        }
    }
}
