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
    property bool dependencyChecked: false
    property bool discardingResult: false
    property string language: ""
    property string pendingImagePath: ""
    property Process recognizeProcess: Process {
        stdout: StdioCollector {
            onStreamFinished: root.recognizedText = text.trim()
        }

        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            root.cleanupInput();

            if (root.discardingResult) {
                root.discardingResult = false;
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
        statusText = "Recognizing text…";
        statusIsError = false;
        recognizeProcess.command = ["tesseract", pendingImagePath, "stdout", "-l", language, "--psm", "6"];
        recognizeProcess.running = false;
        recognizeProcess.running = true;
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
    function recognize(imagePath) {
        if (!imagePath || busy)
            return;

        pendingImagePath = imagePath;
        recognizedText = "";
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
        discardingResult = recognizeProcess.running;
        if (recognizeProcess.running)
            recognizeProcess.signal(15);
        cleanupInput();
        busy = recognizeProcess.running;
        recognizedText = "";
        statusText = "";
        statusIsError = false;
    }
}
