pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property int applyingPercent: -1
    property Process eventStream: Process {
        command: ["sh", "-c", "ls /sys/class/backlight/*/brightness >/dev/null 2>&1 || exit 0; exec inotifywait -m -e modify /sys/class/backlight/*/brightness"]
        running: true

        stdout: SplitParser {
            onRead: root.refresh()
        }

        Component.onDestruction: running = false
    }
    readonly property int percent: Math.round(value * 100)
    property Process query: Process {
        command: ["brightnessctl", "-m"]

        stdout: StdioCollector {
            onStreamFinished: {
                var parts = text.trim().split(",");
                if (parts.length < 5)
                    return;
                var current = parseFloat(parts[2]);
                var maximum = parseFloat(parts[4]);
                if (!isNaN(current) && !isNaN(maximum) && maximum > 0)
                    root.value = Math.max(0, Math.min(1, current / maximum));
            }
        }
    }
    property int requestedPercent: -1
    property Process setter: Process {
        onRunningChanged: {
            if (!running && root.requestedPercent !== root.applyingPercent)
                root.applyPendingValue();
        }
    }
    property real value: 0

    function applyPendingValue() {
        if (setter.running || requestedPercent < 0 || requestedPercent === applyingPercent)
            return;
        applyingPercent = requestedPercent;
        setter.command = ["brightnessctl", "set", applyingPercent + "%"];
        setter.running = true;
    }
    function refresh() {
        query.running = false;
        query.running = true;
    }
    function setValue(newValue) {
        value = Math.max(0, Math.min(1, newValue));
        requestedPercent = Math.round(value * 100);
        applyPendingValue();
    }

    Component.onCompleted: refresh()
}
