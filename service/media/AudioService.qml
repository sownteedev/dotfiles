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
        var nodes = [];
        for (var nodeIndex = 0; nodeIndex < rawMicrophoneNodes.length; ++nodeIndex) {
            var node = rawMicrophoneNodes[nodeIndex];
            if (root.isApplicationCapture(node))
                nodes.push(node);
        }
        return nodes;
    }
    property PwObjectTracker microphoneObjectTracker: PwObjectTracker {
        objects: root.rawMicrophoneNodes
    }
    property var pendingRoutes: []
    readonly property var rawMicrophoneNodes: {
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

        // The default-source tracker does not see applications recording from
        // another microphone or a monitor source. Capture links run from a
        // non-stream source node into an application stream, so include those
        // targets as well and let PwObjectTracker retain their audio metadata.
        var links = Pipewire.links && Pipewire.links.values ? Pipewire.links.values : [];
        for (var linkIndex = 0; linkIndex < links.length; ++linkIndex) {
            var link = links[linkIndex];
            var source = link ? link.source : null;
            var linkTarget = link ? link.target : null;
            if (!source || source.isStream || !linkTarget || !linkTarget.isStream)
                continue;
            var linkKey = linkTarget.id.toString();
            if (seen[linkKey])
                continue;
            seen[linkKey] = true;
            nodes.push(linkTarget);
        }
        return nodes;
    }
    property Process routeProcess: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                console.warn("[AudioService] Failed to route audio stream:", exitCode);
            root.startNextRoute();
        }
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
    function isApplicationCapture(node) {
        if (!node || !node.isStream)
            return false;
        var properties = node.properties || {};
        var mediaClass = String(properties["media.class"] || "");
        if (mediaClass !== "" && mediaClass !== "Stream/Input/Audio")
            return false;
        var applicationName = String(properties["application.name"] || "").trim();
        var processBinary = String(properties["application.process.binary"] || "").trim();
        if (applicationName !== "" || processBinary !== "")
            return true;

        // Quickshell 0.3 may expose an empty properties object for linked
        // capture streams. Keep real streams in that case, but exclude our own
        // Cava monitor helper so playback visualization never trips mic privacy.
        var nodeName = String(node.name || "").trim().toLowerCase();
        return nodeName !== "" && nodeName !== "cava" && nodeName !== "quickshell-cava";
    }
    function isDevice(node, isSink) {
        if (!node || node.isStream || !node.audio || !node.properties)
            return false;

        var mediaClass = String(node.properties["media.class"] || "");
        if (isSink)
            return node.isSink && mediaClass.indexOf("Audio/Sink") === 0;

        // A plain `!isSink` also includes filters, adapters and other virtual
        // PipeWire nodes. Only real source-class nodes belong in the input list.
        var name = String(node.name || "");
        var deviceClass = String(node.properties["device.class"] || "");
        var virtualNode = String(node.properties["node.virtual"] || "") === "true";
        return !node.isSink && mediaClass.indexOf("Audio/Source") === 0 && deviceClass !== "monitor" && !virtualNode && !name.endsWith(".monitor");
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
        var routeKey = (isSink ? "sink:" : "source:") + serial.toString();
        var queued = [];
        for (var i = 0; i < pendingRoutes.length; ++i) {
            if (pendingRoutes[i].key !== routeKey)
                queued.push(pendingRoutes[i]);
        }
        queued.push({
            "key": routeKey,
            "command": ["pactl", isSink ? "move-sink-input" : "move-source-output", serial.toString(), device.name]
        });
        pendingRoutes = queued;
        startNextRoute();
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
    function startNextRoute() {
        if (routeProcess.running || pendingRoutes.length === 0)
            return;

        var queued = pendingRoutes.slice();
        var nextRoute = queued.shift();
        pendingRoutes = queued;
        routeProcess.command = nextRoute.command;
        routeProcess.running = true;
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
