pragma Singleton
import Quickshell
import QtQuick
import "../../"

QtObject {
    id: root

    property bool completed: false
    property double deadline: 0
    readonly property bool hasStarted: remainingMilliseconds < totalMilliseconds && remainingMilliseconds > 0
    property real preparationProgress: 0
    property bool preparing: false
    readonly property real progress: totalMilliseconds > 0 ? Math.max(0, Math.min(1, remainingMilliseconds / totalMilliseconds)) : 0
    property double remainingMilliseconds: totalMilliseconds
    readonly property int remainingSeconds: Math.ceil(remainingMilliseconds / 1000)
    property bool running: false
    property NumberAnimation startAnimation: NumberAnimation {
        duration: Config.animationDuration(480)
        easing.type: Easing.InOutCubic
        from: 0
        property: "preparationProgress"
        target: root
        to: 1

        onFinished: root.finishPreparation()
    }
    property Timer ticker: Timer {
        interval: 200
        repeat: true
        running: root.running

        onTriggered: root.updateRemaining()
    }
    property double totalMilliseconds: 5 * 60 * 1000

    signal finished

    function beginRunning() {
        deadline = Date.now() + remainingMilliseconds;
        running = true;
    }
    function cancelPreparation() {
        if (startAnimation.running)
            startAnimation.stop();
        preparing = false;
        preparationProgress = 0;
    }
    function finishPreparation() {
        if (!preparing)
            return;
        preparationProgress = 1;
        beginRunning();
        preparing = false;
    }
    function pause() {
        if (!running)
            return;
        updateRemaining();
        running = false;
    }
    function reset() {
        cancelPreparation();
        running = false;
        completed = false;
        remainingMilliseconds = totalMilliseconds;
        deadline = 0;
    }
    function setDuration(seconds) {
        cancelPreparation();
        running = false;
        completed = false;
        totalMilliseconds = Math.max(1, seconds) * 1000;
        remainingMilliseconds = totalMilliseconds;
        deadline = 0;
    }
    function start() {
        if (running || preparing)
            return;
        if (remainingMilliseconds <= 0)
            remainingMilliseconds = totalMilliseconds;
        completed = false;
        if (hasStarted) {
            beginRunning();
            return;
        }
        preparationProgress = 0;
        preparing = true;
        startAnimation.restart();
    }
    function toggle() {
        if (preparing)
            return;
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
            Quickshell.execDetached(["canberra-gtk-play", "-i", "alarm-clock-elapsed", "-d", "Timer finished"]);
            Quickshell.execDetached(["notify-send", "-u", "normal", "-t", "5000", "-r", "82471", "-a", "Timer", "-i", "preferences-system-time-symbolic", "-h", "boolean:transient:true", "Timer finished", "Your countdown has ended."]);
        }
    }
}
