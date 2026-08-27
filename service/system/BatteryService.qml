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
    property alias autoPowerSaverEnabled: policy.autoPowerSaverEnabled
    property alias autoPowerSaverManaged: policy.autoPowerSaverManaged
    property alias autoPowerSaverRestoreProfile: policy.autoPowerSaverRestoreProfile
    property Process availabilityQuery: Process {
        command: ["sh", "-c", "command -v powerprofilesctl >/dev/null 2>&1 && power=1 || power=0; " + "command -v auto-cpufreq >/dev/null 2>&1 && auto=1 || auto=0; " + "aware=$(powerprofilesctl query-battery-aware 2>/dev/null || true); " + "printf '%s|%s|%s\\n' \"$power\" \"$auto\" \"$aware\""]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split("|");
                root.powerProfilesAvailable = parts.length > 0 && parts[0] === "1";
                root.autoCpufreqAvailable = parts.length > 1 && parts[1] === "1";
                var awareState = parts.length > 2 ? parts[2].trim().toLowerCase() : "";
                root.batteryAwareAvailable = awareState !== "";
                if (root.batteryAwareAvailable)
                    root.batteryAwareEnabled = awareState === "enabled" || awareState.endsWith("true") || awareState.endsWith("yes");

                if (root.active)
                    root.refresh();

                root.evaluatePolicy();
                root.applySourcePowerProfile();
            }
        }
    }
    property bool batteryAwareAvailable: false
    property bool batteryAwareBusy: false
    property Process batteryAwareCommand: Process {
        onExited: (exitCode, exitStatus) => {
            root.batteryAwareBusy = false;
            if (exitCode === 0) {
                root.batteryAwareEnabled = root.batteryAwareTarget;
                root.batteryAwareError = "";
            } else {
                root.batteryAwareError = qsTr("Could not update Battery-aware mode");
            }
            root.restartAvailabilityQuery();
        }
    }
    property bool batteryAwareEnabled: false
    property string batteryAwareError: ""
    property bool batteryAwareTarget: false
    readonly property int batteryPercentage: UPower.displayDevice ? Math.round(UPower.displayDevice.percentage * 100) : -1
    property alias batteryPowerProfile: policy.batteryPowerProfile
    property Process batteryQuery: Process {
        command: [Config.quickshellDir + "/backend/run-qs-stats", "--battery-stream"]
        running: root.active

        stdout: SplitParser {
            onRead: line => {
                try {
                    var data = JSON.parse(line);
                    root.gpuPower = root.formatValue(data.gpu_power, 1, " W");
                    root.healthNumeric = root.validNumber(data.health) ? Number(data.health) : -1;
                    root.health = root.formatValue(data.health, 1, "%");
                    root.cycleCount = data.cycle_count === null || data.cycle_count <= 0 ? "N/A" : String(Math.round(data.cycle_count));
                    root.temperature = root.formatValue(data.temperature, 1, "°C");
                    root.voltage = root.formatValue(data.voltage, 2, " V");
                    root.powerDraw = root.formatValue(data.power_draw, 1, " W");
                    root.fullEnergy = root.formatValue(data.full_energy, 1, " Wh");
                    root.designEnergy = root.formatValue(data.design_energy, 1, " Wh");
                    root.deviceName = data.device_name || qsTr("Battery");
                } catch (error) {
                    console.warn("[BatteryService] Invalid backend output:", error);
                }
            }
        }

        Component.onDestruction: running = false
    }
    property Process chargeCommand: Process {
        stderr: StdioCollector {
            onStreamFinished: root.chargeCommandStderr = text.trim()
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.chargeStartThreshold = root.pendingChargeStart;
                root.chargeEndThreshold = root.pendingChargeEnd;
                root.chargeMode = root.modeForThresholds(root.pendingChargeStart, root.pendingChargeEnd);
                root.chargeCommandError = "";
                if (root.pendingChargeAction === "restore-once")
                    root.fullChargeOnceActive = false;
            } else {
                root.chargeCommandError = root.chargeCommandStderr || qsTr("Could not update charging thresholds");
                if (root.pendingChargeAction === "start-once")
                    root.fullChargeOnceActive = false;
            }
            root.pendingChargeAction = "";
            root.chargeCommandBusy = false;
            root.refreshDelay.restart();
        }
    }
    property bool chargeCommandBusy: false
    property string chargeCommandError: ""
    property string chargeCommandStderr: ""
    property int chargeEndThreshold: 100
    property string chargeMode: "maximize"
    property int chargeStartThreshold: 50
    property bool chargeThresholdSupported: false
    property Process commandExecutor: Process {
        onExited: root.refreshDelay.restart()
    }
    property Process controlQuery: Process {
        command: [Config.quickshellDir + "/backend/run-qs-stats", "--battery-control"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim());
                    root.chargeMode = data.charge_mode || "custom";
                    root.chargeStartThreshold = root.validNumber(data.charge_start_threshold) ? Math.round(Number(data.charge_start_threshold)) : 0;
                    root.chargeEndThreshold = root.validNumber(data.charge_end_threshold) ? Math.round(Number(data.charge_end_threshold)) : 0;
                    root.chargeThresholdSupported = data.charge_threshold_supported === true;
                    root.currentGovernor = data.current_governor || "N/A";
                    root.governorOverride = data.governor_override || "default";
                    root.turboOverride = data.turbo_override || "auto";
                } catch (error) {
                    console.warn("[BatteryService] Invalid control output:", error);
                }
            }
        }
    }
    property alias criticalBatteryAction: policy.criticalBatteryAction
    property alias criticalBatteryHandled: policy.criticalBatteryHandled
    property alias criticalBatteryThreshold: policy.criticalBatteryThreshold
    property string currentGovernor: "N/A"
    property string cycleCount: "N/A"
    property string designEnergy: "N/A"
    property string deviceName: qsTr("Battery")
    property alias fullChargeOnceActive: policy.fullChargeOnceActive
    property string fullEnergy: "N/A"
    property string governorOverride: "default"
    property string gpuPower: "N/A"
    property string health: "N/A"
    property real healthNumeric: -1
    property alias lowBatteryNotificationEnabled: policy.lowBatteryNotificationEnabled
    property alias lowBatteryNotified: policy.lowBatteryNotified
    property alias lowBatteryThreshold: policy.lowBatteryThreshold
    readonly property bool onBattery: UPower.onBattery
    property string pendingChargeAction: ""
    property int pendingChargeEnd: 100
    property int pendingChargeStart: 50
    readonly property int performanceDegradationReason: PowerProfiles.degradationReason
    readonly property string performanceDegradationText: {
        switch (performanceDegradationReason) {
        case PerformanceDegradationReason.LapDetected:
            return qsTr("Performance is limited because the laptop is on a lap");
        case PerformanceDegradationReason.HighTemperature:
            return qsTr("Performance is limited by high temperature");
        default:
            return "";
        }
    }
    readonly property bool performanceDegraded: PowerProfiles.degradationReason !== PerformanceDegradationReason.None
    property alias pluggedInPowerProfile: policy.pluggedInPowerProfile
    property FileView policyFile: FileView {
        atomicWrites: true
        blockLoading: true
        blockWrites: true
        path: root.policyPath
        printErrors: false
        watchChanges: false

        adapter: JsonAdapter {
            id: policy

            property bool autoPowerSaverEnabled: false
            property bool autoPowerSaverManaged: false
            property string autoPowerSaverRestoreProfile: "balanced"
            property string batteryPowerProfile: "unchanged"
            property string criticalBatteryAction: "none"
            property bool criticalBatteryHandled: false
            property int criticalBatteryThreshold: 5
            property bool fullChargeOnceActive: false
            property bool lowBatteryNotificationEnabled: true
            property bool lowBatteryNotified: false
            property int lowBatteryThreshold: 20
            property string pluggedInPowerProfile: "unchanged"
            property int restoreChargeEnd: 80
            property int restoreChargeStart: 75
        }

        onAdapterUpdated: writeAdapter()
        onLoadFailed: {
            root.policyReady = true;
            writeAdapter();
            Qt.callLater(root.evaluatePolicy);
            Qt.callLater(root.applySourcePowerProfile);
        }
        onLoadedChanged: {
            if (!loaded)
                return;

            root.policyReady = true;
            root.normalizePolicy();
            Qt.callLater(root.evaluatePolicy);
            Qt.callLater(root.applySourcePowerProfile);
            Qt.callLater(root.evaluateFullChargeOnce);
        }
    }
    readonly property string policyPath: Config.cacheRoot + "/battery-policy.json"
    property bool policyReady: false
    property string powerDraw: "N/A"
    property bool powerProfilesAvailable: false
    property Timer refreshDelay: Timer {
        interval: 700
        repeat: false

        onTriggered: root.refresh()
    }
    property alias restoreChargeEnd: policy.restoreChargeEnd
    property alias restoreChargeStart: policy.restoreChargeStart
    property string temperature: "N/A"
    property string turboOverride: "auto"
    property string voltage: "N/A"

    function applySourcePowerProfile() {
        if (!policyReady || !powerProfilesAvailable || autoPowerSaverManaged)
            return;

        var profile = configuredSourceProfile();
        if (profile !== "unchanged")
            setPowerProfile(profile);
    }
    function configuredSourceProfile() {
        return onBattery ? batteryPowerProfile : pluggedInPowerProfile;
    }
    function evaluateFullChargeOnce() {
        if (!policyReady || !fullChargeOnceActive || !onBattery || chargeCommandBusy)
            return;

        restoreFullChargeOnce();
    }
    function evaluatePolicy() {
        if (!policyReady || batteryPercentage < 0)
            return;

        var low = Math.max(1, Math.min(99, lowBatteryThreshold));
        var critical = Math.max(1, Math.min(low - 1, criticalBatteryThreshold));
        var lowCondition = onBattery && batteryPercentage <= low;
        var criticalCondition = onBattery && batteryPercentage <= critical;
        if (autoPowerSaverEnabled && powerProfilesAvailable && lowCondition) {
            if (!autoPowerSaverManaged)
                autoPowerSaverRestoreProfile = profileName(PowerProfiles.profile);

            autoPowerSaverManaged = true;
            if (PowerProfiles.profile !== PowerProfile.PowerSaver)
                PowerProfiles.profile = PowerProfile.PowerSaver;
        } else if (autoPowerSaverManaged) {
            var sourceProfile = configuredSourceProfile();
            autoPowerSaverManaged = false;
            if (sourceProfile !== "unchanged")
                setPowerProfile(sourceProfile);
            else if (PowerProfiles.profile === PowerProfile.PowerSaver)
                setPowerProfile(autoPowerSaverRestoreProfile);
        }
        if (lowCondition && !criticalCondition && lowBatteryNotificationEnabled && !lowBatteryNotified) {
            Quickshell.execDetached(["notify-send", "-a", qsTr("Battery"), "-u", "normal", "-r", "92841", "-i", "battery-low-symbolic", qsTr("Low battery"), qsTr("Battery is at %1%").arg(batteryPercentage)]);
            lowBatteryNotified = true;
        } else if (!lowCondition && (batteryPercentage > low + 2 || !onBattery)) {
            lowBatteryNotified = false;
        }
        if (criticalCondition && !criticalBatteryHandled) {
            Quickshell.execDetached(["notify-send", "-a", qsTr("Battery"), "-u", "critical", "-r", "92842", "-i", "battery-caution-symbolic", qsTr("Critical battery"), criticalBatteryAction === "none" ? qsTr("Connect a charger soon") : qsTr("The system will %1 now").arg(criticalBatteryAction)]);
            criticalBatteryHandled = true;
            lowBatteryNotified = true;
            if (criticalBatteryAction === "suspend" || criticalBatteryAction === "hibernate")
                Quickshell.execDetached(["systemctl", criticalBatteryAction]);
        } else if (!criticalCondition && (batteryPercentage > critical + 2 || !onBattery)) {
            criticalBatteryHandled = false;
        }
    }
    function formatValue(value, precision, suffix) {
        return !validNumber(value) || Number(value) <= 0 ? "N/A" : Number(value).toFixed(precision) + suffix;
    }
    function modeForThresholds(start, end) {
        if (start === 55 && end === 60)
            return "conservation";

        if (start === 75 && end === 80)
            return "preserve";

        if (start === 50 && end === 100)
            return "maximize";

        return "custom";
    }
    function normalizePolicy() {
        lowBatteryThreshold = Math.max(5, Math.min(50, Number(lowBatteryThreshold) || 20));
        criticalBatteryThreshold = Math.max(1, Math.min(lowBatteryThreshold - 1, Number(criticalBatteryThreshold) || 5));
        batteryPowerProfile = normalizeProfilePolicy(batteryPowerProfile);
        pluggedInPowerProfile = normalizeProfilePolicy(pluggedInPowerProfile);
        if (["none", "suspend", "hibernate"].indexOf(criticalBatteryAction) < 0)
            criticalBatteryAction = "none";

        if (["balanced", "performance", "power-saver"].indexOf(autoPowerSaverRestoreProfile) < 0)
            autoPowerSaverRestoreProfile = "balanced";

        if (!(restoreChargeStart >= 0 && restoreChargeStart < restoreChargeEnd && restoreChargeEnd <= 100)) {
            restoreChargeStart = 75;
            restoreChargeEnd = 80;
        }
    }
    function normalizeProfilePolicy(profile) {
        var value = String(profile || "unchanged");
        return ["unchanged", "power-saver", "balanced", "performance"].indexOf(value) >= 0 ? value : "unchanged";
    }
    function profileName(profile) {
        if (profile === PowerProfile.Performance)
            return "performance";

        if (profile === PowerProfile.PowerSaver)
            return "power-saver";

        return "balanced";
    }
    function refresh() {
        if (!active)
            return;

        controlQuery.running = false;
        controlQuery.running = true;
    }
    function restartAvailabilityQuery() {
        availabilityQuery.running = false;
        availabilityQuery.running = true;
    }
    function restoreFullChargeOnce() {
        if (!fullChargeOnceActive || chargeCommandBusy)
            return;

        runChargeThresholdCommand(restoreChargeStart, restoreChargeEnd, "restore-once");
    }
    function runChargeThresholdCommand(start, end, action) {
        if (chargeCommandBusy || !(start >= 0 && start < end && end <= 100))
            return false;

        pendingChargeStart = Math.round(start);
        pendingChargeEnd = Math.round(end);
        pendingChargeAction = action;
        chargeCommandError = "";
        chargeCommandStderr = "";
        chargeCommandBusy = true;
        chargeCommand.command = ["pkexec", Config.quickshellDir + "/backend/run-qs-stats", "--set-charge-thresholds", String(pendingChargeStart), String(pendingChargeEnd)];
        chargeCommand.running = false;
        chargeCommand.running = true;
        return true;
    }
    function runCommand(command) {
        commandExecutor.command = ["sh", "-c", command];
        commandExecutor.running = false;
        commandExecutor.running = true;
    }
    function selectPowerProfile(profile) {
        autoPowerSaverManaged = false;
        setPowerProfile(profile);
        Qt.callLater(evaluatePolicy);
    }
    function setBatteryAwareEnabled(enabled) {
        if (!batteryAwareAvailable || batteryAwareBusy)
            return;

        batteryAwareTarget = enabled;
        batteryAwareError = "";
        batteryAwareBusy = true;
        batteryAwareCommand.command = ["powerprofilesctl", "configure-battery-aware", enabled ? "--enable" : "--disable"];
        batteryAwareCommand.running = false;
        batteryAwareCommand.running = true;
    }
    function setBatteryPowerProfile(profile) {
        batteryPowerProfile = normalizeProfilePolicy(profile);
        if (onBattery)
            applySourcePowerProfile();
    }
    function setChargeMode(mode) {
        switch (mode) {
        case "conservation":
            setChargeThresholds(55, 60);
            break;
        case "preserve":
            setChargeThresholds(75, 80);
            break;
        case "maximize":
            setChargeThresholds(50, 100);
            break;
        }
    }
    function setChargeThresholds(start, end) {
        if (chargeCommandBusy || !(start >= 0 && start < end && end <= 100))
            return false;

        fullChargeOnceActive = false;
        return runChargeThresholdCommand(start, end, "manual");
    }
    function setCriticalBatteryAction(action) {
        criticalBatteryAction = ["none", "suspend", "hibernate"].indexOf(action) >= 0 ? action : "none";
        if (onBattery && batteryPercentage <= criticalBatteryThreshold)
            criticalBatteryHandled = true;

        evaluatePolicy();
    }
    function setCriticalBatteryThreshold(value) {
        var nextThreshold = Math.max(1, Math.min(lowBatteryThreshold - 1, Math.round(Number(value) || 5)));
        if (onBattery && batteryPercentage <= nextThreshold)
            criticalBatteryHandled = true;

        criticalBatteryThreshold = nextThreshold;
        evaluatePolicy();
    }
    function setLowBatteryThreshold(value) {
        var nextThreshold = Math.max(5, Math.min(50, Math.round(Number(value) || 20)));
        if (onBattery && batteryPercentage <= nextThreshold)
            lowBatteryNotified = true;

        lowBatteryThreshold = nextThreshold;
        if (criticalBatteryThreshold >= lowBatteryThreshold)
            criticalBatteryThreshold = Math.max(1, lowBatteryThreshold - 5);

        evaluatePolicy();
    }
    function setPluggedInPowerProfile(profile) {
        pluggedInPowerProfile = normalizeProfilePolicy(profile);
        if (!onBattery)
            applySourcePowerProfile();
    }
    function setPowerProfile(profile) {
        if (profile === "performance")
            PowerProfiles.profile = PowerProfile.Performance;
        else if (profile === "power-saver")
            PowerProfiles.profile = PowerProfile.PowerSaver;
        else
            PowerProfiles.profile = PowerProfile.Balanced;
    }
    function startFullChargeOnce() {
        if (onBattery || chargeCommandBusy || !chargeThresholdSupported)
            return false;

        restoreChargeStart = chargeStartThreshold >= 0 && chargeStartThreshold < chargeEndThreshold ? chargeStartThreshold : 75;
        restoreChargeEnd = chargeEndThreshold > restoreChargeStart && chargeEndThreshold <= 100 ? chargeEndThreshold : 80;
        fullChargeOnceActive = true;
        if (!runChargeThresholdCommand(50, 100, "start-once")) {
            fullChargeOnceActive = false;
            return false;
        }
        return true;
    }
    function validNumber(value) {
        return value !== null && value !== undefined && isFinite(Number(value));
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", Config.cacheRoot])
    onActiveChanged: {
        if (active)
            refresh();
        else
            controlQuery.running = false;
    }
    onAutoPowerSaverEnabledChanged: evaluatePolicy()
    onBatteryPercentageChanged: evaluatePolicy()
    onFullChargeOnceActiveChanged: Qt.callLater(evaluateFullChargeOnce)
    onLowBatteryNotificationEnabledChanged: evaluatePolicy()
    onOnBatteryChanged: {
        evaluatePolicy();
        applySourcePowerProfile();
        evaluateFullChargeOnce();
    }
}
