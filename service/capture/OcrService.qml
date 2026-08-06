pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property Process availabilityQuery: Process {
        command: ["sh", "-c", "if ! command -v tesseract >/dev/null 2>&1; then echo missing; exit; fi; langs=$(tesseract --list-langs 2>/dev/null); if printf '%s' \"$langs\" | grep -qx vie && printf '%s' \"$langs\" | grep -qx eng; then echo vie+eng; elif printf '%s' \"$langs\" | grep -qx vie; then echo vie; elif printf '%s' \"$langs\" | grep -qx eng; then echo eng; else echo missing-data; fi"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var result = text.trim();
                root.dependencyChecked = true;
                root.available = result === "vie+eng" || result === "eng" || result === "vie";
                root.language = root.available ? result : "";
                if (root.pendingImagePath)
                    root.beginRecognition();
            }
        }
    }
    property bool available: false
    property bool busy: false
    property string cancellationReason: ""
    property bool dependencyChecked: false
    property int generation: 0
    property string language: ""
    property int pendingGeneration: 0
    property string pendingImagePath: ""
    property int runningGeneration: 0
    property Timer recognizeStopTimer: Timer {
        interval: 1000
        repeat: false

        onTriggered: {
            if (root.recognizeProcess.running && root.runningGeneration !== root.generation)
                root.recognizeProcess.signal(9);
        }
    }
    property Timer recognizeWatchdog: Timer {
        interval: 15000
        repeat: false

        onTriggered: {
            if (!root.recognizeProcess.running || root.runningGeneration !== root.generation)
                return;

            root.generation += 1;
            root.cancellationReason = "timeout";
            root.recognizedText = "";
            root.statusText = "OCR timed out after 15 seconds";
            root.statusIsError = true;
            root.cleanupInput();
            root.recognizeProcess.signal(15);
            root.recognizeStopTimer.restart();
            root.finished(false, "");
        }
    }
    property Process recognizeProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.runningGeneration === root.generation && root.cancellationReason === "")
                    root.recognizedText = text.trim();
            }
        }

        onExited: (exitCode, exitStatus) => {
            var resultIsCurrent = root.runningGeneration === root.generation && root.cancellationReason === "";
            root.recognizeWatchdog.stop();
            root.recognizeStopTimer.stop();
            root.busy = false;
            root.cleanupInput();
            root.runningGeneration = 0;
            root.cancellationReason = "";
            if (!resultIsCurrent) {
                root.recognizedText = "";
                return;
            }

            if (exitCode !== 0) {
                root.statusText = "Could not recognize text";
                root.statusIsError = true;
                root.finished(false, "");
                return;
            }
            if (!root.recognizedText) {
                root.statusText = "No text found in this region";
                root.statusIsError = true;
                root.finished(false, "");
                return;
            }

            Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "copy-ocr", root.recognizedText]);
            root.statusText = "Text copied · " + root.recognizedText.length + " characters";
            root.statusIsError = false;
            root.finished(true, root.recognizedText);
        }
    }
    property string recognizedText: ""
    property bool statusIsError: false
    property string statusText: ""

    signal finished(bool success, string text)

    function beginRecognition() {
        if (!pendingImagePath)
            return;
        if (!available) {
            statusText = "OCR requires tesseract with English or Vietnamese data";
            statusIsError = true;
            cleanupInput();
            finished(false, "");
            return;
        }

        busy = true;
        runningGeneration = pendingGeneration;
        cancellationReason = "";
        statusText = "Recognizing text…";
        statusIsError = false;
        recognizeProcess.command = ["tesseract", pendingImagePath, "stdout", "-l", language, "--psm", "6"];
        recognizeProcess.running = true;
        recognizeWatchdog.restart();
    }
    function cleanupInput() {
        if (pendingImagePath)
            Quickshell.execDetached(["rm", "-f", pendingImagePath]);
        pendingImagePath = "";
    }
    function clearStatus() {
        if (!busy) {
            statusText = "";
            statusIsError = false;
        }
    }
    function discardFile(path) {
        if (path)
            Quickshell.execDetached(["rm", "-f", path]);
    }
    function recognize(imagePath) {
        if (!imagePath || busy)
            return;

        generation += 1;
        pendingGeneration = generation;
        pendingImagePath = imagePath;
        recognizedText = "";
        cancellationReason = "";
        statusIsError = false;

        if (!dependencyChecked || !available) {
            statusText = "Checking OCR support…";
            availabilityQuery.running = false;
            availabilityQuery.running = true;
            return;
        }

        beginRecognition();
    }
    function reportCaptureError() {
        statusText = "Could not capture the OCR region";
        statusIsError = true;
        finished(false, "");
    }
    function reset() {
        generation += 1;
        cancellationReason = "reset";
        recognizeWatchdog.stop();
        if (recognizeProcess.running) {
            recognizeProcess.signal(15);
            recognizeStopTimer.restart();
        }
        cleanupInput();
        busy = recognizeProcess.running;
        pendingGeneration = 0;
        recognizedText = "";
        statusText = "";
        statusIsError = false;
    }

    Component.onDestruction: reset()
}
