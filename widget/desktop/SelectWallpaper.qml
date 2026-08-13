import "../../"
import "../../components"
import "../../service"
import Qt.labs.folderlistmodel
import QtQuick
import Quickshell

PanelWindow {
    id: wallpaperWindow

    readonly property int activeCount: activeModel.count
    readonly property var activeModel: selectedMode === "video" ? videoModel : staticModel
    readonly property real cardWidth: Responsive.fit(380, (width - 24) / 1.15, 240)
    readonly property real cardHeight: cardWidth * 240 / 380
    property bool changingMode: false
    property string selectedMode: "static"
    property bool selectionCommitted: false
    readonly property real pathSpan: Math.min(450, Math.max(cardWidth * 0.85, width * 0.34))
    property int staticIndex: 0
    property int videoIndex: 0

    signal dismissed

    function closeSelector() {
        previewTimer.stop();
        preloadTimer.stop();
        rememberCurrentIndex();
        EngineWallpaperService.endBrowsing();
        if (!selectionCommitted) {
            WallpaperService.cancelPreview();
            WallpaperPreviewService.cancel();
        }
        contentRoot.opacity = 0;
        hideTimer.start();
    }
    function openSelector() {
        var targetScreen = StateManager.resolvePanelScreen();
        if (targetScreen)
            screen = targetScreen;
        hideTimer.stop();
        changingMode = true;
        selectionCommitted = false;
        selectedMode = WallpaperService.currentMode;
        if (selectedMode === "video") {
            EngineWallpaperService.beginBrowsing();
            LiveWallpaperService.checkAvailability();
            syncVideoModel();
            WallpaperPreviewService.begin();
        } else {
            WallpaperService.beginPreview();
            WallpaperPreviewService.begin();
        }
        wallpaperWindow.visible = true;
        contentRoot.forceActiveFocus();
        Qt.callLater(() => {
            syncCurrentWallpaper();
            changingMode = false;
            contentRoot.opacity = 1;
            schedulePreview();
        });
    }
    function pathAt(index) {
        return roleAt(index, "filePath", "");
    }
    function preloadNeighbours() {
        if (!wallpaperWindow.visible || changingMode || activeCount < 2)
            return;

        WallpaperPreviewService.resetPreloads();
        var current = pathView.currentIndex;
        var offsets = [1, -1, 2, -2];
        for (var i = 0; i < offsets.length; ++i) {
            var index = (current + offsets[i] + activeCount) % activeCount;
            if (index === current)
                continue;
            var preloadPath = selectedMode === "video" ? videoPreviewImageAt(index) : pathAt(index);
            if (preloadPath)
                WallpaperPreviewService.preload(preloadPath, roleAt(index, "fileModified", 0));
        }
    }
    function previewCurrent() {
        if (!wallpaperWindow.visible || changingMode || pathView.currentIndex < 0)
            return;

        if (selectedMode === "static") {
            var path = pathAt(pathView.currentIndex);
            if (!path)
                return;
            var modified = roleAt(pathView.currentIndex, "fileModified", 0);
            WallpaperService.previewStatic(path);
            WallpaperPreviewService.preview(path, modified);
            preloadTimer.restart();
        } else if (selectedMode === "video") {
            var previewImage = videoPreviewImageAt(pathView.currentIndex);
            if (!previewImage)
                return;
            var videoModified = roleAt(pathView.currentIndex, "fileModified", 0);
            WallpaperPreviewService.preview(previewImage, videoModified);
            preloadTimer.restart();
        }
    }
    function rememberCurrentIndex() {
        if (pathView.currentIndex < 0)
            return;

        if (selectedMode === "video")
            videoIndex = pathView.currentIndex;
        else
            staticIndex = pathView.currentIndex;
    }
    function restoreModeIndex() {
        if (activeCount === 0) {
            pathView.currentIndex = -1;
            return;
        }
        var remembered = selectedMode === "video" ? videoIndex : staticIndex;
        pathView.currentIndex = Math.max(0, Math.min(remembered, activeCount - 1));
    }
    function roleAt(index, role, fallbackValue) {
        if (index < 0 || index >= activeCount)
            return fallbackValue;
        if (selectedMode === "video") {
            var item = videoModel.get(index);
            return item && item[role] !== undefined ? item[role] : fallbackValue;
        }
        var value = staticModel.get(index, role);
        return value !== undefined ? value : fallbackValue;
    }
    function schedulePreview() {
        if (!changingMode) {
            previewTimer.restart();
        }
    }
    function selectCurrentWallpaper() {
        if (!pathView.currentItem)
            return;

        selectionCommitted = true;
        WallpaperService.apply(pathView.currentItem.filePath, selectedMode, pathView.currentItem.fileModified);
        closeSelector();
    }
    function switchMode(mode) {
        if (mode !== "static" && mode !== "video" || mode === selectedMode)
            return false;

        rememberCurrentIndex();
        changingMode = true;
        selectedMode = mode;
        if (mode === "video") {
            previewTimer.stop();
            preloadTimer.stop();
            WallpaperService.cancelPreview();
            WallpaperPreviewService.cancel();
            WallpaperPreviewService.begin();
            EngineWallpaperService.beginBrowsing();
            LiveWallpaperService.checkAvailability();
            syncVideoModel();
        } else {
            EngineWallpaperService.endBrowsing();
            WallpaperPreviewService.cancel();
            WallpaperService.beginPreview();
            WallpaperPreviewService.begin();
        }

        Qt.callLater(() => {
            restoreModeIndex();
            changingMode = false;
            contentRoot.forceActiveFocus();
            schedulePreview();
        });
    }
    function videoPreviewImageAt(index) {
        if (index < 0 || index >= activeCount || selectedMode !== "video")
            return "";

        var isEngine = roleAt(index, "isEngine", false);
        var filePath = pathAt(index);
        var modified = roleAt(index, "fileModified", 0);

        if (isEngine) {
            var preview = roleAt(index, "preview", "");
            if (!preview)
                return "";
            if (EngineWallpaperService.previewNeedsConversion(preview)) {
                var thumbPath = EngineWallpaperService.previewThumbnailPath(preview, modified);
                return EngineWallpaperService.previewThumbnailKnown(preview, modified) ? thumbPath : "";
            }
            return preview;
        }

        // Live wallpaper — use the ffmpeg-generated thumbnail.
        var livePath = LiveWallpaperService.thumbnailPath(filePath, modified);
        return LiveWallpaperService.thumbnailKnown(filePath, modified) ? livePath : "";
    }
    function syncCurrentWallpaper() {
        var currentWall = WallpaperService.currentWallpaper;
        for (var i = 0; i < activeCount; ++i) {
            if (pathAt(i) === currentWall) {
                pathView.currentIndex = i;
                if (selectedMode === "video")
                    videoIndex = i;
                else
                    staticIndex = i;
                return;
            }
        }
        restoreModeIndex();
    }
    function syncVideoModel() {
        videoModel.clear();
        // Add Wallpaper Engine projects.
        for (var i = 0; i < EngineWallpaperService.wallpapers.length; ++i) {
            var wp = EngineWallpaperService.wallpapers[i];
            videoModel.append({
                "filePath": wp.path,
                "fileName": wp.title || wp.id,
                "fileModified": String(wp.modified || 0),
                "isEngine": true,
                "preview": wp.preview || "",
                "type": wp.type || "",
                "file": wp.file || ""
            });
        }
        // Add Live wallpapers
        for (var j = 0; j < liveModel.count; ++j) {
            videoModel.append({
                "filePath": liveModel.get(j, "filePath"),
                "fileName": liveModel.get(j, "fileName"),
                "fileModified": String(liveModel.get(j, "fileModified")),
                "isEngine": false,
                "file": "",
                "type": "video"
            });
        }
        if (wallpaperWindow.visible && wallpaperWindow.selectedMode === "video")
            Qt.callLater(wallpaperWindow.syncCurrentWallpaper);
    }

    aboveWindows: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    anchors.top: true
    color: "transparent"
    focusable: true
    visible: false

    Component.onDestruction: EngineWallpaperService.endBrowsing()

    Timer {
        id: hideTimer

        interval: 200
        repeat: false

        onTriggered: {
            wallpaperWindow.visible = false;
            wallpaperWindow.dismissed();
        }
    }
    Timer {
        id: previewTimer

        interval: 40
        repeat: false

        onTriggered: wallpaperWindow.previewCurrent()
    }
    Timer {
        id: preloadTimer

        interval: 180
        repeat: false

        onTriggered: wallpaperWindow.preloadNeighbours()
    }
    Item {
        id: contentRoot

        anchors.fill: parent
        focus: true
        opacity: 0

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }

        Keys.onEscapePressed: closeSelector()
        Keys.onLeftPressed: pathView.decrementCurrentIndex()
        Keys.onReturnPressed: selectCurrentWallpaper()
        Keys.onRightPressed: pathView.incrementCurrentIndex()
        Keys.onSpacePressed: selectCurrentWallpaper()
        Keys.onTabPressed: pathView.incrementCurrentIndex()

        ListModel {
            id: videoModel
        }
        FolderListModel {
            id: staticModel

            folder: "file://" + Config.wallFolder
            nameFilters: ["*.jpg", "*.png", "*.jpeg", "*.webp", "*.bmp", "*.JPG", "*.PNG", "*.JPEG", "*.WEBP", "*.BMP"]
            showDirs: false

            onCountChanged: {
                if (wallpaperWindow.visible && wallpaperWindow.selectedMode === "static")
                    Qt.callLater(wallpaperWindow.syncCurrentWallpaper);
            }
        }
        FolderListModel {
            id: liveModel

            folder: "file://" + Config.liveWallFolder
            nameFilters: ["*.gif", "*.mp4", "*.webm", "*.mkv", "*.mov", "*.m4v", "*.GIF", "*.MP4", "*.WEBM", "*.MKV", "*.MOV", "*.M4V"]
            showDirs: false

            onCountChanged: Qt.callLater(wallpaperWindow.syncVideoModel)

            onStatusChanged: {
                if (status === FolderListModel.Ready)
                    wallpaperWindow.syncVideoModel();
            }
        }
        Connections {
            function onWallpapersChanged() {
                wallpaperWindow.syncVideoModel();
            }

            target: EngineWallpaperService
        }
        WallpaperModeSwitch {
            id: modeSwitch

            anchors.bottom: pathView.top
            anchors.bottomMargin: -48
            anchors.horizontalCenter: parent.horizontalCenter
            mode: wallpaperWindow.selectedMode
            z: 300

            onModeRequested: mode => {
                return wallpaperWindow.switchMode(mode);
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: modeSwitch.bottom
            anchors.topMargin: 10
            color: Config.md3.tertiary
            elide: Text.ElideRight
            font.family: Config.fontName
            font.pixelSize: 13
            font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter
            text: {
                if (wallpaperWindow.selectedMode !== "video")
                    return "";

                var msgs = [];
                if (!EngineWallpaperService.available && EngineWallpaperService.availabilityKnown)
                    msgs.push("Install linux-wallpaperengine");

                if (!LiveWallpaperService.available && LiveWallpaperService.availabilityKnown)
                    msgs.push("Install mpvpaper");

                return msgs.length > 0 ? "Missing: " + msgs.join(" / ") : "";
            }
            visible: wallpaperWindow.selectedMode === "video" && ((!LiveWallpaperService.available && LiveWallpaperService.availabilityKnown) || (!EngineWallpaperService.available && EngineWallpaperService.availabilityKnown))
            width: Math.max(0, parent.width - 24)
            z: 300
        }
        PathView {
            id: pathView

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            delegate: wallpaperDelegate
            height: Math.min(400, parent.height * 0.56)
            highlightRangeMode: PathView.StrictlyEnforceRange
            model: wallpaperWindow.activeModel
            pathItemCount: wallpaperWindow.width < 1000 ? 5 : 7
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5

            path: Path {
                startX: pathView.width / 2 - wallpaperWindow.pathSpan
                startY: pathView.height / 2

                PathAttribute {
                    name: "itemScale"
                    value: 0.55
                }
                PathAttribute {
                    name: "itemZ"
                    value: 1
                }
                PathAttribute {
                    name: "itemOpacity"
                    value: 0.3
                }
                PathLine {
                    x: pathView.width / 2
                    y: pathView.height / 2
                }
                PathAttribute {
                    name: "itemScale"
                    value: 1.15
                }
                PathAttribute {
                    name: "itemZ"
                    value: 100
                }
                PathAttribute {
                    name: "itemOpacity"
                    value: 1
                }
                PathLine {
                    x: pathView.width / 2 + wallpaperWindow.pathSpan
                    y: pathView.height / 2
                }
                PathAttribute {
                    name: "itemScale"
                    value: 0.55
                }
                PathAttribute {
                    name: "itemZ"
                    value: 1
                }
                PathAttribute {
                    name: "itemOpacity"
                    value: 0.3
                }
            }

            onCurrentIndexChanged: {
                if (!wallpaperWindow.changingMode) {
                    wallpaperWindow.rememberCurrentIndex();
                    wallpaperWindow.schedulePreview();
                }
            }

            MouseArea {
                acceptedButtons: Qt.NoButton
                anchors.fill: parent

                onWheel: wheel => {
                    if (wheel.angleDelta.y > 0)
                        pathView.decrementCurrentIndex();
                    else if (wheel.angleDelta.y < 0)
                        pathView.incrementCurrentIndex();
                }
            }
        }
        Column {
            anchors.centerIn: parent
            spacing: 8
            visible: wallpaperWindow.activeCount === 0
            width: Math.max(0, parent.width - 24)

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: Config.md3.on_surface
                elide: Text.ElideRight
                font.family: Config.fontName
                font.pixelSize: 18
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                text: wallpaperWindow.selectedMode === "video" ? (EngineWallpaperService.scanning ? "Scanning Steam Workshop…" : "No videos") : "No static wallpapers"
                width: parent.width
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: Config.md3.on_surface_variant
                elide: Text.ElideMiddle
                font.family: Config.fontName
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                text: wallpaperWindow.selectedMode === "video" ? (Config.wallpaperEngineWorkshopDir + " / " + Config.liveWallFolder) : Config.wallFolder
                width: parent.width
            }
        }
    }
    Component {
        id: wallpaperDelegate

        Item {
            id: delegateRoot

            readonly property bool convertedEnginePreview: isEngine && EngineWallpaperService.previewNeedsConversion(previewPath)
            readonly property string engineThumbnail: convertedEnginePreview ? EngineWallpaperService.previewThumbnailPath(previewPath, fileModified) : previewPath
            property bool engineThumbnailAvailable: !convertedEnginePreview || EngineWallpaperService.previewThumbnailKnown(previewPath, fileModified)
            readonly property var fileModified: wallpaperWindow.roleAt(index, "fileModified", 0)
            readonly property string filePath: wallpaperWindow.roleAt(index, "filePath", "")
            readonly property string fileUrl: wallpaperWindow.roleAt(index, "fileUrl", "")
            required property int index
            readonly property bool isEngine: wallpaperWindow.roleAt(index, "isEngine", false)
            readonly property bool live: wallpaperWindow.selectedMode === "video" && !isEngine && LiveWallpaperService.isLivePath(filePath)
            readonly property string liveThumbnail: live ? LiveWallpaperService.thumbnailPath(filePath, fileModified) : ""
            property bool permitThumbnailLoad: false
            readonly property string previewPath: wallpaperWindow.roleAt(index, "preview", "")
            property bool thumbnailAvailable: !live || LiveWallpaperService.thumbnailKnown(filePath, fileModified)
            property int thumbnailRevision: 0

            function circularDistanceFromCurrent() {
                var count = Math.max(1, wallpaperWindow.activeCount);
                var distance = Math.abs(index - pathView.currentIndex);
                return Math.min(distance, count - distance);
            }
            function requestCurrentThumbnail() {
                if (live) {
                    thumbnailAvailable = LiveWallpaperService.thumbnailKnown(filePath, fileModified);
                    LiveWallpaperService.requestThumbnail(filePath, fileModified, PathView.isCurrentItem);
                } else if (convertedEnginePreview) {
                    engineThumbnailAvailable = EngineWallpaperService.previewThumbnailKnown(previewPath, fileModified);
                    EngineWallpaperService.requestPreviewThumbnail(previewPath, fileModified, PathView.isCurrentItem);
                }
            }
            function scheduleThumbnailLoad() {
                if (PathView.isCurrentItem || (!live && !convertedEnginePreview)) {
                    // Static images and current item: load immediately.
                    permitThumbnailLoad = true;
                    requestCurrentThumbnail();
                    return;
                }
                // Video thumbnails that need generation: short staggered delay.
                thumbnailLoadTimer.interval = 40 * Math.max(1, circularDistanceFromCurrent());
                thumbnailLoadTimer.restart();
            }

            height: wallpaperWindow.cardHeight
            opacity: PathView.itemOpacity !== undefined ? PathView.itemOpacity : 0
            scale: PathView.itemScale !== undefined ? PathView.itemScale : 0.55
            width: wallpaperWindow.cardWidth
            z: PathView.itemZ !== undefined ? PathView.itemZ : 1

            transform: Shear {
                origin.x: delegateRoot.width / 2
                origin.y: delegateRoot.height / 2
                xAngle: -12.4
            }

            Component.onCompleted: {
                scheduleThumbnailLoad();
            }
            onFileModifiedChanged: {
                permitThumbnailLoad = false;
                Qt.callLater(delegateRoot.scheduleThumbnailLoad);
            }
            onFilePathChanged: {
                permitThumbnailLoad = false;
                Qt.callLater(delegateRoot.scheduleThumbnailLoad);
            }
            onPreviewPathChanged: {
                permitThumbnailLoad = false;
                Qt.callLater(delegateRoot.scheduleThumbnailLoad);
            }

            Connections {
                function onCurrentIndexChanged() {
                    if (!delegateRoot.permitThumbnailLoad)
                        delegateRoot.scheduleThumbnailLoad();
                    else
                        delegateRoot.requestCurrentThumbnail();
                }

                target: pathView
            }
            Timer {
                id: thumbnailLoadTimer

                repeat: false

                onTriggered: {
                    delegateRoot.permitThumbnailLoad = true;
                    delegateRoot.requestCurrentThumbnail();
                }
            }

            Connections {
                function onThumbnailReady(sourcePath, thumbnailPath) {
                    if (delegateRoot.live && sourcePath === delegateRoot.filePath && thumbnailPath === delegateRoot.liveThumbnail) {
                        delegateRoot.thumbnailAvailable = true;
                        ++delegateRoot.thumbnailRevision;
                        if (delegateRoot.PathView.isCurrentItem)
                            wallpaperWindow.schedulePreview();
                    }
                }

                target: LiveWallpaperService
            }
            Connections {
                function onPreviewThumbnailReady(sourcePath, thumbnailPath) {
                    if (delegateRoot.convertedEnginePreview && sourcePath === delegateRoot.previewPath && thumbnailPath === delegateRoot.engineThumbnail) {
                        delegateRoot.engineThumbnailAvailable = true;
                        ++delegateRoot.thumbnailRevision;
                        if (delegateRoot.PathView.isCurrentItem)
                            wallpaperWindow.schedulePreview();
                    }
                }

                target: EngineWallpaperService
            }
            Rectangle {
                anchors.fill: parent
                border.color: Config.md3.outline
                border.width: 10
                clip: true
                color: Config.alpha(Config.md3.surface, 0.8)
                radius: 12

                CachingImage {
                    anchors.fill: parent
                    cacheKey: String(delegateRoot.fileModified) + "-" + String(delegateRoot.thumbnailRevision)
                    fillMode: Image.PreserveAspectCrop
                    path: {
                        if (delegateRoot.live)
                            return (delegateRoot.permitThumbnailLoad && delegateRoot.thumbnailAvailable) ? delegateRoot.liveThumbnail : "";

                        if (delegateRoot.isEngine) {
                            if (delegateRoot.convertedEnginePreview)
                                return (delegateRoot.permitThumbnailLoad && delegateRoot.engineThumbnailAvailable) ? delegateRoot.engineThumbnail : "";
                            return delegateRoot.engineThumbnail;
                        }

                        return delegateRoot.filePath;
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: delegateRoot.PathView.isCurrentItem ? 0 : 0.6
                    radius: 12

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: {
                        if (pathView.currentIndex === index)
                            wallpaperWindow.selectCurrentWallpaper();
                        else
                            pathView.currentIndex = index;
                        contentRoot.forceActiveFocus();
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    border.color: Config.alpha(Config.md3.on_surface, 0.22)
                    border.width: 1
                    color: Config.alpha(Config.md3.background, 0.72)
                    enabled: false
                    height: 48
                    radius: width / 2
                    visible: wallpaperWindow.selectedMode === "video"
                    width: 48

                    Text {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 2
                        color: Config.md3.on_surface
                        font.family: Config.fontName
                        font.pixelSize: 20
                        text: "▶"
                    }
                }
            }
        }
    }
}
