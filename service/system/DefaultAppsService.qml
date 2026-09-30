pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

QtObject {
    id: root

    readonly property var audioExtensions: ["mp3", "flac", "ogg", "oga", "wav", "m4a", "aac", "opus", "aiff"]
    readonly property var audioPlayerDefinitions: [
        {
            "label": qsTr("System default"),
            "value": "system"
        },
        {
            "label": qsTr("mpv"),
            "value": "mpv"
        },
        {
            "label": qsTr("VLC"),
            "value": "vlc"
        },
        {
            "label": qsTr("Audacious"),
            "value": "audacious"
        },
        {
            "label": qsTr("Rhythmbox"),
            "value": "rhythmbox"
        },
        {
            "label": qsTr("Amberol"),
            "value": "amberol"
        },
        {
            "label": qsTr("Elisa"),
            "value": "elisa"
        },
        {
            "label": qsTr("DeaDBeeF"),
            "value": "deadbeef"
        }
    ]
    readonly property var audioPlayerOptions: optionsFor(audioPlayerDefinitions, Config.defaultAudioPlayer)
    property Process availabilityProbe: Process {
        command: ["sh", "-c", "for command_name in blackbox-terminal foot kitty alacritty wezterm kgx konsole xdg-terminal-exec neovide code codium gio brave brave-browser firefox chromium google-chrome microsoft-edge zen-browser nautilus dolphin thunar nemo pcmanfm loupe gwenview feh imv ristretto sxiv eog qimgv mpv vlc celluloid haruna totem audacious rhythmbox amberol elisa deadbeef evince okular zathura atril mupdf xdg-open; do command -v \"$command_name\" >/dev/null 2>&1 && printf '%s\\n' \"$command_name\"; done"]

        stdout: StdioCollector {
            onStreamFinished: root.applyAvailability(text)
        }

        onExited: {
            if (!root.availabilityReady)
                root.applyAvailability("");
        }
    }
    property bool availabilityReady: false
    readonly property var browserDefinitions: [
        {
            "label": qsTr("System default"),
            "value": "system"
        },
        {
            "label": qsTr("Brave"),
            "value": "brave"
        },
        {
            "label": qsTr("Firefox"),
            "value": "firefox"
        },
        {
            "label": qsTr("Chromium"),
            "value": "chromium"
        },
        {
            "label": qsTr("Google Chrome"),
            "value": "google-chrome"
        },
        {
            "label": qsTr("Microsoft Edge"),
            "value": "microsoft-edge"
        },
        {
            "label": qsTr("Zen Browser"),
            "value": "zen-browser"
        }
    ]
    readonly property var browserOptions: optionsFor(browserDefinitions, Config.defaultBrowser)
    property var commandAvailability: ({})
    readonly property var documentExtensions: ["pdf", "epub", "djvu"]
    readonly property var documentViewerDefinitions: [
        {
            "label": qsTr("System default"),
            "value": "system"
        },
        {
            "label": qsTr("Evince"),
            "value": "evince"
        },
        {
            "label": qsTr("Okular"),
            "value": "okular"
        },
        {
            "label": qsTr("Zathura"),
            "value": "zathura"
        },
        {
            "label": qsTr("Atril"),
            "value": "atril"
        },
        {
            "label": qsTr("MuPDF"),
            "value": "mupdf"
        }
    ]
    readonly property var documentViewerOptions: optionsFor(documentViewerDefinitions, Config.defaultDocumentViewer)
    readonly property var editorDefinitions: [
        {
            "label": qsTr("Neovide"),
            "value": "neovide"
        },
        {
            "label": qsTr("Visual Studio Code"),
            "value": "code"
        },
        {
            "label": qsTr("VSCodium"),
            "value": "codium"
        },
        {
            "label": qsTr("System file handler"),
            "value": "gio"
        }
    ]
    readonly property var editorOptions: optionsFor(editorDefinitions, Config.defaultEditor)
    readonly property var fileManagerDefinitions: [
        {
            "label": qsTr("System default"),
            "value": "system"
        },
        {
            "label": qsTr("Nautilus"),
            "value": "nautilus"
        },
        {
            "label": qsTr("Dolphin"),
            "value": "dolphin"
        },
        {
            "label": qsTr("Thunar"),
            "value": "thunar"
        },
        {
            "label": qsTr("Nemo"),
            "value": "nemo"
        },
        {
            "label": qsTr("PCManFM"),
            "value": "pcmanfm"
        }
    ]
    readonly property var fileManagerOptions: optionsFor(fileManagerDefinitions, Config.defaultFileManager)
    readonly property var imageExtensions: ["png", "jpg", "jpeg", "webp", "avif", "gif", "bmp", "tif", "tiff", "svg"]
    readonly property var imageViewerDefinitions: [
        {
            "label": qsTr("System default"),
            "value": "system"
        },
        {
            "label": qsTr("Loupe"),
            "value": "loupe"
        },
        {
            "label": qsTr("Gwenview"),
            "value": "gwenview"
        },
        {
            "label": qsTr("feh"),
            "value": "feh"
        },
        {
            "label": qsTr("imv"),
            "value": "imv"
        },
        {
            "label": qsTr("Ristretto"),
            "value": "ristretto"
        },
        {
            "label": qsTr("sxiv"),
            "value": "sxiv"
        },
        {
            "label": qsTr("Eye of GNOME"),
            "value": "eog"
        },
        {
            "label": qsTr("qimgv"),
            "value": "qimgv"
        }
    ]
    readonly property var imageViewerOptions: optionsFor(imageViewerDefinitions, Config.defaultImageViewer)
    readonly property var terminalDefinitions: [
        {
            "label": qsTr("Black Box"),
            "value": "blackbox-terminal"
        },
        {
            "label": qsTr("Foot"),
            "value": "foot"
        },
        {
            "label": qsTr("Kitty"),
            "value": "kitty"
        },
        {
            "label": qsTr("Alacritty"),
            "value": "alacritty"
        },
        {
            "label": qsTr("WezTerm"),
            "value": "wezterm"
        },
        {
            "label": qsTr("GNOME Console"),
            "value": "kgx"
        },
        {
            "label": qsTr("Konsole"),
            "value": "konsole"
        },
        {
            "label": qsTr("System terminal"),
            "value": "xdg-terminal-exec"
        }
    ]
    readonly property var terminalOptions: optionsFor(terminalDefinitions, Config.defaultTerminal)
    readonly property var textExtensions: ["txt", "md", "markdown", "json", "yaml", "yml", "xml", "csv", "log", "qml", "js", "mjs", "ts", "tsx", "jsx", "py", "rs", "go", "c", "cc", "cpp", "h", "hpp", "sh", "zsh", "fish", "kdl", "toml", "ini", "conf", "css", "scss", "html"]
    readonly property var videoExtensions: ["mp4", "mkv", "avi", "mov", "webm", "m4v", "mpeg", "mpg", "ogv", "3gp"]
    readonly property var videoPlayerDefinitions: [
        {
            "label": qsTr("System default"),
            "value": "system"
        },
        {
            "label": qsTr("mpv"),
            "value": "mpv"
        },
        {
            "label": qsTr("VLC"),
            "value": "vlc"
        },
        {
            "label": qsTr("Celluloid"),
            "value": "celluloid"
        },
        {
            "label": qsTr("Haruna"),
            "value": "haruna"
        },
        {
            "label": qsTr("Totem"),
            "value": "totem"
        }
    ]
    readonly property var videoPlayerOptions: optionsFor(videoPlayerDefinitions, Config.defaultVideoPlayer)

    function applyAvailability(output) {
        var available = {};
        available.system = true;
        var lines = String(output || "").split(/\r?\n/);
        for (var index = 0; index < lines.length; ++index) {
            var value = lines[index].trim();
            if (value !== "")
                available[value] = true;
        }
        commandAvailability = available;
        availabilityReady = true;
    }
    function audioPlayerCommand(path) {
        return openWith("defaultAudioPlayer", audioPlayerDefinitions, path, "xdg-open");
    }
    function browserCommand(url) {
        return openWith("defaultBrowser", browserDefinitions, url, "xdg-open");
    }
    function documentViewerCommand(path) {
        return openWith("defaultDocumentViewer", documentViewerDefinitions, path, "xdg-open");
    }
    function editorCommand(path) {
        var selected = String(Config.defaultEditor || "neovide");
        if (availabilityReady && commandAvailability[selected] !== true) {
            selected = "";
            var fallbacks = ["gio", "neovide", "code", "codium"];
            for (var editorIndex = 0; editorIndex < fallbacks.length; ++editorIndex) {
                var editor = fallbacks[editorIndex];
                if (commandAvailability[editor] === true) {
                    selected = editor;
                    break;
                }
            }
        }

        if (selected === "gio")
            return ["gio", "open", path];
        if (selected === "")
            return [];
        return [selected, path];
    }
    function fileCommand(path) {
        var extension = pathExtension(path);
        if (imageExtensions.indexOf(extension) !== -1)
            return imageViewerCommand(path);
        if (videoExtensions.indexOf(extension) !== -1)
            return videoPlayerCommand(path);
        if (audioExtensions.indexOf(extension) !== -1)
            return audioPlayerCommand(path);
        if (documentExtensions.indexOf(extension) !== -1)
            return documentViewerCommand(path);
        if (textExtensions.indexOf(extension) !== -1)
            return editorCommand(path);
        return availabilityReady && commandAvailability.gio === true ? ["gio", "open", path] : ["xdg-open", path];
    }
    function fileManagerCommand(path) {
        var selected = resolveCommand("defaultFileManager", fileManagerDefinitions);
        var systemCommand = availabilityReady && commandAvailability.gio === true ? "gio" : "xdg-open";
        if (selected === "system")
            return systemCommand === "gio" ? ["gio", "open", path] : [systemCommand, path];
        return [selected, path];
    }
    function imageViewerCommand(path) {
        return openWith("defaultImageViewer", imageViewerDefinitions, path, "xdg-open");
    }
    function openPath(path, isDirectory) {
        if (isDirectory === true)
            return fileManagerCommand(path);
        return fileCommand(path);
    }
    function openUrl(url) {
        var target = String(url || "");
        if (/^https?:\/\//i.test(target))
            return browserCommand(target);
        return ["xdg-open", target];
    }
    function openWith(settingName, definitions, path, systemCommand) {
        var selected = resolveCommand(settingName, definitions);
        if (selected === "system")
            return [systemCommand, path];
        return [selected, path];
    }
    function optionsFor(definitions, currentValue) {
        var result = [];
        var current = String(currentValue || "");
        var seen = {};
        for (var index = 0; index < definitions.length; ++index) {
            var definition = definitions[index];
            if (availabilityReady && definition.value !== "system" && commandAvailability[definition.value] !== true)
                continue;
            result.push({
                "label": definition.label,
                "value": definition.value
            });
            seen[definition.value] = true;
        }

        if (current !== "" && !seen[current]) {
            result.unshift({
                "label": qsTr("%1 (unavailable)").arg(current),
                "value": current
            });
        }
        return result;
    }
    function pathExtension(path) {
        var cleanPath = String(path || "").split(/[?#]/)[0];
        var slash = cleanPath.lastIndexOf("/");
        var dot = cleanPath.lastIndexOf(".");
        return dot > slash ? cleanPath.slice(dot + 1).toLowerCase() : "";
    }
    function resolveCommand(settingName, definitions) {
        var selected = String(Config[settingName] || "system");
        if (selected === "system" || !availabilityReady || commandAvailability[selected] === true)
            return selected;

        for (var index = 0; index < definitions.length; ++index) {
            var candidate = String(definitions[index].value || "");
            if (candidate !== "system" && commandAvailability[candidate] === true)
                return candidate;
        }
        return "system";
    }
    function terminalCommand(command) {
        var selected = String(Config.defaultTerminal || "blackbox-terminal");
        if (availabilityReady && commandAvailability[selected] !== true) {
            selected = "";
            var fallbacks = ["blackbox-terminal", "xdg-terminal-exec", "foot", "kitty", "alacritty", "wezterm", "kgx", "konsole"];
            for (var terminalIndex = 0; terminalIndex < fallbacks.length; ++terminalIndex) {
                if (commandAvailability[fallbacks[terminalIndex]] === true) {
                    selected = fallbacks[terminalIndex];
                    break;
                }
            }
        }

        if (selected === "")
            return [];
        if (selected === "blackbox-terminal")
            return [selected, "--command", command];
        if (selected === "alacritty")
            return [selected, "-e", "/usr/bin/zsh", "-lc", command];
        if (selected === "wezterm")
            return [selected, "start", "--", "/usr/bin/zsh", "-lc", command];
        if (selected === "kgx")
            return [selected, "--", "/usr/bin/zsh", "-lc", command];
        if (selected === "konsole")
            return [selected, "-e", "/usr/bin/zsh", "-lc", command];
        return [selected, "/usr/bin/zsh", "-lc", command];
    }
    function videoPlayerCommand(path) {
        return openWith("defaultVideoPlayer", videoPlayerDefinitions, path, "xdg-open");
    }

    Component.onCompleted: availabilityProbe.running = true
}
