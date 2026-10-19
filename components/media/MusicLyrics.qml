import "../../"
import "../../service"
import "../"
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets

Rectangle {
    id: root

    property int activeLineIndex: -1
    property var fallbackRecord: null
    property bool followLyrics: true
    readonly property bool hasLyrics: plainLyrics.trim() !== "" || syncedLines.length > 0
    readonly property bool hasSyncedLyrics: syncedLines.length > 0
    readonly property bool hasWordLyrics: syncedLines.some(line => line.words && line.words.length > 0)
    property bool instrumental: false
    property bool loading: false
    property bool lookupFailed: false
    property bool lookupSettled: false
    property bool lyricScrollAnimating: false
    property var lyricsCache: ({})
    readonly property int lyricsCacheLimit: 24
    property var lyricsCacheOrder: []
    readonly property bool lyricsSeekable: !!player && player.canSeek && player.positionSupported
    property string lyricsSource: ""
    property var pendingCommand: []
    property string pendingRequestKey: ""
    property real pendingSeekPosition: -1
    property real pendingSeekStartedAt: 0
    readonly property var plainLines: hasSyncedLyrics ? [] : plainLyrics.trim().split(/\r?\n/)
    property string plainLyrics: ""
    property real playbackPosition: 0
    property var player: null
    property bool previewPositioned: false
    property int previewPrepareAttempts: 0
    readonly property bool previewReady: !hasSyncedLyrics || previewPositioned
    property string processRequestKey: ""
    property int processRevision: -1
    property string requestKey: ""
    property int requestRevision: 0
    property var syncedLines: []

    function applyLyrics(plainValue, syncedValue, isInstrumental, sourceName, wordLines) {
        instrumental = !!isInstrumental;
        syncedLines = wordLines && wordLines.length > 0 ? wordLines : parseSyncedLyrics(syncedValue);
        plainLyrics = String(plainValue || "").trim();
        if (plainLyrics === "" && syncedLines.length > 0)
            plainLyrics = stripSyncedLyrics(syncedValue);

        lyricsSource = sourceName || "";
        loading = false;
        activeLineIndex = -1;
        previewPositioned = false;
        preparePreview();
    }
    function cachedLyrics(key) {
        var entry = lyricsCache[key];
        if (entry === undefined)
            return null;

        var order = lyricsCacheOrder.filter(function (cachedKey) {
            return cachedKey !== key;
        });
        order.unshift(key);
        lyricsCacheOrder = order;
        return entry;
    }
    function currentKey() {
        if (!player)
            return "";

        return [player.dbusName || "", player.uniqueId || 0, player.trackTitle || "", player.trackArtist || "", player.trackAlbum || "", player.length || 0].join("|");
    }
    function embeddedLyrics() {
        if (!player || !player.metadata)
            return "";

        var metadata = player.metadata;
        var keys = ["xesam:asText", "xesam:lyrics", "mpris:lyrics", "lyrics"];
        for (var index = 0; index < keys.length; ++index) {
            var value = metadata[keys[index]];
            if (value !== undefined && value !== null && String(value).trim() !== "")
                return String(value).trim();
        }
        return "";
    }
    function lineTargetY(lineIndex) {
        var lineHeight = 44;
        var minimumY = syncedList.originY;
        var maximumY = Math.max(minimumY, minimumY + syncedList.contentHeight - syncedList.height);
        var centeredY = minimumY + lineIndex * (lineHeight + syncedList.spacing) - (syncedList.height - lineHeight) / 2;
        return Math.max(minimumY, Math.min(maximumY, centeredY));
    }
    function lookup() {
        seekGuard.stop();
        pendingSeekPosition = -1;
        requestRevision++;
        requestKey = currentKey();
        pendingRequestKey = "";
        pendingCommand = [];
        if (lyricsProcess.running)
            lyricsProcess.running = false;
        loading = false;
        lookupFailed = false;
        lookupSettled = false;
        fallbackRecord = null;
        instrumental = false;
        plainLyrics = "";
        syncedLines = [];
        playbackPosition = 0;
        activeLineIndex = -1;
        previewPositioned = false;
        lyricsSource = "";
        if (!player || !player.trackTitle)
            return;

        var embedded = embeddedLyrics();
        if (embedded !== "") {
            fallbackRecord = {
                "plainLyrics": embedded,
                "syncedLyrics": "",
                "instrumental": false,
                "source": "MPRIS"
            };
            if (parseSyncedLyrics(embedded).length > 0)
                fallbackRecord.syncedLyrics = embedded;
        }
        var cached = cachedLyrics(requestKey);
        if (cached !== null) {
            settleLookup(cached, false);
            return;
        }
        loading = true;
        pendingRequestKey = requestKey;
        pendingCommand = ["python3", Config.sownteeshellDir + "/backend/python/media/lyrics.py", "--title=" + (player.trackTitle || ""), "--artist=" + (player.trackArtist || ""), "--album=" + (player.trackAlbum || ""), "--duration=" + Math.max(0, Number(player.length || 0))];
        Qt.callLater(startPendingLookup);
    }
    function parseSyncedLyrics(value) {
        var result = [];
        var rows = String(value || "").split(/\r?\n/);
        var timestampPattern = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
        for (var rowIndex = 0; rowIndex < rows.length; ++rowIndex) {
            var row = rows[rowIndex];
            var text = row.replace(timestampPattern, "").trim();
            var match;
            timestampPattern.lastIndex = 0;
            while ((match = timestampPattern.exec(row)) !== null)
                result.push({
                    "time": Number(match[1]) * 60 + Number(match[2]),
                    "text": text === "" ? "♪" : text
                });
        }
        result.sort(function (left, right) {
            return left.time - right.time;
        });
        return result;
    }
    function positionPreview() {
        if (!hasSyncedLyrics) {
            previewPositioned = true;
            return;
        }

        syncedList.forceLayout();
        var lineIndex = activeLineIndex >= 0 ? activeLineIndex : 0;
        if (syncedList.height <= 0 || syncedList.count <= lineIndex || syncedList.contentHeight <= 0) {
            ++previewPrepareAttempts;
            if (previewPrepareAttempts < 8)
                previewPositionTimer.restart();
            return;
        }

        lyricScrollAnimation.stop();
        syncedList.contentY = lineTargetY(lineIndex);
        lyricScrollAnimating = false;
        previewPositioned = true;
    }
    function preparePreview() {
        previewPrepareAttempts = 0;
        previewPositioned = !hasSyncedLyrics;
        if (previewPositioned)
            return;

        updateActiveLine();
        previewPositionTimer.restart();
    }
    function receiveLookup(line) {
        if (lookupSettled || processRevision !== requestRevision || processRequestKey !== currentKey() || pendingRequestKey !== "")
            return;

        try {
            var message = JSON.parse(line);
            var record = message.record;
            if (record && (!fallbackRecord || !fallbackRecord.syncedLyrics || record.syncedLyrics))
                fallbackRecord = record;
            if ((record && record.wordLines && record.wordLines.length > 0) || message.done)
                settleLookup(fallbackRecord, !!message.failed);
        } catch (error) {
            console.warn("[MusicLyrics] Invalid lookup response:", error);
        }
    }
    function returnToCurrentLine() {
        updateActiveLine();
        if (activeLineIndex >= 0)
            scrollToLine(activeLineIndex, false);
    }
    function scheduleLookup() {
        if (lookupSettled && requestKey === currentKey())
            return;
        requestRevision++;
        lookupDelay.restart();
    }
    function scrollToLine(lineIndex, selectLine) {
        if (lineIndex < 0 || lineIndex >= syncedLines.length || syncedList.height <= 0)
            return;

        lyricScrollAnimation.stop();
        lyricScrollAnimating = true;
        followLyrics = true;
        if (selectLine)
            activeLineIndex = lineIndex;

        var targetY = lineTargetY(lineIndex);
        var distance = Math.abs(targetY - syncedList.contentY);
        if (distance < 0.5) {
            syncedList.contentY = targetY;
            lyricScrollAnimating = false;
            return;
        }

        lyricScrollAnimation.from = syncedList.contentY;
        lyricScrollAnimation.to = targetY;
        lyricScrollAnimation.duration = Config.animationDuration(Math.min(320, 180 + distance * 0.45));
        lyricScrollAnimation.start();
    }
    function seekToLine(lineIndex) {
        if (!lyricsSeekable || lineIndex < 0 || lineIndex >= syncedLines.length)
            return;

        var targetPosition = Math.max(0, Number(syncedLines[lineIndex].time || 0));
        pendingSeekPosition = targetPosition;
        pendingSeekStartedAt = Date.now();
        seekGuard.restart();
        playbackPosition = targetPosition;
        syncedList.cancelFlick();
        scrollToLine(lineIndex, true);
        player.position = targetPosition;
        updateActiveLine();
    }
    function settleLookup(record, failed) {
        if (lookupSettled)
            return;
        lookupSettled = true;
        if (record) {
            applyLyrics(record.plainLyrics, record.syncedLyrics, record.instrumental, record.source, record.wordLines);
            if (record.syncedLyrics)
                storeCachedLyrics(requestKey, record);
        }
        loading = false;
        lookupFailed = failed && !hasLyrics;
    }
    function smoothPlainScroll(delta) {
        var minimumY = plainFlick.originY;
        var maximumY = minimumY + Math.max(0, plainFlick.contentHeight - plainFlick.height);
        var currentTarget = plainScrollAnimation.running ? plainScrollAnimation.to : plainFlick.contentY;
        var targetY = Math.max(minimumY, Math.min(maximumY, currentTarget - delta));
        if (Math.abs(targetY - plainFlick.contentY) < 0.5)
            return;

        plainScrollAnimation.stop();
        plainScrollAnimation.from = plainFlick.contentY;
        plainScrollAnimation.to = targetY;
        plainScrollAnimation.start();
    }
    function smoothSyncedScroll(delta) {
        var minimumY = syncedList.originY;
        var maximumY = minimumY + Math.max(0, syncedList.contentHeight - syncedList.height);
        var currentTarget = lyricScrollAnimation.running ? lyricScrollAnimation.to : syncedList.contentY;
        var targetY = Math.max(minimumY, Math.min(maximumY, currentTarget - delta));
        if (Math.abs(targetY - syncedList.contentY) < 0.5)
            return;

        lyricScrollAnimation.stop();
        lyricScrollAnimating = true;
        lyricScrollAnimation.from = syncedList.contentY;
        lyricScrollAnimation.to = targetY;
        lyricScrollAnimation.duration = Config.animationDuration(150);
        lyricScrollAnimation.start();
    }
    function startPendingLookup() {
        if (lyricsProcess.running || pendingRequestKey === "" || pendingCommand.length === 0)
            return;

        processRequestKey = pendingRequestKey;
        processRevision = requestRevision;
        pendingRequestKey = "";
        lyricsProcess.command = pendingCommand;
        pendingCommand = [];
        lyricsProcess.running = true;
        lookupTimeout.restart();
    }
    function storeCachedLyrics(key, entry) {
        var updatedCache = Object.assign({}, lyricsCache);
        var order = lyricsCacheOrder.filter(function (cachedKey) {
            return cachedKey !== key;
        });
        updatedCache[key] = entry;
        order.unshift(key);
        while (order.length > lyricsCacheLimit) {
            var evictedKey = order.pop();
            delete updatedCache[evictedKey];
        }
        lyricsCache = updatedCache;
        lyricsCacheOrder = order;
    }
    function stripSyncedLyrics(value) {
        return String(value || "").split(/\r?\n/).map(function (line) {
            return line.replace(/\[(\d+):(\d+(?:\.\d+)?)\]/g, "").trim();
        }).filter(function (line) {
            return line !== "";
        }).join("\n");
    }
    function updateActiveLine() {
        var reportedPosition = player && player.positionSupported ? Math.max(0, Number(player.position || 0)) : 0;
        if (pendingSeekPosition >= 0 && seekGuard.running) {
            var elapsed = Math.max(0, Date.now() - pendingSeekStartedAt) / 1000;
            var maximumAdvance = elapsed * Math.max(1, Number(player.rate || 1)) + 0.25;
            if (reportedPosition < pendingSeekPosition - 0.025 || reportedPosition > pendingSeekPosition + maximumAdvance)
                return;
            reportedPosition = Math.max(pendingSeekPosition, reportedPosition);
        }
        playbackPosition = reportedPosition;
        if (!hasSyncedLyrics || !player || !player.positionSupported) {
            activeLineIndex = -1;
            return;
        }
        var position = playbackPosition;
        var nextIndex = -1;
        var start = (activeLineIndex >= 0 && activeLineIndex < syncedLines.length && position >= syncedLines[activeLineIndex].time) ? activeLineIndex : 0;
        for (var index = start; index < syncedLines.length; ++index) {
            if (syncedLines[index].time <= position + (hasWordLyrics ? 0 : 0.1))
                nextIndex = index;
            else
                break;
        }
        if (nextIndex !== activeLineIndex) {
            activeLineIndex = nextIndex;
            if (followLyrics && nextIndex >= 0) {
                if (!previewPositioned) {
                    previewPositionTimer.restart();
                } else {
                    Qt.callLater(function () {
                        if (root.followLyrics && root.activeLineIndex === nextIndex)
                            root.scrollToLine(nextIndex, false);
                    });
                }
            }
        }
    }

    clip: true
    color: "transparent"
    radius: 14

    Component.onCompleted: scheduleLookup()
    onPlainLyricsChanged: {
        plainScrollAnimation.stop();
        plainFlick.contentY = plainFlick.originY;
    }
    onPlayerChanged: scheduleLookup()
    onVisibleChanged: {
        if (visible)
            Qt.callLater(preparePreview);
        else
            lyricScrollAnimation.stop();
    }

    Connections {
        function onMetadataChanged() {
            root.scheduleLookup();
        }
        function onPlaybackStateChanged() {
            root.updateActiveLine();
        }
        function onPositionChanged() {
            root.updateActiveLine();
        }
        function onPostTrackChanged() {
            root.scheduleLookup();
        }

        enabled: !!root.player
        target: root.player
    }
    Timer {
        id: seekGuard

        interval: 800

        onTriggered: {
            root.pendingSeekPosition = -1;
            root.updateActiveLine();
        }
    }
    Timer {
        id: lookupDelay

        interval: 260
        repeat: false

        onTriggered: root.lookup()
    }
    Timer {
        id: previewPositionTimer

        interval: 16
        repeat: false

        onTriggered: root.positionPreview()
    }
    Timer {
        interval: root.hasWordLyrics ? 33 : 150
        repeat: true
        running: root.visible && root.hasSyncedLyrics && !!root.player && MediaService.playing

        onTriggered: root.updateActiveLine()
    }
    Process {
        id: lyricsProcess

        stdout: SplitParser {
            onRead: line => root.receiveLookup(line)
        }

        onExited: (exitCode, exitStatus) => {
            lookupTimeout.stop();
            if (root.processRevision === root.requestRevision && root.processRequestKey === root.currentKey())
                root.settleLookup(root.fallbackRecord, exitCode !== 0 || root.loading);
            root.processRequestKey = "";
            if (root.pendingRequestKey !== "")
                Qt.callLater(root.startPendingLookup);
        }
    }
    Timer {
        id: lookupTimeout

        interval: 14000

        onTriggered: {
            if (root.processRevision === root.requestRevision)
                root.settleLookup(root.fallbackRecord, true);
            lyricsProcess.running = false;
        }
    }
    ListView {
        id: syncedList

        anchors.fill: parent
        anchors.leftMargin: Math.min(20, root.width * 0.05)
        anchors.rightMargin: anchors.leftMargin
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 64
        clip: true
        currentIndex: -1
        highlightRangeMode: ListView.NoHighlightRange
        model: root.visible ? root.syncedLines : []
        reuseItems: true
        spacing: 0
        visible: root.hasSyncedLyrics

        delegate: Item {
            id: lineDelegate

            readonly property int distance: Math.abs(index - root.activeLineIndex)
            required property int index
            readonly property bool karaokeActive: index === root.activeLineIndex && wordTimed
            required property var modelData
            readonly property bool wordTimed: !!modelData.words && modelData.words.length > 0

            height: 44
            width: syncedList.width

            Text {
                id: smallLineText

                anchors.centerIn: parent
                color: Config.md3.on_surface
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.05
                maximumLineCount: 2
                opacity: distance === 1 ? 0.58 : 0.24
                text: modelData.text
                textFormat: Text.PlainText
                verticalAlignment: Text.AlignVCenter
                visible: lineDelegate.wordTimed ? !lineDelegate.karaokeActive : index !== root.activeLineIndex
                width: parent.width
                wrapMode: Text.Wrap

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animationDuration(160)
                        easing.type: Easing.OutCubic
                    }
                }
            }
            Text {
                id: activeLineText

                anchors.centerIn: parent
                color: Config.md3.primary
                font.family: Config.fontName
                font.pixelSize: 18
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.05
                maximumLineCount: 2
                opacity: index === root.activeLineIndex ? 1 : 0
                text: modelData.text
                textFormat: Text.PlainText
                verticalAlignment: Text.AlignVCenter
                visible: !lineDelegate.wordTimed
                width: parent.width
                wrapMode: Text.Wrap

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animationDuration(160)
                        easing.type: Easing.OutCubic
                    }
                }
            }
            Loader {
                active: lineDelegate.karaokeActive
                anchors.fill: parent
                opacity: 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animationDuration(160)
                        easing.type: Easing.OutCubic
                    }
                }
                sourceComponent: KaraokeLine {
                    fontSize: lineDelegate.karaokeActive ? 18 : 14
                    highlighted: lineDelegate.karaokeActive
                    position: root.playbackPosition
                    words: lineDelegate.modelData.words
                }
            }
            TapHandler {
                acceptedButtons: Qt.LeftButton
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: root.lyricsSeekable

                onTapped: root.seekToLine(index)
            }
        }

        onContentHeightChanged: {
            if (root.hasSyncedLyrics && !root.previewReady)
                previewPositionTimer.restart();
        }
        onCountChanged: {
            if (root.hasSyncedLyrics && !root.previewReady)
                previewPositionTimer.restart();
        }
        onDraggingChanged: {
            if (dragging) {
                lyricScrollAnimation.stop();
                if (root.followLyrics)
                    root.followLyrics = false;
            }
        }
        onFlickingChanged: {
            if (flicking) {
                lyricScrollAnimation.stop();
                if (root.followLyrics)
                    root.followLyrics = false;
            }
        }
        onHeightChanged: {
            if (root.hasSyncedLyrics && !root.previewReady)
                previewPositionTimer.restart();
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            target: null

            onWheel: event => {
                if (root.followLyrics)
                    root.followLyrics = false;
                var pixelDelta = event.pixelDelta.y;
                var angleDelta = event.angleDelta.y;
                var delta = pixelDelta !== 0 ? pixelDelta : (angleDelta / 120) * 72;
                root.smoothSyncedScroll(delta);
                event.accepted = true;
            }
        }
    }
    NumberAnimation {
        id: lyricScrollAnimation

        easing.type: Easing.InOutCubic
        property: "contentY"
        target: syncedList

        onStopped: root.lyricScrollAnimating = false
    }
    Flickable {
        id: plainFlick

        activeFocusOnTab: visible
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.margins: 12
        anchors.rightMargin: 20
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        contentHeight: plainColumn.implicitHeight
        contentWidth: width
        flickableDirection: Flickable.VerticalFlick
        layer.enabled: visible && contentHeight > height && GraphicsInfo.api !== GraphicsInfo.Software
        visible: !root.hasSyncedLyrics && root.plainLyrics !== ""

        layer.effect: OpacityMask {
            maskSource: Rectangle {
                height: plainFlick.height
                width: plainFlick.width

                gradient: Gradient {
                    GradientStop {
                        color: plainFlick.atYBeginning ? "black" : "transparent"
                        position: 0
                    }
                    GradientStop {
                        color: "black"
                        position: Math.min(0.5, 12 / Math.max(1, plainFlick.height))
                    }
                    GradientStop {
                        color: "black"
                        position: 1 - Math.min(0.5, 16 / Math.max(1, plainFlick.height))
                    }
                    GradientStop {
                        color: plainFlick.atYEnd ? "black" : "transparent"
                        position: 1
                    }
                }
            }
        }

        Keys.onDownPressed: root.smoothPlainScroll(-32)
        Keys.onPressed: event => {
            if (event.key === Qt.Key_PageDown)
                root.smoothPlainScroll(-plainFlick.height);
            else if (event.key === Qt.Key_PageUp)
                root.smoothPlainScroll(plainFlick.height);
            else
                return;
            event.accepted = true;
        }
        Keys.onUpPressed: root.smoothPlainScroll(32)
        onDraggingChanged: {
            if (dragging)
                plainScrollAnimation.stop();
        }

        Column {
            id: plainColumn

            spacing: 4
            width: plainFlick.width

            Repeater {
                model: root.plainLines

                Text {
                    readonly property string line: modelData.trim()
                    required property string modelData
                    readonly property bool sectionHeading: /^(\[[^\]]+\]|\([^\)]+\))$/.test(line)

                    bottomPadding: sectionHeading ? 4 : 0
                    color: sectionHeading ? Config.alpha(Config.md3.on_surface, 0.58) : Config.md3.primary
                    font.capitalization: sectionHeading ? Font.AllUppercase : Font.MixedCase
                    font.family: Config.fontName
                    font.letterSpacing: sectionHeading ? 1.1 : 0
                    font.pixelSize: sectionHeading ? 11 : 17
                    font.weight: sectionHeading ? Font.DemiBold : Font.Medium
                    height: line === "" ? 10 : implicitHeight
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.35
                    text: sectionHeading ? line.slice(1, -1) : line
                    textFormat: Text.PlainText
                    topPadding: sectionHeading ? 8 : 0
                    width: plainColumn.width
                    wrapMode: Text.Wrap
                }
            }
        }
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            target: null

            onWheel: event => {
                var pixelDelta = event.pixelDelta.y;
                var angleDelta = event.angleDelta.y;
                var delta = pixelDelta !== 0 ? pixelDelta : (angleDelta / 120) * 72;
                root.smoothPlainScroll(delta);
                event.accepted = true;
            }
        }
    }
    NumberAnimation {
        id: plainScrollAnimation

        duration: Config.animationDuration(150)
        easing.type: Easing.OutCubic
        property: "contentY"
        target: plainFlick
    }
    Column {
        anchors.centerIn: parent
        spacing: 6
        visible: !root.hasLyrics
        width: parent.width

        AnimatedImage {
            anchors.horizontalCenter: parent.horizontalCenter
            fillMode: Image.PreserveAspectFit
            height: 70
            playing: root.visible && !root.hasLyrics && !root.loading
            source: "file://" + Config.sownteeshellDir + "/assets/kurukuru.gif"
            visible: !root.loading && !root.instrumental
        }
        LoadingIndicator {
            anchors.horizontalCenter: parent.horizontalCenter
            animated: root.loading
            color: Config.md3.primary
            height: 60
            visible: root.loading
            width: 60
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Config.md3.primary
            font.family: Config.fontName
            font.pixelSize: 14
            font.weight: Font.DemiBold
            text: "Instrumental track"
            visible: root.instrumental
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.margins: 12
        anchors.right: parent.right
        color: followMouse.containsMouse ? Config.md3.primary : Config.alpha(Config.md3.primary, 0.8)
        height: 28
        radius: 14
        visible: root.hasSyncedLyrics && !root.followLyrics
        width: 28
        z: 10

        IconImage {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: 1
            implicitHeight: 14
            implicitWidth: 14
            layer.enabled: true
            source: Quickshell.iconPath("media-playback-start-symbolic", "media-playback-start")

            layer.effect: ColorOverlay {
                color: Config.md3.on_primary
            }
        }
        MouseArea {
            id: followMouse

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: root.returnToCurrentLine()
        }
    }
}
