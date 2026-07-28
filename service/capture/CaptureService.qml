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
        onExited: (exitCode, exitStatus) => {
            console.log("[Capture] Screen recording stopped with code:", exitCode);
            recordingTicker.stop();
            if (root.recordingStartedAt <= 0)
                return;
            root.recordingElapsedSeconds = Math.max(0, Math.floor((Date.now() - root.recordingStartedAt) / 1000));
            root.recordingStartedAt = 0;
            root.latestRecordingPath = root.recordingPath;
            if (Config.captureAutoCopyRecording)
                root.copyRecording(root.latestRecordingPath);
            root.recordingSavedVisible = true;
            recordingSavedTimer.restart();
        }
        onStarted: {
            console.log("[Capture] Screen recording started:", root.recordingPath);
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
                recorder.command = ["gpu-screen-recorder", "-w", "region", "-region", region, "-f", String(Config.captureRecordingFps), "-a", "default_output", "-ac", "opus", "-q", Config.captureRecordingQuality, "-k", Config.captureRecordingCodec, "-cr", "limited", "-fm", "vfr", "-o", root.recordingPath];
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
    property bool screenshotBusy: false
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
    property Process screenshotWatcher: Process {
        command: ["inotifywait", "-q", "-t", "60", "-e", "close_write,moved_to", "--include", "\\.(png|jpg|jpeg)$", "--format", "%w%f", root.screenshotDir]

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                var path = lines.length > 0 ? lines[lines.length - 1].trim() : "";
                root.screenshotBusy = false;
                if (!path)
                    return;
                root.screenshotPath = path;
                root.screenshotCapturedAt = Date.now();
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.screenshotBusy = false;
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
        screenshotWatcher.running = true;
        screenshotLaunchDelay.restart();
    }
    function closeScreenshotEditor() {
        screenshotEditorVisible = false;
        Quickshell.execDetached(["notify-send", "-a", "Screenshot", "-u", "low", "Canceled", "Screenshot editing canceled"]);
    }
    function copyRecording(path) {
        var target = path || latestRecordingPath;
        if (!target)
            return;

        // Copy the file URI instead of buffering the whole video in RAM.
        // File-aware Wayland applications can paste it as an MP4 file.
        Quickshell.execDetached(["sh", "-c", "printf 'file://%s\\r\\n' \"$1\" | wl-copy --type text/uri-list", "copy-recording", target]);
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
            Quickshell.execDetached(["notify-send", "-a", "Screenshot", "-i", path, "Copied to Clipboard", "The edited screenshot has been saved to your clipboard"]);
        } else {
            Quickshell.execDetached(["notify-send", "-a", "Screenshot", "-i", path, "Screenshot saved", path]);
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
    function screenshot() {
        // Niri does not emit a cancellation event for its screenshot overlay.
        // A second shortcut press therefore replaces any stale one-shot watcher.
        if (screenshotBusy) {
            screenshotLaunchDelay.stop();
            screenshotWatcher.running = false;
        }

        screenshotBusy = true;
        screenshotPath = "";
        screenshotCapturedAt = 0;
        beginScreenshotCapture();
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
    function stopRecording() {
        if (selectingRegion) {
            selectingRegion = false;
            if (regionSelector.running)
                regionSelector.running = false;
            return;
        }

        if (recorder.running)
            recorder.signal(2);
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
