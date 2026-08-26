import "../.."
import "../../service"
import QtMultimedia
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property int activeSlot: 0
    readonly property int crossfadeDuration: Math.max(260, Math.min(420, Config.wallpaperTransitionDuration))
    property int pendingSlot: -1
    readonly property string rendererName: screen ? String(screen.name || "") : windowNamespace
    property int transitionGeneration: 0
    property int transitionIncomingSlot: -1
    property Item transitionIncomingView: null
    property int transitionOutgoingSlot: -1
    property Item transitionOutgoingView: null
    property string transitionPath: ""
    property int transitionSerial: 0
    property bool transitioning: false
    property string windowNamespace: "video-wallpaper"

    function abortTransition() {
        if (!transitioning)
            return;

        crossfadeAnimation.stop();
        if (transitionIncomingSlot >= 0) {
            viewFor(transitionIncomingSlot).opacity = 1;
            if (transitionOutgoingSlot >= 0 && transitionOutgoingSlot !== transitionIncomingSlot) {
                viewFor(transitionOutgoingSlot).opacity = 0;
                stopSlot(transitionOutgoingSlot);
            }
            activeSlot = transitionIncomingSlot;
        }
        pendingSlot = -1;
        clearTransitionState();
    }
    function clearTransitionState() {
        transitioning = false;
        transitionGeneration = 0;
        transitionIncomingSlot = -1;
        transitionIncomingView = null;
        transitionOutgoingSlot = -1;
        transitionOutgoingView = null;
        transitionPath = "";
        transitionSerial = 0;
    }
    function fileUrl(path) {
        var value = String(path || "");
        return value.startsWith("file:") ? value : "file://" + value;
    }
    function finishTransition() {
        var incoming = transitionIncomingSlot;
        var outgoing = transitionOutgoingSlot;
        var path = transitionPath;
        var generation = transitionGeneration;
        var serial = transitionSerial;
        if (incoming < 0 || path !== LiveWallpaperService.desiredPath || generation !== LiveWallpaperService.desiredGeneration || serial !== LiveWallpaperService.requestSerial) {
            clearTransitionState();
            syncRequest();
            return;
        }
        viewFor(incoming).opacity = 1;
        if (outgoing >= 0 && outgoing !== incoming) {
            viewFor(outgoing).opacity = 0;
            stopSlot(outgoing);
        }
        activeSlot = incoming;
        pendingSlot = -1;
        clearTransitionState();
        LiveWallpaperService.reportTransitionFinished(rendererName, path, generation, serial);
    }
    function handleAnimatedImageStatus(index, status) {
        var player = playerFor(index);
        if (!player.requestIsGif || !player.requestPath || player.requestSerial !== LiveWallpaperService.requestSerial)
            return;

        if (status === Image.Ready)
            markSlotReady(index);
        else if (status === Image.Error)
            LiveWallpaperService.reportPlaybackError(rendererName, player.requestPath, player.requestGeneration, player.requestSerial, "Could not decode the animated wallpaper");
    }
    function handlePlayerError(index, error, errorString) {
        if (error === MediaPlayer.NoError)
            return;

        var player = playerFor(index);
        if (!player.requestPath || player.requestIsGif)
            return;

        LiveWallpaperService.reportPlaybackError(rendererName, player.requestPath, player.requestGeneration, player.requestSerial, errorString || "Could not decode the live wallpaper");
    }
    function handleVideoFrame(index) {
        var player = playerFor(index);
        if (index !== pendingSlot || player.requestIsGif || !player.requestPath || player.frameReady || player.requestSerial !== LiveWallpaperService.requestSerial)
            return;

        var expectedSerial = player.requestSerial;
        Qt.callLater(() => {
            var currentPlayer = root.playerFor(index);
            if (index !== root.pendingSlot || currentPlayer.requestSerial !== expectedSerial || !currentPlayer.requestPath || currentPlayer.requestIsGif)
                return;
            var videoSize = root.videoOutputFor(index).videoSink.videoSize;
            if (!currentPlayer.hasVideo || currentPlayer.mediaStatus === MediaPlayer.NoMedia || currentPlayer.mediaStatus === MediaPlayer.LoadingMedia || currentPlayer.mediaStatus === MediaPlayer.InvalidMedia || videoSize.width <= 0 || videoSize.height <= 0)
                return;

            root.markSlotReady(index);
        });
    }
    function isGifPath(path) {
        return String(path || "").split("?")[0].toLowerCase().endsWith(".gif");
    }
    function markSlotReady(index) {
        var player = playerFor(index);
        if (index !== pendingSlot || player.frameReady || !player.requestPath || player.requestSerial !== LiveWallpaperService.requestSerial)
            return;

        player.frameReady = true;
        LiveWallpaperService.reportFrameReady(rendererName, player.requestPath, player.requestGeneration, player.requestSerial);
        Qt.callLater(root.maybeStartTransition);
    }
    function maybeStartTransition() {
        if (transitioning || pendingSlot < 0 || WallpaperService.isTransitionPending)
            return;

        if (WallpaperService.currentMode !== "video" || WallpaperService.isEngineVideo)
            return;

        var incomingPlayer = playerFor(pendingSlot);
        if (!incomingPlayer.frameReady || incomingPlayer.requestPath !== LiveWallpaperService.desiredPath || incomingPlayer.requestGeneration !== LiveWallpaperService.desiredGeneration || incomingPlayer.requestSerial !== LiveWallpaperService.requestSerial)
            return;

        if (WallpaperService.startupVideoRestore) {
            var restoredSlot = pendingSlot;
            var previousSlot = activeSlot;
            viewFor(restoredSlot).opacity = 1;
            if (previousSlot !== restoredSlot) {
                viewFor(previousSlot).opacity = 0;
                stopSlot(previousSlot);
            }
            activeSlot = restoredSlot;
            pendingSlot = -1;
            LiveWallpaperService.reportTransitionFinished(rendererName, incomingPlayer.requestPath, incomingPlayer.requestGeneration, incomingPlayer.requestSerial);
            return;
        }

        transitionIncomingSlot = pendingSlot;
        transitionOutgoingSlot = activeSlot;
        transitionIncomingView = viewFor(transitionIncomingSlot);
        transitionOutgoingView = viewFor(transitionOutgoingSlot);
        transitionPath = incomingPlayer.requestPath;
        transitionGeneration = incomingPlayer.requestGeneration;
        transitionSerial = incomingPlayer.requestSerial;
        transitionIncomingView.opacity = 0;
        transitionOutgoingView.opacity = 1;
        transitioning = true;
        crossfadeAnimation.restart();
    }
    function playerFor(index) {
        return index === 0 ? playerA : playerB;
    }
    function startSlot(index, path, generation, serial) {
        stopSlot(index);
        var player = playerFor(index);
        player.requestPath = path;
        player.requestGeneration = generation;
        player.requestSerial = serial;
        player.requestIsGif = isGifPath(path);
        player.frameReady = false;
        viewFor(index).opacity = 0;
        Qt.callLater(() => {
            return root.syncSlotPlayback(index);
        });
    }
    function stopAll() {
        crossfadeAnimation.stop();
        stopSlot(0);
        stopSlot(1);
        activeSlot = 0;
        pendingSlot = -1;
        slotA.opacity = 1;
        slotB.opacity = 0;
        clearTransitionState();
    }
    function stopSlot(index) {
        var player = playerFor(index);
        player.requestPath = "";
        player.requestGeneration = 0;
        player.requestSerial = 0;
        player.requestIsGif = false;
        player.frameReady = false;
        player.stop();
        videoOutputFor(index).clearOutput();
    }
    function syncPolicy() {
        syncSlotPlayback(0);
        syncSlotPlayback(1);
    }
    function syncRequest() {
        var path = String(LiveWallpaperService.desiredPath || "");
        if (!path) {
            stopAll();
            return;
        }
        if (transitioning)
            abortTransition();

        if (pendingSlot >= 0) {
            var pendingPlayer = playerFor(pendingSlot);
            if (pendingPlayer.requestPath === path && pendingPlayer.requestGeneration === LiveWallpaperService.desiredGeneration && pendingPlayer.requestSerial === LiveWallpaperService.requestSerial)
                return;

            stopSlot(pendingSlot);
            viewFor(pendingSlot).opacity = 0;
            pendingSlot = -1;
        }
        var targetSlot = activeSlot === 0 ? 1 : 0;
        pendingSlot = targetSlot;
        startSlot(targetSlot, path, LiveWallpaperService.desiredGeneration, LiveWallpaperService.requestSerial);
    }
    function syncSlotPlayback(index) {
        var player = playerFor(index);
        if (!player.requestPath || player.requestIsGif)
            return;

        if (WallpaperPlaybackPolicy.shouldPause) {
            if (player.playbackState === MediaPlayer.PlayingState)
                player.pause();
        } else if (player.playbackState !== MediaPlayer.PlayingState) {
            player.play();
        }
    }
    function videoOutputFor(index) {
        return index === 0 ? videoA : videoB;
    }
    function viewFor(index) {
        return index === 0 ? slotA : slotB;
    }

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: windowNamespace
    aboveWindows: false
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    anchors.top: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    Component.onCompleted: {
        LiveWallpaperService.registerRenderer(rendererName);
        syncRequest();
    }
    Component.onDestruction: {
        crossfadeAnimation.stop();
        stopSlot(0);
        stopSlot(1);
        LiveWallpaperService.unregisterRenderer(rendererName);
    }

    Connections {
        function onRequestSerialChanged() {
            root.syncRequest();
        }

        target: LiveWallpaperService
    }
    Connections {
        function onShouldPauseChanged() {
            root.syncPolicy();
        }

        target: WallpaperPlaybackPolicy
    }
    Connections {
        function onIsTransitionPendingChanged() {
            if (!WallpaperService.isTransitionPending)
                Qt.callLater(root.maybeStartTransition);
        }

        target: WallpaperService
    }
    Connections {
        function onVideoFrameChanged(frame) {
            root.handleVideoFrame(0);
        }

        target: videoA.videoSink
    }
    Connections {
        function onVideoFrameChanged(frame) {
            root.handleVideoFrame(1);
        }

        target: videoB.videoSink
    }
    Item {
        id: slotA

        anchors.fill: parent
        opacity: 1

        VideoOutput {
            id: videoA

            anchors.fill: parent
            endOfStreamPolicy: VideoOutput.KeepLastFrame
            fillMode: VideoOutput.PreserveAspectCrop
            visible: playerA.requestPath !== "" && !playerA.requestIsGif
        }
        AnimatedImage {
            id: animatedA

            anchors.fill: parent
            asynchronous: true
            cache: false
            fillMode: Image.PreserveAspectCrop
            playing: playerA.requestPath !== "" && playerA.requestIsGif && !WallpaperPlaybackPolicy.shouldPause
            source: playerA.requestIsGif ? root.fileUrl(playerA.requestPath) : ""
            sourceSize: Qt.size(Math.ceil(root.width), Math.ceil(root.height))
            visible: playerA.requestPath !== "" && playerA.requestIsGif

            onStatusChanged: root.handleAnimatedImageStatus(0, status)
        }
    }
    Item {
        id: slotB

        anchors.fill: parent
        opacity: 0

        VideoOutput {
            id: videoB

            anchors.fill: parent
            endOfStreamPolicy: VideoOutput.KeepLastFrame
            fillMode: VideoOutput.PreserveAspectCrop
            visible: playerB.requestPath !== "" && !playerB.requestIsGif
        }
        AnimatedImage {
            id: animatedB

            anchors.fill: parent
            asynchronous: true
            cache: false
            fillMode: Image.PreserveAspectCrop
            playing: playerB.requestPath !== "" && playerB.requestIsGif && !WallpaperPlaybackPolicy.shouldPause
            source: playerB.requestIsGif ? root.fileUrl(playerB.requestPath) : ""
            sourceSize: Qt.size(Math.ceil(root.width), Math.ceil(root.height))
            visible: playerB.requestPath !== "" && playerB.requestIsGif

            onStatusChanged: root.handleAnimatedImageStatus(1, status)
        }
    }
    AudioOutput {
        id: audioA

        muted: true
        volume: 0
    }
    AudioOutput {
        id: audioB

        muted: true
        volume: 0
    }
    MediaPlayer {
        id: playerA

        property bool frameReady: false
        property int requestGeneration: 0
        property bool requestIsGif: false
        property string requestPath: ""
        property int requestSerial: 0

        audioOutput: audioA
        loops: MediaPlayer.Infinite
        source: requestPath !== "" && !requestIsGif ? root.fileUrl(requestPath) : ""
        videoOutput: videoA

        onErrorOccurred: (error, errorString) => {
            return root.handlePlayerError(0, error, errorString);
        }
    }
    MediaPlayer {
        id: playerB

        property bool frameReady: false
        property int requestGeneration: 0
        property bool requestIsGif: false
        property string requestPath: ""
        property int requestSerial: 0

        audioOutput: audioB
        loops: MediaPlayer.Infinite
        source: requestPath !== "" && !requestIsGif ? root.fileUrl(requestPath) : ""
        videoOutput: videoB

        onErrorOccurred: (error, errorString) => {
            return root.handlePlayerError(1, error, errorString);
        }
    }
    ParallelAnimation {
        id: crossfadeAnimation

        alwaysRunToEnd: false

        onFinished: root.finishTransition()

        OpacityAnimator {
            duration: root.crossfadeDuration
            easing.type: Easing.OutCubic
            from: 0
            target: root.transitionIncomingView
            to: 1
        }
        OpacityAnimator {
            duration: root.crossfadeDuration
            easing.type: Easing.InOutCubic
            from: 1
            target: root.transitionOutgoingView
            to: 0
        }
    }
}
