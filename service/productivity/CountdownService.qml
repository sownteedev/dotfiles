pragma Singleton
import Quickshell
import QtQuick

QtObject {
    id: root

    property bool completed: false
    property double deadline: 0
    readonly property bool hasStarted: remainingMilliseconds < totalMilliseconds && remainingMilliseconds > 0
    readonly property real progress: totalMilliseconds > 0 ? Math.max(0, Math.min(1, remainingMilliseconds / totalMilliseconds)) : 0
    property double remainingMilliseconds: totalMilliseconds
    readonly property int remainingSeconds: Math.ceil(remainingMilliseconds / 1000)
    property bool running: false
    property Timer ticker: Timer {
        interval: 200
        repeat: true
        running: root.running

        onTriggered: root.updateRemaining()
    }
    property double totalMilliseconds: 5 * 60 * 1000

    signal finished

    function pause() {
        if (!running)
            return;
        updateRemaining();
        running = false;
    }
    function reset() {
        running = false;
        completed = false;
        remainingMilliseconds = totalMilliseconds;
        deadline = 0;
    }
    function setDuration(seconds) {
        running = false;
        completed = false;
        totalMilliseconds = Math.max(1, seconds) * 1000;
        remainingMilliseconds = totalMilliseconds;
        deadline = 0;
    }
    function start() {
        if (running)
            return;
        if (remainingMilliseconds <= 0)
            remainingMilliseconds = totalMilliseconds;
        completed = false;
        deadline = Date.now() + remainingMilliseconds;
        running = true;
    }
    function toggle() {
        if (running)
            pause();
        else
            start();
    }
    function updateRemaining() {
        if (!running)
            return;
        remainingMilliseconds = Math.max(0, deadline - Date.now());
        if (remainingMilliseconds <= 0) {
            running = false;
            completed = true;
            remainingMilliseconds = 0;
            finished();
            Quickshell.execDetached(["notify-send", "-u", "normal", "-t", "5000", "-r", "82471", "-a", "Timer", "-i", "preferences-system-time-symbolic", "Timer finished", "Your countdown has ended."]);
        }
    }
}
