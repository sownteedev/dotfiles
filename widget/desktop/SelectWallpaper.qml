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
    property bool changingMode: false
    property string selectedMode: "static"
    property bool selectionCommitted: false
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
        hideTimer.stop();
        changingMode = true;
        selectionCommitted = false;
        selectedMode = WallpaperService.currentMode;
        if (selectedMode === "video") {
            EngineWallpaperService.beginBrowsing();
            LiveWallpaperService.checkAvailability();
            syncVideoModel();
        } else {
            WallpaperService.beginPreview();
            WallpaperPreviewService.begin();
        }
        wallpaperWindow.visible = true;
        contentRoot.opacity = 1;
        contentRoot.forceActiveFocus();
        Qt.callLater(() => {
            syncCurrentWallpaper();
            changingMode = false;
            schedulePreview();
        });
    }
    function pathAt(index) {
        return roleAt(index, "filePath", "");
    }
    function preloadNeighbours() {
        if (!wallpaperWindow.visible || changingMode || selectedMode !== "static" || activeCount < 2)
            return;

        WallpaperPreviewService.resetPreloads();
        var current = pathView.currentIndex;
        var offsets = [1, -1, 2, -2];
        for (var i = 0; i < offsets.length; ++i) {
            var index = (current + offsets[i] + activeCount) % activeCount;
            if (index === current)
                continue;
            WallpaperPreviewService.preload(pathAt(index), roleAt(index, "fileModified", 0));
        }
    }
    function previewCurrent() {
        if (!wallpaperWindow.visible || changingMode || selectedMode !== "static" || pathView.currentIndex < 0)
            return;

        var path = pathAt(pathView.currentIndex);
        if (!path)
            return;

        var modified = roleAt(pathView.currentIndex, "fileModified", 0);
        WallpaperService.previewStatic(path);
        WallpaperPreviewService.preview(path, modified);
        preloadTimer.restart();
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
        if (selectedMode === "static" && !changingMode) {
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
            EngineWallpaperService.beginBrowsing();
            LiveWallpaperService.checkAvailability();
            syncVideoModel();
        } else {
            EngineWallpaperService.endBrowsing();
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
            font.family: Config.fontName
            font.pixelSize: 13
            font.weight: Font.Medium
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
            z: 300
        }
        PathView {
            id: pathView

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            delegate: wallpaperDelegate
            height: 400
            highlightRangeMode: PathView.StrictlyEnforceRange
            model: wallpaperWindow.activeModel
            pathItemCount: 7
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5

            path: Path {
                startX: pathView.width / 2 - 450
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
                    x: pathView.width / 2 + 450
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

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 18
                font.weight: Font.DemiBold
                text: wallpaperWindow.selectedMode === "video" ? (EngineWallpaperService.scanning ? "Scanning Steam Workshop…" : "No videos") : "No static wallpapers"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                color: Config.md3.on_surface_variant
                font.family: Config.fontName
                font.pixelSize: 13
                text: wallpaperWindow.selectedMode === "video" ? (Config.wallpaperEngineWorkshopDir + " / " + Config.liveWallFolder) : Config.wallFolder
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
            readonly property string previewPath: wallpaperWindow.roleAt(index, "preview", "")
            property bool thumbnailAvailable: !live || LiveWallpaperService.thumbnailKnown(filePath, fileModified)
            property int thumbnailRevision: 0

            function requestCurrentThumbnail() {
                if (live) {
                    thumbnailAvailable = LiveWallpaperService.thumbnailKnown(filePath, fileModified);
                    LiveWallpaperService.requestThumbnail(filePath, fileModified, PathView.isCurrentItem);
                } else if (convertedEnginePreview) {
                    engineThumbnailAvailable = EngineWallpaperService.previewThumbnailKnown(previewPath, fileModified);
                    EngineWallpaperService.requestPreviewThumbnail(previewPath, fileModified, PathView.isCurrentItem);
                }
            }

            height: 240
            opacity: PathView.itemOpacity !== undefined ? PathView.itemOpacity : 0
            scale: PathView.itemScale !== undefined ? PathView.itemScale : 0.55
            width: 380
            z: PathView.itemZ !== undefined ? PathView.itemZ : 1

            transform: Shear {
                origin.x: delegateRoot.width / 2
                origin.y: delegateRoot.height / 2
                xAngle: -12.4
            }

            Component.onCompleted: {
                if (live)
                    LiveWallpaperService.requestThumbnail(filePath, fileModified);
                else if (convertedEnginePreview)
                    EngineWallpaperService.requestPreviewThumbnail(previewPath, fileModified);
            }
            onFileModifiedChanged: Qt.callLater(delegateRoot.requestCurrentThumbnail)
            onFilePathChanged: Qt.callLater(delegateRoot.requestCurrentThumbnail)
            onPreviewPathChanged: Qt.callLater(delegateRoot.requestCurrentThumbnail)

            Connections {
                function onThumbnailReady(sourcePath, thumbnailPath) {
                    if (delegateRoot.live && sourcePath === delegateRoot.filePath && thumbnailPath === delegateRoot.liveThumbnail) {
                        delegateRoot.thumbnailAvailable = true;
                        ++delegateRoot.thumbnailRevision;
                    }
                }

                target: LiveWallpaperService
            }
            Connections {
                function onPreviewThumbnailReady(sourcePath, thumbnailPath) {
                    if (delegateRoot.convertedEnginePreview && sourcePath === delegateRoot.previewPath && thumbnailPath === delegateRoot.engineThumbnail) {
                        delegateRoot.engineThumbnailAvailable = true;
                        ++delegateRoot.thumbnailRevision;
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
                            return delegateRoot.thumbnailAvailable ? delegateRoot.liveThumbnail : "";

                        if (delegateRoot.isEngine)
                            return delegateRoot.engineThumbnailAvailable ? delegateRoot.engineThumbnail : "";

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
