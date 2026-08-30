import QtMultimedia
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property bool frameReadyState: false
    property int loadedGeneration: 0
    property bool loadedIsGif: false
    property string loadedPath: ""
    property int loadedSerial: 0
    property string loadedSession: ""
    readonly property bool paused: Boolean(requestData && requestData.paused)
    required property var requestData
    readonly property string screenName: screen ? String(screen.name || "") : windowNamespace
    property string windowNamespace: "native-video-wallpaper"

    signal frameReady(string screenName, string session, string path, int generation, int serial)
    signal playbackError(string screenName, string session, string path, int generation, int serial, string message)

    function currentRequestMatches() {
        var request = requestData || {};
        return loadedSession !== "" && loadedSession === String(request.session || "") && loadedPath !== "" && loadedPath === String(request.path || "") && loadedGeneration === Number(request.generation || 0) && loadedSerial === Number(request.serial || 0);
    }
    function fileUrl(path) {
        var value = String(path || "");
        return value.startsWith("file:") ? value : "file://" + value;
    }
    function handleAnimatedImageStatus(status) {
        if (!loadedIsGif || !currentRequestMatches() || frameReadyState)
            return;

        if (status === Image.Ready)
            markReady();
        else if (status === Image.Error)
            playbackError(screenName, loadedSession, loadedPath, loadedGeneration, loadedSerial, "Could not decode the animated wallpaper");
    }
    function handlePlayerError(error, errorString) {
        if (error === MediaPlayer.NoError || loadedIsGif || !currentRequestMatches())
            return;

        playbackError(screenName, loadedSession, loadedPath, loadedGeneration, loadedSerial, errorString || "Could not decode the live wallpaper");
    }
    function handleVideoFrame() {
        if (loadedIsGif || frameReadyState || !currentRequestMatches())
            return;

        var expectedPath = loadedPath;
        var expectedGeneration = loadedGeneration;
        var expectedSerial = loadedSerial;
        var expectedSession = loadedSession;
        Qt.callLater(() => {
            if (root.loadedSession !== expectedSession || root.loadedPath !== expectedPath || root.loadedGeneration !== expectedGeneration || root.loadedSerial !== expectedSerial || !root.currentRequestMatches())
                return;

            var videoSize = videoOutput.videoSink.videoSize;
            if (!player.hasVideo || player.mediaStatus === MediaPlayer.NoMedia || player.mediaStatus === MediaPlayer.LoadingMedia || player.mediaStatus === MediaPlayer.InvalidMedia || videoSize.width <= 0 || videoSize.height <= 0)
                return;

            root.markReady();
        });
    }
    function isGifPath(path) {
        return String(path || "").split("?")[0].toLowerCase().endsWith(".gif");
    }
    function markReady() {
        if (frameReadyState || !currentRequestMatches())
            return;

        frameReadyState = true;
        frameReady(screenName, loadedSession, loadedPath, loadedGeneration, loadedSerial);
    }
    function startRequest(session, path, generation, serial) {
        stopPlayback();
        Qt.callLater(() => {
            var request = root.requestData || {};
            if (session !== String(request.session || "") || path !== String(request.path || "") || generation !== Number(request.generation || 0) || serial !== Number(request.serial || 0))
                return;

            root.loadedSession = session;
            root.loadedGeneration = generation;
            root.loadedSerial = serial;
            root.loadedIsGif = root.isGifPath(path);
            root.loadedPath = path;
            Qt.callLater(root.syncPlayback);
        });
    }
    function stopPlayback() {
        loadedPath = "";
        loadedGeneration = 0;
        loadedSerial = 0;
        loadedSession = "";
        loadedIsGif = false;
        frameReadyState = false;
        player.stop();
        videoOutput.clearOutput();
    }
    function syncPlayback() {
        if (!loadedPath || loadedIsGif)
            return;

        if (paused) {
            if (player.playbackState === MediaPlayer.PlayingState)
                player.pause();
        } else if (player.playbackState !== MediaPlayer.PlayingState) {
            player.play();
        }
    }
    function syncRequest() {
        var request = requestData || {};
        var path = String(request.path || "");
        var generation = Number(request.generation || 0);
        var serial = Number(request.serial || 0);
        var session = String(request.session || "");
        if (!session || !path) {
            stopPlayback();
            return;
        }
        if (loadedSession === session && loadedPath === path && loadedGeneration === generation && loadedSerial === serial) {
            syncPlayback();
            return;
        }
        startRequest(session, path, generation, serial);
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

    Component.onCompleted: syncRequest()
    Component.onDestruction: stopPlayback()
    onPausedChanged: syncPlayback()
    onRequestDataChanged: syncRequest()

    Connections {
        function onVideoFrameChanged() {
            root.handleVideoFrame();
        }

        target: videoOutput.videoSink
    }
    VideoOutput {
        id: videoOutput

        anchors.fill: parent
        endOfStreamPolicy: VideoOutput.KeepLastFrame
        fillMode: VideoOutput.PreserveAspectCrop
        visible: root.loadedPath !== "" && !root.loadedIsGif
    }
    AnimatedImage {
        anchors.fill: parent
        asynchronous: true
        cache: false
        fillMode: Image.PreserveAspectCrop
        playing: root.loadedPath !== "" && root.loadedIsGif && !root.paused
        source: root.loadedIsGif ? root.fileUrl(root.loadedPath) : ""
        sourceSize: Qt.size(Math.ceil(root.width), Math.ceil(root.height))
        visible: root.loadedPath !== "" && root.loadedIsGif

        onStatusChanged: root.handleAnimatedImageStatus(status)
    }
    MediaPlayer {
        id: player

        activeAudioTrack: -1
        loops: MediaPlayer.Infinite
        source: root.loadedPath !== "" && !root.loadedIsGif ? root.fileUrl(root.loadedPath) : ""
        videoOutput: videoOutput

        onErrorOccurred: (error, errorString) => {
            return root.handlePlayerError(error, errorString);
        }
    }
}
