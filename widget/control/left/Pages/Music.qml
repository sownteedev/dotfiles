import "../../../../"
import "../../../../components"
import "../../../../service"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../../../../components/common"

Item {
    id: root

    // Scale the artwork from the viewport; compact panels can scroll once the
    // controls reach their minimum usable size.
    readonly property real artworkSize: Math.max(96, Math.min(280, playerArea.height - 370))
    property bool isSwipingOut: false
    readonly property bool mediaMuted: !mediaStream || !mediaStream.audio || mediaStream.audio.muted
    readonly property var mediaStream: findMediaStream()
    readonly property real mediaVolume: {
        if (!mediaStream || !mediaStream.audio)
            return 0;
        var volumes = mediaStream.audio.volumes;
        if (!volumes || volumes.length === 0)
            return Math.max(0, Math.min(1, mediaStream.audio.volume));

        var maximum = 0;
        for (var i = 0; i < volumes.length; ++i)
            maximum = Math.max(maximum, Number(volumes[i]) || 0);
        return Math.max(0, Math.min(1, maximum));
    }
    readonly property string mediaVolumeIcon: mediaMuted || mediaVolume <= 0 ? "audio-volume-muted-symbolic" : mediaVolume < 0.34 ? "audio-volume-low-symbolic" : mediaVolume < 0.67 ? "audio-volume-medium-symbolic" : "audio-volume-high-symbolic"
    readonly property var player: MediaService.activePlayer
    property int swipeDirection: 1
    property real swipeOffset: 0
    property bool swipeTimerRunning: swipeActionTimer.running

    function findMediaStream() {
        if (!player || !Pipewire.ready || !Pipewire.nodes || !Pipewire.nodes.values)
            return null;

        var playerIdentity = normalizeMediaName(player.identity);
        var playerDesktop = normalizeMediaName(player.desktopEntry);
        var playerBus = normalizeMediaName(player.dbusName);
        var playerHints = playerIdentity + " " + playerDesktop + " " + playerBus;
        var playerIsChromium = playerHints.indexOf("chromium") !== -1 || playerHints.indexOf("googlechrome") !== -1 || playerHints.indexOf("chrome") !== -1 || playerHints.indexOf("brave") !== -1 || playerHints.indexOf("vivaldi") !== -1 || playerHints.indexOf("edge") !== -1;
        var bestMatch = null;
        var bestScore = 0;
        var fallbackMatch = null;

        for (var i = 0; i < Pipewire.nodes.values.length; ++i) {
            var node = Pipewire.nodes.values[i];
            if (!node || !node.isStream || !AudioService.isPlaybackStream(node))
                continue;

            var properties = node.properties || {};
            var appName = normalizeMediaName(properties["application.name"] || node.name);
            var appBinary = normalizeMediaName(properties["application.process.binary"]);
            var appIcon = normalizeMediaName(properties["application.icon-name"]);
            var nodeHints = appName + " " + appBinary + " " + appIcon;
            var score = 0;

            if (!fallbackMatch && nodeHints.indexOf("wallpaper") === -1 && nodeHints.indexOf("cava") === -1 && nodeHints.indexOf("quickshell") === -1)
                fallbackMatch = node;

            if (playerDesktop && (appBinary === playerDesktop || appIcon === playerDesktop || appName === playerDesktop))
                score = 300;
            else if (playerIdentity && appName === playerIdentity)
                score = 280;
            else if (playerDesktop && nodeHints.indexOf(playerDesktop) !== -1)
                score = 220;
            else if (playerIdentity && nodeHints.indexOf(playerIdentity) !== -1)
                score = 200;
            else if (appBinary && playerHints.indexOf(appBinary) !== -1)
                score = 180;

            var nodeIsChromium = nodeHints.indexOf("chromium") !== -1 || nodeHints.indexOf("googlechrome") !== -1 || appBinary === "chrome" || nodeHints.indexOf("brave") !== -1 || nodeHints.indexOf("vivaldi") !== -1 || nodeHints.indexOf("edge") !== -1;
            if (score === 0 && playerIsChromium && nodeIsChromium)
                score = 120;

            if (score > bestScore) {
                bestScore = score;
                bestMatch = node;
            }
        }
        return bestMatch || fallbackMatch;
    }
    function normalizeMediaName(value) {
        return String(value || "").toLowerCase().replace(/[^a-z0-9]+/g, "");
    }
    function setMediaVolume(value) {
        var stream = mediaStream;
        if (!stream || !stream.audio)
            return;

        var target = Math.max(0, Math.min(1, value));
        var volumes = stream.audio.volumes;
        if (volumes && volumes.length > 0) {
            var maximum = 0;
            for (var i = 0; i < volumes.length; ++i)
                maximum = Math.max(maximum, Number(volumes[i]) || 0);

            var updatedVolumes = [];
            for (var channel = 0; channel < volumes.length; ++channel)
                updatedVolumes.push(maximum > 0 ? volumes[channel] * target / maximum : target);
            stream.audio.volumes = updatedVolumes;
        } else {
            stream.audio.volume = target;
        }
        if (target > 0)
            stream.audio.muted = false;
    }

    anchors.fill: parent

    Behavior on swipeOffset {
        enabled: !musicDrag.active && !root.isSwipingOut

        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    PwObjectTracker {
        objects: Pipewire.nodes && Pipewire.nodes.values ? Pipewire.nodes.values : []
    }
    Timer {
        id: swipeActionTimer

        interval: 150

        onTriggered: {
            root.isSwipingOut = true;
            if (root.swipeDirection === 1) {
                MediaService.selectPrevPlayer();
            } else {
                MediaService.selectNextPlayer();
            }
            root.swipeOffset = -root.swipeDirection * root.width;
            swipeInTimer.start();
        }
    }
    Timer {
        id: swipeInTimer

        interval: 20

        onTriggered: {
            root.isSwipingOut = false;
            root.swipeOffset = 0;
        }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Flickable {
            id: playerArea

            Layout.fillHeight: true
            Layout.fillWidth: true
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            contentHeight: root.player ? Math.max(height, playerContent.implicitHeight + 40) : Math.max(height, emptyState.implicitHeight + 36)
            contentWidth: width
            flickableDirection: Flickable.VerticalFlick
            interactive: contentHeight > height
            maximumFlickVelocity: 1800

            ColumnLayout {
                id: playerContent

                anchors.fill: parent
                anchors.margins: 20
                spacing: 15
                visible: !!root.player

                // Center: Vinyl Artwork with Swipe Gesture
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: root.artworkSize
                    Layout.preferredWidth: root.artworkSize

                    transform: Translate {
                        x: root.swipeOffset
                    }

                    MusicArtwork {
                        anchors.fill: parent
                        player: root.player
                    }
                    DragHandler {
                        id: musicDrag

                        target: null
                        xAxis.enabled: true
                        yAxis.enabled: false

                        onActiveChanged: {
                            if (!active && !root.isSwipingOut && !root.swipeTimerRunning) {
                                if (root.swipeOffset < -50) {
                                    root.swipeOffset = -root.width;
                                    root.swipeDirection = -1;
                                    swipeActionTimer.start();
                                } else if (root.swipeOffset > 50) {
                                    root.swipeOffset = root.width;
                                    root.swipeDirection = 1;
                                    swipeActionTimer.start();
                                } else {
                                    root.swipeOffset = 0;
                                }
                            }
                        }
                        onTranslationChanged: {
                            if (!root.isSwipingOut) {
                                root.swipeOffset = translation.x;
                            }
                        }
                    }
                }

                // Title and Artist
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        horizontalAlignment: Text.AlignHCenter
                        maximumLineCount: 1
                        renderType: Text.NativeRendering
                        text: MediaService.title
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.primary
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        maximumLineCount: 1
                        renderType: Text.NativeRendering
                        text: MediaService.artist
                    }
                }

                // Progress Bar
                MusicProgress {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    player: root.player
                }

                // Playback Controls
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 15

                    // Shuffle
                    Rectangle {
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: 36
                        color: shuffleMouse.containsMouse && root.player && root.player.canControl && root.player.shuffleSupported ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent"
                        opacity: root.player && root.player.canControl && root.player.shuffleSupported ? 1 : 0.3
                        radius: 18

                        IconImage {
                            anchors.centerIn: parent
                            implicitHeight: 18
                            implicitWidth: 18
                            layer.enabled: true
                            source: Quickshell.iconPath("media-playlist-shuffle-symbolic", "media-playlist-shuffle")

                            layer.effect: ColorOverlay {
                                color: root.player && root.player.shuffle ? Config.md3.primary : Config.md3.on_surface
                            }
                        }
                        MouseArea {
                            id: shuffleMouse

                            anchors.fill: parent
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: !!root.player && root.player.canControl && root.player.shuffleSupported
                            hoverEnabled: true

                            onClicked: root.player.shuffle = !root.player.shuffle
                        }
                    }

                    // Prev
                    Rectangle {
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: 36
                        color: prevMouse.containsMouse && root.player && root.player.canGoPrevious ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent"
                        opacity: root.player && root.player.canGoPrevious ? 1 : 0.3
                        radius: 18

                        IconImage {
                            anchors.centerIn: parent
                            implicitHeight: 18
                            implicitWidth: 18
                            layer.enabled: true
                            source: Quickshell.iconPath("media-skip-backward-symbolic", "media-skip-backward")

                            layer.effect: ColorOverlay {
                                color: Config.md3.on_surface
                            }
                        }
                        MouseArea {
                            id: prevMouse

                            anchors.fill: parent
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: !!root.player && root.player.canGoPrevious
                            hoverEnabled: true

                            onClicked: root.player.previous()
                        }
                    }

                    // Play/Pause
                    Rectangle {
                        Layout.preferredHeight: 48
                        Layout.preferredWidth: 48
                        color: root.player && MediaService.playing ? Config.md3.primary : Config.alpha(Config.md3.on_surface, 0.12)
                        radius: 24

                        IconImage {
                            anchors.centerIn: parent
                            implicitHeight: 22
                            implicitWidth: 22
                            layer.enabled: true
                            source: Quickshell.iconPath(root.player && MediaService.playing ? "media-playback-pause-symbolic" : "media-playback-start-symbolic", "media-playback-start")

                            layer.effect: ColorOverlay {
                                color: root.player && MediaService.playing ? Config.md3.on_primary : Config.md3.on_surface
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: !!root.player && root.player.canTogglePlaying

                            onClicked: root.player.togglePlaying()
                        }
                    }

                    // Next
                    Rectangle {
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: 36
                        color: nextMouse.containsMouse && root.player && root.player.canGoNext ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent"
                        opacity: root.player && root.player.canGoNext ? 1 : 0.3
                        radius: 18

                        IconImage {
                            anchors.centerIn: parent
                            implicitHeight: 18
                            implicitWidth: 18
                            layer.enabled: true
                            source: Quickshell.iconPath("media-skip-forward-symbolic", "media-skip-forward")

                            layer.effect: ColorOverlay {
                                color: Config.md3.on_surface
                            }
                        }
                        MouseArea {
                            id: nextMouse

                            anchors.fill: parent
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: !!root.player && root.player.canGoNext
                            hoverEnabled: true

                            onClicked: root.player.next()
                        }
                    }

                    // Loop
                    Rectangle {
                        Layout.preferredHeight: 36
                        Layout.preferredWidth: 36
                        color: loopMouse.containsMouse && root.player && root.player.canControl && root.player.loopSupported ? Config.alpha(Config.md3.on_surface, 0.09) : "transparent"
                        opacity: root.player && root.player.canControl && root.player.loopSupported ? 1 : 0.3
                        radius: 18

                        IconImage {
                            id: loopIcon

                            anchors.centerIn: parent
                            implicitHeight: 18
                            implicitWidth: 18
                            layer.enabled: true
                            source: Quickshell.iconPath("media-playlist-repeat-symbolic", "media-playlist-repeat")

                            layer.effect: ColorOverlay {
                                color: root.player && root.player.loopState !== MprisLoopState.None ? Config.md3.primary : Config.md3.on_surface
                            }
                        }
                        Rectangle {
                            anchors.bottom: loopIcon.bottom
                            anchors.bottomMargin: -2
                            anchors.right: loopIcon.right
                            anchors.rightMargin: -2
                            color: Config.md3.primary
                            height: 10
                            radius: 5
                            visible: root.player && root.player.loopState === MprisLoopState.Track
                            width: 10

                            Text {
                                anchors.centerIn: parent
                                color: Config.md3.background
                                font.family: Config.fontName
                                font.pixelSize: 7
                                font.weight: Font.ExtraBold
                                text: "1"
                            }
                        }
                        MouseArea {
                            id: loopMouse

                            anchors.fill: parent
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: !!root.player && root.player.canControl && root.player.loopSupported
                            hoverEnabled: true

                            onClicked: {
                                if (root.player.loopState === MprisLoopState.None)
                                    root.player.loopState = MprisLoopState.Playlist;
                                else if (root.player.loopState === MprisLoopState.Playlist)
                                    root.player.loopState = MprisLoopState.Track;
                                else
                                    root.player.loopState = MprisLoopState.None;
                            }
                        }
                    }
                }

                // Active media stream volume
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    Layout.maximumWidth: 340
                    Layout.preferredHeight: 22
                    enabled: !!root.mediaStream && !!root.mediaStream.audio
                    spacing: 8
                    visible: !!root.player

                    IconImage {
                        id: mediaVolumeIcon

                        implicitHeight: 16
                        implicitWidth: 16
                        layer.enabled: true
                        source: Quickshell.iconPath(root.mediaVolumeIcon, "audio-volume-high")

                        layer.effect: ColorOverlay {
                            color: root.mediaMuted ? Config.md3.on_surface_variant : Config.md3.primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                if (root.mediaStream && root.mediaStream.audio)
                                    root.mediaStream.audio.muted = !root.mediaStream.audio.muted;
                            }
                        }
                    }
                    CustomVolumeSlider {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 18
                        highlightColor: Config.md3.primary
                        hoverTrackHeight: 5
                        isMuted: root.mediaMuted
                        maximumValue: Config.audioMaxVolume
                        showThumbOnHover: true
                        thumbSize: 9
                        trackHeight: 3
                        value: root.mediaVolume

                        onSliderMoved: volume => root.setMediaVolume(volume)
                    }
                    Text {
                        Layout.preferredWidth: 34
                        color: Config.alpha(Config.md3.on_surface, 0.68)
                        font.family: Config.fontName
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(root.mediaVolume * 100) + "%"
                    }
                }

                // Bottom: 3-line Lyrics
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 115
                    Layout.topMargin: 12
                    border.color: Config.alpha(Config.md3.on_surface, 0.04)
                    border.width: 1
                    color: Config.alpha(Config.md3.on_surface, 0.02)
                    radius: 12
                    visible: !!root.player

                    MusicLyrics {
                        anchors.fill: parent
                        anchors.margins: 8
                        player: root.player
                    }
                }
            }
            MusicEmptyState {
                id: emptyState

                anchors.centerIn: parent
                height: implicitHeight
                opacity: root.player ? 0 : 1
                visible: !root.player
                width: Math.min(440, parent.width - 32)

                Behavior on opacity {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
