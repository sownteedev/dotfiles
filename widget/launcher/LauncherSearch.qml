import "../../"
import "../../components"
import "../../components/animate" as Animate
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// Unified search results list (Apps + Files).
Item {
    // We now rely on ListView's highlightRangeMode to scroll smoothly!

    id: searchRoot

    // Combine apps and file results into a single list, or output clipboard history/file search
    readonly property var combinedResults: {
        if (isCalculatorMode)
            return [];

        if (isClipboardMode)
            return clipboardSearch.clipboardResults;

        if (isEmojiMode)
            return emojiLoader.results;

        if (isGifMode || isStickerMode)
            return [];

        if (isFileMode) {
            var fileList = [];
            var files = filesSearch.fileResults;
            for (var j = 0; j < files.length; j++) {
                var fileEntry = files[j];
                var path = fileEntry.path ? fileEntry.path : files[j];
                var kind = fileEntry.kind ? fileEntry.kind : "file";
                fileList.push({
                    "type": kind,
                    "data": {
                        "path": path,
                        "name": fileEntry.name ? fileEntry.name : path.substring(path.lastIndexOf("/") + 1)
                    }
                });
            }
            return fileList;
        }
        // Default mode: ONLY show apps (saving CPU/IO from file search!)
        var appList = [];
        var apps = searchResults;
        for (var i = 0; i < apps.length; i++) {
            appList.push({
                "type": "app",
                "data": apps[i]
            });
        }
        return appList;
    }
    // Optimize icon lookup using O(1) object key mappings
    readonly property var extensionMap: {
        "png": "image-x-generic-symbolic",
        "jpg": "image-x-generic-symbolic",
        "jpeg": "image-x-generic-symbolic",
        "avif": "image-x-generic-symbolic",
        "gif": "image-x-generic-symbolic",
        "svg": "image-x-generic-symbolic",
        "webp": "image-x-generic-symbolic",
        "mp4": "video-x-generic-symbolic",
        "mkv": "video-x-generic-symbolic",
        "avi": "video-x-generic-symbolic",
        "mov": "video-x-generic-symbolic",
        "webm": "video-x-generic-symbolic",
        "m4v": "video-x-generic-symbolic",
        "mpeg": "video-x-generic-symbolic",
        "mpg": "video-x-generic-symbolic",
        "mp3": "audio-x-generic-symbolic",
        "flac": "audio-x-generic-symbolic",
        "wav": "audio-x-generic-symbolic",
        "ogg": "audio-x-generic-symbolic",
        "m4a": "audio-x-generic-symbolic",
        "pdf": "document-send-symbolic",
        "epub": "document-send-symbolic",
        "zip": "package-x-generic-symbolic",
        "tar": "package-x-generic-symbolic",
        "gz": "package-x-generic-symbolic",
        "xz": "package-x-generic-symbolic",
        "7z": "package-x-generic-symbolic",
        "rar": "package-x-generic-symbolic"
    }
    readonly property bool isCalculatorMode: Config.launcherCalculatorEnabled && query.toLowerCase().startsWith(Config.launcherCalculatorPrefix.toLowerCase() + " ")
    readonly property bool isClipboardMode: Config.launcherClipboardEnabled && query.toLowerCase().startsWith(Config.launcherClipboardPrefix.toLowerCase() + " ")
    readonly property bool isEmojiMode: Config.launcherEmojiEnabled && query.toLowerCase().startsWith(Config.launcherEmojiPrefix.toLowerCase() + " ")
    readonly property bool isFileMode: Config.launcherFilesEnabled && query.toLowerCase().startsWith(Config.launcherFilesPrefix.toLowerCase() + " ")
    readonly property bool isGifMode: Config.launcherGifEnabled && query.toLowerCase().startsWith(Config.launcherGifPrefix.toLowerCase() + " ")
    readonly property bool isStickerMode: Config.launcherStickerEnabled && query.toLowerCase().startsWith(Config.launcherStickerPrefix.toLowerCase() + " ")
    readonly property color providerAccent: isClipboardMode ? Config.md3.secondary : isEmojiMode ? Config.md3.tertiary : Config.md3.primary
    readonly property bool providerEmpty: (isFileMode || isClipboardMode || isEmojiMode) && !providerLoading && combinedResults.length === 0
    readonly property bool providerLoading: isFileMode ? filesSearch.loading : isClipboardMode ? clipboardSearch.loading : isEmojiMode ? emojiLoader.loading : false
    property string query: ""
    // List of apps matching query
    readonly property var searchResults: {
        var apps = DesktopEntries.applications.values;
        if (!apps)
            return [];

        var q = query.trim().toLowerCase();
        if (q === "" || isCalculatorMode || isClipboardMode || isEmojiMode || isFileMode || isGifMode || isStickerMode)
            return [];

        var matches = [];
        for (var i = 0; i < apps.length; i++) {
            var entry = apps[i];
            if (entry.runInTerminal || !entry.name)
                continue;

            var name = entry.name.toLowerCase();
            var comment = (entry.comment || "").toLowerCase();
            var genericName = (entry.genericName || "").toLowerCase();
            var substringMatch = name.indexOf(q) !== -1 || comment.indexOf(q) !== -1 || genericName.indexOf(q) !== -1;
            var fuzzyScore = Config.launcherFuzzySearch ? searchRoot.fuzzyScore(name + " " + genericName, q) : -1;
            if (substringMatch || fuzzyScore >= 0) {
                var score = substringMatch ? (name.startsWith(q) ? 0 : (name.indexOf(" " + q) !== -1 ? 1 : 2)) : 10 + fuzzyScore;
                matches.push({
                    "entry": entry,
                    "score": score,
                    "name": entry.name
                });
            }
        }
        matches.sort(function (a, b) {
            if (a.score !== b.score)
                return a.score - b.score;

            return a.name.localeCompare(b.name);
        });
        return matches.slice(0, Config.launcherMaxResults).map(m => {
            return m.entry;
        });
    }
    property int selectedIndex: 0

    signal resultLaunched

    function fuzzyScore(text, pattern) {
        var source = String(text || "").toLowerCase();
        var needle = String(pattern || "").toLowerCase();
        var cursor = 0;
        var score = 0;
        var previous = -2;
        for (var i = 0; i < needle.length; ++i) {
            var found = source.indexOf(needle.charAt(i), cursor);
            if (found < 0)
                return -1;
            score += found === previous + 1 ? 0 : found - cursor + 1;
            previous = found;
            cursor = found + 1;
        }
        return score;
    }
    function getFileIcon(filename) {
        var ext = filename.split('.').pop().toLowerCase();
        var icon = extensionMap[ext];
        return icon ? icon : "text-x-generic-symbolic";
    }
    function isImageFile(filename) {
        if (!filename)
            return false;

        var ext = filename.split('.').pop().toLowerCase();
        return ["png", "jpg", "jpeg", "avif", "gif", "svg", "webp", "bmp"].indexOf(ext) !== -1;
    }
    function isVideoFile(filename) {
        if (!filename)
            return false;

        var ext = filename.split('.').pop().toLowerCase();
        return ["mp4", "mkv", "avi", "mov", "webm", "m4v", "mpeg", "mpg"].indexOf(ext) !== -1;
    }
    function launchSelected() {
        if (combinedResults.length > 0) {
            var idx = Math.max(0, Math.min(selectedIndex, combinedResults.length - 1));
            var item = combinedResults[idx];
            if (isClipboardMode)
                clipboardSearch.copySelected(item.id);
            else if (item.type === "emoji")
                emojiLoader.copyEntry(item.data);
            else if (item.type === "app")
                item.data.execute();
            else if (item.type === "folder")
                openInNeovide(item.data.path);
            else if (item.type === "file")
                Quickshell.execDetached(["gio", "open", item.data.path]);
            searchRoot.resultLaunched();
        }
    }
    function openInNeovide(path) {
        Quickshell.execDetached(["neovide", path]);
    }
    function selectNext() {
        if (combinedResults.length > 0)
            selectedIndex = (selectedIndex + 1) % combinedResults.length;
    }
    function selectPrev() {
        if (combinedResults.length > 0)
            selectedIndex = (selectedIndex - 1 + combinedResults.length) % combinedResults.length;
    }

    clip: true
    // Auto-fit height: show up to 5 items (apps + files + clipboards), scroll for more
    implicitHeight: Math.min(combinedResults.length, 5) * (80 + 12) - (combinedResults.length > 0 ? 12 : 0)

    onQueryChanged: selectedIndex = 0
    onSelectedIndexChanged: {}

    Loader {
        id: filesSearch

        readonly property var fileResults: item ? item["fileResults"] : []
        readonly property bool loading: active && (status === Loader.Null || status === Loader.Loading || status === Loader.Ready && item && item["loading"])

        function ensureVideoPreview(path) {
            if (item)
                item["ensureVideoPreview"](path);
        }
        function isVideoPreviewReady(path) {
            return item ? item["isVideoPreviewReady"](path) : false;
        }
        function removeFile(path) {
            if (item)
                item["removeFile"](path);
        }
        function videoPreviewSource(path) {
            return item ? item["videoPreviewSource"](path) : "";
        }

        active: searchRoot.isFileMode
        source: Qt.resolvedUrl("LauncherFiles.qml")

        onLoaded: {
            item["query"] = Qt.binding(function () {
                return searchRoot.query;
            });
        }
    }
    Loader {
        id: clipboardSearch

        readonly property var clipboardResults: item ? item["clipboardResults"] : []
        readonly property bool loading: active && (status === Loader.Null || status === Loader.Loading || status === Loader.Ready && item && item["loading"])
        readonly property var readyPreviewIds: item ? item["readyPreviewIds"] : ({})

        function copySelected(id) {
            if (item)
                item["copySelected"](id);
        }
        function ensurePreview(id) {
            if (item)
                item["ensurePreview"](id);
        }
        function isPreviewReady(id) {
            return !!readyPreviewIds[id];
        }
        function previewPath(id) {
            return readyPreviewIds[id] || "";
        }
        function togglePinned(id) {
            return status === Loader.Ready && item ? item["togglePinned"](id) : -1;
        }

        active: searchRoot.isClipboardMode
        source: Qt.resolvedUrl("LauncherClipboard.qml")

        onLoaded: {
            item["query"] = Qt.binding(function () {
                return searchRoot.query;
            });
        }
    }
    Loader {
        id: emojiLoader

        // The Emoji and Unicode catalogues stay outside the launcher's normal
        // startup path and are instantiated only while this provider is open.
        readonly property bool loading: active && (status === Loader.Null || status === Loader.Loading || status === Loader.Ready && item && item["loading"])
        readonly property var results: item ? item["results"] : []

        function copyEntry(entry) {
            if (item)
                item["copy"](entry);
        }

        active: searchRoot.isEmojiMode
        asynchronous: true
        source: Qt.resolvedUrl("LauncherEmoji.qml")

        onLoaded: {
            item["query"] = Qt.binding(function () {
                return searchRoot.query;
            });
        }
    }
    ListView {
        id: searchList

        function smoothWheelScroll(delta) {
            var minimumY = searchList.originY;
            var maximumY = minimumY + Math.max(0, searchList.contentHeight - searchList.height);
            var currentTarget = wheelScrollAnimation.running ? wheelScrollAnimation.to : searchList.contentY;
            var targetY = Math.max(minimumY, Math.min(maximumY, currentTarget - delta));

            if (Math.abs(targetY - searchList.contentY) < 0.5)
                return;

            wheelScrollAnimation.stop();
            wheelScrollAnimation.from = searchList.contentY;
            wheelScrollAnimation.to = targetY;
            wheelScrollAnimation.start();
        }

        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        currentIndex: searchRoot.selectedIndex
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 250
        highlightRangeMode: ListView.ApplyRange
        model: searchRoot.combinedResults
        preferredHighlightBegin: 0
        preferredHighlightEnd: Math.max(0, searchList.height - 80)
        spacing: 12

        delegate: Rectangle {
            id: delegateRoot

            readonly property color accentColor: isClipboard ? Config.md3.secondary : (isFolder ? Config.md3.primary : (isApp ? Config.md3.primary : (isEmoji ? (isUnicode ? Config.md3.tertiary : Config.md3.error) : Config.md3.tertiary)))
            readonly property var clipData: modelData
            readonly property bool isApp: !isClipboard && modelData.type === "app"
            readonly property bool isClipboard: searchRoot.isClipboardMode
            property bool isDeleting: false
            readonly property bool isEmoji: !isClipboard && modelData.type === "emoji"
            readonly property bool isFile: !isClipboard && modelData.type === "file"
            readonly property bool isFolder: !isClipboard && modelData.type === "folder"
            readonly property bool isSelected: index === searchRoot.selectedIndex
            readonly property bool isUnicode: isEmoji && modelData.characterKind === "unicode"
            readonly property var itemData: !isClipboard ? modelData.data : null

            function characterSubtitle() {
                if (!isEmoji || !itemData)
                    return "";
                var label = isUnicode ? (itemData.category || qsTr("Unicode")) : qsTr("Emoji");
                if (isUnicode && itemData.codepoint)
                    label += " · " + itemData.codepoint;
                if (itemData.keywords)
                    label += " · " + itemData.keywords;
                return label;
            }
            function requestClipboardPreview() {
                if (isClipboard && clipData && (clipData.isImage || clipData.isVideo) && !clipboardSearch.isPreviewReady(clipData.id))
                    clipboardSearch.ensurePreview(clipData.id);
            }
            function requestVideoPreview() {
                if (isFile && itemData && isVideoFile(itemData.name) && !filesSearch.isVideoPreviewReady(itemData.path))
                    filesSearch.ensureVideoPreview(itemData.path);
            }
            function snapBack() {
                swipeContent.x = 0;
            }
            function snapToReveal() {
                swipeContent.x = 80;
            }
            function triggerDelete() {
                if (isDeleting)
                    return;

                isDeleting = true;
                swipeContent.x = swipeContent.width;
                Quickshell.execDetached(["gio", "trash", itemData.path]);
                collapseTimer.start();
            }

            clip: true
            color: "transparent"
            height: isDeleting ? 0 : 80
            opacity: isDeleting ? 0 : 1
            radius: 28
            width: searchList.width

            Behavior on height {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.InOutQuad
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                }
            }

            Component.onCompleted: {
                requestClipboardPreview();
                requestVideoPreview();
            }
            onClipDataChanged: requestClipboardPreview()
            onItemDataChanged: requestVideoPreview()

            Timer {
                id: collapseTimer

                interval: 250
                repeat: false
                running: false

                onTriggered: {
                    filesSearch.removeFile(itemData.path);
                }
            }
            SwipeDeleteBackground {
                actionText: qsTr("Trash")
                anchors.fill: parent
                cornerRadius: 28
                leading: true
                swipeOffset: swipeContent.x
                visible: isFile && revealProgress > 0.005

                onTriggered: delegateRoot.triggerDelete()
            }

            // Sliding panel containing actual item UI
            Rectangle {
                id: swipeContent

                color: listMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.1) : "transparent"
                height: parent.height
                radius: 28
                width: parent.width

                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }
                Behavior on x {
                    enabled: !listMouse.drag.active && !Config.shellReducedMotion

                    SpringAnimation {
                        damping: 0.52
                        epsilon: 0.25
                        mass: 0.85
                        spring: 4.6
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 15
                    anchors.rightMargin: isClipboard ? 64 : 15
                    spacing: 15

                    Item {
                        id: iconContainer

                        readonly property color iconColor: delegateRoot.isSelected ? delegateRoot.accentColor : Config.md3.on_surface_variant
                        readonly property string imagePreviewSource: {
                            if (isClipboard) {
                                if (clipData.isFileImage)
                                    return "file://" + clipData.sourcePath;
                                return (clipData.isImage || clipData.isVideo) ? clipboardSearch.previewPath(clipData.id) : "";
                            }

                            if (!isFile)
                                return "";
                            if (isImageFile(itemData.name))
                                return "file://" + itemData.path;
                            return isVideoFile(itemData.name) ? filesSearch.videoPreviewSource(itemData.path) : "";
                        }
                        readonly property bool isImagePreview: {
                            if (isClipboard)
                                return clipData.isFileImage || (clipData.isImage || clipData.isVideo) && clipboardSearch.isPreviewReady(clipData.id);

                            return isFile && (isImageFile(itemData.name) || isVideoFile(itemData.name) && filesSearch.isVideoPreviewReady(itemData.path));
                        }

                        Layout.alignment: Qt.AlignVCenter
                        height: 50
                        width: 50

                        Rectangle {
                            anchors.fill: parent
                            border.color: Config.alpha(iconContainer.iconColor, delegateRoot.isSelected ? 0.28 : 0.14)
                            border.width: 1
                            color: delegateRoot.isSelected ? Config.alpha(delegateRoot.accentColor, 0.16) : Config.md3.surface_container_high
                            radius: 14
                            visible: !iconContainer.isImagePreview && !isEmoji

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 160
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: 160
                                }
                            }
                        }

                        // Show standard IconImage for apps, non-image files, and text clipboard items
                        IconImage {
                            id: standardIcon

                            anchors.centerIn: parent
                            height: isApp ? 38 : 28
                            mipmap: true
                            smooth: true
                            source: isClipboard ? Quickshell.iconPath(clipData.iconName || "edit-copy-symbolic") : Quickshell.iconPath(isApp ? (itemData.icon || "application-x-executable") : (isFolder ? "folder-symbolic" : getFileIcon(itemData.name)))
                            visible: !iconContainer.isImagePreview && !isEmoji
                            width: height
                        }
                        ColorOverlay {
                            anchors.fill: standardIcon
                            color: iconContainer.iconColor
                            source: standardIcon
                            visible: standardIcon.visible && !isApp

                            Behavior on color {
                                ColorAnimation {
                                    duration: 160
                                }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            font.family: isUnicode ? "Noto Sans Symbols" : "Noto Color Emoji"
                            font.pixelSize: isUnicode ? 32 : 34
                            text: isEmoji && itemData ? itemData.glyph : ""
                            visible: isEmoji
                        }

                        // Show real Image preview for images, video frames, and clipboard images
                        Image {
                            anchors.fill: parent
                            asynchronous: true
                            cache: false
                            clip: true
                            fillMode: Image.PreserveAspectCrop
                            // Round the corners of the preview image to make it look premium
                            layer.enabled: true
                            smooth: true
                            source: iconContainer.imagePreviewSource
                            sourceSize: Qt.size(iconContainer.width * 2, iconContainer.height * 2)
                            visible: iconContainer.isImagePreview

                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    height: iconContainer.height
                                    radius: 8
                                    width: iconContainer.width
                                }
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            color: isFile && swipeContent.x > 0.4 ? Config.md3.on_error : Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            text: isClipboard ? clipData.title : itemData.name

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animationDuration(100)
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.alpha(isFile && swipeContent.x > 0.4 ? Config.md3.on_error : Config.md3.on_surface, 0.68)
                            elide: isApp ? Text.ElideRight : Text.ElideMiddle
                            font.family: Config.fontName
                            font.pixelSize: 15
                            text: isClipboard ? clipData.subtitle : (isEmoji ? characterSubtitle() : (isApp ? (itemData.comment || itemData.genericName || "") : itemData.path.replace(Config.homeDir, "~")))

                            Behavior on color {
                                ColorAnimation {
                                    duration: Config.animationDuration(100)
                                }
                            }
                        }
                    }
                }
            }
            MouseArea {
                id: listMouse

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                drag.axis: Drag.XAxis
                drag.maximumX: 160
                drag.minimumX: 0
                drag.target: isFile ? swipeContent : null
                drag.threshold: 10
                hoverEnabled: true

                // Keep pointer hover visual-only. Updating selectedIndex here
                // changes ListView.currentIndex and scrolls the last visible row.
                onClicked: {
                    if (isFile && swipeContent.x > 10) {
                        delegateRoot.snapBack();
                        return;
                    }
                    searchRoot.selectedIndex = index;
                    if (isClipboard)
                        clipboardSearch.copySelected(clipData.id);
                    else if (isEmoji)
                        emojiLoader.copyEntry(itemData);
                    else if (isApp)
                        itemData.execute();
                    else if (isFolder)
                        openInNeovide(itemData.path);
                    else
                        Quickshell.execDetached(["gio", "open", itemData.path]);
                    searchRoot.resultLaunched();
                }
                onReleased: {
                    if (isFile) {
                        if (swipeContent.x > 120)
                            delegateRoot.triggerDelete();
                        else if (swipeContent.x > 40)
                            delegateRoot.snapToReveal();
                        else
                            delegateRoot.snapBack();
                    }
                }
            }
            Rectangle {
                id: pinButton

                readonly property bool pinned: isClipboard && clipData.pinned === true

                Accessible.name: pinned ? qsTr("Unpin clipboard item") : qsTr("Pin clipboard item")
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                border.color: pinned ? Config.alpha(Config.md3.secondary, 0.44) : Config.alpha(Config.md3.outline_variant, 0.4)
                border.width: 1
                color: pinned ? Config.alpha(Config.md3.secondary, 0.18) : (pinMouse.containsMouse ? Config.alpha(Config.md3.on_surface, 0.1) : "transparent")
                height: 40
                radius: 20
                visible: isClipboard
                width: 40
                z: 2

                Behavior on border.color {
                    ColorAnimation {
                        duration: 140
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }
                }

                IconImage {
                    anchors.centerIn: parent
                    height: 21
                    layer.enabled: true
                    source: Quickshell.iconPath(pinButton.pinned ? "starred-symbolic" : "non-starred-symbolic")
                    width: 21

                    layer.effect: ColorOverlay {
                        color: pinButton.pinned ? Config.md3.secondary : Config.md3.on_surface_variant
                    }
                }
                MouseArea {
                    id: pinMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: mouse => {
                        var updatedIndex = clipboardSearch.togglePinned(clipData.id);
                        searchRoot.selectedIndex = updatedIndex >= 0 ? updatedIndex : index;
                        mouse.accepted = true;
                    }
                }
            }
        }

        // Invisible highlight just for the engine
        highlight: Item {
        }

        NumberAnimation {
            id: wheelScrollAnimation

            duration: 220
            easing.type: Easing.OutCubic
            property: "contentY"
            target: searchList
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            target: null

            onWheel: event => {
                var pixelDelta = event.pixelDelta.y;
                var delta = pixelDelta !== 0 ? pixelDelta : (event.angleDelta.y / 120) * 82;
                searchList.smoothWheelScroll(delta);
                event.accepted = true;
            }
        }

        // Our actual visible custom highlight
        Rectangle {
            color: searchList.currentItem ? Config.alpha(searchList.currentItem.accentColor, 0.13) : "transparent"
            height: searchList.currentItem ? searchList.currentItem.height : 80
            parent: searchList.contentItem
            radius: 28
            visible: searchList.currentItem !== null && searchRoot.combinedResults.length > 0
            width: searchList.width
            y: searchList.currentItem ? searchList.currentItem.y : 0
            z: -1

            Behavior on y {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutBack
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                color: searchList.currentItem ? searchList.currentItem.accentColor : "transparent"
                height: 36
                radius: 2
                width: 3

                Behavior on color {
                    ColorAnimation {
                        duration: 160
                    }
                }
            }
        }
    }
    Column {
        anchors.centerIn: parent
        spacing: 8
        visible: searchRoot.providerEmpty
        z: 2

        IconImage {
            anchors.horizontalCenter: parent.horizontalCenter
            height: 42
            layer.enabled: true
            source: Quickshell.iconPath(searchRoot.isClipboardMode ? "edit-paste-symbolic" : searchRoot.isEmojiMode ? "emojichooser-symbolic" : "folder-symbolic")
            width: 42

            layer.effect: ColorOverlay {
                color: searchRoot.providerAccent
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Config.md3.on_surface
            font.family: Config.fontName
            font.pixelSize: 17
            font.weight: Font.DemiBold
            text: searchRoot.isClipboardMode ? qsTr("No clipboard items found") : searchRoot.isEmojiMode ? qsTr("No emoji or Unicode found") : qsTr("No files found")
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Config.md3.on_surface_variant
            font.family: Config.fontName
            font.pixelSize: 12
            text: searchRoot.isClipboardMode ? qsTr("Try another search or copy something new") : searchRoot.isEmojiMode ? qsTr("Try another name, keyword or symbol") : qsTr("Try another file name or path")
        }
    }
    Animate.LoadingIndicator {
        anchors.centerIn: parent
        animated: searchRoot.providerLoading
        color: searchRoot.providerAccent
        height: 64
        visible: animated
        width: 64
        z: 3
    }
}
