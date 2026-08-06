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
    property bool followLyrics: true
    readonly property bool hasLyrics: plainLyrics.trim() !== "" || syncedLines.length > 0
    readonly property bool hasSyncedLyrics: syncedLines.length > 0
    property bool instrumental: false
    property bool loading: false
    property var lyricsCache: ({})
    property string lyricsSource: ""
    property var pendingCommand: []
    property string pendingRequestKey: ""
    property string plainLyrics: ""
    property var player: null
    property string processRequestKey: ""
    property string requestKey: ""
    property var syncedLines: []

    function applyLyrics(plainValue, syncedValue, isInstrumental, sourceName) {
        instrumental = !!isInstrumental;
        syncedLines = parseSyncedLyrics(syncedValue);
        plainLyrics = String(plainValue || "").trim();
        if (plainLyrics === "" && syncedLines.length > 0)
            plainLyrics = stripSyncedLyrics(syncedValue);

        lyricsSource = sourceName || "";
        loading = false;
        activeLineIndex = -1;
        updateActiveLine();
    }
    function bestRecord(records) {
        var best = null;
        var bestScore = -1;
        for (var index = 0; index < records.length; ++index) {
            var score = recordScore(records[index]);
            if (score > bestScore) {
                best = records[index];
                bestScore = score;
            }
        }
        return best;
    }
    function currentKey() {
        if (!player)
            return "";

        return [player.dbusName || "", player.uniqueId || 0, player.trackTitle || "", player.trackArtist || ""].join("|");
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
    function finishLookup(output, exitCode, completedKey) {
        if (completedKey === "")
            return;

        if (exitCode !== 0) {
            if (completedKey === currentKey() && pendingRequestKey === "")
                loading = false;
            return;
        }

        var result = null;
        if (output.trim() !== "") {
            try {
                var records = JSON.parse(output);
                if (Array.isArray(records))
                    result = bestRecord(records);
            } catch (error) {
                console.warn("[MusicLyrics] Invalid LRCLIB response:", error);
            }
        }
        var cacheEntry = result ? {
            "plainLyrics": result.plainLyrics || "",
            "syncedLyrics": result.syncedLyrics || "",
            "instrumental": !!result.instrumental,
            "source": "LRCLIB"
        } : {
            "plainLyrics": "",
            "syncedLyrics": "",
            "instrumental": false,
            "source": ""
        };
        var updatedCache = Object.assign({}, lyricsCache);
        updatedCache[completedKey] = cacheEntry;
        lyricsCache = updatedCache;
        if (completedKey === currentKey())
            applyLyrics(cacheEntry.plainLyrics, cacheEntry.syncedLyrics, cacheEntry.instrumental, cacheEntry.source);
    }
    function lookup() {
        requestKey = currentKey();
        pendingRequestKey = "";
        pendingCommand = [];
        if (lyricsProcess.running)
            lyricsProcess.running = false;
        loading = false;
        instrumental = false;
        plainLyrics = "";
        syncedLines = [];
        activeLineIndex = -1;
        lyricsSource = "";
        if (!player || !player.trackTitle)
            return;

        var embedded = embeddedLyrics();
        if (embedded !== "") {
            applyLyrics(embedded, embedded, false, "MPRIS");
            return;
        }
        var cached = lyricsCache[requestKey];
        if (cached !== undefined) {
            applyLyrics(cached.plainLyrics, cached.syncedLyrics, cached.instrumental, cached.source);
            return;
        }
        loading = true;
        pendingRequestKey = requestKey;
        pendingCommand = ["curl", "-fsSL", "--max-time", "8", "--user-agent", "Quickshell-Music/1.0", "--get", "https://lrclib.net/api/search", "--data-urlencode", "track_name=" + (player.trackTitle || ""), "--data-urlencode", "artist_name=" + (player.trackArtist || "")];
        Qt.callLater(startPendingLookup);
    }
    function normalized(value) {
        return String(value || "").trim().toLowerCase().replace(/\s+/g, " ");
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
    function recordScore(record) {
        if (!record || (!record.plainLyrics && !record.syncedLyrics && !record.instrumental))
            return -1;

        var wantedTitle = normalized(player ? player.trackTitle : "");
        var wantedArtist = normalized(player ? player.trackArtist : "");
        var recordTitle = normalized(record.trackName);
        var recordArtist = normalized(record.artistName);
        var score = 0;

        if (recordTitle === wantedTitle)
            score += 100;
        else if (recordTitle.indexOf(wantedTitle) !== -1 || wantedTitle.indexOf(recordTitle) !== -1)
            score += 45;

        if (wantedArtist !== "" && recordArtist === wantedArtist)
            score += 60;
        else if (wantedArtist !== "" && (recordArtist.indexOf(wantedArtist) !== -1 || wantedArtist.indexOf(recordArtist) !== -1))
            score += 25;

        // Prefer synced lyrics heavily over plain text
        if (record.syncedLyrics)
            score += 50;

        var rawDuration = player ? Number(player.length || 0) : 0;
        // Quickshell uses microseconds for MPRIS length. Convert to seconds if it's large.
        if (rawDuration > 86400)
            rawDuration = rawDuration / 1000000;

        if (rawDuration > 0 && rawDuration < 86400 && record.duration)
            score += Math.max(0, 25 - Math.abs(Number(record.duration) - rawDuration) * 5);

        return score;
    }
    function scheduleLookup() {
        lookupDelay.restart();
    }
    function startPendingLookup() {
        if (lyricsProcess.running || pendingRequestKey === "" || pendingCommand.length === 0)
            return;

        processRequestKey = pendingRequestKey;
        pendingRequestKey = "";
        lyricsProcess.command = pendingCommand;
        pendingCommand = [];
        lyricsProcess.running = true;
    }
    function stripSyncedLyrics(value) {
        return String(value || "").split(/\r?\n/).map(function (line) {
            return line.replace(/\[(\d+):(\d+(?:\.\d+)?)\]/g, "").trim();
        }).filter(function (line) {
            return line !== "";
        }).join("\n");
    }
    function updateActiveLine() {
        if (!hasSyncedLyrics || !player || !player.positionSupported) {
            activeLineIndex = -1;
            return;
        }
        var position = Math.max(0, Number(player.position || 0));
        var nextIndex = -1;
        var start = (activeLineIndex >= 0 && activeLineIndex < syncedLines.length && position >= syncedLines[activeLineIndex].time) ? activeLineIndex : 0;
        for (var index = start; index < syncedLines.length; ++index) {
            if (syncedLines[index].time <= position + 0.1)
                nextIndex = index;
            else
                break;
        }
        if (nextIndex !== activeLineIndex)
            activeLineIndex = nextIndex;
    }

    clip: true
    color: "transparent"
    radius: 14

    Component.onCompleted: scheduleLookup()
    onPlayerChanged: scheduleLookup()

    Connections {
        function onMetadataChanged() {
            root.scheduleLookup();
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
        id: lookupDelay

        interval: 260
        repeat: false

        onTriggered: root.lookup()
    }
    Timer {
        interval: 150
        repeat: true
        running: root.hasSyncedLyrics && !!root.player && MediaService.playing

        onTriggered: root.updateActiveLine()
    }
    Process {
        id: lyricsProcess

        stdout: StdioCollector {
            id: lyricsCollector
        }

        onExited: (exitCode, exitStatus) => {
            var completedKey = root.processRequestKey;
            root.processRequestKey = "";
            root.finishLookup(lyricsCollector.text, exitCode, completedKey);
            if (root.pendingRequestKey !== "")
                Qt.callLater(root.startPendingLookup);
        }
    }
    ListView {
        id: syncedList

        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 128
        clip: true
        currentIndex: root.followLyrics ? root.activeLineIndex : -1
        highlightMoveDuration: 350
        highlightRangeMode: root.followLyrics ? ListView.StrictlyEnforceRange : ListView.NoHighlightRange
        model: root.syncedLines
        preferredHighlightBegin: height / 2 - 16
        preferredHighlightEnd: height / 2 + 16
        spacing: 0
        visible: root.hasSyncedLyrics

        delegate: Item {
            readonly property int distance: Math.abs(index - root.activeLineIndex)
            required property int index
            required property var modelData

            height: 32
            width: syncedList.width

            Item {
                anchors.centerIn: parent
                height: parent.height
                width: parent.width

                Text {
                    anchors.centerIn: parent
                    color: Config.md3.on_surface
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    maximumLineCount: 1
                    opacity: index === root.activeLineIndex ? 0.0 : (distance === 1 ? 0.58 : 0.24)
                    renderType: Text.NativeRendering
                    scale: index === root.activeLineIndex ? (18.0 / 14.0) : 1.0
                    text: modelData.text
                    width: parent.width

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 350
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 350
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    color: Config.md3.primary
                    elide: Text.ElideRight
                    font.family: Config.fontName
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    maximumLineCount: 1
                    opacity: index === root.activeLineIndex ? 1.0 : 0.0
                    renderType: Text.NativeRendering
                    scale: index === root.activeLineIndex ? 1.0 : (14.0 / 18.0)
                    text: modelData.text
                    width: parent.width

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 350
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 350
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        onDraggingChanged: {
            if (dragging && root.followLyrics)
                root.followLyrics = false;
        }
        onFlickingChanged: {
            if (flicking && root.followLyrics)
                root.followLyrics = false;
        }

        WheelHandler {
            onWheel: event => {
                if (root.followLyrics)
                    root.followLyrics = false;
                event.accepted = false;
            }
        }
    }
    Flickable {
        id: plainFlick

        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        contentHeight: plainText.implicitHeight
        contentWidth: width
        visible: !root.hasSyncedLyrics && root.plainLyrics !== ""

        Text {
            id: plainText

            color: Config.alpha(Config.md3.on_surface, 0.8)
            font.family: Config.fontName
            font.pixelSize: 14
            font.weight: Font.Medium
            lineHeight: 1.25
            text: root.plainLyrics
            width: plainFlick.width
            wrapMode: Text.Wrap
        }
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
            playing: !root.hasLyrics && !root.loading
            source: "file://" + Config.quickshellDir + "/assets/kurukuru.gif"
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

            onClicked: {
                root.followLyrics = true;
                root.updateActiveLine();
                if (root.activeLineIndex >= 0)
                    syncedList.positionViewAtIndex(root.activeLineIndex, ListView.Center);
            }
        }
    }
}
