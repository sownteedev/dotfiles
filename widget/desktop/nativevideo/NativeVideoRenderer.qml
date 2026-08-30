//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded

import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    property bool readyReported: false
    property var readyScreens: ({})
    property var requestData: ({
            "generation": 0,
            "path": "",
            "paused": false,
            "serial": 0,
            "session": ""
        })
    readonly property string requestFilePath: Quickshell.env("QS_NATIVE_VIDEO_REQUEST_FILE")
    readonly property string statusFilePath: Quickshell.env("QS_NATIVE_VIDEO_STATUS_FILE")

    function applyRequestText(text) {
        var next;
        try {
            next = JSON.parse(String(text || "").trim());
        } catch (error) {
            return;
        }
        var path = String(next.path || "");
        var generation = Number(next.generation || 0);
        var serial = Number(next.serial || 0);
        var session = String(next.session || "");
        var paused = Boolean(next.paused);
        var current = requestData || {};
        if (session === String(current.session || "") && path === String(current.path || "") && generation === Number(current.generation || 0) && serial === Number(current.serial || 0)) {
            if (paused !== Boolean(current.paused))
                requestData = Object.assign({}, current, {
                    "paused": paused
                });
            return;
        }

        readyReported = false;
        readyScreens = {};
        requestData = {
            "generation": generation,
            "path": path,
            "paused": paused,
            "serial": serial,
            "session": session
        };
        writeStatus(path ? "starting" : "stopped", "");
    }
    function currentScreenNames() {
        var names = [];
        for (var i = 0; i < Quickshell.screens.length; ++i)
            names.push(String(Quickshell.screens[i].name || ""));
        return names;
    }
    function loadRequest() {
        if (!requestFilePath)
            return;
        applyRequestText(requestFile.text());
    }
    function maybeReportReady() {
        if (readyReported || !requestData.path)
            return;

        var names = currentScreenNames();
        if (names.length === 0)
            return;
        for (var i = 0; i < names.length; ++i) {
            if (readyScreens[names[i]] !== true)
                return;
        }

        readyReported = true;
        writeStatus("ready", "");
    }
    function reportFrameReady(screenName, session, path, generation, serial) {
        if (session !== requestData.session || path !== requestData.path || generation !== requestData.generation || serial !== requestData.serial)
            return;

        var next = Object.assign({}, readyScreens);
        next[String(screenName || "")] = true;
        readyScreens = next;
        maybeReportReady();
    }
    function reportPlaybackError(screenName, session, path, generation, serial, message) {
        if (session !== requestData.session || path !== requestData.path || generation !== requestData.generation || serial !== requestData.serial)
            return;
        writeStatus("error", String(message || "Could not decode the live wallpaper"));
    }
    function writeStatus(state, message) {
        if (!statusFilePath)
            return;
        statusFile.setText(JSON.stringify({
            "generation": Number(requestData.generation || 0),
            "message": String(message || ""),
            "path": String(requestData.path || ""),
            "serial": Number(requestData.serial || 0),
            "session": String(requestData.session || ""),
            "state": String(state || "")
        }) + "\n");
    }

    Component.onCompleted: Qt.callLater(root.loadRequest)

    Connections {
        function onScreensChanged() {
            root.maybeReportReady();
        }

        target: Quickshell
    }
    FileView {
        id: requestFile

        blockLoading: true
        path: root.requestFilePath
        printErrors: false
        watchChanges: true

        onFileChanged: {
            reload();
            root.loadRequest();
        }
        onLoaded: root.loadRequest()
    }
    FileView {
        id: statusFile

        atomicWrites: true
        blockWrites: true
        path: root.statusFilePath
        printErrors: false
    }
    Variants {
        model: Quickshell.screens

        delegate: Component {
            NativeVideoSurface {
                required property var modelData

                requestData: root.requestData
                screen: modelData
                windowNamespace: "native-video-wallpaper-" + modelData.name

                onFrameReady: (screenName, session, path, generation, serial) => root.reportFrameReady(screenName, session, path, generation, serial)
                onPlaybackError: (screenName, session, path, generation, serial, message) => root.reportPlaybackError(screenName, session, path, generation, serial, message)
            }
        }
    }
}
