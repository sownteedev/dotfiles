pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
import "../"

Item {
    id: root

    // Keep the last frame alive briefly after playback stops so consumers can
    // draw a natural release instead of disappearing in a single frame.
    property bool available: false
    property var bars: []
    property int frameRevision: 0
    property real levelScale: 0
    property bool waitingForSignal: false

    function animateLevel(targetLevel, duration) {
        levelAnimation.stop();
        levelAnimation.from = levelScale;
        levelAnimation.to = targetLevel;
        levelAnimation.duration = duration;
        levelAnimation.start();
    }
    function clearBars() {
        var emptyBars = [];
        for (var i = 0; i < 48; ++i)
            emptyBars.push(0);
        bars = emptyBars;
        frameRevision++;
    }
    function setPlaying(playing) {
        if (playing) {
            releaseDelay.stop();

            // If playback resumes during the release, keep the existing frame
            // and reverse the fade. After a full stop, wait for Cava's first
            // real frame instead of briefly showing an empty circular stroke.
            if (available && bars.length > 0) {
                waitingForSignal = false;
                animateLevel(1, 180);
            } else {
                waitingForSignal = true;
                available = false;
                levelScale = 0;
            }
            return;
        }

        waitingForSignal = false;
        if (!available) {
            levelAnimation.stop();
            levelScale = 0;
            clearBars();
            return;
        }

        animateLevel(0, 420);
        releaseDelay.restart();
    }

    Component.onCompleted: {
        available = false;
        levelScale = 0;
        waitingForSignal = MediaService.playing;
        if (!MediaService.playing)
            clearBars();
    }
    Component.onDestruction: cavaProcess.running = false
    onLevelScaleChanged: frameRevision++

    Connections {
        function onPlayingChanged() {
            root.setPlaying(MediaService.playing);
        }

        target: MediaService
    }
    NumberAnimation {
        id: levelAnimation

        easing.type: Easing.OutCubic
        property: "levelScale"
        target: root
    }
    Timer {
        id: releaseDelay

        interval: 440
        repeat: false

        onTriggered: {
            if (MediaService.playing)
                return;
            root.available = false;
            root.clearBars();
        }
    }
    Process {
        id: cavaProcess

        command: ["cava", "-p", Config.quickshellDir + "/cava.conf"]
        running: Config.cavaEnabled && !Config.shellLowPowerMode && MediaService.playing

        stdout: SplitParser {
            onRead: line => {
                var newBars = root.bars ? root.bars.slice(0) : [];
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
                        var current = Number(newBars[slot] || 0);
                        // Faster attack, slower release. Muting an active
                        // stream therefore settles smoothly instead of
                        // snapping every bar to zero.
                        var response = normalized > current ? 0.58 : 0.24;
                        newBars[slot++] = current + (normalized - current) * response;
                        value = 0;
                        hasDigit = false;
                    }
                }
                while (slot < 48)
                    newBars[slot++] = 0;

                var peak = 0;
                for (var barIndex = 0; barIndex < newBars.length; ++barIndex)
                    peak = Math.max(peak, Number(newBars[barIndex] || 0));

                root.bars = newBars;

                // Reveal only once Cava has produced useful spectrum data.
                // Opacity and amplitude then rise together from zero.
                if (root.waitingForSignal && peak > 0.012) {
                    root.waitingForSignal = false;
                    root.available = true;
                    root.animateLevel(1, 220);
                }

                root.frameRevision++;
            }
        }
    }
}
