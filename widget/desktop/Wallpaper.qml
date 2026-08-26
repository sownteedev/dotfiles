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
    readonly property real commitRippleDiameter: Math.max(120, Math.min(width, height) * 0.18)
    property int commitRippleGeneration: -1
    readonly property real commitRippleTargetScale: Math.max(1, Math.sqrt(width * width + height * height) * 1.08 / commitRippleDiameter)
    property string currentWall: ""
    property Item displayedImage: null
    property bool isTransitionPending: WallpaperService.isTransitionPending
    property bool isVideoWallpaper: allowVideoFade && WallpaperService.currentMode === "video"
    property Item outgoingImage: null
    readonly property bool pendingStaticTransition: allowVideoFade && WallpaperService.staticTransitionPending && WallpaperService.currentMode === "static"
    readonly property int previewCoverDuration: Math.max(220, Math.min(300, Config.wallpaperTransitionDuration))
    property bool previewCoverTransition: false
    readonly property bool revealVideo: isVideoWallpaper && !isTransitionPending && !waitingForPolicyRestart && videoRendererReady && transitionStarted && !WallpaperService.previewActive
    property int sourceGeneration: 0
    property bool transitionStarted: false
    property bool useNativeCache: true
    readonly property int videoCoverInDuration: Math.max(140, Math.min(200, Config.wallpaperTransitionDuration))
    readonly property bool videoRendererReady: WallpaperService.isEngineVideo ? EngineWallpaperService.playbackReadyState : LiveWallpaperService.activePath !== "" && LiveWallpaperService.activePath === LiveWallpaperService.desiredPath
    readonly property int videoRevealDuration: Math.max(260, Math.min(340, Config.wallpaperTransitionDuration))
    readonly property bool waitingForPolicyRestart: WallpaperService.isEngineVideo && EngineWallpaperService.policyRestarting && !EngineWallpaperService.playbackReadyState
    property string wallpaperPath: ""
    property string windowNamespace: "wallpaper"

    function effectiveSource() {
        if (revealVideo)
            return "";

        var path = String(wallpaperPath || "");
        return path.startsWith("/") ? "file://" + path : path;
    }
    function finishStartupVideoRestore(image) {
        if (!WallpaperService.startupVideoRestore || !isVideoWallpaper || image.sourceKey !== "")
            return false;

        if (outgoingImage) {
            var oldOutgoing = outgoingImage;
            outgoingImage = null;
            oldOutgoing.destroy();
        }
        if (displayedImage) {
            var oldDisplayed = displayedImage;
            displayedImage = null;
            oldDisplayed.destroy();
        }
        displayedImage = image;
        displayedImage.opacity = 0;
        displayedImage.z = 0;
        previewCoverTransition = false;
        transitionStarted = true;
        return true;
    }
    function finishTransition() {
        if (outgoingImage) {
            var old = outgoingImage;
            outgoingImage = null;
            old.destroy();
        }
        if (displayedImage) {
            displayedImage.opacity = 1;
            displayedImage.scale = 1;
            displayedImage.z = 0;
        }
        previewCoverTransition = false;
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
    function isPendingStaticCover(image) {
        return pendingStaticTransition && image && normalizedPath(image.sourceKey) === normalizedPath(WallpaperService.selectedPath);
    }
    function isPendingVideoCover(image) {
        return allowVideoFade && WallpaperService.currentMode === "video" && WallpaperService.isTransitionPending && image && normalizedPath(image.sourceKey) === normalizedPath(WallpaperService.pendingVideoThumbnail);
    }
    function isPreviewCover(image) {
        return image && image.previewCover;
    }
    function normalizedPath(path) {
        return String(path || "").replace(/^file:\/\//, "");
    }
    function promoteCandidate(image, generation) {
        if (!image || image !== candidateImage || generation !== sourceGeneration)
            return;

        candidateImage = null;
        image.visible = true;
        image.z = 0;
        currentWall = image.sourceKey;

        if (!displayedImage) {
            displayedImage = image;
            transitionStarted = true;
            if (isPendingVideoCover(image)) {
                previewCoverTransition = false;
                displayedImage.opacity = 1;
                startVideoCommitPulse(image);
                reportVideoCoverReady(image);
                return;
            }
            if (isPendingStaticCover(image)) {
                previewCoverTransition = false;
                displayedImage.opacity = 0;
                initialRevealAnimation.restart();
                return;
            }
            if (isPreviewCover(image)) {
                previewCoverTransition = true;
                displayedImage.opacity = 0;
                initialRevealAnimation.restart();
                return;
            }
            previewCoverTransition = false;
            displayedImage.opacity = 1;
            reportVideoCoverReady(image);
            return;
        }

        if (isPendingVideoCover(image)) {
            previewCoverTransition = false;
            if (outgoingImage) {
                var staleOutgoing = outgoingImage;
                outgoingImage = null;
                staleOutgoing.destroy();
            }
            outgoingImage = displayedImage;
            outgoingImage.opacity = 1;
            outgoingImage.visible = true;
            outgoingImage.z = 0;
            displayedImage = image;
            displayedImage.opacity = 0;
            displayedImage.z = 1;
            transitionStarted = true;
            startVideoCommitPulse(image);
            transitionAnimation.restart();
            return;
        }

        if (finishStartupVideoRestore(image))
            return;

        outgoingImage = displayedImage;
        outgoingImage.opacity = 1;
        outgoingImage.visible = true;
        outgoingImage.z = 0;
        displayedImage = image;
        displayedImage.opacity = 0;
        displayedImage.z = 1;
        previewCoverTransition = isPreviewCover(image);
        transitionStarted = true;
        transitionAnimation.restart();
    }
    function reportStaticCoverReady(image) {
        if (!isPendingStaticCover(image))
            return;
        WallpaperService.markStaticTransitionReady(wallpaperPath, screen ? screen.name : windowNamespace);
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
        if (initialRevealAnimation.running) {
            initialRevealAnimation.stop();
            if (displayedImage) {
                displayedImage.opacity = 1;
                displayedImage.scale = 1;
            }
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
        var previewCover = WallpaperService.previewActive && WallpaperService.currentMode === "video" && normalizedPath(source) === normalizedPath(WallpaperService.previewPath);
        var component = source === "" ? transparentWallpaper : (animateSource ? animatedWallpaper : (useNativeCache ? staticWallpaper : directStaticWallpaper));
        var imageProperties = {
            "requestId": sourceGeneration,
            "sourceKey": source,
            "videoCover": WallpaperService.currentMode === "video" && WallpaperService.isTransitionPending && source !== "",
            "previewCover": previewCover
        };
        if (component === staticWallpaper)
            imageProperties.cacheKey = wallpaperWindow.allowVideoFade && WallpaperService.currentMode === "video" ? String(WallpaperService.videoTransitionGeneration) : "";
        candidateImage = component.createObject(imageHost, imageProperties);
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
    function startVideoCommitPulse(image) {
        if (!isPendingVideoCover(image))
            return false;

        image.opacity = 1;
        image.scale = 1;
        if (WallpaperService.startupVideoRestore)
            return true;

        var generation = WallpaperService.videoTransitionGeneration;
        if (commitRippleGeneration !== generation) {
            commitRippleGeneration = generation;
            commitRipple.opacity = 0.72;
            commitRipple.scale = 0.28;
            commitRippleAnimation.restart();
        }
        return true;
    }

    WlrLayershell.layer: allowVideoFade ? WlrLayer.Bottom : WlrLayer.Background
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
    onIsVideoWallpaperChanged: {
        if (isVideoWallpaper)
            return;
        commitRippleAnimation.stop();
        requestWallpaper();
    }
    onRevealVideoChanged: requestWallpaper()
    onWallpaperPathChanged: requestWallpaper()

    Connections {
        function onPendingVideoThumbnailChanged() {
            if (wallpaperWindow.startVideoCommitPulse(wallpaperWindow.displayedImage))
                wallpaperWindow.reportVideoCoverReady(wallpaperWindow.displayedImage);
        }
        function onStartupVideoRestoreChanged() {
            if (WallpaperService.startupVideoRestore)
                commitRippleAnimation.stop();
        }

        target: WallpaperService
    }
    Item {
        id: imageHost

        anchors.fill: parent
    }
    Rectangle {
        id: commitRipple

        anchors.centerIn: parent
        antialiasing: true
        color: Config.alpha(Config.md3.primary, 0.16)
        height: width
        opacity: 0
        radius: width / 2
        visible: commitRippleAnimation.running || opacity > 0
        width: wallpaperWindow.commitRippleDiameter
        z: 100
    }
    Component {
        id: staticWallpaper

        CachingImage {
            id: staticImage

            readonly property bool blurEngineCover: wallpaperWindow.shouldBlurEngineCover(sourceKey)
            property bool previewCover: false
            property int requestId: 0
            property string sourceKey: ""
            property bool videoCover: false

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            layer.enabled: false
            opacity: 0
            path: sourceKey

            onStatusChanged: wallpaperWindow.imageStatusChanged(staticImage, status)
        }
    }
    Component {
        id: directStaticWallpaper

        Image {
            id: directImage

            readonly property bool blurEngineCover: wallpaperWindow.shouldBlurEngineCover(sourceKey)
            property bool previewCover: false
            property int requestId: 0
            property string sourceKey: ""
            property bool videoCover: false

            anchors.fill: parent
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            layer.enabled: false
            opacity: 0
            source: sourceKey
            sourceSize: Qt.size(Math.ceil(wallpaperWindow.width * Screen.devicePixelRatio), Math.ceil(wallpaperWindow.height * Screen.devicePixelRatio))

            onStatusChanged: wallpaperWindow.imageStatusChanged(directImage, status)
        }
    }
    Component {
        id: animatedWallpaper

        AnimatedImage {
            id: animatedImage

            property bool previewCover: false
            property int requestId: 0
            property string sourceKey: ""
            property bool videoCover: false

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

            property bool previewCover: false
            property int requestId: 0
            property string sourceKey: ""
            property bool videoCover: false

            anchors.fill: parent
            opacity: 0
        }
    }
    ParallelAnimation {
        id: initialRevealAnimation

        onFinished: {
            if (wallpaperWindow.displayedImage) {
                wallpaperWindow.displayedImage.opacity = 1;
                wallpaperWindow.displayedImage.scale = 1;
            }
            wallpaperWindow.reportVideoCoverReady(wallpaperWindow.displayedImage);
            wallpaperWindow.reportStaticCoverReady(wallpaperWindow.displayedImage);
        }

        OpacityAnimator {
            duration: wallpaperWindow.previewCoverTransition ? wallpaperWindow.previewCoverDuration : (wallpaperWindow.isVideoWallpaper ? wallpaperWindow.videoCoverInDuration : Math.max(280, Config.wallpaperTransitionDuration))
            easing.type: wallpaperWindow.previewCoverTransition ? Easing.OutCubic : (wallpaperWindow.isVideoWallpaper ? Easing.InOutSine : Easing.OutCubic)
            from: 0
            target: wallpaperWindow.displayedImage
            to: 1
        }
        ScaleAnimator {
            duration: wallpaperWindow.previewCoverTransition ? wallpaperWindow.previewCoverDuration : (wallpaperWindow.isVideoWallpaper ? wallpaperWindow.videoCoverInDuration : Math.max(340, Config.wallpaperTransitionDuration + 100))
            easing.type: Easing.OutQuint
            from: wallpaperWindow.previewCoverTransition ? 1.04 : (wallpaperWindow.isVideoWallpaper ? 1 : 1.04)
            target: wallpaperWindow.displayedImage
            to: 1
        }
    }
    ParallelAnimation {
        id: commitRippleAnimation

        onFinished: {
            commitRipple.opacity = 0;
            commitRipple.scale = 1;
        }

        ScaleAnimator {
            duration: 360
            easing.type: Easing.OutCubic
            from: 0.28
            target: commitRipple
            to: wallpaperWindow.commitRippleTargetScale
        }
        OpacityAnimator {
            duration: 360
            easing.type: Easing.OutQuad
            from: 0.72
            target: commitRipple
            to: 0
        }
    }
    ParallelAnimation {
        id: transitionAnimation

        onFinished: {
            wallpaperWindow.finishTransition();
            wallpaperWindow.reportVideoCoverReady(wallpaperWindow.displayedImage);
            wallpaperWindow.reportStaticCoverReady(wallpaperWindow.displayedImage);
        }

        OpacityAnimator {
            duration: wallpaperWindow.previewCoverTransition ? wallpaperWindow.previewCoverDuration : (wallpaperWindow.isVideoWallpaper ? wallpaperWindow.videoRevealDuration : Math.max(280, Config.wallpaperTransitionDuration))
            easing.type: wallpaperWindow.previewCoverTransition ? Easing.OutCubic : (wallpaperWindow.isVideoWallpaper ? Easing.InOutSine : Easing.OutCubic)
            from: 0
            target: wallpaperWindow.displayedImage
            to: 1
        }
        OpacityAnimator {
            duration: wallpaperWindow.previewCoverTransition ? wallpaperWindow.previewCoverDuration : (wallpaperWindow.isVideoWallpaper ? wallpaperWindow.videoRevealDuration : Math.max(280, Config.wallpaperTransitionDuration))
            easing.type: wallpaperWindow.previewCoverTransition ? Easing.OutCubic : (wallpaperWindow.isVideoWallpaper ? Easing.InOutSine : Easing.OutCubic)
            from: 1
            target: wallpaperWindow.outgoingImage
            to: 0
        }
        ScaleAnimator {
            duration: wallpaperWindow.previewCoverTransition ? wallpaperWindow.previewCoverDuration : (wallpaperWindow.isVideoWallpaper ? wallpaperWindow.videoRevealDuration : Math.max(340, Config.wallpaperTransitionDuration + 100))
            easing.type: Easing.OutQuint
            from: wallpaperWindow.previewCoverTransition ? 1.04 : (wallpaperWindow.isVideoWallpaper ? 1 : 1.04)
            target: wallpaperWindow.displayedImage
            to: 1.0
        }
        ScaleAnimator {
            duration: wallpaperWindow.previewCoverTransition ? wallpaperWindow.previewCoverDuration : (wallpaperWindow.isVideoWallpaper ? wallpaperWindow.videoRevealDuration : Math.max(340, Config.wallpaperTransitionDuration + 100))
            easing.type: Easing.OutQuint
            from: 1.0
            target: wallpaperWindow.outgoingImage
            to: wallpaperWindow.previewCoverTransition ? 1.03 : (wallpaperWindow.isVideoWallpaper ? 1 : 1.03)
        }
    }
}
