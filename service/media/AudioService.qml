pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

QtObject {
    id: root

    readonly property int appStreamCount: {
        if (!Pipewire.ready || !Pipewire.nodes || !Pipewire.nodes.values)
            return 0;
        var count = 0;
        for (var i = 0; i < Pipewire.nodes.values.length; ++i) {
            var node = Pipewire.nodes.values[i];
            if (node && node.isStream && node.audio && root.isPlaybackStream(node))
                ++count;
        }
        return count;
    }
    readonly property var microphoneApps: {
        var apps = [];
        for (var i = 0; i < microphoneNodes.length; ++i) {
            var node = microphoneNodes[i];
            apps.push({
                node: node,
                name: root.applicationName(node),
                icon: root.resolveAppIcon(node, "audio-input-microphone-symbolic")
            });
        }
        return apps;
    }
    readonly property bool microphoneInUse: microphoneApps.length > 0
    property PwNodeLinkTracker microphoneLinkTracker: PwNodeLinkTracker {
        node: Pipewire.defaultAudioSource
    }
    readonly property var microphoneNodes: {
        var groups = microphoneLinkTracker.linkGroups;
        var nodes = [];
        var seen = {};
        for (var i = 0; i < groups.length; ++i) {
            var target = groups[i] ? groups[i].target : null;
            if (!target || !target.isStream)
                continue;
            var key = target.id.toString();
            if (seen[key])
                continue;
            seen[key] = true;
            nodes.push(target);
        }
        return nodes;
    }
    property PwObjectTracker microphoneObjectTracker: PwObjectTracker {
        objects: root.microphoneNodes
    }
    property Process routeProcess: Process {
    }

    function applicationName(node) {
        if (!node)
            return "Unknown application";
        var properties = node.properties || {};
        return properties["application.name"] || properties["app.name"] || properties["node.description"] || node.description || node.nickname || node.name || "Unknown application";
    }
    function cleanDeviceName(name) {
        if (!name)
            return "";
        var clean = name;
        clean = clean.replace(/Family 17h\/19h \(AMD|AMD|Intel|NVIDIA|Realtek|Alder Lake PCH-P|Tiger Lake-LP|Comet Lake|AMD-Fi|HDA/gi, "");
        clean = clean.replace(/High Definition Audio Controller/gi, "");
        clean = clean.replace(/Audio Controller/gi, "");
        clean = clean.replace(/Analog Stereo/gi, "Stereo");
        clean = clean.replace(/Digital Stereo \(HDMI\)/gi, "HDMI");
        clean = clean.replace(/ Output$/gi, "");
        clean = clean.replace(/ Input$/gi, "");
        clean = clean.replace(/\s+/g, " ").trim();
        if (clean.startsWith("-"))
            clean = clean.substring(1).trim();
        if (clean.endsWith("-"))
            clean = clean.substring(0, clean.length - 1).trim();
        return clean === "" ? name : clean;
    }
    function isDevice(node, isSink) {
        return node && !node.isStream && node.audio && (isSink ? node.isSink : !node.isSink);
    }
    function isPlaybackStream(node) {
        if (!node || !node.properties)
            return true;
        var mediaClass = node.properties["media.class"] || "";
        return mediaClass.includes("Output") || mediaClass.includes("Sink");
    }
    function moveStream(stream, isSink, device) {
        if (!stream || !device)
            return;
        var serial = stream.properties && stream.properties["object.serial"] ? stream.properties["object.serial"] : stream.id;
        routeProcess.command = ["pactl", isSink ? "move-sink-input" : "move-source-output", serial.toString(), device.name];
        routeProcess.running = false;
        routeProcess.running = true;
    }
    function resolveAppIcon(node, fallbackIcon) {
        var fallback = fallbackIcon || "audio-volume-high-symbolic";
        if (!node || !node.properties)
            return fallback;
        var properties = node.properties;
        var icon = properties["window.icon"] || properties["app.icon"] || properties["application.icon-name"] || properties["application.icon"] || properties["app.icon-name"];
        if (icon)
            return icon;

        var appName = properties["application.name"] || node.description || node.name;
        if (appName) {
            var normalized = appName.toLowerCase().replace(/:.*/, "").replace(/playback/, "").replace(/input/, "").trim();
            var entry = DesktopEntries.byId(normalized) || DesktopEntries.heuristicLookup(normalized);
            if (entry && entry.icon)
                return entry.icon;
        }
        return fallback;
    }
    function setDefaultDevice(device, isSink) {
        if (!device)
            return;
        if (isSink)
            Pipewire.preferredDefaultAudioSink = device;
        else
            Pipewire.preferredDefaultAudioSource = device;
    }
    function streamTargetDevice(node, isSink) {
        if (!node)
            return isSink ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource;

        if (Pipewire.links && Pipewire.links.values) {
            for (var i = 0; i < Pipewire.links.values.length; ++i) {
                var link = Pipewire.links.values[i];
                if (!link || !link.source || link.source.id !== node.id || !link.target)
                    continue;
                if (isSink && link.target.isSink)
                    return link.target;
                if (!isSink && !link.target.isStream && !link.target.isSink)
                    return link.target;
            }
        }

        var properties = node.properties || {};
        var target = properties["node.driver-id"] || properties["target.node"] || properties["target.object"] || properties["node.target"];
        if (target && Pipewire.nodes && Pipewire.nodes.values) {
            for (var j = 0; j < Pipewire.nodes.values.length; ++j) {
                var candidate = Pipewire.nodes.values[j];
                var correctType = candidate && (isSink ? candidate.isSink : (!candidate.isStream && !candidate.isSink));
                if (correctType && (candidate.name === target || candidate.id.toString() === target.toString()))
                    return candidate;
            }
        }
        return isSink ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource;
    }
}
