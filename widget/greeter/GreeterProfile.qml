pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property FileView manifestFile: FileView {
        blockLoading: true
        path: root.manifestPath
        printErrors: false
        watchChanges: true

        onFileChanged: reload()
        onLoadedChanged: {
            if (loaded)
                root.applyManifest(text());
        }
        onTextChanged: {
            if (loaded)
                root.applyManifest(text());
        }
    }
    readonly property string manifestPath: Quickshell.env("GREETD_PROFILE_PATH") || "/var/lib/quickshell-greeter/profile.json"
    property string sourcePath: ""

    function applyManifest(rawText) {
        try {
            var manifest = JSON.parse(String(rawText || ""));
            sourcePath = String(manifest.path || "");
        } catch (error) {
            sourcePath = "";
            console.warn("[GreeterProfile] Invalid profile manifest:", error);
        }
    }
    function fileUrl(path) {
        var value = String(path || "");
        return value.indexOf("file:") === 0 ? value : value === "" ? "" : "file://" + value;
    }
}
