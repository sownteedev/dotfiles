pragma Singleton
import QtQuick
import Quickshell.Io
import "../../"
import ".."

QtObject {
    id: root

    readonly property bool available: internalOutput ? BrightnessService.available : externalAvailable
    readonly property string backendLabel: internalOutput ? "Laptop backlight" : externalAvailable ? "DDC/CI • " + outputName : externalError
    property string externalError: "Select a display"
    property bool externalAvailable: false
    property int externalBus: -1
    property int externalMaximum: 100
    property real externalRequestedValue: -1
    property real externalValue: 0
    readonly property bool internalOutput: DisplayService.isInternalOutput(outputName)
    property string outputName: ""
    readonly property bool probing: probe.running
    readonly property real value: internalOutput ? BrightnessService.value : externalValue

    property Process probe: Process {
        stdout: StdioCollector {
            id: probeOutput
        }

        onExited: (exitCode, exitStatus) => {
            root.applyResponse(probeOutput.text);
            if (root.pendingProbeOutput !== "") {
                var nextOutput = root.pendingProbeOutput;
                root.pendingProbeOutput = "";
                Qt.callLater(function () {
                    root.startProbe(nextOutput);
                });
            }
        }
    }
    property string pendingProbeOutput: ""
    property Timer setDelay: Timer {
        interval: 140
        repeat: false

        onTriggered: root.applyExternalValue()
    }
    property Process setter: Process {
        stdout: StdioCollector {
            id: setterOutput
        }

        onExited: (exitCode, exitStatus) => {
            root.applyResponse(setterOutput.text);
            if (root.externalRequestedValue >= 0 && Math.abs(root.externalRequestedValue - root.externalValue) > 0.005)
                root.setDelay.restart();
        }
    }

    function applyExternalValue() {
        if (internalOutput || outputName === "" || setter.running || externalRequestedValue < 0)
            return;
        setter.command = ["python3", Config.quickshellDir + "/scripts/display_brightness.py", "set", outputName, String(externalRequestedValue), String(externalBus), String(externalMaximum)];
        setter.running = true;
    }
    function applyResponse(text) {
        try {
            var result = JSON.parse(String(text || "").trim() || "{}");
            if (String(result.output || "") !== outputName)
                return;
            externalAvailable = result.available === true;
            externalError = String(result.error || (externalAvailable ? "DDC/CI • " + outputName : "Brightness unavailable"));
            if (externalAvailable) {
                externalBus = Number(result.bus);
                externalMaximum = Math.max(1, Number(result.maximum) || 100);
                externalValue = Math.max(0, Math.min(1, Number(result.value) || 0));
                if (!setter.running)
                    externalRequestedValue = externalValue;
            }
        } catch (error) {
            externalAvailable = false;
            externalError = "Could not read external display brightness";
        }
    }
    function refresh() {
        if (outputName === "") {
            externalAvailable = false;
            externalError = "Select a display";
            return;
        }
        if (internalOutput) {
            BrightnessService.refresh();
            return;
        }
        startProbe(outputName);
    }
    function selectOutput(name) {
        outputName = String(name || "");
        externalBus = -1;
        externalMaximum = 100;
        externalRequestedValue = -1;
        refresh();
    }
    function setValue(newValue) {
        var nextValue = Math.max(0, Math.min(1, Number(newValue) || 0));
        if (internalOutput) {
            BrightnessService.setValue(nextValue);
            return;
        }
        if (!externalAvailable)
            return;
        externalValue = nextValue;
        externalRequestedValue = nextValue;
        setDelay.restart();
    }
    function startProbe(name) {
        if (probe.running) {
            pendingProbeOutput = name;
            return;
        }
        probe.command = ["python3", Config.quickshellDir + "/scripts/display_brightness.py", "get", name];
        probe.running = true;
    }
}
