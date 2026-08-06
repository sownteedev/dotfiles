pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property int applyingPercent: -1
    property bool available: false
    property FileView brightnessFile: FileView {
        blockLoading: true
        path: root.deviceName === "" ? "" : "/sys/class/backlight/" + root.deviceName + "/brightness"
        preload: root.deviceName !== ""
        printErrors: false
        watchChanges: root.deviceName !== ""

        onFileChanged: reload()
        onLoadedChanged: {
            if (loaded)
                root.syncFromSysfs();
        }
        onTextChanged: {
            if (loaded)
                root.syncFromSysfs();
        }
    }
    property Process detector: Process {
        command: ["brightnessctl", "-m"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.configureDevice(text)
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                root.initialized = true;
        }
    }
    property string deviceName: ""
    property bool initialized: false
    property FileView maximumFile: FileView {
        blockLoading: true
        path: root.deviceName === "" ? "" : "/sys/class/backlight/" + root.deviceName + "/max_brightness"
        preload: root.deviceName !== ""
        printErrors: false
        watchChanges: false

        onLoadedChanged: {
            if (loaded)
                root.syncFromSysfs();
        }
        onTextChanged: {
            if (loaded)
                root.syncFromSysfs();
        }
    }
    property int maximumRaw: 0
    readonly property int percent: Math.round(value * 100)
    property int requestedPercent: -1
    property Process setter: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn("[BrightnessService] brightnessctl failed with code:", exitCode);
                root.requestedPercent = -1;
                root.applyingPercent = -1;
                root.refresh();
                return;
            }
            if (root.requestedPercent !== root.applyingPercent)
                root.applyPendingValue();
        }
    }
    property real value: 0

    function applyPendingValue() {
        if (!available || deviceName === "" || setter.running || requestedPercent < 0 || requestedPercent === applyingPercent)
            return;
        applyingPercent = requestedPercent;
        setter.command = ["brightnessctl", "-d", deviceName, "set", applyingPercent + "%"];
        setter.running = true;
    }
    function configureDevice(output) {
        var line = output.trim().split("\n")[0] || "";
        var parts = line.split(",");
        if (parts.length < 5) {
            initialized = true;
            return;
        }

        var detectedDevice = parts[0].trim();
        var current = parseFloat(parts[2]);
        var maximum = parseFloat(parts[4]);
        if (!/^[A-Za-z0-9_.:-]+$/.test(detectedDevice) || isNaN(current) || isNaN(maximum) || maximum <= 0) {
            initialized = true;
            return;
        }

        deviceName = detectedDevice;
        maximumRaw = maximum;
        value = Math.max(0, Math.min(1, current / maximum));
        available = true;
        initialized = true;
    }
    function refresh() {
        if (brightnessFile.loaded)
            brightnessFile.reload();
        if (maximumFile.loaded)
            maximumFile.reload();
    }
    function setValue(newValue) {
        value = Math.max(0, Math.min(1, newValue));
        requestedPercent = Math.round(value * 100);
        applyPendingValue();
    }
    function syncFromSysfs() {
        if (!brightnessFile.loaded)
            return;

        var current = parseFloat(brightnessFile.text().trim());
        var maximum = maximumRaw;
        if (maximumFile.loaded) {
            var fileMaximum = parseFloat(maximumFile.text().trim());
            if (!isNaN(fileMaximum) && fileMaximum > 0)
                maximum = fileMaximum;
        }
        if (isNaN(current) || maximum <= 0)
            return;

        maximumRaw = maximum;
        value = Math.max(0, Math.min(1, current / maximum));
        available = true;
        initialized = true;
    }
}
