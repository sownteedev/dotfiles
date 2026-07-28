import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: filesRoot

    property var fileResults: []
    property string query: ""

    function removeFile(path) {
        var arr = [];
        for (var i = 0; i < fileResults.length; i++) {
            if (!fileResults[i] || fileResults[i].path !== path) {
                arr.push(fileResults[i]);
            }
        }
        fileResults = arr;
    }
    function runFileSearch() {
        fileSearchProcess.running = false;
        var q = query.trim();
        // Determine search term after "f "
        var searchTerm = "";
        if (q.toLowerCase().startsWith("f ")) {
            searchTerm = q.substring(2).trim();
        } else if (q.toLowerCase() === "f") {
            searchTerm = "";
        } else {
            fileResults = [];
            return;
        }

        if (searchTerm === "") {
            // Empty search term -> show top 5 recently modified files
            fileSearchProcess.command = ["sh", "-c", "find \"$HOME\" -maxdepth 3 -not -path '*/.*' -type f -printf '%T@ %p\\n' 2>/dev/null | sort -nr | head -n 5 | cut -d' ' -f2-", "recent_files"];
        } else {
            if (searchTerm.length < 2) {
                fileResults = [];
                return;
            }
            const downloadWindowsDir = "/mnt/windows/Users/Nguyen\\ Thanh\\ Son/Downloads";
            fileSearchProcess.command = ["sh", "-c", "find \"$HOME\" " + downloadWindowsDir + " -maxdepth 8 \\( -name '.cache' -o -name '.git' -o -name '.local' -o -name '.mozilla' -o -name '.npm' -o -name '.cargo' -o -name '.rustup' -o -name 'node_modules' -o -name 'venv' -o -name 'target' -o -name 'build' -o -name 'dist' -o -name 'Code' -o -name 'google-chrome' -o -name '.gemini' -o -name '.antigravity-ide' -o -name 'Cache' -o -name 'CachedData' -o -name 'Code Cache' -o -name 'GPUCache' -o -name 'logs' -o -name 'blob_storage' -o -name 'Service Worker' -o -name 'Session Storage' -o -name 'session' -o -name 'Local Storage' -o -name 'WebStorage' -o -name 'storage' -o -name '__pycache__' \\) -prune -o \\( -type f -o -type d \\) -iname \"*$1*\" -printf '%y\t%p\\n' 2>/dev/null | head -n 5", "find_script", searchTerm];
        }
        fileSearchProcess.running = true;
    }

    Component.onDestruction: {
        fileSearchProcess.running = false;
    }
    onQueryChanged: {
        fileResults = [];
        searchDebounceTimer.restart();
    }

    Timer {
        id: searchDebounceTimer

        interval: 120
        repeat: false

        onTriggered: {
            runFileSearch();
        }
    }
    Process {
        id: fileSearchProcess

        stdout: StdioCollector {
            id: fileCollector
        }

        onRunningChanged: {
            if (!running) {
                var output = fileCollector.text.trim();
                if (output === "") {
                    fileResults = [];
                } else {
                    var lines = output.split("\n");
                    var results = [];
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i].trim();
                        if (line === "")
                            continue;

                        var tabIdx = line.indexOf("\t");
                        if (tabIdx !== -1) {
                            var kind = line.substring(0, tabIdx);
                            var path = line.substring(tabIdx + 1);
                            results.push({
                                kind: kind === "d" ? "folder" : "file",
                                path: path,
                                name: path.substring(path.lastIndexOf("/") + 1)
                            });
                        } else {
                            results.push({
                                kind: "file",
                                path: line,
                                name: line.substring(line.lastIndexOf("/") + 1)
                            });
                        }
                    }
                    fileResults = results;
                }
            }
        }
    }
}
