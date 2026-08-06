pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../../"

QtObject {
    id: root

    property bool active: false
    property bool autoCpufreqAvailable: false
    property Process availabilityQuery: Process {
        command: ["sh", "-c", "command -v powerprofilesctl >/dev/null 2>&1 && power=1 || power=0; " + "command -v auto-cpufreq >/dev/null 2>&1 && auto=1 || auto=0; " + "echo \"$power|$auto\""]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split("|");
                root.powerProfilesAvailable = parts.length > 0 && parts[0] === "1";
                root.autoCpufreqAvailable = parts.length > 1 && parts[1] === "1";
                if (root.active)
                    root.refresh();
            }
        }
    }
    property Process batteryQuery: Process {
        command: [Config.quickshellDir + "/backend/run-qs-stats", "--battery-stream"]
        running: root.active

        stdout: SplitParser {
            onRead: line => {
                try {
                    var data = JSON.parse(line);
                    root.gpuPower = root.formatValue(data.gpu_power, 1, " W");
                    root.health = root.formatValue(data.health, 1, "%");
                    root.cycleCount = data.cycle_count === null || data.cycle_count <= 0 ? "N/A" : String(Math.round(data.cycle_count));
                    root.temperature = root.formatValue(data.temperature, 1, "°C");
                    root.voltage = root.formatValue(data.voltage, 2, " V");
                    root.powerDraw = root.formatValue(data.power_draw, 1, " W");
                    root.designEnergy = root.formatValue(data.design_energy, 1, " Wh");
                    root.deviceName = data.device_name || "Battery";
                } catch (error) {
                    console.warn("[BatteryService] Invalid backend output:", error);
                }
            }
        }

        Component.onDestruction: running = false
    }
    property string chargeMode: "maximize"
    property Process commandExecutor: Process {
        onExited: root.refreshDelay.restart()
    }
    property Process controlQuery: Process {
        command: [Config.quickshellDir + "/backend/run-qs-stats", "--battery-control"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim());
                    root.chargeMode = data.charge_mode || "maximize";
                    root.currentGovernor = data.current_governor || "N/A";
                    root.governorOverride = data.governor_override || "default";
                    root.turboOverride = data.turbo_override || "auto";
                } catch (error) {
                    console.warn("[BatteryService] Invalid control output:", error);
                }
            }
        }
    }
    property string currentGovernor: "N/A"
    property string cycleCount: "N/A"
    property string designEnergy: "N/A"
    property string deviceName: "Battery"
    property string governorOverride: "default"
    property string gpuPower: "N/A"
    property string health: "N/A"
    property string powerDraw: "N/A"
    property bool powerProfilesAvailable: false
    readonly property bool performanceDegraded: PowerProfiles.degradationReason !== PerformanceDegradationReason.None
    readonly property int performanceDegradationReason: PowerProfiles.degradationReason
    readonly property string performanceDegradationText: {
        switch (performanceDegradationReason) {
        case PerformanceDegradationReason.LapDetected:
            return "Performance is limited because the laptop is on a lap";
        case PerformanceDegradationReason.HighTemperature:
            return "Performance is limited by high temperature";
        default:
            return "";
        }
    }
    property Timer refreshDelay: Timer {
        interval: 1000
        repeat: false

        onTriggered: root.refresh()
    }
    property string temperature: "N/A"
    property string turboOverride: "auto"
    property string voltage: "N/A"

    function formatValue(value, precision, suffix) {
        return value === null || value === undefined || !isFinite(Number(value)) || Number(value) <= 0 ? "N/A" : Number(value).toFixed(precision) + suffix;
    }
    function refresh() {
        if (!active)
            return;
        controlQuery.running = false;
        controlQuery.running = true;
    }
    function runCommand(command) {
        commandExecutor.command = ["sh", "-c", command];
        commandExecutor.running = false;
        commandExecutor.running = true;
    }
    function setChargeMode(mode) {
        commandExecutor.command = ["pkexec", Config.quickshellDir + "/backend/run-qs-stats", "--set-charge-mode", mode];
        commandExecutor.running = false;
        commandExecutor.running = true;
    }

    onActiveChanged: {
        if (active) {
            refresh();
        } else {
            controlQuery.running = false;
        }
    }
}
