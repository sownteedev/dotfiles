pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

QtObject {
    id: root

    property double lastRecordingToggleAt: 0
    property string latestRecordingPath: ""
    property Process recorder: Process {
        stderr: StdioCollector {
            id: recorderError
        }

        onExited: (exitCode, exitStatus) => {
            console.log("[Capture] Screen recording stopped with code:", exitCode);
            recordingTicker.stop();
            if (root.recordingStartedAt <= 0)
                return;
            root.recordingElapsedSeconds = Math.max(0, Math.floor((Date.now() - root.recordingStartedAt) / 1000));
            root.recordingStartedAt = 0;
            var completedPath = root.recordingPath;
            root.recordingPath = "";
            var stoppedByUser = root.recordingStopRequested;
            root.recordingStopRequested = false;
            if (exitCode !== 0 && !stoppedByUser) {
                var errorText = recorderError.text.trim();
                console.warn("[Capture] Screen recording failed:", errorText || "exit code " + exitCode);
                root.recordingSavedVisible = false;
                Quickshell.execDetached(["notify-send", "-a", "Screen Recording", "-u", "normal", "-h", "boolean:transient:true", "Recording failed", "The recorder stopped with exit code " + exitCode]);
                return;
            }

            root.latestRecordingPath = completedPath;
            if (Config.captureAutoCopyRecording)
                root.copyRecording(root.latestRecordingPath);
            root.recordingSavedVisible = true;
            recordingSavedTimer.restart();
        }
        onStarted: {
            console.log("[Capture] Screen recording started:", root.recordingPath);
            root.recordingStopRequested = false;
            root.recordingStartedAt = Date.now();
            root.recordingElapsedSeconds = 0;
            recordingTicker.start();
        }
    }
    readonly property bool recording: recorder.running
    readonly property string recordingDir: Config.captureRecordingDir
    property int recordingElapsedSeconds: 0
    readonly property string recordingElapsedText: formatDuration(recordingElapsedSeconds)
    property Process recordingOutputQuery: Process {
        command: ["niri", "msg", "-j", "focused-output"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.recordingScreenName = root.parseOutputName(text);
            }
        }
    }
    property string recordingPath: ""
    property Timer recordingSavedTimer: Timer {
        interval: 6000
        repeat: false

        onTriggered: root.recordingSavedVisible = false
    }
    property bool recordingSavedVisible: false
    property string recordingScreenName: ""
    property double recordingStartedAt: 0
    property bool recordingStopRequested: false
    property Timer recordingTicker: Timer {
        interval: 1000
        repeat: true

        onTriggered: root.recordingElapsedSeconds = Math.max(0, Math.floor((Date.now() - root.recordingStartedAt) / 1000))
    }
    property Process regionSelector: Process {
        // slurp reads optional predefined rectangles until stdin reaches EOF.
        // Redirecting from /dev/null is required here: stdinEnabled=false alone
        // still lets the child inherit Quickshell's open stdin pipe.
        command: ["sh", "-c", "exec slurp -b '#00000090' -c '#ffffff' -w 2 -f '%wx%h+%x+%y' </dev/null"]
        stdinEnabled: false

        stderr: StdioCollector {
            onStreamFinished: {
                var message = text.trim();
                if (message)
                    console.log("[Capture] slurp error:", message);
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                var region = text.trim();
                root.selectingRegion = false;
                if (!region) {
                    console.log("[Capture] Region selection cancelled");
                    return;
                }

                console.log("[Capture] Region selected:", region);

                var stamp = Qt.formatDateTime(new Date(), "dd-MM-yyyy_HH-mm-ss");
                root.recordingPath = root.recordingDir + "/recording_" + stamp + ".mp4";
                var audioSource = Config.captureRecordingMicrophone ? "default_output|default_input" : "default_output";
                // GPU Screen Recorder automatically uses the GPU driving the
                // selected region. Fall back to H.264 CPU encoding only when
                // that GPU has no usable hardware encoder/VA-API backend.
                recorder.command = ["gpu-screen-recorder", "-w", region, "-f", String(Config.captureRecordingFps), "-a", audioSource, "-ac", "opus", "-ab", "160", "-k", Config.captureRecordingCodec, "-q", Config.captureRecordingQuality, "-bm", "qp", "-encoder", "gpu", "-fallback-cpu-encoding", "yes", "-tune", "performance", "-cr", "limited", "-fm", "vfr", "-keyint", "2", "-cursor", "yes", "-o", root.recordingPath];
                recorder.running = true;
            }
        }

        onExited: (exitCode, exitStatus) => {
            console.log("[Capture] slurp exited with code:", exitCode);
            if (exitCode !== 0)
                root.selectingRegion = false;
        }
        onStarted: console.log("[Capture] slurp process started")
    }
    readonly property bool reverseImageSearchBusy: reverseImageSearchProcess.running
    property Process reverseImageSearchProcess: Process {
        stderr: StdioCollector {
            id: reverseImageSearchErrorCollector
        }
        stdout: StdioCollector {
            id: reverseImageSearchOutputCollector
        }

        onExited: (exitCode, exitStatus) => {
            var result = reverseImageSearchOutputCollector.text.trim();
            if (exitCode !== 0) {
                var errorMessage = reverseImageSearchErrorCollector.text.trim();
                root.reverseImageSearchStatus = errorMessage || qsTr("Could not search this image");
                root.reverseImageSearchStatusIsError = true;
                return;
            }

            root.reverseImageSearchStatusIsError = false;
            root.reverseImageSearchStatus = result === "fallback" ? qsTr("Image copied — paste it into Google Lens") : qsTr("Opened results in your browser");
        }
    }
    property string reverseImageSearchStatus: ""
    property bool reverseImageSearchStatusIsError: false
    property bool screenshotBusy: false
    property int screenshotCaptureSession: 0
    property double screenshotCapturedAt: 0
    readonly property string screenshotDir: Config.captureScreenshotDir
    property string screenshotEditorScreenName: ""
    property int screenshotEditorSession: 0
    property bool screenshotEditorVisible: false
    property Timer screenshotLaunchDelay: Timer {
        interval: 120
        repeat: false

        onTriggered: Quickshell.execDetached(["niri", "msg", "action", "screenshot"])
    }
    property string screenshotPath: ""
    property double screenshotStartedAt: 0
    property Timer screenshotWatchdog: Timer {
        interval: 61500
        repeat: false

        onTriggered: {
            if (!root.screenshotBusy)
                return;
            root.screenshotBusy = false;
            root.screenshotWatcher.running = false;
            console.warn("[Capture] Screenshot watcher timed out");
        }
    }
    property Process screenshotWatcher: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                var result = lines.length > 0 ? lines[lines.length - 1].trim() : "";
                var separator = result.indexOf("\t");
                if (separator < 0)
                    return;
                var session = parseInt(result.substring(0, separator), 10);
                if (session !== root.screenshotCaptureSession || !root.screenshotBusy)
                    return;

                var path = result.substring(separator + 1).trim();
                root.screenshotWatchdog.stop();
                root.screenshotBusy = false;
                if (!path || path === "__NO_MATCH__")
                    return;
                root.screenshotPath = path;
                root.screenshotCapturedAt = Date.now();
            }
        }
    }
    property bool selectingRegion: false

    function beginRegionSelection() {
        if (!selectingRegion)
            return;
        regionSelector.running = false;
        regionSelector.running = true;
    }
    function beginScreenshotCapture() {
        screenshotWatcher.running = false;
        var watcherCommand = "path=$(inotifywait -q -t 60 -e close_write,moved_to --include '(^|/)Screenshot from .*\\.(png|jpg|jpeg)$' --format '%w%f' \"$3\") || { printf '%s\\t__NO_MATCH__\\n' \"$1\"; exit 0; }; " + "modified=$(stat -c %Y -- \"$path\" 2>/dev/null || printf 0); " + "if [ \"$modified\" -lt \"$2\" ]; then printf '%s\\t__NO_MATCH__\\n' \"$1\"; exit 0; fi; " + "printf '%s\\t%s\\n' \"$1\" \"$path\"";
        screenshotWatcher.command = ["sh", "-c", watcherCommand, "screenshot-watch", String(screenshotCaptureSession), String(Math.floor(screenshotStartedAt / 1000)), screenshotDir];
        screenshotWatcher.running = true;
        screenshotWatchdog.restart();
        screenshotLaunchDelay.restart();
    }
    function clearReverseImageSearchStatus() {
        reverseImageSearchStatus = "";
        reverseImageSearchStatusIsError = false;
    }
    function closeScreenshotEditor() {
        dismissScreenshotEditor();
    }
    function copyRecording(path) {
        var target = path || latestRecordingPath;
        if (!target)
            return;

        // Copy the file URI instead of buffering the whole video in RAM.
        // File-aware Wayland applications can paste it as an MP4 file.
        Quickshell.execDetached(["sh", "-c", "printf 'file://%s\\r\\n' \"$1\" | wl-copy --type text/uri-list", "copy-recording", target]);
    }
    function dismissScreenshotEditor() {
        screenshotEditorVisible = false;
    }
    function editedScreenshotPath() {
        if (!screenshotPath)
            return "";
        var dot = screenshotPath.lastIndexOf(".");
        var base = dot > screenshotPath.lastIndexOf("/") ? screenshotPath.substring(0, dot) : screenshotPath;
        return base + "-edited.png";
    }
    function finishScreenshotEditing(path) {
        if (!path)
            return;
        screenshotPath = path;
        screenshotEditorVisible = false;
        if (Config.captureAutoCopyScreenshot) {
            Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < \"$1\"", "copy-edited-screenshot", path]);
            Quickshell.execDetached(["notify-send", "-a", "Screenshot", "-i", path, "-h", "boolean:transient:true", "Copied to Clipboard", "The edited screenshot has been saved to your clipboard"]);
        } else {
            Quickshell.execDetached(["notify-send", "-a", "Screenshot", "-i", path, "-h", "boolean:transient:true", "Screenshot saved", path]);
        }
    }
    function formatDuration(totalSeconds) {
        var seconds = Math.max(0, Math.floor(totalSeconds));
        var hours = Math.floor(seconds / 3600);
        var minutes = Math.floor((seconds % 3600) / 60);
        var remainder = seconds % 60;
        var mm = String(minutes).padStart(2, "0");
        var ss = String(remainder).padStart(2, "0");
        return hours > 0 ? String(hours).padStart(2, "0") + ":" + mm + ":" + ss : mm + ":" + ss;
    }
    function openRecording() {
        var path = recording ? recordingPath : latestRecordingPath;
        if (path)
            Quickshell.execDetached(["xdg-open", path]);
        recordingSavedVisible = false;
    }
    function openRecordingFolder() {
        Quickshell.execDetached(["xdg-open", recordingDir]);
        recordingSavedVisible = false;
    }
    function openScreenshot() {
        if (screenshotPath)
            Quickshell.execDetached(["xdg-open", screenshotPath]);
    }
    function openScreenshotEditor(screenName) {
        if (!screenshotPath)
            return;
        clearReverseImageSearchStatus();
        screenshotEditorScreenName = screenName || "";
        screenshotEditorSession++;
        screenshotEditorVisible = true;
    }
    function openScreenshotFolder() {
        Quickshell.execDetached(["xdg-open", screenshotDir]);
    }
    function parseOutputName(text) {
        try {
            var output = JSON.parse(text.trim());
            return output && output.name ? String(output.name) : "";
        } catch (error) {
            return "";
        }
    }
    function replaceScreenshotForEditing(path) {
        if (!path)
            return;
        screenshotPath = path;
        screenshotEditorSession++;
    }
    function screenshot() {
        // Niri does not emit a cancellation event for its screenshot overlay.
        // A second shortcut press therefore replaces any stale one-shot watcher.
        if (screenshotBusy) {
            screenshotLaunchDelay.stop();
            screenshotWatcher.running = false;
        }

        screenshotBusy = true;
        screenshotCaptureSession += 1;
        screenshotStartedAt = Date.now();
        screenshotPath = "";
        screenshotCapturedAt = 0;
        beginScreenshotCapture();
    }
    function searchScreenshotWithLens(path, width, height) {
        if (!path || reverseImageSearchProcess.running)
            return;

        clearReverseImageSearchStatus();
        reverseImageSearchStatus = qsTr("Searching with Google Lens…");
        reverseImageSearchProcess.command = ["bash", Config.quickshellDir + "/scripts/reverse-image-search.sh", path, String(Math.max(1, Math.round(width))), String(Math.max(1, Math.round(height)))];
        reverseImageSearchProcess.running = true;
    }
    function startRecording() {
        if (recording || selectingRegion)
            return;

        console.log("[Capture] Starting region selector");
        recordingSavedVisible = false;
        selectingRegion = true;
        recordingScreenName = "";
        recordingOutputQuery.running = false;
        recordingOutputQuery.running = true;
        beginRegionSelection();
    }
    function stitchedScreenshotPath() {
        if (!screenshotPath)
            return "";
        var dot = screenshotPath.lastIndexOf(".");
        var base = dot > screenshotPath.lastIndexOf("/") ? screenshotPath.substring(0, dot) : screenshotPath;
        return base + "-stitched-" + Qt.formatDateTime(new Date(), "HH-mm-ss-zzz") + ".png";
    }
    function stopRecording() {
        if (selectingRegion) {
            selectingRegion = false;
            if (regionSelector.running)
                regionSelector.running = false;
            return;
        }

        if (recorder.running) {
            recordingStopRequested = true;
            recorder.signal(2);
        }
    }
    function toggleRecording() {
        var now = Date.now();
        if (now - lastRecordingToggleAt < 500) {
            console.log("[Capture] Ignored repeated recording toggle");
            return;
        }
        lastRecordingToggleAt = now;
        console.log("[Capture] Recording toggle received; recording:", recording, "selecting:", selectingRegion);

        // Repeated hotkey events must never close slurp. Escape remains the
        // natural way to cancel the region selection.
        if (selectingRegion) {
            console.log("[Capture] Region selector already active; ignoring toggle");
            return;
        }

        if (recording)
            stopRecording();
        else
            startRecording();
    }
    function trashRecording() {
        if (latestRecordingPath)
            Quickshell.execDetached(["gio", "trash", latestRecordingPath]);
        latestRecordingPath = "";
        recordingSavedVisible = false;
    }
    function trashScreenshot() {
        if (screenshotPath)
            Quickshell.execDetached(["gio", "trash", screenshotPath]);
        screenshotPath = "";
        screenshotCapturedAt = 0;
        screenshotEditorVisible = false;
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", screenshotDir, recordingDir]);
    }
    Component.onDestruction: {
        if (recorder.running)
            recorder.signal(2);
    }
}
