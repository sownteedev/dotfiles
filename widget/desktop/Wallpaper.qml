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
    property bool candidateReady: false
    readonly property real commitRippleDiameter: Math.max(120, Math.min(width, height) * 0.18)
    property int commitRippleGeneration: -1
    readonly property real commitRippleTargetScale: Math.max(1, Math.sqrt(width * width + height * height) * 1.08 / commitRippleDiameter)
    property string currentWall: ""
    property bool decodeAtScreenSize: true
    property Item displayedImage: null
    readonly property int imageFillMode: Config.wallpaperScalingMode === "fit" ? Image.PreserveAspectFit : (Config.wallpaperScalingMode === "stretch" ? Image.Stretch : Image.PreserveAspectCrop)
    property bool isTransitionPending: WallpaperService.isTransitionPending
    property bool isVideoWallpaper: allowVideoFade && WallpaperService.currentMode === "video"
    property Item outgoingImage: null
    property color overlayColor: "transparent"
    readonly property bool pendingStaticTransition: allowVideoFade && WallpaperService.staticTransitionPending && WallpaperService.currentMode === "static"
    readonly property int previewCoverDuration: Math.max(220, Math.min(300, Config.wallpaperTransitionDuration))
    property bool previewCoverTransition: false
    readonly property int previewEffectCount: 16
    property int previewEffectIndex: -1
    readonly property int previewShaderDuration: Math.max(320, Math.min(420, Config.wallpaperTransitionDuration + 100))
    property bool previewTransitionActive: false
    property bool previewTransitionLoaded: false
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

    function completeTransition() {
        previewTransitionActive = false;
        finishTransition();
        reportVideoCoverReady(displayedImage);
        reportStaticCoverReady(displayedImage);
        Qt.callLater(promoteReadyCandidate);
    }
    function effectiveSource() {
        if (revealVideo)
            return "";

        var path = String(wallpaperPath || "");
        return path.startsWith("/") ? "file://" + path : path;
    }
    function fallbackPreviewTransition() {
        if (!previewTransitionActive)
            return;
        previewTransitionActive = false;
        if (displayedImage)
            displayedImage.opacity = 0;
        transitionAnimation.restart();
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
            candidateReady = false;
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
    function nextPreviewEffect() {
        if (previewEffectIndex < 0)
            return Math.floor(Math.random() * previewEffectCount);
        return (previewEffectIndex + 1 + Math.floor(Math.random() * (previewEffectCount - 1))) % previewEffectCount;
    }
    function normalizedPath(path) {
        return String(path || "").replace(/^file:\/\//, "");
    }
    function promoteCandidate(image, generation) {
        if (!image || image !== candidateImage || generation !== sourceGeneration)
            return;

        if (previewTransitionActive || transitionAnimation.running || initialRevealAnimation.running) {
            candidateReady = true;
            return;
        }

        candidateReady = false;
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
            displayedImage.opacity = 0;
            initialRevealAnimation.restart();
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
        if (WallpaperService.previewActive && normalizedPath(image.sourceKey) === normalizedPath(WallpaperService.previewPath) && image.sourceKey !== "" && outgoingImage.sourceKey !== "" && imageHost.GraphicsInfo.api !== GraphicsInfo.Software) {
            outgoingImage.scale = 1;
            displayedImage.scale = 1;
            displayedImage.opacity = 1;
            previewEffectIndex = nextPreviewEffect();
            previewTransitionLoaded = true;
            previewTransitionActive = true;
            return;
        }
        transitionAnimation.restart();
    }
    function promoteReadyCandidate() {
        if (candidateImage && candidateReady)
            promoteCandidate(candidateImage, candidateImage.requestId);
    }
    function reportDisplayedStaticCover() {
        if (!candidateImage && !previewTransitionActive && !transitionAnimation.running && !initialRevealAnimation.running && displayedImage && displayedImage.opacity === 1)
            reportStaticCoverReady(displayedImage);
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
        if (candidateImage) {
            var stale = candidateImage;
            candidateImage = null;
            stale.destroy();
        }
        candidateReady = false;
        if (displayedImage && displayedImage.sourceKey === source)
            return;

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
    onPendingStaticTransitionChanged: {
        if (pendingStaticTransition)
            Qt.callLater(reportDisplayedStaticCover);
    }
    onRevealVideoChanged: requestWallpaper()
    onWallpaperPathChanged: requestWallpaper()

    Connections {
        function onPendingVideoThumbnailChanged() {
            if (!wallpaperWindow.previewTransitionActive && wallpaperWindow.startVideoCommitPulse(wallpaperWindow.displayedImage))
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
    Loader {
        active: wallpaperWindow.previewTransitionLoaded
        anchors.fill: parent
        z: 1

        sourceComponent: WallpaperPreviewTransition {
            active: wallpaperWindow.previewTransitionActive
            duration: wallpaperWindow.previewShaderDuration
            effectIndex: wallpaperWindow.previewEffectIndex
            incomingItem: wallpaperWindow.displayedImage
            outgoingItem: wallpaperWindow.outgoingImage

            onFailed: wallpaperWindow.fallbackPreviewTransition()
            onFinished: Qt.callLater(wallpaperWindow.completeTransition)
        }
    }
    Rectangle {
        anchors.fill: parent
        color: wallpaperWindow.overlayColor
        visible: color.a > 0
        z: 90
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
            cache: false
            fillMode: wallpaperWindow.imageFillMode
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
            cache: false
            fillMode: wallpaperWindow.imageFillMode
            layer.enabled: false
            opacity: 0
            source: sourceKey
            sourceSize: wallpaperWindow.decodeAtScreenSize ? Qt.size(Math.ceil(wallpaperWindow.width * Screen.devicePixelRatio), Math.ceil(wallpaperWindow.height * Screen.devicePixelRatio)) : Qt.size(0, 0)

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
            fillMode: wallpaperWindow.imageFillMode
            opacity: 0
            playing: wallpaperWindow.displayedImage === animatedImage && !wallpaperWindow.previewTransitionActive && !transitionAnimation.running && !WallpaperPlaybackPolicy.shouldPause
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
            Qt.callLater(wallpaperWindow.promoteReadyCandidate);
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

        onFinished: wallpaperWindow.completeTransition()

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
