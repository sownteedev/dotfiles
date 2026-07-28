pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

QtObject {
    id: root

    property bool active: false
    property string activeProfile: "balanced"
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
    property Process chargeQuery: Process {
        command: ["cat", "/sys/class/power_supply/BAT0/charge_control_end_threshold"]

        stdout: StdioCollector {
            onStreamFinished: root.chargeMode = text.trim() === "80" ? "preserve" : "maximize"
        }
    }
    property Process commandExecutor: Process {
    }
    property Process cpuQuery: Process {
        command: ["sh", "-c", "gov_current=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo N/A)\n" + "python3 -c '\n" + "import os, pickle\n" + "gov = \"default\"\n" + "if os.path.exists(\"/opt/auto-cpufreq/override.pickle\"):\n" + "    try:\n" + "        with open(\"/opt/auto-cpufreq/override.pickle\", \"rb\") as f: gov = pickle.load(f)\n" + "    except: pass\n" + "turbo = \"auto\"\n" + "if os.path.exists(\"/opt/auto-cpufreq/turbo-override.pickle\"):\n" + "    try:\n" + "        with open(\"/opt/auto-cpufreq/turbo-override.pickle\", \"rb\") as f: turbo = pickle.load(f)\n" + "    except: pass\n" + "print(f\"{gov}|{turbo}\")\n" + "' | while read line; do echo \"$gov_current|$line\"; done"]

        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split("|");
                if (parts.length >= 3) {
                    root.currentGovernor = parts[0];
                    root.governorOverride = parts[1];
                    root.turboOverride = parts[2];
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
    property Process profileQuery: Process {
        command: ["powerprofilesctl", "get"]

        stdout: StdioCollector {
            onStreamFinished: {
                var profile = text.trim();
                if (profile !== "")
                    root.activeProfile = profile;
            }
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

    function refresh() {
        if (!active)
            return;
        if (powerProfilesAvailable) {
            profileQuery.running = false;
            profileQuery.running = true;
        }
        chargeQuery.running = false;
        chargeQuery.running = true;
        if (autoCpufreqAvailable) {
            cpuQuery.running = false;
            cpuQuery.running = true;
        }
    }
    function formatValue(value, precision, suffix) {
        return value === null || value === undefined || !isFinite(Number(value)) || Number(value) <= 0 ? "N/A" : Number(value).toFixed(precision) + suffix;
    }
    function runCommand(command) {
        commandExecutor.command = ["sh", "-c", command];
        commandExecutor.running = false;
        commandExecutor.running = true;
        refreshDelay.restart();
    }

    onActiveChanged: {
        if (active) {
            refresh();
        } else {
            profileQuery.running = false;
            chargeQuery.running = false;
            cpuQuery.running = false;
        }
    }
}
