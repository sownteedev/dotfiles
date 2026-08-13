import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: filesRoot

    property var fileResults: []
    property string query: ""
    property int requestGeneration: 0

    function removeFile(path) {
        var arr = [];
        for (var i = 0; i < fileResults.length; i++) {
            if (!fileResults[i] || fileResults[i].path !== path)
                arr.push(fileResults[i]);
        }
        fileResults = arr;
    }
    function runFileSearch() {
        fileSearchProcess.running = false;
        var q = query.trim();
        var searchTerm = "";
        if (q.toLowerCase().startsWith("f ")) {
            searchTerm = q.substring(2).trim();
        } else if (q.toLowerCase() !== "f") {
            fileResults = [];
            return;
        }

        var generation = requestGeneration;
        if (searchTerm === "") {
            var recentScript = "printf '__QS_REQUEST__%s\\n' \"$1\"; " + "find \"$HOME\" -maxdepth 3 -not -path '*/.*' -type f -printf '%T@ %p\\n' 2>/dev/null " + "| sort -nr 2>/dev/null | head -n 5 | cut -d' ' -f2-";
            fileSearchProcess.command = ["sh", "-c", recentScript, "recent_files", String(generation)];
        } else {
            if (searchTerm.length < 2) {
                fileResults = [];
                return;
            }

            var searchScript = "printf '__QS_REQUEST__%s\\n' \"$1\"; term=$2; set -- \"$HOME\"; " + "for candidate in /mnt/windows/Users/*/Downloads; do [ -d \"$candidate\" ] && set -- \"$@\" \"$candidate\"; done; " + "LC_ALL=C find \"$@\" -maxdepth 6 " + "\\( -name '.cache' -o -name '.git' -o -name '.local' -o -name '.mozilla' -o -name '.npm' -o -name '.cargo' -o -name '.rustup' " + "-o -name 'node_modules' -o -name 'venv' -o -name 'target' -o -name 'build' -o -name 'dist' -o -name 'Code' -o -name 'google-chrome' " + "-o -name '.gemini' -o -name '.antigravity-ide' -o -name 'Cache' -o -name 'CachedData' -o -name 'Code Cache' -o -name 'GPUCache' " + "-o -name 'logs' -o -name 'blob_storage' -o -name 'Service Worker' -o -name 'Session Storage' -o -name 'session' " + "-o -name 'Local Storage' -o -name 'WebStorage' -o -name 'storage' -o -name '__pycache__' \\) -prune -o " + "\\( -type f -o -type d -o -xtype d \\) -iname \"*$term*\" -printf '%y\\t%f\\t%p\\n' 2>/dev/null " + "| awk -F '\\t' -v term=\"$term\" 'BEGIN { term=tolower(term) } { kind=($1 == \"d\" || $1 == \"l\") ? \"d\" : \"f\"; name=tolower($2); rank=(name == term ? 0 : (index(name, term) == 1 ? 2 : 4)) + (kind == \"f\" ? 1 : 0); path=substr($0, length($1) + length($2) + 3); print rank \"\\t\" kind \"\\t\" path }' " + "| sort -n | head -n 5 | cut -f2-";
            fileSearchProcess.command = ["sh", "-c", searchScript, "find_script", String(generation), searchTerm];
        }
        fileSearchProcess.running = true;
    }

    Component.onDestruction: {
        requestGeneration += 1;
        fileSearchProcess.running = false;
    }
    onQueryChanged: {
        requestGeneration += 1;
        fileResults = [];
        fileSearchProcess.running = false;
        searchDebounceTimer.restart();
    }

    Timer {
        id: searchDebounceTimer

        interval: 260
        repeat: false

        onTriggered: runFileSearch()
    }
    Process {
        id: fileSearchProcess

        stdout: StdioCollector {
            id: fileCollector
        }

        onRunningChanged: {
            if (!running) {
                var output = fileCollector.text.trim();
                var lines = output === "" ? [] : output.split("\n");
                var markerPrefix = "__QS_REQUEST__";
                if (lines.length === 0 || lines[0].indexOf(markerPrefix) !== 0)
                    return;

                var responseGeneration = parseInt(lines.shift().substring(markerPrefix.length));
                if (responseGeneration !== requestGeneration)
                    return;

                if (lines.length === 0) {
                    fileResults = [];
                    return;
                }

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
