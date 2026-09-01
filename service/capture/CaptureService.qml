pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
import ".."

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
            if (root.recordingStartedAt <= 0) {
                root.recordingTarget = "";
                root.recordingTargetMode = "";
                root.recordingCountdownRemaining = 0;
                if (exitCode !== 0)
                    root.failRecordingStart(recorderError.text.trim() || qsTr("Could not start screen recording"));
                return;
            }
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
            root.recordingCountdownTimer.stop();
            root.recordingCountdownRemaining = 0;
            root.recordingOutputPending = false;
            root.recordingTarget = "";
            root.recordingTargetMode = "";
            root.recordingStopRequested = false;
            root.recordingStartedAt = Date.now();
            root.recordingElapsedSeconds = 0;
            recordingTicker.start();
        }
    }
    readonly property bool recording: recorder.running
    property int recordingCountdownRemaining: 0
    property Timer recordingCountdownTimer: Timer {
        interval: 1000
        repeat: true

        onTriggered: {
            root.recordingCountdownRemaining = Math.max(0, root.recordingCountdownRemaining - 1);
            if (root.recordingCountdownRemaining === 0) {
                stop();
                root.startPreparedRecording();
            }
        }
    }
    readonly property string recordingDir: Config.captureRecordingDir
    property int recordingElapsedSeconds: 0
    readonly property string recordingElapsedText: formatDuration(recordingElapsedSeconds)
    property var recordingMicrophoneOptions: [
        {
            "label": qsTr("Default microphone"),
            "value": "default_input"
        }
    ]
    property Process recordingMicrophoneQuery: Process {
        command: ["gpu-screen-recorder", "--list-audio-devices"]

        stdout: StdioCollector {
            id: recordingMicrophoneOutput
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                return;
            root.recordingMicrophoneOptions = root.parseRecordingMicrophones(recordingMicrophoneOutput.text);
        }
    }
    readonly property bool recordingMicrophoneQueryBusy: recordingMicrophoneQuery.running
    property bool recordingOutputPending: false
    property Process recordingOutputQuery: Process {
        command: ["niri", "msg", "-j", "focused-output"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.recordingScreenName = root.parseOutputName(text);
                if (!root.recordingOutputPending)
                    return;

                root.recordingOutputPending = false;
                if (root.recordingScreenName !== "")
                    root.prepareRecording("screen", root.recordingScreenName);
                else
                    root.failRecordingStart(qsTr("Could not detect the focused display"));
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && root.recordingOutputPending) {
                root.recordingOutputPending = false;
                root.failRecordingStart(qsTr("Could not detect the focused display"));
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
    readonly property bool recordingStarting: !recording && (recordingOutputPending || recordingTarget !== "")
    property bool recordingStopRequested: false
    property string recordingTarget: ""
    property string recordingTargetMode: ""
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
                root.prepareRecording("region", region);
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
    property string screenshotCaptureScreenName: ""
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
    property Process screenshotPrepareProcess: Process {
        stderr: StdioCollector {
            id: screenshotPrepareError
        }

        onExited: (exitCode, exitStatus) => {
            var session = root.screenshotPrepareSession;
            var sourcePath = root.screenshotPrepareSourcePath;
            var targetPath = root.screenshotPrepareTargetPath;
            root.screenshotPrepareSession = -1;
            root.screenshotPrepareSourcePath = "";
            root.screenshotPrepareTargetPath = "";
            if (session !== root.screenshotCaptureSession) {
                if (targetPath !== "")
                    Quickshell.execDetached(["rm", "-f", "--", targetPath]);
                return;
            }

            if (exitCode === 0 && targetPath !== "") {
                if (sourcePath !== targetPath)
                    Quickshell.execDetached(["rm", "-f", "--", sourcePath]);
                root.finalizeScreenshotCapture(targetPath);
                return;
            }

            if (targetPath !== "")
                Quickshell.execDetached(["rm", "-f", "--", targetPath]);
            console.warn("[Capture] Screenshot conversion failed:", screenshotPrepareError.text.trim() || "exit code " + exitCode);
            root.finalizeScreenshotCapture(sourcePath);
        }
    }
    property int screenshotPrepareSession: -1
    property string screenshotPrepareSourcePath: ""
    property string screenshotPrepareTargetPath: ""
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
                if (!path || path === "__NO_MATCH__") {
                    root.screenshotBusy = false;
                    return;
                }
                root.prepareScreenshotCapture(path);
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
    function cancelRecordingStart() {
        recordingCountdownTimer.stop();
        recordingCountdownRemaining = 0;
        recordingOutputPending = false;
        recordingTarget = "";
        recordingTargetMode = "";
    }
    function clearReverseImageSearchStatus() {
        reverseImageSearchStatus = "";
        reverseImageSearchStatusIsError = false;
    }
    function closeScreenshotEditor() {
        dismissScreenshotEditor();
    }
    function configuredScreenshotFormat() {
        var format = String(Config.captureScreenshotFormat || "png").toLowerCase();
        return format === "jpeg" || format === "webp" ? format : "png";
    }
    function copyRecording(path) {
        var target = path || latestRecordingPath;
        if (!target)
            return;

        // Copy the file URI instead of buffering the whole video in RAM.
        // File-aware Wayland applications can paste it as an MP4 file.
        Quickshell.execDetached(["sh", "-c", "printf 'file://%s\\r\\n' \"$1\" | wl-copy --type text/uri-list", "copy-recording", target]);
    }
    function copyScreenshot(path) {
        var target = path || screenshotPath;
        if (!target)
            return;

        Quickshell.execDetached(["sh", "-c", "wl-copy --type \"$2\" < \"$1\"", "copy-screenshot", target, screenshotMimeType(target)]);
    }
    function dismissScreenshotEditor() {
        screenshotEditorVisible = false;
    }
    function editedScreenshotPath() {
        if (!screenshotPath)
            return "";

        var capturedAt = screenshotCapturedAt > 0 ? new Date(screenshotCapturedAt) : new Date();
        var template = String(Config.captureScreenshotFilenameTemplate || "{date}_{time}-edited");
        var name = template.split("{date}").join(Qt.formatDateTime(capturedAt, "yyyy-MM-dd"));
        name = name.split("{time}").join(Qt.formatDateTime(capturedAt, "HH-mm-ss"));
        name = name.replace(/[\/\\]/g, "-").replace(/\s+/g, " ").trim();
        name = name.replace(/\.(png|jpe?g|webp)$/i, "").replace(/^\.+/, "");
        if (name === "")
            name = Qt.formatDateTime(capturedAt, "yyyy-MM-dd_HH-mm-ss") + "-edited";

        var format = configuredScreenshotFormat();
        var extension = format === "jpeg" ? "jpg" : format;
        var outputPath = screenshotDir + "/" + name + "." + extension;
        if (outputPath === screenshotPath)
            outputPath = screenshotDir + "/" + name + "-edited." + extension;
        return outputPath;
    }
    function failRecordingStart(message) {
        cancelRecordingStart();
        recordingPath = "";
        recordingSavedVisible = false;
        var detail = message || qsTr("Could not start screen recording");
        console.warn("[Capture]", detail);
        Quickshell.execDetached(["notify-send", "-a", "Screen Recording", "-u", "normal", "-h", "boolean:transient:true", qsTr("Recording failed"), detail]);
    }
    function finalizeScreenshotCapture(path) {
        screenshotBusy = false;
        if (!path)
            return;

        screenshotPath = path;
        screenshotCapturedAt = Date.now();
        var action = String(Config.captureScreenshotAction || "notification");
        if (action === "editor")
            openScreenshotEditor(screenshotCaptureScreenName);
        else if (action === "copy")
            copyScreenshot(path);
    }
    function finishScreenshotEditing(path) {
        if (!path)
            return;
        screenshotPath = path;
        screenshotEditorVisible = false;
        if (Config.captureAutoCopyScreenshot) {
            copyScreenshot(path);
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
        var targetScreen = screenName || WorkspaceService.focusedOutputName || "";
        if (targetScreen === "" && Quickshell.screens.length > 0)
            targetScreen = Quickshell.screens[0].name;
        screenshotEditorScreenName = targetScreen;
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
    function parseRecordingMicrophones(output) {
        var options = [
            {
                "label": qsTr("Default microphone"),
                "value": "default_input"
            }
        ];
        var seen = {
            "default_input": true
        };
        var lines = String(output || "").split("\n");
        for (var i = 0; i < lines.length; ++i) {
            var separator = lines[i].indexOf("|");
            if (separator <= 0)
                continue;
            var value = lines[i].substring(0, separator).trim();
            var label = lines[i].substring(separator + 1).trim();
            if (value === "" || value === "default_output" || value.endsWith(".monitor") || seen[value])
                continue;
            seen[value] = true;
            options.push({
                "label": label || value,
                "value": value
            });
        }
        return options;
    }
    function prepareRecording(mode, target) {
        if (!target) {
            failRecordingStart(qsTr("No recording target was selected"));
            return;
        }

        recordingTargetMode = mode === "screen" ? "screen" : "region";
        recordingTarget = String(target);
        var countdown = Math.round(Number(Config.captureRecordingCountdown) || 0);
        recordingCountdownRemaining = countdown === 3 || countdown === 5 || countdown === 10 ? countdown : 0;
        if (recordingCountdownRemaining > 0)
            recordingCountdownTimer.restart();
        else
            startPreparedRecording();
    }
    function prepareScreenshotCapture(path) {
        var format = configuredScreenshotFormat();
        if (format === "png") {
            finalizeScreenshotCapture(path);
            return;
        }

        var dot = path.lastIndexOf(".");
        var slash = path.lastIndexOf("/");
        var base = dot > slash ? path.substring(0, dot) : path;
        var target = base + (format === "jpeg" ? ".jpg" : ".webp");
        var quality = Math.max(1, Math.min(100, Math.round(Number(Config.captureScreenshotQuality) || 90)));
        var command = ["nice", "-n", "10", "magick", "-limit", "thread", "2", "-limit", "memory", "256MiB", "-limit", "map", "512MiB", path + "[0]", "-strip", "-quality", String(quality)];
        if (format === "webp")
            command = command.concat(["-define", "webp:method=4"]);
        command.push(target);
        screenshotPrepareSourcePath = path;
        screenshotPrepareTargetPath = target;
        screenshotPrepareSession = screenshotCaptureSession;
        screenshotPrepareProcess.command = command;
        screenshotPrepareProcess.running = true;
    }
    function refreshRecordingMicrophones() {
        if (!recordingMicrophoneQuery.running)
            recordingMicrophoneQuery.running = true;
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
        screenshotCaptureSession += 1;
        if (screenshotBusy) {
            screenshotLaunchDelay.stop();
            screenshotWatcher.running = false;
        }
        if (screenshotPrepareProcess.running)
            screenshotPrepareProcess.running = false;

        screenshotBusy = true;
        screenshotCaptureScreenName = WorkspaceService.focusedOutputName || "";
        screenshotStartedAt = Date.now();
        screenshotPath = "";
        screenshotCapturedAt = 0;
        beginScreenshotCapture();
    }
    function screenshotMimeType(path) {
        var lowerPath = String(path || "").toLowerCase();
        if (lowerPath.endsWith(".jpg") || lowerPath.endsWith(".jpeg"))
            return "image/jpeg";
        if (lowerPath.endsWith(".webp"))
            return "image/webp";
        return "image/png";
    }
    function searchScreenshotWithLens(path, width, height) {
        if (!path || reverseImageSearchProcess.running)
            return;

        clearReverseImageSearchStatus();
        reverseImageSearchStatus = qsTr("Searching with Google Lens…");
        reverseImageSearchProcess.command = ["bash", Config.quickshellDir + "/scripts/capture/google-lens-search.sh", path, String(Math.max(1, Math.round(width))), String(Math.max(1, Math.round(height)))];
        reverseImageSearchProcess.running = true;
    }
    function startPreparedRecording() {
        if (recording || recordingTarget === "")
            return;

        var stamp = Qt.formatDateTime(new Date(), "dd-MM-yyyy_HH-mm-ss");
        recordingPath = recordingDir + "/recording_" + stamp + ".mp4";
        var microphoneSource = String(Config.captureRecordingMicrophoneSource || "default_input").trim() || "default_input";
        var audioSource = Config.captureRecordingMicrophone ? "default_output|" + microphoneSource : "default_output";
        var command = ["gpu-screen-recorder"];
        if (recordingTargetMode === "screen")
            command = command.concat(["-w", recordingTarget]);
        else
            command = command.concat(["-w", "region", "-region", recordingTarget]);
        command = command.concat(["-f", String(Config.captureRecordingFps), "-a", audioSource, "-ac", "opus", "-ab", "160", "-k", Config.captureRecordingCodec, "-q", Config.captureRecordingQuality, "-bm", "qp", "-encoder", "gpu", "-fallback-cpu-encoding", "yes", "-tune", "performance", "-cr", "limited", "-fm", "vfr", "-keyint", "2", "-cursor", Config.captureRecordingCursor ? "yes" : "no", "-o", recordingPath]);
        recorder.command = command;
        recorder.running = true;
    }
    function startRecording() {
        if (recording || selectingRegion || recordingStarting)
            return;

        recordingSavedVisible = false;
        recordingScreenName = WorkspaceService.focusedOutputName || "";
        if (String(Config.captureRecordingMode || "region") === "screen") {
            console.log("[Capture] Starting focused display recording");
            if (recordingScreenName !== "") {
                prepareRecording("screen", recordingScreenName);
                return;
            }

            recordingOutputPending = true;
            recordingOutputQuery.running = false;
            recordingOutputQuery.running = true;
            return;
        }

        console.log("[Capture] Starting region selector");
        selectingRegion = true;
        if (recordingScreenName !== "") {
            beginRegionSelection();
            return;
        }

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
        if (recordingStarting) {
            cancelRecordingStart();
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
        console.log("[Capture] Recording toggle received; recording:", recording, "selecting:", selectingRegion, "starting:", recordingStarting);

        // Repeated hotkey events must never close slurp. Escape remains the
        // natural way to cancel the region selection.
        if (selectingRegion) {
            console.log("[Capture] Region selector already active; ignoring toggle");
            return;
        }

        if (recording || recordingStarting)
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
        recordingCountdownTimer.stop();
        if (screenshotPrepareProcess.running)
            screenshotPrepareProcess.running = false;
        if (recorder.running)
            recorder.signal(2);
    }
}
