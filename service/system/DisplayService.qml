pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
import ".."

QtObject {
    id: root

    property Process actionExecutor: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("[DisplayService] Failed to reload Niri output configuration:", exitCode);
            if (root.outputReloadPending) {
                root.outputReloadPending = false;
                Qt.callLater(root.reloadOutputConfig);
                return;
            }
            root.optionsQuery.running = false;
            root.optionsQuery.running = true;
            root.delayedRefresh.restart();
        }
    }

    // Dark mode
    property string applyingDarkmodeMode: ""
    property Timer configApplyDebounce: Timer {
        interval: 70
        repeat: false

        onTriggered: root.startPendingConfigUpdate()
    }
    readonly property string configPath: Config.niriOutputConfig
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
                ThemeService.updateMode(completedMode, true);
        }
    }
    property bool darkmodeEnabled: false
    property Process darkmodeQuery: Process {
        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface color-scheme"]

        stdout: StdioCollector {
            onStreamFinished: {
                ThemeService.syncSystemMode(text, ThemeService.modeResolved);
                root.darkmodeEnabled = ThemeService.colorMode === "dark";
            }
        }
    }
    property Timer delayedRefresh: Timer {
        interval: 400
        repeat: false

        onTriggered: root.refresh()
    }
    readonly property string displayMode: detectDisplayMode()
    property bool displayModeApplying: false
    property string displayModeError: ""
    property Process displayModeExecutor: Process {
        stdout: StdioCollector {
            id: displayModeOutput
        }

        onExited: (exitCode, exitStatus) => {
            root.displayModeApplying = false;
            var message = "";
            try {
                var result = JSON.parse(displayModeOutput.text.trim() || "{}");
                message = String(result.error || "");
            } catch (error) {
                message = "Invalid response from the display mode helper";
            }
            if (exitCode !== 0) {
                root.displayModeError = message || "Could not change the display mode";
                console.warn("[DisplayService] Display mode update failed:", root.displayModeError);
            }
            root.delayedRefresh.restart();
        }
    }
    property Timer externalOnlySafety: Timer {
        interval: 450
        repeat: false

        onTriggered: {
            if (Quickshell.screens.length === 0 && !root.displayModeApplying)
                root.applyDisplayMode("internal", "");
        }
    }
    readonly property bool hasExternalOutput: externalOutputNames().length > 0
    readonly property bool hasInternalOutput: internalOutputNames().length > 0
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
    property var outputHardwareIds: ({})
    property Connections outputHotplugConnections: Connections {
        function onScreensChanged() {
            root.outputHotplugRefresh.restart();
            if (root.displayMode === "external" && Quickshell.screens.length === 0)
                root.externalOnlySafety.restart();
            else if (Quickshell.screens.length > 0)
                root.externalOnlySafety.stop();
        }

        target: Quickshell
    }
    property Timer outputHotplugRefresh: Timer {
        interval: 250
        repeat: false

        onTriggered: root.refreshOutputs()
    }
    property bool outputReloadPending: false
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
                    for (var key in data) {
                        if (!data.hasOwnProperty(key))
                            continue;
                        var output = data[key];
                        nextOutputs.push(output);
                    }
                    var identities = root.buildOutputIdentities(nextOutputs);
                    var internalId = "";
                    for (var outputIndex = 0; outputIndex < nextOutputs.length; ++outputIndex) {
                        var outputName = String(nextOutputs[outputIndex].name || "");
                        nextOutputs[outputIndex].hardwareId = identities[outputName] || outputName;
                        if (root.isInternalOutput(outputName))
                            internalId = nextOutputs[outputIndex].hardwareId;
                    }
                    root.outputHardwareIds = identities;
                    root.internalHardwareId = internalId;
                    root.outputs = nextOutputs;
                } catch (error) {
                    console.warn("[DisplayService] Failed to parse outputs:", error);
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("[DisplayService] Failed to query outputs:", exitCode);
            if (root.outputsRefreshPending) {
                root.outputsRefreshPending = false;
                Qt.callLater(root.refreshOutputs);
            }
        }
    }
    property bool outputsRefreshPending: false
    property var pendingConfigCommands: []
    property string pendingDarkmodeMode: ""
    property bool sunshineBusy: sunshineProfileProcess.running
    readonly property string sunshineConfigPath: Config.homeDir + "/.config/sunshine/sunshine.conf"
    property Process sunshineProfileProcess: Process {
        stdout: StdioCollector {
            id: sunshineProfileOutput
        }

        onExited: (exitCode, exitStatus) => {
            try {
                var result = JSON.parse(sunshineProfileOutput.text.trim() || "{}");
                if (exitCode === 0 && !result.error)
                    root.sunshineStatus = result.label + " • Display " + result.display_id + " • " + result.output;
                else
                    root.sunshineStatus = String(result.error || "Could not configure Sunshine");
            } catch (error) {
                root.sunshineStatus = "Invalid response from Sunshine profile helper";
            }
            if (root.sunshineStatusRefreshPending) {
                root.sunshineStatusRefreshPending = false;
                Qt.callLater(root.refreshSunshineStatus);
            }
        }
    }
    property string sunshineStatus: "Select a display to configure Sunshine"
    property string sunshineStatusOutput: ""
    property Process sunshineStatusQuery: Process {
        stdout: StdioCollector {
            id: sunshineStatusQueryOutput
        }

        onExited: (exitCode, exitStatus) => {
            try {
                var result = JSON.parse(sunshineStatusQueryOutput.text.trim() || "{}");
                if (exitCode === 0 && result.configured === true) {
                    var output = String(result.output || "");
                    root.sunshineStatusOutput = output;
                    root.sunshineStatus = String(result.label || "Sunshine") + " • Display " + result.display_id + (output !== "" ? " • " + output : "");
                } else if (exitCode === 0) {
                    root.sunshineStatusOutput = "";
                    root.sunshineStatus = "Select a display to configure Sunshine";
                } else {
                    root.sunshineStatusOutput = "";
                    root.sunshineStatus = String(result.error || "Could not read Sunshine configuration");
                }
            } catch (error) {
                root.sunshineStatusOutput = "";
                root.sunshineStatus = "Invalid Sunshine status response";
            }
            if (root.sunshineStatusRefreshPending) {
                root.sunshineStatusRefreshPending = false;
                Qt.callLater(root.refreshSunshineStatus);
            }
        }
    }
    property bool sunshineStatusRefreshPending: false
    property Connections themeConnections: Connections {
        function onColorModeChanged() {
            root.darkmodeEnabled = ThemeService.colorMode === "dark";
        }

        target: ThemeService
    }

    function applyDisplayMode(mode, preferredExternal) {
        if (displayModeApplying)
            return;
        if (mode === "duplicate") {
            displayModeError = "Duplicate is unavailable because Niri has no native output mirroring";
            return;
        }
        if ((mode === "extend" || mode === "external") && !hasExternalOutput) {
            displayModeError = "Connect an external display first";
            return;
        }
        if (mode === "internal" && !hasInternalOutput) {
            displayModeError = "No internal display is available";
            return;
        }
        displayModeError = "";
        displayModeApplying = true;
        displayModeExecutor.command = ["python3", Config.quickshellDir + "/scripts/niri_display_mode.py", mode, String(preferredExternal || "")];
        displayModeExecutor.running = true;
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
    function buildOutputIdentities(outputList) {
        var candidates = [];
        var counts = {};
        var result = {};
        for (var i = 0; i < outputList.length; ++i) {
            var candidate = hardwareIdentity(outputList[i]);
            candidates.push(candidate);
            counts[candidate] = (counts[candidate] || 0) + 1;
        }
        for (var j = 0; j < outputList.length; ++j) {
            var connector = String(outputList[j] && outputList[j].name || "");
            var identity = candidates[j];
            result[connector] = identity !== "" && counts[identity] === 1 ? identity : connector;
        }
        return result;
    }
    function commitNightlightTemperature(temperature) {
        setNightlightTemperature(temperature);
        writeNightlightConfig(nightlightTemperature);
        if (nightlightEnabled && nightlightRequestedTemperature !== nightlightAppliedTemperature && !nightlightApplyDelay.running)
            nightlightApplyDelay.start();
    }
    function configIdentity(output) {
        var connector = String(output || "");
        return String(outputHardwareIds[connector] || connector);
    }
    function configureSunshine(output) {
        var connector = String(output || "");
        if (connector === "" || sunshineProfileProcess.running)
            return;
        var displayId = -1;
        for (var i = 0; i < outputs.length; ++i) {
            if (String(outputs[i] && outputs[i].name || "") === connector) {
                displayId = i;
                break;
            }
        }
        if (displayId < 0) {
            sunshineStatusOutput = connector;
            sunshineStatus = "Selected output is no longer connected";
            return;
        }
        sunshineStatusOutput = connector;
        sunshineStatus = "Restarting Sunshine for " + connector + "…";
        sunshineProfileProcess.command = ["python3", Config.quickshellDir + "/scripts/sunshine_output_profile.py", sunshineConfigPath, connector, String(displayId)];
        sunshineProfileProcess.running = true;
    }
    function detectDisplayMode() {
        var internalEnabled = false;
        var externalEnabled = false;
        for (var i = 0; i < outputs.length; ++i) {
            var output = outputs[i];
            if (!output || !output.logical)
                continue;
            if (isInternalOutput(String(output.name || "")))
                internalEnabled = true;
            else
                externalEnabled = true;
        }
        if (internalEnabled && externalEnabled)
            return "extend";
        if (internalEnabled)
            return "internal";
        if (externalEnabled)
            return "external";
        return "";
    }
    function ensureOutputCommand(output, sourceOutput) {
        var defaults = outputDefaults(sourceOutput || output);
        return "if ! grep -q 'output \"" + output + "\" {' " + configPath + "; then echo -e '\\noutput \"" + output + "\" {\\n    mode \"" + defaults.mode + "\"\\n    scale " + defaults.scale + "\\n    transform \"" + defaults.transform + "\"\\n    position x=" + defaults.x + " y=" + defaults.y + "\\n    // variable-refresh-rate on-demand=true\\n    // focus-at-startup\\n}' >> " + configPath + "; fi";
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
    function externalOutputNames() {
        var result = [];
        for (var i = 0; i < outputs.length; ++i) {
            var name = String(outputs[i] && outputs[i].name || "");
            if (name !== "" && !isInternalOutput(name))
                result.push(name);
        }
        return result;
    }
    function hardwareIdentity(output) {
        if (!output)
            return "";
        var make = String(output.make || "").trim().replace(/\s+/g, " ");
        var model = String(output.model || "").trim().replace(/\s+/g, " ");
        if (make === "" || model === "")
            return String(output.name || "");
        var serial = String(output.serial || "Unknown").trim().replace(/\s+/g, " ") || "Unknown";
        var identity = (make + " " + model + " " + serial).trim().replace(/\s+/g, " ");
        return identity || String(output.name || "");
    }
    function internalOutputNames() {
        var result = [];
        for (var i = 0; i < outputs.length; ++i) {
            var name = String(outputs[i] && outputs[i].name || "");
            if (isInternalOutput(name))
                result.push(name);
        }
        return result;
    }
    function isInternalOutput(name) {
        var connector = String(name || "");
        return connector.startsWith("eDP-") || connector.startsWith("LVDS-") || connector.startsWith("DSI-");
    }
    function nightlightConfigText(temperature) {
        return String(temperature) + "\n";
    }
    function optionEnabled(output, option) {
        var values = kdlOptions[configIdentity(output)];
        return values && values[option] !== undefined ? values[option] : false;
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
            var mode = null;
            var modes = candidate.modes || [];
            for (var modeIndex = 0; modeIndex < modes.length; ++modeIndex) {
                var nextMode = modes[modeIndex];
                var nextArea = Number(nextMode.width) * Number(nextMode.height);
                var currentArea = mode ? Number(mode.width) * Number(mode.height) : -1;
                if (!mode || nextArea > currentArea || (nextArea === currentArea && Number(nextMode.refresh_rate) > Number(mode.refresh_rate)))
                    mode = nextMode;
            }
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
        var identity = configIdentity(output);
        return identity === "" ? [] : [identity];
    }
    function refresh() {
        refreshOutputs();
        refreshSunshineStatus();
        optionsQuery.running = false;
        optionsQuery.running = true;
        darkmodeQuery.running = false;
        darkmodeQuery.running = true;
        nightlightQuery.running = false;
        nightlightQuery.running = true;
    }
    function refreshOutputs() {
        if (outputsQuery.running) {
            outputsRefreshPending = true;
            return;
        }
        outputsRefreshPending = false;
        outputsQuery.running = true;
    }
    function refreshSunshineStatus() {
        if (sunshineProfileProcess.running || sunshineStatusQuery.running) {
            sunshineStatusRefreshPending = true;
            return;
        }
        sunshineStatusRefreshPending = false;
        sunshineStatusQuery.command = ["python3", Config.quickshellDir + "/scripts/sunshine_output_profile.py", "--status", sunshineConfigPath];
        sunshineStatusQuery.running = true;
    }
    function reloadOutputConfig() {
        if (actionExecutor.running) {
            outputReloadPending = true;
            return;
        }
        actionExecutor.command = ["niri", "msg", "action", "load-config-file"];
        actionExecutor.running = true;
    }
    function setDarkmodeEnabled(enabled) {
        darkmodeEnabled = enabled;
        pendingDarkmodeMode = enabled ? "dark" : "light";
        if (!darkmodeApply.running)
            startPendingDarkmodeApply();
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
    function setVrrMode(output, mode) {
        if (output === "")
            return;

        var normalizedMode = mode === "on" || mode === "on-demand" ? mode : "off";
        var names = outputsToUpdate(output);
        var commands = [];
        for (var i = 0; i < names.length; ++i) {
            commands.push(ensureOutputCommand(names[i], output));
            commands.push("python3 " + shellQuote(Config.quickshellDir + "/scripts/display_config_parser.py") + " --set-vrr " + shellQuote(configPath) + " " + shellQuote(names[i]) + " " + shellQuote(normalizedMode));
        }
        executeConfigCommand(commands.join("; "));

        var updated = Object.assign({}, kdlOptions);
        for (var j = 0; j < names.length; ++j) {
            updated[names[j]] = Object.assign({}, updated[names[j]] || {});
            updated[names[j]].vrr = normalizedMode !== "off";
            updated[names[j]].vrrMode = normalizedMode;
        }
        kdlOptions = updated;
    }
    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\"'\"'") + "'";
    }
    function startPendingConfigUpdate() {
        if (configUpdater.running || pendingConfigCommands.length === 0)
            return;

        var commands = pendingConfigCommands.slice();
        pendingConfigCommands = [];
        configUpdater.command = ["sh", "-c", commands.join("; ") + "; niri msg action load-config-file"];
        configUpdater.running = true;
    }
    function startPendingDarkmodeApply() {
        if (darkmodeApply.running || pendingDarkmodeMode === "")
            return;

        var mode = pendingDarkmodeMode;
        pendingDarkmodeMode = "";
        applyingDarkmodeMode = mode;
        darkmodeApply.command = ["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", mode === "dark" ? "prefer-dark" : "prefer-light"];
        darkmodeApply.running = true;
    }
    function toggleOption(output, option, enabled) {
        if (output === "")
            return;
        if (option === "vrr") {
            setVrrMode(output, enabled ? "on-demand" : "off");
            return;
        }
        var names = outputsToUpdate(output);
        var optionName = option === "vrr" ? "variable-refresh-rate" : "focus-at-startup";
        var optionLine = option === "vrr" ? "variable-refresh-rate on-demand=true" : optionName;
        var commands = [];
        if (option === "focus" && enabled)
            commands.push("sed -i 's|^[[:space:]]*focus-at-startup[[:space:]]*$|    // focus-at-startup|' " + configPath);
        for (var i = 0; i < names.length; ++i) {
            commands.push(ensureOutputCommand(names[i], output));
            if (enabled) {
                commands.push("sed -i '/output \"" + names[i] + "\" {/,/}/{s|//[[:space:]]*" + optionName + "|" + optionName + "|}' " + configPath);
                commands.push("sed -n '/output \"" + names[i] + "\" {/,/}/p' " + configPath + " | grep -q '^[[:space:]]*" + optionName + "' || sed -i '/output \"" + names[i] + "\" {/,/}/{/}/i\\    " + optionLine + "' " + configPath);
            } else {
                commands.push("sed -i '/output \"" + names[i] + "\" {/,/}/{s|^[[:space:]]*" + optionName + "|    // " + optionName + "|}' " + configPath);
            }
        }
        executeConfigCommand(commands.join("; "));

        var updated = Object.assign({}, kdlOptions);
        if (option === "focus" && enabled) {
            for (var configuredOutput in updated) {
                if (!updated.hasOwnProperty(configuredOutput))
                    continue;
                updated[configuredOutput] = Object.assign({}, updated[configuredOutput] || {});
                updated[configuredOutput].focus = false;
            }
        }
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
    function vrrMode(output) {
        var values = kdlOptions[configIdentity(output)];
        var mode = String(values && values.vrrMode || "");
        if (mode === "off" || mode === "on" || mode === "on-demand")
            return mode;
        return values && values.vrr ? "on-demand" : "off";
    }
    function writeNightlightConfig(temperature) {
        nightlightConfigFile.setText(nightlightConfigText(temperature));
    }

    Component.onCompleted: refresh()
}
