pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

QtObject {
    id: root

    property Process actionExecutor: Process {
    }
    readonly property string configPath: Config.niriOutputConfig
    property Process configUpdater: Process {
        onRunningChanged: {
            if (!running) {
                delayedRefresh.restart();
            }
        }
    }
    property Process darkmodeApply: Process {
    }

    // Dark mode
    property bool darkmodeEnabled: false
    property Process darkmodeQuery: Process {
        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface color-scheme"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.darkmodeEnabled = text.trim().indexOf("prefer-dark") >= 0;
            }
        }
    }
    property Timer delayedRefresh: Timer {
        interval: 400
        repeat: false

        onTriggered: root.refresh()
    }
    property string internalHardwareId: ""
    property var kdlOptions: ({})
    property Timer nightlightApplyDelay: Timer {
        interval: 160
        repeat: false

        onTriggered: {
            if (root.nightlightEnabled) {
                actionExecutor.command = ["sh", "-c", "pkill -x gammastep >/dev/null 2>&1; gammastep -O " + root.nightlightTemperature + " >/dev/null 2>&1 &"];
                actionExecutor.running = false;
                actionExecutor.running = true;
            }
        }
    }

    // Night Light
    property bool nightlightEnabled: false
    property Process nightlightQuery: Process {
        command: ["sh", "-c", "night_temp=$(pgrep -ax gammastep | sed -n 's/.* -O \\([0-9][0-9]*\\).*/\\1/p' | head -n 1); " + "if pgrep -x gammastep >/dev/null; then echo on:${night_temp:-4000}; " + "else echo off:4000; fi"]

        stdout: StdioCollector {
            onStreamFinished: {
                var cleaned = text.trim();
                if (cleaned === "")
                    return;
                var nightState = cleaned.split(":");
                root.nightlightEnabled = nightState[0] === "on";
                if (nightState.length > 1) {
                    var detectedTemperature = parseInt(nightState[1], 10);
                    if (!isNaN(detectedTemperature))
                        root.nightlightTemperature = detectedTemperature;
                }
            }
        }
    }
    property int nightlightTemperature: 4000
    property Process optionsQuery: Process {
        command: ["python3", Config.quickshellDir + "/scripts/display_config_parser.py", root.configPath]

        stdout: StdioCollector {
            onStreamFinished: {
                var cleaned = text.trim();
                if (cleaned === "")
                    return;
                try {
                    root.kdlOptions = JSON.parse(cleaned);
                } catch (error) {
                    console.warn("[DisplayService] Failed to parse KDL options:", error);
                }
            }
        }
    }
    property var outputs: []
    property Process outputsQuery: Process {
        command: ["niri", "msg", "-j", "outputs"]

        stdout: StdioCollector {
            onStreamFinished: {
                var cleaned = text.trim();
                if (cleaned === "")
                    return;
                try {
                    var data = JSON.parse(cleaned);
                    var nextOutputs = [];
                    var internalId = "";
                    for (var key in data) {
                        if (!data.hasOwnProperty(key))
                            continue;
                        var output = data[key];
                        nextOutputs.push(output);
                        if (output.name && output.name.startsWith("eDP-"))
                            internalId = ((output.make || "") + " " + (output.model || "") + " " + (output.serial || "Unknown")).trim();
                    }
                    root.internalHardwareId = internalId;
                    root.outputs = nextOutputs;
                } catch (error) {
                    console.warn("[DisplayService] Failed to parse outputs:", error);
                }
            }
        }
    }

    function applyPositions(positions) {
        var commands = [];
        for (var output in positions) {
            if (!positions.hasOwnProperty(output))
                continue;
            var position = positions[output];
            var names = outputsToUpdate(output);
            for (var i = 0; i < names.length; ++i) {
                commands.push(ensureOutputCommand(names[i], output));
                commands.push("sed -i '/output \"" + names[i] + "\" {/,/}/{s/position x=[0-9-]* y=[0-9-]*/position x=" + position.x + " y=" + position.y + "/}' " + configPath);
            }
        }
        if (commands.length > 0)
            executeConfigCommand(commands.join("; "));
    }
    function ensureOutputCommand(output, sourceOutput) {
        var defaults = outputDefaults(sourceOutput || output);
        return "if ! grep -q 'output \"" + output + "\" {' " + configPath + "; then echo -e '\\noutput \"" + output + "\" {\\n    mode \"" + defaults.mode + "\"\\n    scale " + defaults.scale + "\\n    transform \"" + defaults.transform + "\"\\n    position x=" + defaults.x + " y=" + defaults.y + "\\n}' >> " + configPath + "; fi";
    }
    function executeConfigCommand(command) {
        configUpdater.command = ["sh", "-c", command + "; niri msg action load-config-file"];
        configUpdater.running = false;
        configUpdater.running = true;
    }
    function optionEnabled(output, option) {
        var values = kdlOptions[output];
        if (values && values[option] !== undefined)
            return values[option];
        if (output.startsWith("eDP-") && internalHardwareId !== "") {
            values = kdlOptions[internalHardwareId];
            if (values && values[option] !== undefined)
                return values[option];
        }
        return false;
    }
    function outputDefaults(sourceOutput) {
        var result = {
            mode: "1920x1080@60.000",
            scale: 1.0,
            transform: "normal",
            x: 0,
            y: 0
        };
        for (var i = 0; i < outputs.length; ++i) {
            var candidate = outputs[i];
            if (!candidate || candidate.name !== sourceOutput)
                continue;
            var modeIndex = Number(candidate.current_mode);
            var mode = candidate.modes && modeIndex >= 0 ? candidate.modes[modeIndex] : null;
            if (mode) {
                result.mode = mode.width + "x" + mode.height + "@" + (Number(mode.refresh_rate) / 1000).toFixed(3);
            }
            if (candidate.logical) {
                result.scale = Number(candidate.logical.scale) || 1.0;
                result.transform = String(candidate.logical.transform || "normal").toLowerCase();
                result.x = Number(candidate.logical.x) || 0;
                result.y = Number(candidate.logical.y) || 0;
            }
            break;
        }
        return result;
    }
    function outputsToUpdate(output) {
        if (output.startsWith("eDP-") || (internalHardwareId !== "" && output === internalHardwareId)) {
            if (internalHardwareId !== "")
                return [internalHardwareId];
            return [output, output === "eDP-1" ? "eDP-2" : "eDP-1"];
        }
        return [output];
    }
    function refresh() {
        outputsQuery.running = false;
        outputsQuery.running = true;
        optionsQuery.running = false;
        optionsQuery.running = true;
        darkmodeQuery.running = false;
        darkmodeQuery.running = true;
        nightlightQuery.running = false;
        nightlightQuery.running = true;
    }
    function setDarkmodeEnabled(enabled) {
        darkmodeEnabled = enabled;
        darkmodeApply.command = ["sh", "-c", "gsettings set org.gnome.desktop.interface color-scheme '" + (enabled ? "prefer-dark" : "prefer-light") + "'" + " && gsettings set org.gnome.desktop.interface gtk-theme '" + (enabled ? "adw-gtk3-dark" : "adw-gtk3") + "'"];
        darkmodeApply.running = false;
        darkmodeApply.running = true;
    }
    function setNightlightEnabled(enabled) {
        nightlightEnabled = enabled;
        nightlightApplyDelay.stop();
        if (enabled) {
            actionExecutor.command = ["sh", "-c", "pkill -x gammastep >/dev/null 2>&1; gammastep -O " + nightlightTemperature + " >/dev/null 2>&1 &"];
            actionExecutor.running = false;
            actionExecutor.running = true;
        } else {
            actionExecutor.command = ["sh", "-c", "pkill -x gammastep >/dev/null 2>&1 || true"];
            actionExecutor.running = false;
            actionExecutor.running = true;
        }
        delayedRefresh.restart();
    }
    function setNightlightTemperature(temperature) {
        nightlightTemperature = Math.max(2500, Math.min(6500, Math.round(temperature / 50) * 50));
        if (nightlightEnabled)
            nightlightApplyDelay.restart();
    }
    function toggleOption(output, option, enabled) {
        if (output === "")
            return;
        var names = outputsToUpdate(output);
        var optionName = option === "vrr" ? "variable-refresh-rate" : "focus-at-startup";
        var commands = [];
        for (var i = 0; i < names.length; ++i) {
            commands.push(ensureOutputCommand(names[i], output));
            if (enabled) {
                commands.push("sed -i '/output \"" + names[i] + "\" {/,/}/{s|//[[:space:]]*" + optionName + "|" + optionName + "|}' " + configPath);
                commands.push("sed -n '/output \"" + names[i] + "\" {/,/}/p' " + configPath + " | grep -q '^[[:space:]]*" + optionName + "' || sed -i '/output \"" + names[i] + "\" {/,/}/{/}/i\\    " + optionName + "' " + configPath);
            } else {
                commands.push("sed -i '/output \"" + names[i] + "\" {/,/}/{s|^[[:space:]]*" + optionName + "|    // " + optionName + "|}' " + configPath);
            }
        }
        executeConfigCommand(commands.join("; "));

        var updated = Object.assign({}, kdlOptions);
        for (var j = 0; j < names.length; ++j) {
            updated[names[j]] = Object.assign({}, updated[names[j]] || {});
            updated[names[j]][option] = enabled;
        }
        kdlOptions = updated;
    }
    function updateConfig(output, field, value) {
        if (output === "")
            return;
        var names = outputsToUpdate(output);
        var commands = [];
        for (var i = 0; i < names.length; ++i) {
            var name = names[i];
            commands.push(ensureOutputCommand(name, output));
            if (field === "mode") {
                commands.push("sed -i '/output \"" + name + "\" {/,/}/{s/mode \".*\"/mode \"" + value + "\"/}' " + configPath);
            } else if (field === "scale") {
                commands.push("sed -i '/output \"" + name + "\" {/,/}/{s/scale [0-9.]*/scale " + value + "/}' " + configPath);
            } else if (field === "transform") {
                commands.push("sed -i '/output \"" + name + "\" {/,/}/{s/transform \".*\"/transform \"" + value + "\"/}' " + configPath);
            }
        }
        executeConfigCommand(commands.join("; "));
    }

    Component.onCompleted: refresh()
}
