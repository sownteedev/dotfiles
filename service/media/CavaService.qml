pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
import "../"

Item {
    id: root

    // Only run cava when music is actually playing
    property bool available: MediaService.playing
    property var bars: []
    property int frameRevision: 0

    Process {
        id: cavaProcess

        command: ["cava", "-p", Config.quickshellDir + "/cava.conf"]
        running: root.available

        stdout: SplitParser {
            onRead: line => {
                var newBars = root.bars;
                if (newBars.length !== 48) {
                    newBars = [];
                    for (var i = 0; i < 48; ++i)
                        newBars.push(0);
                }
                var slot = 0;
                var value = 0;
                var hasDigit = false;
                for (var i = 0; i <= line.length && slot < 48; ++i) {
                    var code = i < line.length ? line.charCodeAt(i) : 59;
                    if (code >= 48 && code <= 57) {
                        value = value * 10 + code - 48;
                        hasDigit = true;
                    } else if (code === 59) {
                        var normalized = hasDigit ? Math.max(0, Math.min(1, value / 100)) : 0;
                        newBars[slot++] = normalized;
                        value = 0;
                        hasDigit = false;
                    }
                }
                while (slot < 48)
                    newBars[slot++] = 0;
                root.bars = newBars;
                root.frameRevision++;
            }
        }

        onRunningChanged: {
            if (!running) {
                var emptyBars = [];
                for (var i = 0; i < 48; ++i)
                    emptyBars.push(0);
                root.bars = emptyBars;
                root.frameRevision++;
            }
        }
    }
}
