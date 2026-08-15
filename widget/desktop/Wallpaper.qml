import "../.."
import "../../service"
import "../../components"
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: wallpaperWindow

    property bool allowVideoFade: true
    property Item candidateImage: null
    property string currentWall: ""
    property Item displayedImage: null
    property bool isTransitionPending: WallpaperService.isTransitionPending
    property bool isVideoWallpaper: allowVideoFade && WallpaperService.currentMode === "video"
    property Item outgoingImage: null
    readonly property bool revealVideo: isVideoWallpaper && !isTransitionPending && !waitingForPolicyRestart && transitionStarted && !WallpaperService.previewActive
    property int sourceGeneration: 0
    property bool transitionStarted: false
    property bool useNativeCache: true
    readonly property bool waitingForPolicyRestart: WallpaperService.isEngineVideo && EngineWallpaperService.policyRestarting && !EngineWallpaperService.playbackReadyState
    property string wallpaperPath: ""
    property string windowNamespace: "wallpaper"

    function effectiveSource() {
        if (revealVideo)
            return "";

        var path = String(wallpaperPath || "");
        return path.startsWith("/") ? "file://" + path : path;
    }
    function finishCoverSwap(reportReady) {
        if (outgoingImage) {
            var old = outgoingImage;
            outgoingImage = null;
            old.destroy();
        }
        if (displayedImage) {
            displayedImage.opacity = 1;
            displayedImage.z = 0;
        }
        if (reportReady !== false)
            reportVideoCoverReady(displayedImage);
    }
    function finishTransition() {
        if (outgoingImage) {
            var old = outgoingImage;
            outgoingImage = null;
            old.destroy();
        }
        if (displayedImage) {
            displayedImage.opacity = 1;
            displayedImage.z = 0;
        }
    }
    function imageStatusChanged(image, status) {
        if (image !== candidateImage)
            return;

        if (status === Image.Ready)
            promoteCandidate(image, image.requestId);
        else if (status === Image.Error) {
            if (image.scheduleRetry && image.scheduleRetry())
                return;
            console.warn("[Wallpaper] Could not load", image.sourceKey);
            var failedSource = image.sourceKey;
            candidateImage = null;
            image.destroy();
            Qt.callLater(() => WallpaperService.handleWallpaperLoadError(failedSource));
        }
    }
    function isAnimated(source) {
        var cleanSource = String(source || "").split("?")[0].toLowerCase();
        return cleanSource.endsWith(".gif");
    }
    function isPendingVideoCover(image) {
        return allowVideoFade && WallpaperService.currentMode === "video" && WallpaperService.isTransitionPending && image && normalizedPath(image.sourceKey) === normalizedPath(WallpaperService.pendingVideoThumbnail);
    }
    function normalizedPath(path) {
        return String(path || "").replace(/^file:\/\//, "");
    }
    function promoteCandidate(image, generation) {
        if (!image || image !== candidateImage || generation !== sourceGeneration)
            return;

        candidateImage = null;
        image.opacity = 1;
        image.visible = true;
        image.z = 0;
        currentWall = image.sourceKey;

        if (!displayedImage) {
            displayedImage = image;
            transitionStarted = true;
            reportVideoCoverReady(image);
            return;
        }

        if (isPendingVideoCover(image)) {
            outgoingImage = displayedImage;
            outgoingImage.opacity = 1;
            outgoingImage.visible = true;
            outgoingImage.z = 0;
            displayedImage = image;
            displayedImage.opacity = 0;
            displayedImage.z = 1;
            transitionStarted = true;
            coverFadeAnimation.restart();
            return;
        }

        outgoingImage = displayedImage;
        outgoingImage.opacity = 1;
        outgoingImage.visible = true;
        outgoingImage.z = 0;
        displayedImage = image;
        displayedImage.opacity = 0;
        displayedImage.z = 1;
        transitionStarted = true;
        transitionAnimation.restart();
    }
    function reportVideoCoverReady(image) {
        if (!isPendingVideoCover(image))
            return;
        WallpaperService.markVideoCoverReady(wallpaperPath, screen ? screen.name : windowNamespace);
    }
    function requestWallpaper() {
        var source = effectiveSource();
        if (candidateImage && candidateImage.sourceKey === source)
            return;
        if (!candidateImage && displayedImage && displayedImage.sourceKey === source)
            return;

        if (transitionAnimation.running) {
            transitionAnimation.stop();
            finishTransition();
        }
        if (coverFadeAnimation.running) {
            coverFadeAnimation.stop();
            finishCoverSwap(false);
        }
        if (candidateImage) {
            var stale = candidateImage;
            candidateImage = null;
            stale.destroy();
        }

        ++sourceGeneration;
        // Video-mode previews are only temporary covers. Decode a single
        // frame, including GIF previews, instead of starting another animated
        // decoder while the real renderer is launching underneath.
        var animateSource = WallpaperService.currentMode !== "video" && isAnimated(source);
        var component = source === "" ? transparentWallpaper : (animateSource ? animatedWallpaper : (useNativeCache ? staticWallpaper : directStaticWallpaper));
        candidateImage = component.createObject(imageHost, {
            "requestId": sourceGeneration,
            "sourceKey": source
        });
        if (!candidateImage) {
            console.warn("[Wallpaper] Could not create wallpaper item for", source);
            return;
        }

        var createdImage = candidateImage;
        var createdGeneration = sourceGeneration;
        Qt.callLater(() => {
            if (createdImage !== wallpaperWindow.candidateImage || createdGeneration !== wallpaperWindow.sourceGeneration)
                return;
            if (source === "")
                wallpaperWindow.promoteCandidate(createdImage, createdGeneration);
            else
                wallpaperWindow.imageStatusChanged(createdImage, createdImage.status);
        });
    }
    function shouldBlurEngineCover(path) {
        if (!allowVideoFade || WallpaperService.currentMode !== "video" || !WallpaperService.isEngineVideo || WallpaperService.lastVideoFrame !== "")
            return false;

        var cover = normalizedPath(path);
        var preview = normalizedPath(WallpaperService.fallbackVideoThumbnail);
        return cover !== "" && preview !== "" && cover === preview;
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

    Component.onCompleted: requestWallpaper()
    Component.onDestruction: {
        if (candidateImage)
            candidateImage.destroy();
        if (outgoingImage)
            outgoingImage.destroy();
        if (displayedImage)
            displayedImage.destroy();
    }
    onRevealVideoChanged: requestWallpaper()
    onWallpaperPathChanged: requestWallpaper()

    Connections {
        function onPendingVideoThumbnailChanged() {
            wallpaperWindow.reportVideoCoverReady(wallpaperWindow.displayedImage);
        }

        target: WallpaperService
    }
    Item {
        id: imageHost

        anchors.fill: parent
    }
    Component {
        id: staticWallpaper

        CachingImage {
            id: staticImage

            readonly property bool blurEngineCover: wallpaperWindow.shouldBlurEngineCover(sourceKey)
            property int requestId: 0
            property string sourceKey: ""

            anchors.fill: parent
            cacheKey: wallpaperWindow.allowVideoFade && WallpaperService.currentMode === "video" ? String(WallpaperService.videoTransitionGeneration) : ""
            fillMode: blurEngineCover || WallpaperService.previewActive || WallpaperService.currentMode !== "video" || !WallpaperService.isEngineVideo ? Image.PreserveAspectCrop : Image.Stretch
            layer.enabled: blurEngineCover
            opacity: 0
            path: sourceKey

            layer.effect: FastBlur {
                radius: 56
                transparentBorder: false
            }

            onStatusChanged: wallpaperWindow.imageStatusChanged(staticImage, status)
        }
    }
    Component {
        id: directStaticWallpaper

        Image {
            id: directImage

            readonly property bool blurEngineCover: wallpaperWindow.shouldBlurEngineCover(sourceKey)
            property int requestId: 0
            property string sourceKey: ""

            anchors.fill: parent
            asynchronous: true
            cache: true
            fillMode: blurEngineCover || WallpaperService.previewActive || WallpaperService.currentMode !== "video" || !WallpaperService.isEngineVideo ? Image.PreserveAspectCrop : Image.Stretch
            layer.enabled: blurEngineCover
            opacity: 0
            source: sourceKey
            sourceSize: Qt.size(Math.ceil(wallpaperWindow.width * Screen.devicePixelRatio), Math.ceil(wallpaperWindow.height * Screen.devicePixelRatio))

            layer.effect: FastBlur {
                radius: 56
                transparentBorder: false
            }

            onStatusChanged: wallpaperWindow.imageStatusChanged(directImage, status)
        }
    }
    Component {
        id: animatedWallpaper

        AnimatedImage {
            id: animatedImage

            property int requestId: 0
            property string sourceKey: ""

            anchors.fill: parent
            asynchronous: true
            cache: false
            fillMode: Image.PreserveAspectCrop
            opacity: 0
            playing: wallpaperWindow.displayedImage === animatedImage && !transitionAnimation.running
            source: sourceKey
            sourceSize: Qt.size(Math.ceil(wallpaperWindow.width), Math.ceil(wallpaperWindow.height))

            onStatusChanged: wallpaperWindow.imageStatusChanged(animatedImage, status)
        }
    }
    Component {
        id: transparentWallpaper

        Item {
            id: transparentItem

            property int requestId: 0
            property string sourceKey: ""

            anchors.fill: parent
            opacity: 0
        }
    }
    ParallelAnimation {
        id: coverFadeAnimation

        onFinished: wallpaperWindow.finishCoverSwap(true)

        NumberAnimation {
            duration: Math.max(0, Math.round(Config.wallpaperTransitionDuration / 2))
            easing.type: Easing.OutCubic
            from: 0
            property: "opacity"
            target: wallpaperWindow.displayedImage
            to: 1
        }
        NumberAnimation {
            duration: Math.max(0, Math.round(Config.wallpaperTransitionDuration / 2))
            easing.type: Easing.OutCubic
            from: 1
            property: "opacity"
            target: wallpaperWindow.outgoingImage
            to: 0
        }
    }
    ParallelAnimation {
        id: transitionAnimation

        onFinished: wallpaperWindow.finishTransition()

        NumberAnimation {
            duration: Config.wallpaperTransitionDuration
            easing.type: Easing.OutCubic
            from: 0
            property: "opacity"
            target: wallpaperWindow.displayedImage
            to: 1
        }
        NumberAnimation {
            duration: Config.wallpaperTransitionDuration
            easing.type: Easing.OutCubic
            from: 1
            property: "opacity"
            target: wallpaperWindow.outgoingImage
            to: 0
        }
    }
}
