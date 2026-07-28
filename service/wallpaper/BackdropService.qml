pragma Singleton
import "../../"
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string activeBackdrop: ""
    property Connections configConnections: Connections {
        function onWallpaperChanged() {
            if (StateManager.wallpaperLoaded)
                root.generate();
        }

        target: Config
    }
    property bool generationPending: false
    property int generationSerial: 0
    property string generationSource: ""
    property Timer generationStart: Timer {
        interval: 60
        repeat: false

        onTriggered: root.startPendingGeneration()
    }
    property Connections globalConnections: Connections {
        function onWallpaperLoadedChanged() {
            if (StateManager.wallpaperLoaded)
                root.generate();
        }

        target: StateManager
    }
    property Process lockBlur: Process {
        property int jobSerial: 0

        onExited: (exitCode, exitStatus) => {
            if (root.generationPending) {
                root.generationStart.restart();
                return;
            }
            if (jobSerial !== root.generationSerial)
                return;

            root.lockFinished = true;
            root.finishIfReady();
        }
    }
    property bool lockFinished: false
    property Process mainBlur: Process {
        property int jobSerial: 0

        onExited: (exitCode, exitStatus) => {
            if (root.generationPending) {
                root.generationStart.restart();
                return;
            }
            if (jobSerial !== root.generationSerial)
                return;

            root.mainFinished = true;
            root.mainSucceeded = exitCode === 0;
            root.finishIfReady();
        }
    }
    property bool mainFinished: false
    property bool mainSucceeded: false
    property int nextIndex: 1
    property string pendingBackdrop: ""
    property string pendingSource: ""
    property bool ready: false

    function backdropSource(path) {
        return String(path || "").toLowerCase().endsWith(".gif") ? path + "[0]" : path;
    }
    function finishIfReady() {
        if (!mainFinished || !lockFinished)
            return;

        if (mainSucceeded) {
            activeBackdrop = pendingBackdrop;
            ready = true;
        } else {
            console.warn("[BackdropService] Failed to generate backdrop for", generationSource);
        }
    }
    function generate() {
        if (!StateManager.wallpaperLoaded || Config.wallpaper === "")
            return;

        pendingSource = Config.wallpaper;
        generationPending = true;
        if (mainBlur.running)
            mainBlur.running = false;

        if (lockBlur.running)
            lockBlur.running = false;

        generationStart.restart();
    }
    function startPendingGeneration() {
        if (!generationPending)
            return;

        if (mainBlur.running || lockBlur.running) {
            generationStart.restart();
            return;
        }
        generationPending = false;
        generationSource = pendingSource;
        ++generationSerial;
        pendingBackdrop = "/tmp/backdrop_" + nextIndex + ".png";
        nextIndex = nextIndex === 1 ? 2 : 1;
        mainFinished = false;
        lockFinished = false;
        mainSucceeded = false;
        mainBlur.jobSerial = generationSerial;
        var source = backdropSource(generationSource);
        mainBlur.command = ["magick", source, "-resize", "10%", "-blur", "0x5", pendingBackdrop];
        lockBlur.jobSerial = generationSerial;
        lockBlur.command = ["magick", source, "-resize", "20%", "-blur", "0x4", "/tmp/backdrop-lock.png"];
        mainBlur.running = true;
        lockBlur.running = true;
    }

    Component.onCompleted: {
        if (StateManager.wallpaperLoaded)
            generate();
    }
}
