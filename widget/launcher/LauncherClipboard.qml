import QtQuick
import Quickshell
import Quickshell.Io

// Logic-only component for clipboard history using cliphist
Item {
    id: clipboardRoot

    property var clipboardResults: []
    property string query: ""

    function copySelected(id) {
        Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "clip_decode", id]);
    }
    function runClipboardSearch() {
        cliphistProcess.running = false;
        var q = query.trim();
        // Determine search term after "c "
        var searchTerm = "";
        if (q.toLowerCase().startsWith("c ")) {
            searchTerm = q.substring(2).trim();
        } else if (q.toLowerCase() === "c") {
            searchTerm = "";
        } else {
            clipboardResults = [];
            return;
        }

        cliphistProcess.command = ["sh", "-c", "cliphist list 2>/dev/null | grep -i \"$1\" 2>/dev/null | head -n 20", "cliphist_script", searchTerm];
        cliphistProcess.running = true;
    }

    Component.onDestruction: {
        cliphistProcess.running = false;
    }
    onQueryChanged: {
        clipboardResults = [];
        searchDebounceTimer.restart();
    }

    Timer {
        id: searchDebounceTimer

        interval: 120
        repeat: false

        onTriggered: {
            runClipboardSearch();
        }
    }
    Process {
        id: cliphistProcess

        stdout: StdioCollector {
            id: cliphistCollector
        }

        onRunningChanged: {
            if (!running) {
                var output = cliphistCollector.text.trim();
                if (output === "") {
                    clipboardResults = [];
                } else {
                    var lines = output.split("\n");
                    var results = [];
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i];
                        if (line.trim() === "")
                            continue;
                        var tabIdx = line.indexOf("\t");
                        if (tabIdx !== -1) {
                            var id = line.substring(0, tabIdx).trim();
                            var content = line.substring(tabIdx + 1);
                            var isImg = content.indexOf("binary data") !== -1 || content.indexOf("image/") !== -1;
                            if (isImg) {
                                // Async fire-and-forget decode image to /tmp
                                Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" > \"$2\"", "decode_image", id, "/tmp/cliphist-" + id + ".png"]);
                            }
                            results.push({
                                id: id,
                                content: content,
                                isImage: isImg,
                                imagePath: "file:///tmp/cliphist-" + id + ".png"
                            });
                        }
                    }
                    clipboardResults = results;
                }
            }
        }
    }
}
