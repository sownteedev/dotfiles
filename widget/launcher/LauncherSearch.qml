import "../../"
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
        "gif": "image-x-generic-symbolic",
        "svg": "image-x-generic-symbolic",
        "webp": "image-x-generic-symbolic",
        "mp4": "video-x-generic-symbolic",
        "mkv": "video-x-generic-symbolic",
        "avi": "video-x-generic-symbolic",
        "mov": "video-x-generic-symbolic",
        "webm": "video-x-generic-symbolic",
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
    readonly property bool isCalculatorMode: query.startsWith("= ")
    readonly property bool isClipboardMode: query.toLowerCase().startsWith("c ")
    readonly property bool isEmojiMode: query.toLowerCase().startsWith("e ")
    readonly property bool isFileMode: query.toLowerCase().startsWith("f ")
    property string query: ""
    // List of apps matching query
    readonly property var searchResults: {
        var apps = DesktopEntries.applications.values;
        if (!apps)
            return [];

        var q = query.trim().toLowerCase();
        if (q === "" || isCalculatorMode || isClipboardMode || isEmojiMode || isFileMode)
            return [];

        var matches = [];
        for (var i = 0; i < apps.length; i++) {
            var entry = apps[i];
            if (entry.runInTerminal || !entry.name)
                continue;

            var name = entry.name.toLowerCase();
            var comment = (entry.comment || "").toLowerCase();
            var genericName = (entry.genericName || "").toLowerCase();
            if (name.indexOf(q) !== -1 || comment.indexOf(q) !== -1 || genericName.indexOf(q) !== -1) {
                var score = name.startsWith(q) ? 0 : (name.indexOf(" " + q) !== -1 ? 1 : 2);
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
        return matches.map(m => {
            return m.entry;
        });
    }
    property int selectedIndex: 0

    signal resultLaunched

    function getFileIcon(filename) {
        var ext = filename.split('.').pop().toLowerCase();
        var icon = extensionMap[ext];
        return icon ? icon : "text-x-generic-symbolic";
    }
    function isImageFile(filename) {
        if (!filename)
            return false;

        var ext = filename.split('.').pop().toLowerCase();
        return ["png", "jpg", "jpeg", "gif", "svg", "webp", "bmp"].indexOf(ext) !== -1;
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

        function removeFile(path) {
            if (item)
                item["removeFile"](path);
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

        function copySelected(id) {
            if (item)
                item["copySelected"](id);
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

        // LauncherEmoji contains the large local emoji catalogue. Loading it by
        // URL keeps that QML unit out of the launcher's normal startup path.
        readonly property var results: item ? item["results"] : []

        function copyEntry(entry) {
            if (item)
                item["copy"](entry);
        }

        active: searchRoot.isEmojiMode
        source: Qt.resolvedUrl("LauncherEmoji.qml")

        onLoaded: {
            item["query"] = Qt.binding(function () {
                return searchRoot.query;
            });
        }
    }
    ListView {
        id: searchList

        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        currentIndex: searchRoot.selectedIndex
        // Let ListView handle smooth scrolling for contentY natively
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 250
        highlightRangeMode: ListView.ApplyRange
        model: searchRoot.combinedResults
        preferredHighlightBegin: 0
        preferredHighlightEnd: Math.max(0, searchList.height - 80)
        spacing: 12

        ScrollBar.vertical: ScrollBar {
            id: searchScrollBar

            implicitWidth: 6
            opacity: active ? 1 : 0
            padding: 0
            policy: ScrollBar.AsNeeded
            visible: opacity > 0.01

            background: Item {
            }
            contentItem: Rectangle {
                color: searchScrollBar.pressed ? Config.alpha(Config.md3.on_surface, 0.75) : (searchScrollBar.hovered ? Config.alpha(Config.md3.on_surface_variant, 0.45) : Config.alpha(Config.md3.on_surface_variant, 0.28))
                implicitHeight: 36
                implicitWidth: 3
                radius: 999
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 500
                }
            }
        }
        delegate: Rectangle {
            id: delegateRoot

            readonly property color accentColor: isClipboard ? Config.md3.secondary : (isApp ? Config.md3.primary : (isEmoji ? Config.md3.error : Config.md3.tertiary))
            readonly property var clipData: modelData
            readonly property bool isApp: !isClipboard && modelData.type === "app"
            readonly property bool isClipboard: searchRoot.isClipboardMode
            property bool isDeleting: false
            readonly property bool isEmoji: !isClipboard && modelData.type === "emoji"
            readonly property bool isFile: !isClipboard && modelData.type === "file"
            readonly property bool isFolder: !isClipboard && modelData.type === "folder"
            readonly property bool isSelected: index === searchRoot.selectedIndex
            readonly property var itemData: !isClipboard ? modelData.data : null

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

            Timer {
                id: collapseTimer

                interval: 250
                repeat: false
                running: false

                onTriggered: {
                    filesSearch.removeFile(itemData.path);
                }
            }

            // Red Delete / Trash background
            Rectangle {
                id: deleteBg

                anchors.fill: parent
                color: Config.md3.error
                opacity: Math.min(1, Math.abs(swipeContent.x) / 80)
                radius: 28
                visible: isFile

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: Math.min(1, Math.abs(swipeContent.x) / 60)
                    scale: swipeContent.x > 120 ? 1.2 : 1
                    spacing: 8

                    Behavior on scale {
                        NumberAnimation {
                            duration: 100
                        }
                    }

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        height: 24
                        layer.enabled: true
                        source: Quickshell.iconPath("user-trash-symbolic")
                        width: 24

                        layer.effect: ColorOverlay {
                            color: "#ffffff"
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#ffffff"
                        font.family: Config.fontName
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        text: "Trash"
                    }
                }
                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        delegateRoot.triggerDelete();
                    }
                }
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
                    id: xBehavior

                    enabled: !listMouse.drag.active

                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 15
                    anchors.rightMargin: 15
                    spacing: 15

                    Item {
                        id: iconContainer

                        readonly property string imagePreviewSource: {
                            if (isClipboard)
                                return clipData.isImage ? clipData.imagePath : "";

                            return (isFile && isImageFile(itemData.name)) ? "file://" + itemData.path : "";
                        }
                        readonly property bool isImagePreview: {
                            if (isClipboard)
                                return clipData.isImage;

                            return isFile && isImageFile(itemData.name);
                        }

                        Layout.alignment: Qt.AlignVCenter
                        height: 50
                        width: 50

                        // Show standard IconImage for apps, non-image files, and text clipboard items
                        IconImage {
                            anchors.fill: parent
                            mipmap: true
                            smooth: true
                            source: isClipboard ? Quickshell.iconPath("edit-copy-symbolic") : Quickshell.iconPath(isApp ? (itemData.icon || "application-x-executable") : (isFolder ? "folder-symbolic" : getFileIcon(itemData.name)))
                            visible: !iconContainer.isImagePreview && !isEmoji
                        }
                        Text {
                            anchors.centerIn: parent
                            font.family: "Noto Color Emoji"
                            font.pixelSize: 34
                            text: isEmoji ? itemData.glyph : ""
                            visible: isEmoji
                        }

                        // Show real Image preview for image files and clipboard images
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
                            color: Config.md3.on_surface
                            elide: Text.ElideRight
                            font.family: Config.fontName
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            text: isClipboard ? (clipData.isImage ? "Image " + clipData.content.replace("[[ binary data ", "").replace(" ]]", "") : clipData.content.trim().split("\n")[0]) : itemData.name
                        }
                        Text {
                            Layout.fillWidth: true
                            color: Config.alpha(Config.md3.on_surface, 0.6)
                            elide: isApp ? Text.ElideRight : Text.ElideMiddle
                            font.family: Config.fontName
                            font.pixelSize: 15
                            text: isClipboard ? (clipData.isImage ? "Clipboard History (Image)" : "Clipboard History") : (isEmoji ? "Emoji & Symbol · " + itemData.keywords : (isApp ? (itemData.comment || itemData.genericName || "") : itemData.path.replace(Config.homeDir, "~")))
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
                onEntered: {
                    if (!isFile || swipeContent.x === 0)
                        searchRoot.selectedIndex = index;
                }
                onPressed: {
                    searchRoot.selectedIndex = index;
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
        }

        // Invisible highlight just for the engine
        highlight: Item {
        }

        // Our actual visible custom highlight
        Rectangle {
            color: Config.alpha(Config.md3.on_surface, 0.06)
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
                        duration: 150
                    }
                }
            }
        }
    }
}
