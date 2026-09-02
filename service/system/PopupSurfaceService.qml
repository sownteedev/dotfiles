pragma Singleton
import "../../"
import ".."
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland

QtObject {
    id: root

    property bool activeBrightnessInit: false
    property bool activeMicInit: false
    property bool activeSpeakerInit: false
    property PwObjectTracker audioTracker: PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
    property Timer brightnessInitTimer: Timer {
        interval: 50
        repeat: false

        onTriggered: root.activeBrightnessInit = root.brightnessReady
    }
    readonly property bool brightnessReady: BrightnessService.initialized && BrightnessService.available
    readonly property real brightnessValue: BrightnessService.value
    property Connections dndConnections: Connections {
        function onDndActiveChanged() {
            if (QuickSettingsService.dndActive)
                root.clearQueuedScreenshotNotifications();
        }
        function onEffectiveDndActiveChanged() {
            if (QuickSettingsService.effectiveDndActive)
                root.clearQueuedNotifications();
        }

        target: QuickSettingsService
    }
    property Timer micInitTimer: Timer {
        interval: 50
        repeat: false

        onTriggered: root.activeMicInit = root.micReady
    }
    readonly property bool micMuted: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? Pipewire.defaultAudioSource.audio.muted : false
    readonly property bool micReady: Pipewire.ready && !!(Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio)
    readonly property real micValue: maximumAudioVolume(Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null)
    property var notificationQueues: ({})
    property var notificationSurfaceRequests: ({})
    property bool osdActive: false
    property Timer osdHideTimer: Timer {
        interval: Config.osdDuration
        repeat: false

        onTriggered: {
            root.osdActive = false;
            root.osdReleaseTimer.restart();
        }
    }
    property string osdIndicator: ""
    property Timer osdReleaseTimer: Timer {
        interval: Config.animationDuration(260) + 40
        repeat: false

        onTriggered: {
            if (!root.osdActive)
                root.osdSurfaceRequested = false;
        }
    }
    property int osdRevision: 0
    property string osdScreenName: ""
    property bool osdSurfaceRequested: false
    property var screenshotNotificationQueues: ({})
    property var screenshotNotificationSurfaceRequests: ({})
    property Timer speakerInitTimer: Timer {
        interval: 50
        repeat: false

        onTriggered: root.activeSpeakerInit = root.speakerReady
    }
    readonly property bool speakerMuted: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio.muted : false
    readonly property bool speakerReady: Pipewire.ready && !!(Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio)
    readonly property real speakerValue: maximumAudioVolume(Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null)

    signal notificationQueued(string screenName)
    signal screenshotNotificationQueued(string screenName)

    function appMatchesList(appName, rawList) {
        var expected = String(appName || "").trim().toLowerCase();
        if (expected === "")
            return false;

        var entries = String(rawList || "").split(",");
        for (var index = 0; index < entries.length; ++index) {
            var entry = entries[index].trim().toLowerCase();
            if (entry !== "" && (expected === entry || expected.indexOf(entry) !== -1))
                return true;
        }
        return false;
    }
    function clearQueuedNotifications() {
        var screenNames = Object.keys(notificationQueues);
        for (var screenIndex = 0; screenIndex < screenNames.length; ++screenIndex) {
            var queue = notificationQueues[screenNames[screenIndex]] || [];
            for (var queueIndex = 0; queueIndex < queue.length; ++queueIndex)
                NotificationHistory.releasePopup(queue[queueIndex].id, queue[queueIndex]);
        }
        notificationQueues = {};
    }
    function clearQueuedScreenshotNotifications() {
        var screenNames = Object.keys(screenshotNotificationQueues);
        for (var screenIndex = 0; screenIndex < screenNames.length; ++screenIndex) {
            var queue = screenshotNotificationQueues[screenNames[screenIndex]] || [];
            for (var queueIndex = 0; queueIndex < queue.length; ++queueIndex)
                NotificationHistory.releasePopup(queue[queueIndex].id, queue[queueIndex]);
        }
        screenshotNotificationQueues = {};
    }
    function enqueueNotification(notification) {
        var screenName = targetScreenName();
        if (!notification || screenName === "")
            return;

        NotificationHistory.retainPopup(notification);
        var queues = Object.assign({}, notificationQueues);
        var queue = queues[screenName] ? queues[screenName].slice() : [];
        var replaced = false;
        for (var index = 0; index < queue.length; ++index) {
            if (queue[index].id !== notification.id)
                continue;

            if (queue[index] === notification) {
                NotificationHistory.releasePopup(notification.id, notification);
                replaced = true;
                break;
            }
            NotificationHistory.releasePopup(queue[index].id, queue[index]);
            queue[index] = notification;
            replaced = true;
            break;
        }
        if (!replaced)
            queue.push(notification);
        queues[screenName] = queue;
        notificationQueues = queues;
        setNotificationSurfaceRequested(screenName, true);
        notificationQueued(screenName);
    }
    function enqueueScreenshotNotification(notification) {
        var screenName = targetScreenName();
        if (!notification || screenName === "")
            return;

        NotificationHistory.retainPopup(notification);
        var queues = Object.assign({}, screenshotNotificationQueues);
        var queue = queues[screenName] ? queues[screenName].slice() : [];
        var replaced = false;
        for (var index = 0; index < queue.length; ++index) {
            if (queue[index].id !== notification.id)
                continue;

            if (queue[index] === notification) {
                NotificationHistory.releasePopup(notification.id, notification);
                replaced = true;
                break;
            }
            NotificationHistory.releasePopup(queue[index].id, queue[index]);
            queue[index] = notification;
            replaced = true;
            break;
        }
        if (!replaced)
            queue.push(notification);
        queues[screenName] = queue;
        screenshotNotificationQueues = queues;
        setScreenshotNotificationSurfaceRequested(screenName, true);
        screenshotNotificationQueued(screenName);
    }
    function isManagedScreenshotNotification(notification) {
        var matchingSummary = String(notification.summary || "").toLowerCase().indexOf("screenshot captured") !== -1;
        var recentCapture = CaptureService.screenshotCapturedAt > 0 && Date.now() - CaptureService.screenshotCapturedAt < 10000;
        return matchingSummary && (CaptureService.screenshotBusy || recentCapture);
    }
    function maximumAudioVolume(audio) {
        if (!audio)
            return 0.0;

        var volumes = audio.volumes;
        if (!volumes || volumes.length === 0)
            return Math.max(0.0, audio.volume || 0.0);

        var maximum = 0.0;
        for (var index = 0; index < volumes.length; ++index) {
            var channelVolume = Number(volumes[index]);
            if (!isNaN(channelVolume))
                maximum = Math.max(maximum, channelVolume);
        }
        return maximum;
    }
    function notificationSurfaceIdle(screenName) {
        if ((notificationQueues[screenName] || []).length > 0)
            return;
        setNotificationSurfaceRequested(screenName, false);
    }
    function notificationSurfaceRequested(screenName) {
        return !!notificationSurfaceRequests[screenName];
    }
    function routeNotification(notification) {
        if (!notification)
            return;

        if (isManagedScreenshotNotification(notification)) {
            if (!QuickSettingsService.dndActive && Config.captureScreenshotAction === "notification")
                enqueueScreenshotNotification(notification);
            return;
        }
        if (QuickSettingsService.effectiveDndActive || StateManager.sessionLocked || !Config.notificationShowInFullscreen && ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.fullscreen)
            return;
        if (appMatchesList(notification.appName, Config.notificationBlockedApps))
            return;
        enqueueNotification(notification);
    }
    function screenshotNotificationSurfaceIdle(screenName) {
        if ((screenshotNotificationQueues[screenName] || []).length > 0)
            return;
        setScreenshotNotificationSurfaceRequested(screenName, false);
    }
    function screenshotNotificationSurfaceRequested(screenName) {
        return !!screenshotNotificationSurfaceRequests[screenName];
    }
    function setNotificationSurfaceRequested(screenName, requested) {
        var requests = Object.assign({}, notificationSurfaceRequests);
        if (requested)
            requests[screenName] = true;
        else
            delete requests[screenName];
        notificationSurfaceRequests = requests;
    }
    function setScreenshotNotificationSurfaceRequested(screenName, requested) {
        var requests = Object.assign({}, screenshotNotificationSurfaceRequests);
        if (requested)
            requests[screenName] = true;
        else
            delete requests[screenName];
        screenshotNotificationSurfaceRequests = requests;
    }
    function showOsd(type) {
        if (!Config.osdEnabled)
            return;
        if ((type === "volume" || type === "volume-mute") && !Config.osdShowVolume)
            return;
        if ((type === "mic" || type === "mic-mute") && !Config.osdShowMicrophone)
            return;
        if (type === "brightness" && !Config.osdShowBrightness)
            return;

        var screenName = targetScreenName();
        if (screenName === "")
            return;
        osdReleaseTimer.stop();
        osdIndicator = type;
        osdScreenName = screenName;
        osdSurfaceRequested = true;
        osdActive = true;
        osdRevision += 1;
        osdHideTimer.restart();
    }
    function takeNotifications(screenName) {
        var queue = notificationQueues[screenName] || [];
        if (queue.length === 0)
            return [];

        var queues = Object.assign({}, notificationQueues);
        delete queues[screenName];
        notificationQueues = queues;
        return queue;
    }
    function takeScreenshotNotifications(screenName) {
        var queue = screenshotNotificationQueues[screenName] || [];
        if (queue.length === 0)
            return [];

        var queues = Object.assign({}, screenshotNotificationQueues);
        delete queues[screenName];
        screenshotNotificationQueues = queues;
        return queue;
    }
    function targetScreenName() {
        var focusedName = String(WorkspaceService.focusedOutputName || "");
        for (var index = 0; index < Quickshell.screens.length; ++index) {
            if (Quickshell.screens[index].name === focusedName)
                return focusedName;
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
    }

    Component.onCompleted: {
        if (brightnessReady)
            brightnessInitTimer.start();
        if (micReady)
            micInitTimer.start();
        if (speakerReady)
            speakerInitTimer.start();
    }
    onBrightnessReadyChanged: {
        brightnessInitTimer.stop();
        activeBrightnessInit = false;
        if (brightnessReady)
            brightnessInitTimer.start();
    }
    onBrightnessValueChanged: {
        if (activeBrightnessInit)
            showOsd("brightness");
    }
    onMicMutedChanged: {
        if (activeMicInit)
            showOsd(micMuted ? "mic-mute" : "mic");
    }
    onMicReadyChanged: {
        micInitTimer.stop();
        activeMicInit = false;
        if (micReady)
            micInitTimer.start();
    }
    onMicValueChanged: {
        if (activeMicInit)
            showOsd("mic");
    }
    onSpeakerMutedChanged: {
        if (activeSpeakerInit)
            showOsd(speakerMuted ? "volume-mute" : "volume");
    }
    onSpeakerReadyChanged: {
        speakerInitTimer.stop();
        activeSpeakerInit = false;
        if (speakerReady)
            speakerInitTimer.start();
    }
    onSpeakerValueChanged: {
        if (activeSpeakerInit)
            showOsd("volume");
    }
}
