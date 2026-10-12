import "../../"
import "../../components"
import "../../service"
import Qt.labs.folderlistmodel
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets

PanelWindow {
    id: wallpaperWindow

    readonly property int activeCount: activeModel.count
    readonly property var activeModel: selectedMode === "video" ? videoModel : staticModel
    readonly property bool browserOpen: workshopOpen || wallhavenOpen
    readonly property bool canTrashDragged: draggedPath !== "" && draggedPath !== WallpaperService.currentWallpaper
    readonly property real cardHeight: cardWidth * 240 / 380
    readonly property real cardWidth: Responsive.fit(380, (width - 24) / 1.15, 240)
    property bool changingMode: false
    property string deleteMessage: ""
    property string deletingPath: ""
    property var dragCard: null
    property string draggedPath: ""
    property string initialSelectionPath: ""
    readonly property bool interactionLocked: browserOpen || dragCard !== null || deletingPath !== ""
    property string lastPreviewSource: ""
    property int openGeneration: 0
    readonly property real pathSpan: Math.min(450, Math.max(cardWidth * 0.85, width * 0.34))
    property string selectedMode: "static"
    readonly property bool selectedVideoNeedsEngine: selectedMode === "video" && roleAt(pathView.currentIndex, "isEngine", false) && String(roleAt(pathView.currentIndex, "type", "")).toLowerCase() !== "video"
    property bool selectionCommitted: false
    property int staticIndex: 0
    readonly property bool trashArmed: dragCard !== null && dragCard.armed && canTrashDragged
    readonly property real trashCenterX: width / 2
    readonly property real trashCenterY: Math.min(height - 92, height / 2 + cardHeight * 0.575 + 78)
    property int videoIndex: 0
    property bool videoPreviewStarted: false
    property bool wallhavenOpen: false
    property bool workshopOpen: false

    signal dismissed

    function closeSelector() {
        if (dragCard)
            dragCard.cancelDrag();
        dragCard = null;
        draggedPath = "";
        openGeneration += 1;
        previewTimer.stop();
        preloadTimer.stop();
        rememberCurrentIndex();
        EngineWallpaperService.endBrowsing();
        LiveWallpaperService.endBrowsing();
        if (!selectionCommitted) {
            WallpaperService.cancelPreview();
            WallpaperPreviewService.cancel();
        }
        contentRoot.opacity = 0;
        hideTimer.start();
        wallhavenOpen = false;
        workshopOpen = false;
    }
    function finishDrag(card, path, accepted) {
        if (dragCard !== card)
            return;

        var canDelete = canTrashDragged;
        dragCard = null;
        draggedPath = "";
        if (!accepted || !canDelete)
            return;

        deletingPath = path;
        deleteMessage = "";
        previewTimer.stop();
        preloadTimer.stop();
        deleteTimer.start();
    }
    function handleVideoCoverReady(sourcePath, coverPath, engineSource) {
        if (!wallpaperWindow.visible || selectedMode !== "video" || !videoPreviewStarted || pathView.currentIndex < 0)
            return;

        for (var i = 0; i < activeCount; ++i) {
            var isEngine = roleAt(i, "isEngine", false);
            if (isEngine !== engineSource)
                continue;

            var modified = roleAt(i, "fileModified", 0);
            var expectedSource = isEngine ? roleAt(i, "preview", "") : pathAt(i);
            var expectedCover = isEngine ? EngineWallpaperService.previewCoverPath(expectedSource, modified) : LiveWallpaperService.coverPath(expectedSource, modified);
            if (sourcePath !== expectedSource || coverPath !== expectedCover)
                continue;

            if (i === pathView.currentIndex) {
                schedulePreview();
            } else {
                var distance = Math.abs(i - pathView.currentIndex);
                distance = Math.min(distance, activeCount - distance);
                if (distance <= 1)
                    WallpaperPreviewService.preload(coverPath, modified);
            }
            return;
        }
    }
    function openSelector() {
        var generation = ++openGeneration;
        var targetScreen = StateManager.resolvePanelScreen();
        if (targetScreen)
            screen = targetScreen;

        hideTimer.stop();
        changingMode = true;
        initialSelectionPath = String(WallpaperService.currentWallpaper || "");
        lastPreviewSource = "";
        selectionCommitted = false;
        deleteMessage = "";
        wallhavenOpen = false;
        workshopOpen = false;
        selectedMode = WallpaperService.currentMode;
        videoPreviewStarted = false;
        wallpaperWindow.visible = true;
        if (selectedMode === "video") {
            WallpaperService.beginPreview();
            EngineWallpaperService.beginBrowsing();
            LiveWallpaperService.beginBrowsing();
            LiveWallpaperService.checkAvailability();
            syncVideoModel();
            WallpaperPreviewService.begin();
        } else {
            WallpaperService.beginPreview();
            WallpaperPreviewService.begin();
        }
        contentRoot.forceActiveFocus();
        Qt.callLater(() => {
            if (generation !== openGeneration || !wallpaperWindow.visible || hideTimer.running)
                return;

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
        if (!wallpaperWindow.visible || changingMode || browserOpen || activeCount < 2)
            return;

        WallpaperPreviewService.resetPreloads();
        var current = pathView.currentIndex;
        var offsets = selectedMode === "video" ? [1, -1] : [1, -1, 2, -2];
        for (var i = 0; i < offsets.length; ++i) {
            var index = (current + offsets[i] + activeCount) % activeCount;
            if (index === current)
                continue;

            if (selectedMode === "video")
                requestVideoCoverAt(index, false);
            var preloadPath = selectedMode === "video" ? videoPreviewImageAt(index) : pathAt(index);
            if (preloadPath)
                WallpaperPreviewService.preload(preloadPath, roleAt(index, "fileModified", 0));
        }
    }
    function previewCurrent() {
        if (!wallpaperWindow.visible || changingMode || initialSelectionPath !== "" || interactionLocked || pathView.currentIndex < 0)
            return;

        if (selectedMode === "static") {
            var path = pathAt(pathView.currentIndex);
            if (!path)
                return;

            var modified = roleAt(pathView.currentIndex, "fileModified", 0);
            previewSource(path, modified);
            preloadTimer.restart();
        } else if (selectedMode === "video") {
            var currentIndex = pathView.currentIndex;
            var videoModified = roleAt(currentIndex, "fileModified", 0);
            requestVideoCoverAt(currentIndex, true);

            var previewImage = videoPreviewImageAt(currentIndex);
            if (!previewImage)
                return;

            previewSource(previewImage, videoModified);
            preloadTimer.restart();
        }
    }
    function previewSource(path, modified) {
        var source = String(path || "");
        if (!source)
            return;

        if (lastPreviewSource !== source) {
            lastPreviewSource = source;
            WallpaperService.previewStatic(source);
        }
        WallpaperPreviewService.preview(source, modified);
    }
    function rememberCurrentIndex() {
        if (pathView.currentIndex < 0)
            return;

        if (selectedMode === "video")
            videoIndex = pathView.currentIndex;
        else
            staticIndex = pathView.currentIndex;
    }
    function replaceStaticModel(items) {
        for (var targetIndex = 0; targetIndex < items.length; ++targetIndex) {
            var item = items[targetIndex];
            var currentIndex = staticModelIndexForPath(item.filePath);
            if (currentIndex < 0) {
                staticModel.insert(targetIndex, item);
            } else {
                if (currentIndex !== targetIndex)
                    staticModel.move(currentIndex, targetIndex, 1);

                staticModel.set(targetIndex, item);
            }
        }
        if (staticModel.count > items.length)
            staticModel.remove(items.length, staticModel.count - items.length);
    }
    function replaceVideoModel(items) {
        for (var targetIndex = 0; targetIndex < items.length; ++targetIndex) {
            var item = items[targetIndex];
            var currentIndex = videoModelIndexForPath(item.filePath);
            if (currentIndex < 0) {
                videoModel.insert(targetIndex, item);
            } else {
                if (currentIndex !== targetIndex)
                    videoModel.move(currentIndex, targetIndex, 1);

                videoModel.set(targetIndex, item);
            }
        }
        if (videoModel.count > items.length)
            videoModel.remove(items.length, videoModel.count - items.length);
    }
    function requestVideoCoverAt(index, priority) {
        if (index < 0 || index >= activeCount || selectedMode !== "video")
            return "";

        var filePath = pathAt(index);
        var modified = roleAt(index, "fileModified", 0);
        if (roleAt(index, "isEngine", false)) {
            if (filePath === EngineWallpaperService.activePath && EngineWallpaperService.validatedFramePath !== "")
                return EngineWallpaperService.validatedFramePath;
            if (EngineWallpaperService.renderedPreviewKnown(filePath))
                return EngineWallpaperService.renderedPreviewPath(filePath);

            var previewPath = roleAt(index, "preview", "");
            if (!previewPath)
                return "";
            if (!EngineWallpaperService.previewNeedsConversion(previewPath))
                return previewPath;

            return EngineWallpaperService.requestPreviewCover(previewPath, modified, priority === true);
        }

        return LiveWallpaperService.requestCover(filePath, modified, priority === true);
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
        var item = staticModel.get(index);
        return item && item[role] !== undefined ? item[role] : fallbackValue;
    }
    function schedulePreview(immediate) {
        if (changingMode || initialSelectionPath !== "" || browserOpen || (selectedMode === "video" && !videoPreviewStarted))
            return;

        if (immediate === true) {
            previewTimer.stop();
            previewCurrent();
        } else if (!previewTimer.running) {
            previewTimer.start();
        }
    }
    function selectCurrentWallpaper() {
        if (interactionLocked || !pathView.currentItem)
            return;

        selectionCommitted = true;
        WallpaperService.apply(pathView.currentItem.filePath, selectedMode, pathView.currentItem.fileModified);
        closeSelector();
    }
    function startUserNavigation() {
        initialSelectionPath = "";
        if (selectedMode === "video")
            videoPreviewStarted = true;
    }
    function staticModelIndexForPath(path) {
        var expectedPath = String(path || "");
        for (var i = 0; i < staticModel.count; ++i) {
            if (String(staticModel.get(i).filePath || "") === expectedPath)
                return i;
        }
        return -1;
    }
    function switchMode(mode) {
        if (interactionLocked || mode !== "static" && mode !== "video" || mode === selectedMode)
            return false;

        rememberCurrentIndex();
        changingMode = true;
        initialSelectionPath = "";
        lastPreviewSource = "";
        selectedMode = mode;
        if (mode === "video") {
            videoPreviewStarted = false;
            previewTimer.stop();
            preloadTimer.stop();
            WallpaperService.beginPreview();
            WallpaperPreviewService.cancel();
            WallpaperPreviewService.begin();
            EngineWallpaperService.beginBrowsing();
            LiveWallpaperService.beginBrowsing();
            LiveWallpaperService.checkAvailability();
            syncVideoModel();
        } else {
            EngineWallpaperService.endBrowsing();
            LiveWallpaperService.endBrowsing();
            WallpaperPreviewService.cancel();
            WallpaperService.beginPreview();
            WallpaperPreviewService.begin();
        }
        var generation = openGeneration;
        Qt.callLater(() => {
            if (generation !== openGeneration || !wallpaperWindow.visible || hideTimer.running)
                return;

            restoreModeIndex();
            changingMode = false;
            contentRoot.forceActiveFocus();
            schedulePreview();
        });
    }
    function syncCurrentWallpaper(preferredPath) {
        var currentWall = String(initialSelectionPath || preferredPath || WallpaperService.currentWallpaper || "");
        for (var i = 0; i < activeCount; ++i) {
            if (pathAt(i) === currentWall) {
                pathView.currentIndex = i;
                if (selectedMode === "video")
                    videoIndex = i;
                else
                    staticIndex = i;
                if (currentWall === initialSelectionPath) {
                    initialSelectionPath = "";
                    schedulePreview();
                }
                return;
            }
        }
        if (initialSelectionPath !== "")
            return;

        restoreModeIndex();
    }
    function syncStaticModel() {
        if (!wallpaperWindow.visible)
            return;

        var preferredPath = initialSelectionPath || (selectedMode === "static" ? pathAt(pathView.currentIndex) : "");
        var items = [];
        var knownPaths = {};
        var sources = [personalStaticModel, wallhavenStaticFolderModel];
        for (var sourceIndex = 0; sourceIndex < sources.length; ++sourceIndex) {
            var source = sources[sourceIndex];
            for (var itemIndex = 0; itemIndex < source.count; ++itemIndex) {
                var filePath = String(source.get(itemIndex, "filePath") || "");
                if (filePath === "" || knownPaths[filePath])
                    continue;

                knownPaths[filePath] = true;
                items.push({
                    "fileModified": String(source.get(itemIndex, "fileModified") || 0),
                    "fileName": String(source.get(itemIndex, "fileName") || ""),
                    "filePath": filePath,
                    "fileUrl": String(source.get(itemIndex, "fileUrl") || "")
                });
            }
        }
        replaceStaticModel(items);
        if (selectedMode === "static")
            Qt.callLater(() => {
                return wallpaperWindow.syncCurrentWallpaper(preferredPath);
            });
    }
    function syncVideoModel() {
        if (!wallpaperWindow.visible)
            return;

        var preferredPath = initialSelectionPath || (selectedMode === "video" ? pathAt(pathView.currentIndex) : "");
        var items = [];
        // Add Wallpaper Engine projects.
        for (var i = 0; i < EngineWallpaperService.wallpapers.length; ++i) {
            var wp = EngineWallpaperService.wallpapers[i];
            items.push({
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
            items.push({
                "filePath": liveModel.get(j, "filePath"),
                "fileName": liveModel.get(j, "fileName"),
                "fileModified": String(liveModel.get(j, "fileModified")),
                "isEngine": false,
                "file": "",
                "type": "video"
            });
        }
        replaceVideoModel(items);
        if (wallpaperWindow.visible && wallpaperWindow.selectedMode === "video")
            Qt.callLater(() => {
                return wallpaperWindow.syncCurrentWallpaper(preferredPath);
            });
    }
    function videoModelIndexForPath(path) {
        var expectedPath = String(path || "");
        for (var i = 0; i < videoModel.count; ++i) {
            if (String(videoModel.get(i).filePath || "") === expectedPath)
                return i;
        }
        return -1;
    }
    function videoPreviewImageAt(index) {
        if (index < 0 || index >= activeCount || selectedMode !== "video")
            return "";

        var isEngine = roleAt(index, "isEngine", false);
        var filePath = pathAt(index);
        var modified = roleAt(index, "fileModified", 0);
        if (isEngine) {
            if (filePath === EngineWallpaperService.activePath && EngineWallpaperService.validatedFramePath !== "")
                return EngineWallpaperService.validatedFramePath;

            var renderedPreview = EngineWallpaperService.renderedPreviewPath(filePath);
            if (EngineWallpaperService.renderedPreviewKnown(filePath))
                return renderedPreview;

            var preview = roleAt(index, "preview", "");
            if (!preview)
                return "";

            if (EngineWallpaperService.previewNeedsConversion(preview)) {
                var coverPath = EngineWallpaperService.previewCoverPath(preview, modified);
                if (EngineWallpaperService.previewCoverKnown(preview, modified))
                    return coverPath;
                return "";
            }
            return preview;
        }
        var liveCover = LiveWallpaperService.coverPath(filePath, modified);
        return LiveWallpaperService.coverKnown(filePath, modified) ? liveCover : "";
    }
    function videoThumbnailImageAt(index) {
        if (index < 0 || index >= activeCount || selectedMode !== "video")
            return "";

        var filePath = pathAt(index);
        var modified = roleAt(index, "fileModified", 0);
        if (roleAt(index, "isEngine", false)) {
            var preview = roleAt(index, "preview", "");
            if (!preview)
                return "";
            if (!EngineWallpaperService.previewNeedsConversion(preview))
                return preview;

            var thumbnailPath = EngineWallpaperService.previewThumbnailPath(preview, modified);
            return EngineWallpaperService.previewThumbnailKnown(preview, modified) ? thumbnailPath : "";
        }

        var livePath = LiveWallpaperService.thumbnailPath(filePath, modified);
        return LiveWallpaperService.thumbnailKnown(filePath, modified) ? livePath : "";
    }

    aboveWindows: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    anchors.top: true
    color: "transparent"
    focusable: true
    visible: false

    Component.onDestruction: {
        EngineWallpaperService.endBrowsing();
        LiveWallpaperService.endBrowsing();
    }
    onBrowserOpenChanged: {
        if (browserOpen) {
            previewTimer.stop();
            preloadTimer.stop();
            return;
        }
        if (visible && !changingMode && !hideTimer.running) {
            contentRoot.forceActiveFocus();
            schedulePreview();
        }
    }

    Timer {
        id: deleteTimer

        interval: 180

        onTriggered: {
            WallpaperService.cancelPreview();
            WallpaperPreviewService.cancel();
            wallpaperWindow.lastPreviewSource = "";
            if (!WallpaperService.removeWallpaper(wallpaperWindow.deletingPath)) {
                wallpaperWindow.deletingPath = "";
                wallpaperWindow.deleteMessage = qsTr("Cannot delete this wallpaper. Choose another wallpaper if it is in use.");
                if (wallpaperWindow.visible && !hideTimer.running) {
                    WallpaperService.beginPreview();
                    WallpaperPreviewService.begin();
                    wallpaperWindow.schedulePreview();
                }
            }
        }
    }
    Connections {
        function onRemovalFinished(path, success, message) {
            if (path !== wallpaperWindow.deletingPath)
                return;

            if (success) {
                var model = wallpaperWindow.activeModel;
                for (var index = model.count - 1; index >= 0; --index) {
                    if (String(model.get(index).filePath) === path)
                        model.remove(index);
                }
            }
            wallpaperWindow.deletingPath = "";
            wallpaperWindow.deleteMessage = success ? "" : message;
            if (wallpaperWindow.visible && !hideTimer.running) {
                WallpaperService.beginPreview();
                WallpaperPreviewService.begin();
                wallpaperWindow.schedulePreview();
            }
        }

        target: WallpaperService
    }
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

        interval: 120
        repeat: false

        onTriggered: wallpaperWindow.previewCurrent()
    }
    Timer {
        id: preloadTimer

        interval: 180
        repeat: false

        onTriggered: wallpaperWindow.preloadNeighbours()
    }
    Connections {
        function onPreviewThumbnailReady(sourcePath, thumbnailPath) {
            wallpaperWindow.handleVideoCoverReady(sourcePath, thumbnailPath, true);
        }

        target: EngineWallpaperService
    }
    Connections {
        function onThumbnailReady(sourcePath, thumbnailPath) {
            wallpaperWindow.handleVideoCoverReady(sourcePath, thumbnailPath, false);
        }

        target: LiveWallpaperService
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

        Keys.onEscapePressed: {
            if (wallpaperWindow.dragCard)
                wallpaperWindow.dragCard.cancelDrag();
            else if (wallpaperWindow.wallhavenOpen)
                wallpaperWindow.wallhavenOpen = false;
            else if (wallpaperWindow.workshopOpen)
                wallpaperWindow.workshopOpen = false;
            else
                closeSelector();
        }
        Keys.onLeftPressed: {
            if (!wallpaperWindow.interactionLocked) {
                wallpaperWindow.startUserNavigation();
                pathView.decrementCurrentIndex();
            }
        }
        Keys.onReturnPressed: {
            if (!wallpaperWindow.interactionLocked) {
                wallpaperWindow.startUserNavigation();
                selectCurrentWallpaper();
            }
        }
        Keys.onRightPressed: {
            if (!wallpaperWindow.interactionLocked) {
                wallpaperWindow.startUserNavigation();
                pathView.incrementCurrentIndex();
            }
        }
        Keys.onSpacePressed: {
            if (!wallpaperWindow.interactionLocked) {
                wallpaperWindow.startUserNavigation();
                selectCurrentWallpaper();
            }
        }
        Keys.onTabPressed: {
            if (!wallpaperWindow.interactionLocked) {
                wallpaperWindow.startUserNavigation();
                pathView.incrementCurrentIndex();
            }
        }

        ListModel {
            id: videoModel
        }
        ListModel {
            id: staticModel
        }
        FolderListModel {
            id: personalStaticModel

            folder: wallpaperWindow.visible ? "file://" + Config.wallFolder : ""
            nameFilters: ["*.jpg", "*.png", "*.jpeg", "*.webp", "*.bmp", "*.JPG", "*.PNG", "*.JPEG", "*.WEBP", "*.BMP"]
            showDirs: false

            onCountChanged: {
                if (wallpaperWindow.visible)
                    Qt.callLater(wallpaperWindow.syncStaticModel);
            }
            onStatusChanged: {
                if (wallpaperWindow.visible && status === FolderListModel.Ready)
                    wallpaperWindow.syncStaticModel();
            }
        }
        FolderListModel {
            id: wallhavenStaticFolderModel

            folder: wallpaperWindow.visible ? "file://" + Config.wallhavenCacheFolder : ""
            nameFilters: ["*.jpg", "*.png", "*.jpeg", "*.webp", "*.JPG", "*.PNG", "*.JPEG", "*.WEBP"]
            showDirs: false

            onCountChanged: {
                if (wallpaperWindow.visible)
                    Qt.callLater(wallpaperWindow.syncStaticModel);
            }
            onStatusChanged: {
                if (wallpaperWindow.visible && status === FolderListModel.Ready)
                    wallpaperWindow.syncStaticModel();
            }
        }
        FolderListModel {
            id: liveModel

            folder: wallpaperWindow.visible ? "file://" + Config.liveWallFolder : ""
            nameFilters: ["*.gif", "*.mp4", "*.webm", "*.mkv", "*.mov", "*.m4v", "*.GIF", "*.MP4", "*.WEBM", "*.MKV", "*.MOV", "*.M4V"]
            showDirs: false

            onCountChanged: {
                if (wallpaperWindow.visible)
                    Qt.callLater(wallpaperWindow.syncVideoModel);
            }
            onStatusChanged: {
                if (wallpaperWindow.visible && status === FolderListModel.Ready)
                    wallpaperWindow.syncVideoModel();
            }
        }
        Connections {
            function onDataChanged() {
                wallpaperWindow.syncVideoModel();
            }
            function onModelReset() {
                wallpaperWindow.syncVideoModel();
            }
            function onRowsInserted() {
                wallpaperWindow.syncVideoModel();
            }
            function onRowsRemoved() {
                wallpaperWindow.syncVideoModel();
            }

            enabled: wallpaperWindow.visible
            target: liveModel
        }
        Connections {
            function onKnownPreviewThumbnailsChanged() {
                if (wallpaperWindow.visible && wallpaperWindow.selectedMode === "video" && wallpaperWindow.videoPreviewStarted)
                    wallpaperWindow.schedulePreview();
            }
            function onValidatedFramePathChanged() {
                if (wallpaperWindow.visible && wallpaperWindow.selectedMode === "video" && wallpaperWindow.videoPreviewStarted)
                    wallpaperWindow.schedulePreview();
            }
            function onWallpapersChanged() {
                if (wallpaperWindow.visible)
                    wallpaperWindow.syncVideoModel();
            }

            target: EngineWallpaperService
        }
        Row {
            id: wallpaperToolbar

            anchors.bottom: pathView.top
            anchors.bottomMargin: -48
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            z: 300

            WallpaperModeSwitch {
                id: modeSwitch

                enabled: !wallpaperWindow.interactionLocked
                mode: wallpaperWindow.selectedMode

                onAddRequested: mode => {
                    if (mode === "video")
                        wallpaperWindow.workshopOpen = true;
                    else
                        wallpaperWindow.wallhavenOpen = true;
                }
                onModeRequested: mode => {
                    return wallpaperWindow.switchMode(mode);
                }
            }
        }
        Text {
            anchors.bottom: wallpaperToolbar.top
            anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
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
                if (wallpaperWindow.selectedVideoNeedsEngine && !EngineWallpaperService.available && EngineWallpaperService.availabilityKnown)
                    msgs.push(qsTr("Install linux-wallpaperengine"));

                return msgs.length > 0 ? qsTr("Missing: %1").arg(msgs.join(" / ")) : "";
            }
            visible: wallpaperWindow.selectedVideoNeedsEngine && !EngineWallpaperService.available && EngineWallpaperService.availabilityKnown
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
            interactive: !wallpaperWindow.interactionLocked
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
                    if (!wallpaperWindow.browserOpen)
                        wallpaperWindow.schedulePreview();
                }
            }
            onMovementEnded: Qt.callLater(() => wallpaperWindow.schedulePreview(true))
            onMovementStarted: {
                wallpaperWindow.startUserNavigation();
                if (wallpaperWindow.selectedMode === "video") {
                    preloadTimer.stop();
                    WallpaperPreviewService.resetPreloads();
                }
            }

            MouseArea {
                acceptedButtons: Qt.NoButton
                anchors.fill: parent
                enabled: !wallpaperWindow.interactionLocked

                onWheel: wheel => {
                    wallpaperWindow.startUserNavigation();
                    if (wheel.angleDelta.y > 0)
                        pathView.decrementCurrentIndex();
                    else if (wheel.angleDelta.y < 0)
                        pathView.incrementCurrentIndex();
                }
            }
        }
        Item {
            id: trashTarget

            height: 60
            opacity: (wallpaperWindow.dragCard !== null && wallpaperWindow.dragCard.pullDistance > 0) || wallpaperWindow.deletingPath !== "" ? 1 : 0
            visible: !wallpaperWindow.browserOpen && wallpaperWindow.activeCount > 0 && opacity > 0
            width: 60
            x: wallpaperWindow.trashCenterX - width / 2
            y: wallpaperWindow.trashCenterY - 30
            z: 600

            Behavior on opacity {
                NumberAnimation {
                    duration: 140
                }
            }

            Rectangle {
                anchors.fill: parent
                border.color: wallpaperWindow.trashArmed ? Config.md3.error : Config.alpha(Config.md3.on_surface, 0.2)
                border.width: 1
                color: wallpaperWindow.trashArmed ? Config.md3.error : Config.md3.surface_container_high
                radius: 30
                scale: wallpaperWindow.trashArmed ? 1.1 : 1

                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }

                IconImage {
                    id: trashIcon

                    anchors.centerIn: parent
                    implicitSize: 26
                    source: Quickshell.iconPath("user-trash-symbolic")
                    visible: false
                }
                ColorOverlay {
                    anchors.fill: trashIcon
                    color: wallpaperWindow.trashArmed ? Config.md3.on_error : Config.md3.on_surface
                    source: trashIcon
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Config.md3.on_surface
            font.family: Config.fontName
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            text: wallpaperWindow.deleteMessage
            visible: wallpaperWindow.dragCard === null && wallpaperWindow.deletingPath === "" && text !== ""
            width: Math.min(520, parent.width - 32)
            wrapMode: Text.WordWrap
            y: wallpaperWindow.trashCenterY + 48
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
                text: wallpaperWindow.selectedMode === "video" ? (Config.wallpaperEngineWorkshopDir + " / " + Config.liveWallFolder) : (Config.wallFolder + " / " + Config.wallhavenCacheFolder)
                width: parent.width
            }
        }
        Loader {
            id: workshopLoader

            active: wallpaperWindow.workshopOpen
            anchors.fill: parent
            asynchronous: true
            z: 700

            sourceComponent: Component {
                WallpaperWorkshopPanel {
                    onApplyRequested: (path, modified) => {
                        wallpaperWindow.selectionCommitted = true;
                        WallpaperService.apply(path, "video", modified);
                        wallpaperWindow.closeSelector();
                    }
                    onCloseRequested: wallpaperWindow.workshopOpen = false
                }
            }
        }
        Loader {
            id: wallhavenLoader

            active: wallpaperWindow.wallhavenOpen
            anchors.fill: parent
            asynchronous: true
            z: 700

            sourceComponent: Component {
                WallhavenPanel {
                    onApplyRequested: (path, modified) => {
                        wallpaperWindow.selectionCommitted = true;
                        WallpaperService.apply(path, "static", modified);
                        wallpaperWindow.closeSelector();
                    }
                    onCloseRequested: wallpaperWindow.wallhavenOpen = false
                }
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
                    if (!thumbnailAvailable)
                        LiveWallpaperService.requestThumbnail(filePath, fileModified, PathView.isCurrentItem);
                } else if (convertedEnginePreview) {
                    engineThumbnailAvailable = EngineWallpaperService.previewThumbnailKnown(previewPath, fileModified);
                    if (!engineThumbnailAvailable)
                        EngineWallpaperService.requestPreviewThumbnail(previewPath, fileModified, PathView.isCurrentItem);
                }
            }
            function scheduleThumbnailLoad() {
                var thumbnailCached = delegateRoot.live ? delegateRoot.thumbnailAvailable : delegateRoot.engineThumbnailAvailable;
                if (wallpaperWindow.selectedMode === "video" && pathView.moving && !thumbnailCached) {
                    thumbnailLoadTimer.stop();
                    return;
                }
                if (delegateRoot.PathView.isCurrentItem || (!delegateRoot.live && !delegateRoot.convertedEnginePreview) || delegateRoot.thumbnailAvailable || delegateRoot.engineThumbnailAvailable) {
                    // Cached thumbnails, static images and current item: load immediately without delay.
                    delegateRoot.permitThumbnailLoad = true;
                    delegateRoot.requestCurrentThumbnail();
                    return;
                }
                // Video thumbnails that need generation in background: short staggered delay.
                thumbnailLoadTimer.interval = 30 * Math.max(1, delegateRoot.circularDistanceFromCurrent());
                thumbnailLoadTimer.restart();
            }

            height: wallpaperWindow.cardHeight
            opacity: PathView.itemOpacity !== undefined ? PathView.itemOpacity : 0
            scale: PathView.itemScale !== undefined ? PathView.itemScale : 0.55
            width: wallpaperWindow.cardWidth
            z: PathView.itemZ !== undefined ? PathView.itemZ : 1

            Component.onCompleted: {
                delegateRoot.scheduleThumbnailLoad();
            }
            onFileModifiedChanged: {
                permitThumbnailLoad = false;
                scheduleThumbnailTimer.restart();
            }
            onFilePathChanged: {
                permitThumbnailLoad = false;
                scheduleThumbnailTimer.restart();
            }
            onPreviewPathChanged: {
                permitThumbnailLoad = false;
                scheduleThumbnailTimer.restart();
            }

            Connections {
                function onCurrentIndexChanged() {
                    if (delegateRoot.PathView.isCurrentItem || !delegateRoot.permitThumbnailLoad)
                        delegateRoot.scheduleThumbnailLoad();
                }
                function onMovingChanged() {
                    if (!pathView.moving && (delegateRoot.PathView.isCurrentItem || !delegateRoot.permitThumbnailLoad))
                        delegateRoot.scheduleThumbnailLoad();
                }

                target: pathView
            }
            Timer {
                id: scheduleThumbnailTimer

                interval: 0
                repeat: false

                onTriggered: delegateRoot.scheduleThumbnailLoad()
            }
            Timer {
                id: thumbnailLoadTimer

                repeat: false

                onTriggered: {
                    if (pathView.moving) {
                        delegateRoot.scheduleThumbnailLoad();
                        return;
                    }
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
            WallpaperDragCard {
                id: cardDrag

                anchors.fill: parent
                deletePending: wallpaperWindow.deletingPath === delegateRoot.filePath
                dropDistance: (wallpaperWindow.trashCenterY - (pathView.y + delegateRoot.y + delegateRoot.height / 2)) / Math.max(0.01, delegateRoot.scale)
                dropOffsetX: (wallpaperWindow.trashCenterX - (pathView.x + delegateRoot.x + delegateRoot.width / 2)) / Math.max(0.01, delegateRoot.scale)
                dropTarget: trashTarget
                enabled: !wallpaperWindow.browserOpen && wallpaperWindow.deletingPath === "" && !pathView.moving
                hitItem: cardImage

                Component.onDestruction: {
                    if (wallpaperWindow.dragCard === cardDrag) {
                        wallpaperWindow.dragCard = null;
                        wallpaperWindow.draggedPath = "";
                    }
                }
                onClicked: {
                    if (wallpaperWindow.interactionLocked)
                        return;
                    wallpaperWindow.startUserNavigation();
                    if (pathView.currentIndex === delegateRoot.index)
                        wallpaperWindow.selectCurrentWallpaper();
                    else
                        pathView.currentIndex = delegateRoot.index;
                    contentRoot.forceActiveFocus();
                }
                onDragFinished: accepted => wallpaperWindow.finishDrag(cardDrag, delegateRoot.filePath, accepted)
                onDragStarted: {
                    wallpaperWindow.dragCard = cardDrag;
                    wallpaperWindow.draggedPath = delegateRoot.filePath;
                    wallpaperWindow.deleteMessage = "";
                    previewTimer.stop();
                    preloadTimer.stop();
                }

                Rectangle {
                    id: cardImage

                    anchors.fill: parent
                    color: Config.md3.surface_container_low

                    transform: Shear {
                        origin.x: delegateRoot.width / 2
                        origin.y: delegateRoot.height / 2
                        xAngle: -12.4
                    }

                    CachingImage {
                        anchors.fill: parent
                        cache: false
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
                        color: Config.md3.scrim
                        opacity: delegateRoot.PathView.isCurrentItem ? 0 : 0.6

                        Behavior on opacity {
                            OpacityAnimator {
                                duration: 150
                            }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: Config.alpha(Config.md3.primary, 0.07)
                        opacity: cardDrag.hovered ? 1 : 0

                        Behavior on opacity {
                            OpacityAnimator {
                                duration: 140
                            }
                        }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        color: cardDrag.hovered ? Config.alpha(Config.md3.primary_container, 0.94) : Config.alpha(Config.md3.background, 0.78)
                        enabled: false
                        height: 50
                        radius: width / 2
                        scale: cardDrag.hovered ? 1.08 : 1
                        visible: wallpaperWindow.selectedMode === "video"
                        width: 50

                        Behavior on color {
                            ColorAnimation {
                                duration: 140
                            }
                        }
                        Behavior on scale {
                            ScaleAnimator {
                                duration: 170
                                easing.type: Easing.OutCubic
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: 2
                            color: cardDrag.hovered ? Config.md3.on_primary_container : Config.md3.on_surface
                            font.family: Config.fontName
                            font.pixelSize: 20
                            text: "▶"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 140
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
