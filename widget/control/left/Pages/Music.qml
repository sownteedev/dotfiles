import "../../../../"
import "../../../../components"
import "../../../../service"
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../../../../components/common"

Item {
    id: root

    readonly property real artworkSize: {
        var lyricsHeight = lyricsExpanded ? expandedLyricsHeight : 0;
        var gapCount = lyricsExpanded ? 4 : 3;
        var reservedHeight = contentPadding * 2 + trackMetadata.implicitHeight + 36 + 48 + lyricsHeight + contentSpacing * gapCount;
        return Math.max(96, Math.min(280, playerArea.height - reservedHeight));
    }

    // Keep the full player in view by shrinking the flexible parts first.
    // Very short panels can still scroll after the artwork reaches its minimum.
    readonly property real contentPadding: Math.max(12, Math.min(20, playerArea.height / 30))
    readonly property real contentSpacing: Math.max(8, Math.min(15, playerArea.height / 40))
    readonly property real expandedLyricsHeight: Math.max(88, Math.min(115, playerArea.height * 0.2))
    property bool isSwipingOut: false
    readonly property bool lyricsAvailable: lyrics.hasLyrics && !lyrics.loading && !lyrics.lookupFailed
    property bool lyricsExpanded: false
    readonly property color lyricsStateColor: lyrics.lookupFailed ? Config.md3.error : lyrics.hasSyncedLyrics ? Config.md3.primary : lyrics.hasLyrics ? Config.md3.tertiary : Config.md3.on_surface_variant
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
    property real trackArtworkOpacity: 1
    property real trackArtworkScale: 1
    property real trackMetadataOffset: 0
    property real trackMetadataOpacity: 1

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
    function toggleLyrics() {
        if (lyricsExpanded || (lyricsAvailable && lyrics.previewReady))
            lyricsExpanded = !lyricsExpanded;
    }

    anchors.fill: parent

    Behavior on swipeOffset {
        enabled: !musicDrag.active && !root.isSwipingOut

        NumberAnimation {
            duration: Config.animationDuration(250)
            easing.type: Easing.OutCubic
        }
    }

    PwObjectTracker {
        objects: Pipewire.nodes && Pipewire.nodes.values ? Pipewire.nodes.values : []
    }
    Connections {
        function onPostTrackChanged() {
            trackChangeDebounce.restart();
        }

        enabled: !!root.player
        target: root.player
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
                duration: Config.animationDuration(105)
                easing.type: Easing.InCubic
                from: 1
                property: "trackArtworkOpacity"
                target: root
                to: 0.12
            }
            NumberAnimation {
                duration: Config.animationDuration(105)
                easing.type: Easing.InCubic
                from: 1
                property: "trackArtworkScale"
                target: root
                to: 0.86
            }
            NumberAnimation {
                duration: Config.animationDuration(90)
                easing.type: Easing.InCubic
                from: 1
                property: "trackMetadataOpacity"
                target: root
                to: 0
            }
            NumberAnimation {
                duration: Config.animationDuration(105)
                easing.type: Easing.InCubic
                from: 0
                property: "trackMetadataOffset"
                target: root
                to: 8
            }
        }
        ParallelAnimation {
            NumberAnimation {
                duration: Config.animationDuration(230)
                easing.type: Easing.OutCubic
                from: 0.12
                property: "trackArtworkOpacity"
                target: root
                to: 1
            }
            NumberAnimation {
                duration: Config.animationDuration(250)
                easing.type: Easing.OutCubic
                from: 0.86
                property: "trackArtworkScale"
                target: root
                to: 1
            }
            NumberAnimation {
                duration: Config.animationDuration(210)
                easing.type: Easing.OutCubic
                from: 0
                property: "trackMetadataOpacity"
                target: root
                to: 1
            }
            NumberAnimation {
                duration: Config.animationDuration(230)
                easing.type: Easing.OutCubic
                from: 8
                property: "trackMetadataOffset"
                target: root
                to: 0
            }
        }
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
            contentHeight: root.player ? Math.max(height, playerContent.implicitHeight + root.contentPadding * 2) : Math.max(height, emptyState.implicitHeight + 36)
            contentWidth: width
            flickableDirection: Flickable.VerticalFlick
            interactive: contentHeight > height
            maximumFlickVelocity: 1800

            ColumnLayout {
                id: playerContent

                anchors.fill: parent
                anchors.margins: root.contentPadding
                spacing: root.contentSpacing
                visible: !!root.player

                // Center: Vinyl Artwork with Swipe Gesture
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: root.artworkSize
                    Layout.preferredWidth: root.artworkSize
                    scale: root.trackArtworkScale

                    Behavior on Layout.preferredHeight {
                        NumberAnimation {
                            duration: Config.animationDuration(Md3.motion.medium2)
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on Layout.preferredWidth {
                        NumberAnimation {
                            duration: Config.animationDuration(Md3.motion.medium2)
                            easing.type: Easing.OutCubic
                        }
                    }
                    transform: Translate {
                        x: root.swipeOffset
                    }

                    MusicArtwork {
                        anchors.fill: parent
                        artworkOpacity: root.trackArtworkOpacity
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
                    id: trackMetadata

                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    opacity: root.trackMetadataOpacity
                    spacing: 8

                    transform: Translate {
                        y: root.trackMetadataOffset
                    }

                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.letterSpacing: Md3.typeScale.titleLarge.letterSpacing
                        font.pixelSize: Md3.typeScale.titleLarge.size
                        font.weight: Md3.typeScale.titleLarge.emphasizedWeight
                        horizontalAlignment: Text.AlignHCenter
                        maximumLineCount: 1
                        renderType: Text.NativeRendering
                        text: MediaService.title
                    }
                    Text {
                        Layout.fillWidth: true
                        color: Config.md3.on_surface_variant
                        elide: Text.ElideRight
                        font.family: Config.fontName
                        font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
                        font.pixelSize: Md3.typeScale.bodyLarge.size
                        font.weight: Md3.typeScale.bodyLarge.weight
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
                Item {
                    id: playbackControls

                    readonly property real controlSize: Math.max(24, Math.min(40, (width - volumeControl.width - lyricsButton.width - 48 - 4 * Md3.spacing.xxs) / 4))

                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Math.max(Md3.spacing.xxs, Math.min(Md3.spacing.sm, (parent.width - volumeControl.width - lyricsButton.width - 4 * playbackControls.controlSize - 48) / 4))

                        Md3IconButton {
                            Accessible.name: qsTr("Shuffle")
                            Layout.preferredHeight: playbackControls.controlSize
                            Layout.preferredWidth: playbackControls.controlSize
                            checkable: true
                            checked: !!root.player && root.player.shuffle
                            containerSize: playbackControls.controlSize
                            enabled: !!root.player && root.player.canControl && root.player.shuffleSupported
                            iconName: "media-playlist-shuffle-symbolic"
                            iconSize: 22

                            onClicked: root.player.shuffle = !root.player.shuffle
                        }
                        Md3IconButton {
                            Accessible.name: qsTr("Previous track")
                            Layout.preferredHeight: playbackControls.controlSize
                            Layout.preferredWidth: playbackControls.controlSize
                            containerSize: playbackControls.controlSize
                            enabled: !!root.player && root.player.canGoPrevious
                            iconName: "media-skip-backward-symbolic"
                            iconSize: 24

                            onClicked: root.player.previous()
                        }
                        Md3IconButton {
                            Accessible.name: MediaService.playing ? qsTr("Pause") : qsTr("Play")
                            Layout.preferredHeight: 48
                            Layout.preferredWidth: 48
                            containerSize: 48
                            containerStyle: MediaService.playing ? "filled" : "tonal"
                            enabled: !!root.player && root.player.canTogglePlaying
                            iconName: MediaService.playing ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                            iconSize: 28

                            onClicked: root.player.togglePlaying()
                        }
                        Md3IconButton {
                            Accessible.name: qsTr("Next track")
                            Layout.preferredHeight: playbackControls.controlSize
                            Layout.preferredWidth: playbackControls.controlSize
                            containerSize: playbackControls.controlSize
                            enabled: !!root.player && root.player.canGoNext
                            iconName: "media-skip-forward-symbolic"
                            iconSize: 24

                            onClicked: root.player.next()
                        }
                        Md3IconButton {
                            Accessible.name: root.player && root.player.loopState === MprisLoopState.Track ? qsTr("Repeat track") : root.player && root.player.loopState === MprisLoopState.Playlist ? qsTr("Repeat playlist") : qsTr("Repeat off")
                            Layout.preferredHeight: playbackControls.controlSize
                            Layout.preferredWidth: playbackControls.controlSize
                            checkable: true
                            checked: !!root.player && root.player.loopState !== MprisLoopState.None
                            containerSize: playbackControls.controlSize
                            enabled: !!root.player && root.player.canControl && root.player.loopSupported
                            iconName: root.player && root.player.loopState === MprisLoopState.Track ? "repeat_one" : "media-playlist-repeat-symbolic"
                            iconSize: 22

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
                    MusicVolumeControl {
                        id: volumeControl

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        available: !!root.mediaStream && !!root.mediaStream.audio
                        iconName: root.mediaVolumeIcon
                        maximumValue: Config.audioMaxVolume
                        muted: root.mediaMuted
                        value: root.mediaVolume

                        onMuteRequested: {
                            if (root.mediaStream && root.mediaStream.audio)
                                root.mediaStream.audio.muted = !root.mediaStream.audio.muted;
                        }
                        onVolumeChanged: value => root.setMediaVolume(value)
                    }

                    // Lyrics status and visibility
                    Rectangle {
                        id: lyricsButton

                        Accessible.checkable: true
                        Accessible.checked: root.lyricsExpanded
                        Accessible.description: lyrics.loading ? qsTr("Loading lyrics") : lyrics.lookupFailed ? qsTr("Lyrics lookup failed") : lyrics.hasSyncedLyrics ? qsTr("Synced lyrics") : root.lyricsAvailable ? qsTr("Lyrics available") : qsTr("Lyrics unavailable")
                        Accessible.name: root.lyricsExpanded ? qsTr("Hide lyrics") : qsTr("Show lyrics")
                        Accessible.role: Accessible.Button
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.lyricsExpanded ? Config.md3.secondary_container : Config.alpha(Config.md3.on_surface, lyricsMouse.pressed ? Md3.state.pressed : lyricsMouse.containsMouse && lyricsMouse.enabled ? Md3.state.hover : 0)
                        height: 36
                        opacity: lyrics.loading || root.lyricsAvailable || root.lyricsExpanded ? 1 : 0.36
                        radius: Md3.shape.full
                        width: 36

                        Behavior on color {
                            ColorAnimation {
                                duration: Config.animationDuration(150)
                            }
                        }

                        Accessible.onPressAction: {
                            if (lyricsMouse.enabled)
                                root.toggleLyrics();
                        }

                        Md3Icon {
                            anchors.centerIn: parent
                            color: root.lyricsExpanded ? Config.md3.on_secondary_container : root.lyricsStateColor
                            filled: root.lyricsExpanded
                            name: "media-view-subtitles-symbolic"
                            size: 22
                            visible: !lyrics.loading
                        }
                        LoadingIndicator {
                            anchors.centerIn: parent
                            animated: lyrics.loading
                            color: root.lyricsExpanded ? Config.md3.on_secondary_container : Config.md3.primary
                            height: 22
                            visible: lyrics.loading
                            width: 22
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 5
                            anchors.right: parent.right
                            anchors.rightMargin: 5
                            border.color: Config.md3.surface
                            border.width: 1
                            color: root.lyricsStateColor
                            height: 7
                            radius: 4
                            visible: !lyrics.loading
                            width: 7
                        }
                        MouseArea {
                            id: lyricsMouse

                            anchors.fill: parent
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            enabled: root.lyricsExpanded || (root.lyricsAvailable && lyrics.previewReady)
                            hoverEnabled: true

                            onClicked: {
                                root.toggleLyrics();
                            }
                        }
                    }
                }
                Item {
                    id: lyricsSection

                    Layout.fillWidth: true
                    Layout.minimumHeight: 0
                    Layout.preferredHeight: root.lyricsExpanded ? root.expandedLyricsHeight : 0
                    clip: true
                    opacity: root.lyricsExpanded && lyrics.previewReady ? 1 : 0

                    Behavior on Layout.preferredHeight {
                        NumberAnimation {
                            duration: Config.animationDuration(Md3.motion.medium2)
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Config.animationDuration(Md3.motion.short4)
                            easing.type: Easing.OutCubic
                        }
                    }

                    MusicLyrics {
                        id: lyrics

                        height: root.expandedLyricsHeight
                        player: root.player
                        width: parent.width

                        onHasLyricsChanged: {
                            if (!hasLyrics)
                                root.lyricsExpanded = false;
                        }
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
                        duration: Config.animationDuration(220)
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}
