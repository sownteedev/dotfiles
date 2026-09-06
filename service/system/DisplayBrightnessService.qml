pragma Singleton
import QtQuick
import Quickshell.Io
import "../../"
import ".."

QtObject {
    id: root

    readonly property bool available: internalOutput ? BrightnessService.available : externalAvailable
    readonly property string backendLabel: internalOutput ? "Laptop backlight" : externalAvailable ? "DDC/CI • " + outputName : externalError
    readonly property string coreRunner: Config.sownteeshellDir + "/backend/rust/core-daemon/run-core-daemon"
    property bool externalAvailable: false
    property int externalBus: -1
    property string externalError: "Select a display"
    property int externalMaximum: 100
    property real externalRequestedValue: -1
    property real externalValue: 0
    readonly property bool internalOutput: DisplayService.isInternalOutput(outputName)
    property string outputName: ""
    property string pendingProbeOutput: ""
    property CoreRequest probe: CoreRequest {
        timeoutMs: 12000

        onFailed: message => {
            root.externalAvailable = false;
            root.externalError = String(message || qsTr("Could not read external display brightness"));
            root.finishProbe();
        }
        onSucceeded: response => {
            root.applyResponse(response);
            root.finishProbe();
        }
    }
    readonly property bool probing: probe.active
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
    readonly property real value: internalOutput ? BrightnessService.value : externalValue

    function applyExternalValue() {
        if (internalOutput || outputName === "" || setter.running || externalRequestedValue < 0)
            return;
        setter.command = [coreRunner, "display-ddc-set", outputName, String(externalRequestedValue), String(externalBus), String(externalMaximum)];
        setter.running = true;
    }
    function applyResponse(payload) {
        try {
            var result = typeof payload === "string" ? JSON.parse(String(payload || "").trim() || "{}") : (payload || {});
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
    function finishProbe() {
        if (pendingProbeOutput === "")
            return;
        var nextOutput = pendingProbeOutput;
        pendingProbeOutput = "";
        Qt.callLater(function () {
            root.startProbe(nextOutput);
        });
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
        if (probe.active) {
            pendingProbeOutput = name;
            return;
        }
        probe.start("display.ddc.get", {
            "output": name
        });
    }
}
