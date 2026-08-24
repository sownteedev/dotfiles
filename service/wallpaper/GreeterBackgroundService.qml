pragma Singleton
import "../../"
import ".."
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    readonly property bool busy: syncProcess.running
    property Timer clearMessageTimer: Timer {
        interval: 5000
        repeat: false

        onTriggered: {
            root.errorMessage = "";
            root.statusMessage = "";
        }
    }
    property string errorMessage: ""
    readonly property string helperPath: Config.quickshellDir + "/scripts/sync-greeter-background.py"
    property string statusMessage: ""
    property Process syncProcess: Process {
        property bool launchPending: false

        stderr: StdioCollector {
            id: syncError
        }
        stdout: StdioCollector {
            id: syncOutput
        }

        onExited: (exitCode, exitStatus) => {
            var response = root.parseResponse(syncOutput.text, syncError.text);
            if (exitCode !== 0 || !response.ok) {
                root.errorMessage = root.errorForCode(response.code, response.message);
                root.statusMessage = "";
            } else {
                root.errorMessage = "";
                root.statusMessage = response.kind === "image" ? qsTr("Wallhaven image set as login background") : qsTr("Wallpaper Engine video set as login background");
            }
            clearMessageTimer.restart();
        }
        onRunningChanged: {
            if (!running && launchPending) {
                launchPending = false;
                root.errorMessage = qsTr("Could not start the greetd background helper");
                root.statusMessage = "";
                clearMessageTimer.restart();
            }
        }
        onStarted: launchPending = false
    }
    property Connections wallhavenConnections: Connections {
        function onDownloadCompleted(wallpaperId, path, modified, purpose) {
            if (purpose === "greetd" || purpose === "both")
                root.setImage(path);
        }

        target: WallhavenService
    }
    property Connections workshopConnections: Connections {
        function onDownloadCompleted(publishedFileId, path, modified, purpose) {
            if (purpose === "greetd" || purpose === "both")
                root.setEngineVideo(path);
        }

        target: WallpaperWorkshopService
    }

    function errorForCode(code, fallback) {
        if (code === "missing_dependency")
            return qsTr("Matugen and ffmpeg are required to create the Greetd theme");
        if (code === "palette_frame_failed")
            return qsTr("Could not extract colors from the selected Greetd background");
        if (code === "palette_generation_failed")
            return qsTr("Could not generate Material colors for the Greetd background");
        if (code === "unsupported_project_type")
            return qsTr("Only Wallpaper Engine video projects can be used as the login background");
        if (code === "missing_video")
            return qsTr("The Wallpaper Engine project has no usable video file");
        if (code === "destination_unavailable")
            return qsTr("The greetd background directory is not writable");
        return fallback || qsTr("Could not update the login background");
    }
    function parseResponse(stdoutText, stderrText) {
        var output = String(stdoutText || "").trim();
        try {
            var parsed = JSON.parse(output);
            if (parsed && typeof parsed === "object")
                return parsed;
        } catch (error) {}
        return {
            "ok": false,
            "message": String(stderrText || "").trim()
        };
    }
    function setEngineVideo(projectPath) {
        return start("engine-video", projectPath);
    }
    function setImage(path) {
        return start("image", path);
    }
    function start(kind, sourcePath) {
        var path = String(sourcePath || "").trim();
        if (path === "" || busy)
            return false;
        errorMessage = "";
        statusMessage = kind === "image" ? qsTr("Setting Wallhaven image as login background…") : qsTr("Setting Wallpaper Engine video as login background…");
        clearMessageTimer.stop();
        syncProcess.command = ["python3", "-u", helperPath, kind, path];
        syncProcess.launchPending = true;
        syncProcess.running = true;
        return true;
    }
}
