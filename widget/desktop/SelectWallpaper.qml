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
    readonly property real cardHeight: cardWidth * 240 / 380
    readonly property real cardWidth: Responsive.fit(380, (width - 24) / 1.15, 240)
    property bool changingMode: false
    property string initialSelectionPath: ""
    property int openGeneration: 0
    readonly property real pathSpan: Math.min(450, Math.max(cardWidth * 0.85, width * 0.34))
    property string selectedMode: "static"
    property bool selectionCommitted: false
    property int staticIndex: 0
    property int videoIndex: 0
    property bool wallhavenOpen: false
    property bool workshopOpen: false

    signal dismissed

    function closeSelector() {
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
    function openSelector() {
        var generation = ++openGeneration;
        var targetScreen = StateManager.resolvePanelScreen();
        if (targetScreen)
            screen = targetScreen;

        hideTimer.stop();
        changingMode = true;
        initialSelectionPath = String(WallpaperService.currentWallpaper || "");
        selectionCommitted = false;
        wallhavenOpen = false;
        workshopOpen = false;
        selectedMode = WallpaperService.currentMode;
        wallpaperWindow.visible = true;
        if (selectedMode === "video") {
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
        if (!wallpaperWindow.visible || changingMode || initialSelectionPath !== "" || browserOpen || pathView.currentIndex < 0)
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
    function schedulePreview() {
        if (changingMode || initialSelectionPath !== "" || browserOpen)
            return;

        previewTimer.restart();
    }
    function selectCurrentWallpaper() {
        if (browserOpen || !pathView.currentItem)
            return;

        selectionCommitted = true;
        WallpaperService.apply(pathView.currentItem.filePath, selectedMode, pathView.currentItem.fileModified);
        closeSelector();
    }
    function startUserNavigation() {
        initialSelectionPath = "";
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
        if (mode !== "static" && mode !== "video" || mode === selectedMode)
            return false;

        rememberCurrentIndex();
        changingMode = true;
        initialSelectionPath = "";
        selectedMode = mode;
        if (mode === "video") {
            previewTimer.stop();
            preloadTimer.stop();
            WallpaperService.cancelPreview();
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

        Keys.onEscapePressed: {
            if (wallpaperWindow.wallhavenOpen)
                wallpaperWindow.wallhavenOpen = false;
            else if (wallpaperWindow.workshopOpen)
                wallpaperWindow.workshopOpen = false;
            else
                closeSelector();
        }
        Keys.onLeftPressed: {
            if (!wallpaperWindow.browserOpen) {
                wallpaperWindow.startUserNavigation();
                pathView.decrementCurrentIndex();
            }
        }
        Keys.onReturnPressed: {
            if (!wallpaperWindow.browserOpen) {
                wallpaperWindow.startUserNavigation();
                selectCurrentWallpaper();
            }
        }
        Keys.onRightPressed: {
            if (!wallpaperWindow.browserOpen) {
                wallpaperWindow.startUserNavigation();
                pathView.incrementCurrentIndex();
            }
        }
        Keys.onSpacePressed: {
            if (!wallpaperWindow.browserOpen) {
                wallpaperWindow.startUserNavigation();
                selectCurrentWallpaper();
            }
        }
        Keys.onTabPressed: {
            if (!wallpaperWindow.browserOpen) {
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

            WallpaperSourceButton {
                fallbackIconName: "preferences-desktop-wallpaper-symbolic"
                iconName: "image-x-generic-symbolic"
                label: qsTr("Add image")

                onClicked: wallpaperWindow.wallhavenOpen = true
            }
            WallpaperModeSwitch {
                id: modeSwitch

                mode: wallpaperWindow.selectedMode

                onModeRequested: mode => {
                    return wallpaperWindow.switchMode(mode);
                }
            }
            WallpaperSourceButton {
                fallbackIconName: "media-playback-start-symbolic"
                iconName: "video-x-generic-symbolic"
                label: qsTr("Add video")

                onClicked: wallpaperWindow.workshopOpen = true
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
                if (!EngineWallpaperService.available && EngineWallpaperService.availabilityKnown)
                    msgs.push(qsTr("Install linux-wallpaperengine"));

                if (!LiveWallpaperService.available && LiveWallpaperService.availabilityKnown)
                    msgs.push(qsTr("Install mpvpaper"));

                return msgs.length > 0 ? qsTr("Missing: %1").arg(msgs.join(" / ")) : "";
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
            interactive: !wallpaperWindow.browserOpen
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

            MouseArea {
                acceptedButtons: Qt.NoButton
                anchors.fill: parent
                enabled: !wallpaperWindow.browserOpen

                onWheel: wheel => {
                    wallpaperWindow.startUserNavigation();
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

            transform: Shear {
                origin.x: delegateRoot.width / 2
                origin.y: delegateRoot.height / 2
                xAngle: -12.4
            }

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
                color: Config.md3.surface_container_low

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
                    opacity: cardMouse.containsMouse ? 1 : 0

                    Behavior on opacity {
                        OpacityAnimator {
                            duration: 140
                        }
                    }
                }
                MouseArea {
                    id: cardMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: {
                        wallpaperWindow.startUserNavigation();
                        if (pathView.currentIndex === index)
                            wallpaperWindow.selectCurrentWallpaper();
                        else
                            pathView.currentIndex = index;
                        contentRoot.forceActiveFocus();
                    }
                }
                Rectangle {
                    anchors.centerIn: parent
                    color: cardMouse.containsMouse ? Config.alpha(Config.md3.primary_container, 0.94) : Config.alpha(Config.md3.background, 0.78)
                    enabled: false
                    height: 50
                    radius: width / 2
                    scale: cardMouse.containsMouse ? 1.08 : 1
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
                        color: cardMouse.containsMouse ? Config.md3.on_primary_container : Config.md3.on_surface
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
