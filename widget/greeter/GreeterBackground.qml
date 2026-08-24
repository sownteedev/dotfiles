import QtMultimedia
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    readonly property bool hasBackground: kind !== "" && sourcePath !== ""
    property string kind: ""
    property FileView manifestFile: FileView {
        blockLoading: true
        path: root.manifestPath
        printErrors: false
        watchChanges: true

        onFileChanged: reload()
        onLoadedChanged: {
            if (loaded)
                root.applyManifest(text());
        }
        onTextChanged: {
            if (loaded)
                root.applyManifest(text());
        }
    }
    readonly property string manifestPath: Quickshell.env("GREETD_BACKGROUND_PATH") || "/var/lib/quickshell-greeter/background.json"
    property string sourcePath: ""

    function applyManifest(rawText) {
        try {
            var manifest = JSON.parse(String(rawText || ""));
            var nextKind = String(manifest.kind || "");
            var nextPath = String(manifest.path || "");
            if (!["image", "engine-video"].includes(nextKind) || nextPath === "")
                return;
            kind = nextKind;
            sourcePath = nextPath;
        } catch (error) {
            console.warn("[GreeterBackground] Invalid background manifest:", error);
        }
    }
    function fileUrl(path) {
        var value = String(path || "");
        return value.startsWith("file:") ? value : "file://" + value;
    }

    Image {
        anchors.fill: parent
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        source: root.kind === "image" ? root.fileUrl(root.sourcePath) : ""
        visible: root.kind === "image"
    }
    VideoOutput {
        id: videoOutput

        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        visible: root.kind === "engine-video"
    }
    AudioOutput {
        id: audioOutput

        muted: true
        volume: 0
    }
    MediaPlayer {
        audioOutput: audioOutput
        autoPlay: true
        loops: MediaPlayer.Infinite
        source: root.kind === "engine-video" ? root.fileUrl(root.sourcePath) : ""
        videoOutput: videoOutput
    }
}
