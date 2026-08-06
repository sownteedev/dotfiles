pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
import ".."

QtObject {
    id: root

    property Process actionExecutor: Process {
    }
    readonly property string configPath: Config.niriOutputConfig
    property var pendingConfigCommands: []
    property Timer configApplyDebounce: Timer {
        interval: 70
        repeat: false

        onTriggered: root.startPendingConfigUpdate()
    }
    property Process configUpdater: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("[DisplayService] Failed to update output configuration:", exitCode);

            if (root.pendingConfigCommands.length > 0)
                root.startPendingConfigUpdate();
            else
                delayedRefresh.restart();
        }
    }
    property Process darkmodeApply: Process {
        onExited: (exitCode, exitStatus) => {
            var completedMode = root.applyingDarkmodeMode;
            root.applyingDarkmodeMode = "";
            if (root.pendingDarkmodeMode !== "") {
                root.startPendingDarkmodeApply();
                return;
            }
            if (exitCode !== 0) {
                console.warn("[DisplayService] Failed to apply color mode:", exitCode);
                root.delayedRefresh.restart();
                return;
            }

            if (completedMode !== "")
                ThemeService.generate(WallpaperService.displayWallpaper, completedMode, true);
        }
    }

    // Dark mode
    property string applyingDarkmodeMode: ""
    property bool darkmodeEnabled: false
    property Process darkmodeQuery: Process {
        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface color-scheme"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.darkmodeEnabled = text.trim().indexOf("prefer-dark") >= 0;
                ThemeService.colorMode = root.darkmodeEnabled ? "dark" : "light";
            }
        }
    }
    property string pendingDarkmodeMode: ""
    property Timer delayedRefresh: Timer {
        interval: 400
        repeat: false

        onTriggered: root.refresh()
    }
    property string internalHardwareId: ""
    property var kdlOptions: ({})
    property int nightlightAppliedTemperature: 4000
    property Timer nightlightApplyDelay: Timer {
        // Keep the visual thumb frame-perfect while capping compositor updates
        // to 20 Hz. wl-gammarelay-rs applies these updates without restarting.
        interval: 50
        repeat: false

        onTriggered: root.applyNightlightTemperature()
    }
    property int nightlightApplyingTemperature: -1
    property bool nightlightAvailable: false
    property FileView nightlightConfigFile: FileView {
        atomicWrites: true
        path: root.nightlightConfigPath
        printErrors: false
        watchChanges: false
    }
    readonly property string nightlightConfigPath: (Quickshell.env("XDG_CACHE_HOME") || Config.homeDir + "/.cache") + "/quickshell/nightlight.conf"
    property bool nightlightControllerReady: false
    property bool nightlightControllerStarting: false

    // Night Light
    property bool nightlightEnabled: false
    property Process nightlightQuery: Process {
        command: ["sh", "-c", "saved=$(sed -n -e '/^[0-9][0-9]*$/p' -e 's/^temp-day=\\([0-9][0-9]*\\)$/\\1/p' '" + root.nightlightConfigPath + "' 2>/dev/null | head -n 1); " + "[ -n \"$saved\" ] || saved=4000; " + "if ! command -v wl-gammarelay-rs >/dev/null 2>&1; then printf 'unavailable:off:%s:stopped\\n' \"$saved\"; exit 0; fi; " + "current=$(busctl --user get-property rs.wl-gammarelay / rs.wl.gammarelay Temperature 2>/dev/null | awk '{print $2}'); " + "if [ -n \"$current\" ]; then " + "if [ \"$current\" -lt 6500 ]; then printf 'relay:on:%s:ready\\n' \"$current\"; else printf 'relay:off:%s:ready\\n' \"$saved\"; fi; " + "else printf 'relay:off:%s:stopped\\n' \"$saved\"; fi"]

        stdout: StdioCollector {
            onStreamFinished: {
                var cleaned = text.trim();
                if (cleaned === "")
                    return;
                var nightState = cleaned.split(":");
                root.nightlightAvailable = nightState[0] === "relay";
                root.nightlightControllerReady = root.nightlightAvailable && nightState.length > 3 && nightState[3] === "ready";
                root.nightlightEnabled = nightState.length > 1 && nightState[1] === "on";
                if (nightState.length > 2) {
                    var detectedTemperature = parseInt(nightState[2], 10);
                    if (!isNaN(detectedTemperature)) {
                        root.nightlightTemperature = detectedTemperature;
                        root.nightlightRequestedTemperature = detectedTemperature;
                        root.nightlightAppliedTemperature = detectedTemperature;
                    }
                }
            }
        }
    }
    property int nightlightRequestedTemperature: 4000
    property Process nightlightSetter: Process {
        onExited: (exitCode, exitStatus) => {
            var completedTemperature = root.nightlightApplyingTemperature;
            if (exitCode === 0) {
                root.nightlightAppliedTemperature = completedTemperature;
                if (root.nightlightControllerStarting)
                    root.nightlightControllerReady = true;
            } else {
                root.nightlightControllerReady = false;
                console.warn("[DisplayService] Night Light update failed:", exitCode);
            }
            root.nightlightApplyingTemperature = -1;
            root.nightlightControllerStarting = false;
            if (exitCode === 0 && root.nightlightEnabled && root.nightlightRequestedTemperature !== root.nightlightAppliedTemperature && !root.nightlightApplyDelay.running)
                root.nightlightApplyDelay.start();
        }
    }
    property int nightlightTemperature: 4000
    property Process nightlightToggleProcess: Process {
    }
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

    function applyNightlightTemperature() {
        if (!nightlightEnabled || !nightlightAvailable || nightlightSetter.running)
            return;
        var nextTemperature = nightlightRequestedTemperature;
        nightlightApplyingTemperature = nextTemperature;
        if (nightlightControllerReady) {
            nightlightControllerStarting = false;
            nightlightSetter.command = ["busctl", "--user", "set-property", "rs.wl-gammarelay", "/", "rs.wl.gammarelay", "Temperature", "q", String(nextTemperature)];
        } else {
            nightlightControllerStarting = true;
            nightlightSetter.command = ["sh", "-c", "if ! busctl --user get-property rs.wl-gammarelay / rs.wl.gammarelay Temperature >/dev/null 2>&1; then " + "wl-gammarelay-rs run >/dev/null 2>&1 & " + "i=0; while [ \"$i\" -lt 25 ]; do " + "busctl --user get-property rs.wl-gammarelay / rs.wl.gammarelay Temperature >/dev/null 2>&1 && break; " + "i=$((i + 1)); sleep 0.02; done; fi; " + "busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Temperature q " + nextTemperature];
        }
        nightlightSetter.running = true;
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
    function commitNightlightTemperature(temperature) {
        setNightlightTemperature(temperature);
        writeNightlightConfig(nightlightTemperature);
        if (nightlightEnabled && nightlightRequestedTemperature !== nightlightAppliedTemperature && !nightlightApplyDelay.running)
            nightlightApplyDelay.start();
    }
    function ensureOutputCommand(output, sourceOutput) {
        var defaults = outputDefaults(sourceOutput || output);
        return "if ! grep -q 'output \"" + output + "\" {' " + configPath + "; then echo -e '\\noutput \"" + output + "\" {\\n    mode \"" + defaults.mode + "\"\\n    scale " + defaults.scale + "\\n    transform \"" + defaults.transform + "\"\\n    position x=" + defaults.x + " y=" + defaults.y + "\\n}' >> " + configPath + "; fi";
    }
    function executeConfigCommand(command) {
        if (!command)
            return;

        var queued = pendingConfigCommands.slice();
        queued.push(command);
        pendingConfigCommands = queued;
        if (!configUpdater.running)
            configApplyDebounce.restart();
    }
    function startPendingConfigUpdate() {
        if (configUpdater.running || pendingConfigCommands.length === 0)
            return;

        var commands = pendingConfigCommands.slice();
        pendingConfigCommands = [];
        configUpdater.command = ["sh", "-c", commands.join("; ") + "; niri msg action load-config-file"];
        configUpdater.running = true;
    }
    function nightlightConfigText(temperature) {
        return String(temperature) + "\n";
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
        pendingDarkmodeMode = enabled ? "dark" : "light";
        if (!darkmodeApply.running)
            startPendingDarkmodeApply();
    }
    function startPendingDarkmodeApply() {
        if (darkmodeApply.running || pendingDarkmodeMode === "")
            return;

        var mode = pendingDarkmodeMode;
        pendingDarkmodeMode = "";
        applyingDarkmodeMode = mode;
        darkmodeApply.command = ["sh", "-c", "gsettings set org.gnome.desktop.interface color-scheme '" + (mode === "dark" ? "prefer-dark" : "prefer-light") + "'" + " && gsettings set org.gnome.desktop.interface gtk-theme '" + (mode === "dark" ? "adw-gtk3-dark" : "adw-gtk3") + "'"];
        darkmodeApply.running = true;
    }
    function setNightlightEnabled(enabled) {
        if (enabled && !nightlightAvailable) {
            nightlightEnabled = false;
            console.warn("[DisplayService] wl-gammarelay-rs is not installed");
            return;
        }
        nightlightEnabled = enabled;
        nightlightApplyDelay.stop();
        nightlightSetter.running = false;
        if (enabled) {
            nightlightRequestedTemperature = nightlightTemperature;
            nightlightAppliedTemperature = -1;
            writeNightlightConfig(nightlightTemperature);
            applyNightlightTemperature();
        } else {
            nightlightToggleProcess.command = ["busctl", "--user", "set-property", "rs.wl-gammarelay", "/", "rs.wl.gammarelay", "Temperature", "q", "6500"];
            nightlightToggleProcess.running = false;
            nightlightToggleProcess.running = true;
        }
        delayedRefresh.restart();
    }
    function setNightlightTemperature(temperature) {
        nightlightTemperature = Math.max(2500, Math.min(6500, Math.round(temperature / 50) * 50));
        nightlightRequestedTemperature = nightlightTemperature;
        if (nightlightEnabled && !nightlightApplyDelay.running)
            nightlightApplyDelay.start();
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
    function writeNightlightConfig(temperature) {
        nightlightConfigFile.setText(nightlightConfigText(temperature));
    }

    Component.onCompleted: refresh()
}
