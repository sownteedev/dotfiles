import "../../"
import "../../components"
import "../../service"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications

PanelWindow {
    // Starts false for entry transition

    id: notifWindow

    readonly property bool isNotificationScreen: Quickshell.screens.length > 0 && (WorkspaceService.focusedOutputName !== "" ? screen && screen.name === WorkspaceService.focusedOutputName : screen === Quickshell.screens[0])
    readonly property int maxVisiblePopups: screen && screen.height < 800 ? Math.min(2, Config.notificationMaxVisible) : Config.notificationMaxVisible
    property var pendingUpdates: ({})
    readonly property bool popupAtBottom: Config.notificationPosition === "bottom-right"
    readonly property bool popupAtRight: Config.notificationPosition === "top-right" || Config.notificationPosition === "bottom-right"
    readonly property bool popupFromTop: Config.notificationPosition === "top"
    readonly property real popupMaximumWidth: screen ? Responsive.fit(600, screen.width - 40, 260) : 600
    readonly property real popupMinimumWidth: Math.min(380, popupMaximumWidth)
    readonly property bool popupsSuppressed: QuickSettingsService.effectiveDndActive || StateManager.sessionLocked || (!Config.notificationShowInFullscreen && ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.fullscreen)
    property real retainedStackHeight: 0

    // Track active timer objects by notification ID
    property var timersMap: ({})

    function appMatchesList(appName, rawList) {
        var expected = String(appName || "").trim().toLowerCase();
        if (expected === "")
            return false;
        var entries = String(rawList || "").split(",");
        for (var i = 0; i < entries.length; ++i) {
            var entry = entries[i].trim().toLowerCase();
            if (entry !== "" && (expected === entry || expected.indexOf(entry) !== -1))
                return true;
        }
        return false;
    }
    function closeAllPopups() {
        var transientNotifications = [];
        for (var i = 0; i < notifModel.count; ++i) {
            var nid = notifModel.get(i).nid;
            var nativeNotification = notifModel.get(i).rawNotification;
            stopNotifTimer(nid);
            notifModel.setProperty(i, "active", false);
            if (nativeNotification && nativeNotification.transient)
                transientNotifications.push(nativeNotification);
        }
        for (var nativeIndex = 0; nativeIndex < transientNotifications.length; nativeIndex++) {
            try {
                transientNotifications[nativeIndex].expire();
            } catch (error) {
                console.log("[Notification] Transient DND object already closed:", error);
            }
        }
    }

    // Auto-dismiss or close trigger (just closes popup visually)
    function closeNotif(nid) {
        stopNotifTimer(nid);
        triggerCloseAnimation(nid);
    }
    function connectNotificationUpdates(notification) {
        var schedule = function () {
            notifWindow.scheduleNotificationUpdate(notification);
        };
        notification.appNameChanged.connect(schedule);
        notification.appIconChanged.connect(schedule);
        notification.summaryChanged.connect(schedule);
        notification.bodyChanged.connect(schedule);
        notification.imageChanged.connect(schedule);
        notification.urgencyChanged.connect(schedule);
        notification.actionsChanged.connect(schedule);
        notification.expireTimeoutChanged.connect(schedule);
        notification.transientChanged.connect(schedule);
    }

    // Step 2: Remove from model immediately after animation finishes
    function handleCloseImmediate(nid) {
        console.log("[Notification] Closing/Removing notification ID (Animation Finished):", nid);
        for (var i = 0; i < notifModel.count; i++) {
            if (notifModel.get(i).nid === nid) {
                removePopupAt(i);
                break;
            }
        }
    }

    // Handle incoming notifications
    function handleNotify(notification) {
        if (appMatchesList(notification.appName, Config.notificationBlockedApps))
            return;
        var index = -1;
        for (var i = 0; i < notifModel.count; i++) {
            if (notifModel.get(i).nid === notification.id) {
                index = i;
                break;
            }
        }
        var isCritical = notification.urgency === 2; // 2 is Critical urgency in Quickshell
        var notifData = {
            "nid": notification.id,
            "appName": notification.appName || "",
            "appIcon": notification.appIcon || "",
            "summary": notification.summary || "",
            "body": notification.body || "",
            "image": notification.image || "",
            "isCritical": isCritical,
            "revision": 0,
            "showActions": false,
            "active": false,
            "rawNotification": notification
        };
        if (index !== -1) {
            console.log("[Notification] Updating notification ID:", notification.id);
            // Preserving the active state during updates
            notifData.active = notifModel.get(index).active;
            notifModel.set(index, notifData);
            resetNotifTimer(notification.id);
        } else {
            console.log("[Notification] Adding notification ID:", notification.id);
            if (notifWindow.popupAtBottom)
                notifModel.insert(0, notifData);
            else
                notifModel.append(notifData);
            // Connect to native closed signal to run exit animation automatically
            notification.closed.connect(function () {
                console.log("[Notification] Received closed signal for ID:", notification.id);
                stopNotifTimer(notification.id);
                triggerCloseAnimation(notification.id);
            });
            connectNotificationUpdates(notification);
            // Manage auto-dismiss timeout using pre-compiled Timer Component
            if (shouldAutoExpire(notification, isCritical)) {
                var timeout = notificationTimeout(notification);
                var timer = notifTimerComponent.createObject(notifWindow, {
                    "interval": timeout,
                    "nid": notification.id,
                    "notif": notification
                });
                timersMap[notification.id] = timer;
                timer.start();
            }
            trimPopupStack();
        }
    }
    function isManagedScreenshotNotification(notification) {
        var matchingSummary = String(notification.summary || "").toLowerCase().indexOf("screenshot captured") !== -1;
        var recentCapture = CaptureService.screenshotCapturedAt > 0 && Date.now() - CaptureService.screenshotCapturedAt < 10000;
        return matchingSummary && (CaptureService.screenshotBusy || recentCapture);
    }
    function notificationTimeout(notification) {
        return notification && notification.expireTimeout > 0 ? notification.expireTimeout : Config.notificationPopupDuration;
    }
    function popupBlurTarget(index) {
        if (!Config.shellBlurNotificationEnabled || index < 0 || index >= notifModel.count)
            return null;
        var delegateItem = notificationRepeater.itemAt(index);
        return delegateItem ? delegateItem.blurTarget : null;
    }
    function removePopupAt(index) {
        if (index < 0 || index >= notifModel.count)
            return;

        if (notifModel.count > 1) {
            // Keep the layer surface stable while the remaining cards slide into place.
            // Resizing the PanelWindow during reflow makes multi-popup stacks stutter.
            retainedStackHeight = Math.max(retainedStackHeight, layout.implicitHeight);
            stackHeightReleaseTimer.restart();
        } else {
            stackHeightReleaseTimer.stop();
            retainedStackHeight = 0;
        }

        var nid = notifModel.get(index).nid;
        if (timersMap[nid]) {
            timersMap[nid].destroy();
            delete timersMap[nid];
        }
        notifModel.remove(index);
    }

    // Reset notification timer
    function resetNotifTimer(nid) {
        var isCrit = false;
        var notifObj = null;
        for (var i = 0; i < notifModel.count; i++) {
            if (notifModel.get(i).nid === nid) {
                isCrit = notifModel.get(i).isCritical;
                notifObj = notifModel.get(i).rawNotification;
                break;
            }
        }
        if (!shouldAutoExpire(notifObj, isCrit)) {
            if (timersMap[nid]) {
                timersMap[nid].destroy();
                delete timersMap[nid];
            }
            return;
        }

        if (!timersMap[nid]) {
            timersMap[nid] = notifTimerComponent.createObject(notifWindow, {
                "nid": nid,
                "notif": notifObj
            });
        }
        timersMap[nid].stop();
        timersMap[nid].interval = notificationTimeout(notifObj);
        timersMap[nid].start();
    }

    // Resume notification timer with remaining progress
    function resumeNotifTimer(nid, remainingProgress, notifObj) {
        if (timersMap[nid]) {
            timersMap[nid].stop();
            var timeout = (notifObj && notifObj.expireTimeout > 0) ? notifObj.expireTimeout : Config.notificationPopupDuration;
            timersMap[nid].interval = Math.max(50, timeout * remainingProgress);
            timersMap[nid].start();
        }
    }
    function scheduleNotificationUpdate(notification) {
        if (!notification)
            return;
        var updates = Object.assign({}, pendingUpdates);
        updates[notification.id] = notification;
        pendingUpdates = updates;
        Qt.callLater(function () {
            if (!notifWindow.pendingUpdates[notification.id])
                return;
            var queued = Object.assign({}, notifWindow.pendingUpdates);
            delete queued[notification.id];
            notifWindow.pendingUpdates = queued;
            notifWindow.syncNotification(notification);
        });
    }
    function shouldAutoExpire(notification, isCritical) {
        if (!notification || notification.expireTimeout === 0)
            return false;
        return notification.expireTimeout > 0 || !isCritical;
    }

    // Timer management
    function stopNotifTimer(nid) {
        if (timersMap[nid])
            timersMap[nid].stop();
    }
    function syncNotification(notification) {
        var index = -1;
        for (var i = 0; i < notifModel.count; i++) {
            if (notifModel.get(i).nid === notification.id) {
                index = i;
                break;
            }
        }
        if (index < 0)
            return;

        var oldRevision = notifModel.get(index).revision || 0;
        notifModel.setProperty(index, "appName", notification.appName || "");
        notifModel.setProperty(index, "appIcon", notification.appIcon || "");
        notifModel.setProperty(index, "summary", notification.summary || "");
        notifModel.setProperty(index, "body", notification.body || "");
        notifModel.setProperty(index, "image", notification.image || "");
        notifModel.setProperty(index, "isCritical", notification.urgency === 2);
        notifModel.setProperty(index, "revision", oldRevision + 1);
        resetNotifTimer(notification.id);
    }

    // Step 1: Trigger exit animation
    function triggerCloseAnimation(nid) {
        for (var i = 0; i < notifModel.count; i++) {
            if (notifModel.get(i).nid === nid) {
                notifModel.setProperty(i, "active", false);
                break;
            }
        }
    }
    function trimPopupStack() {
        while (notifModel.count > maxVisiblePopups) {
            // Prefer keeping critical notifications visible. Everything removed
            // here remains available in NotificationHistory.
            var removeIndex = -1;
            var startIndex = notifWindow.popupAtBottom ? notifModel.count - 1 : 0;
            var endIndex = notifWindow.popupAtBottom ? -1 : notifModel.count;
            var step = notifWindow.popupAtBottom ? -1 : 1;
            for (var i = startIndex; i !== endIndex; i += step) {
                if (!notifModel.get(i).isCritical) {
                    removeIndex = i;
                    break;
                }
            }
            var finalIndex = removeIndex >= 0 ? removeIndex : startIndex;
            var removedNotification = notifModel.get(finalIndex).rawNotification;
            removePopupAt(finalIndex);
            if (removedNotification && removedNotification.transient) {
                try {
                    removedNotification.expire();
                } catch (error) {
                    console.log("[Notification] Trimmed transient notification already closed:", error);
                }
            }
        }
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notification-popup"
    anchors.bottom: popupAtBottom
    anchors.left: false
    anchors.right: popupAtRight

    // Bottom stacks use a vertically stable surface so the compositor does not
    // move the entire popup window whenever the stack grows or shrinks.
    anchors.top: true
    color: "transparent"
    exclusiveZone: 0 // Float, do not reserve space or push windows

    focusable: false
    implicitHeight: visible ? Math.max(layout.implicitHeight, retainedStackHeight) + 30 : 0
    // Dynamically sized window wrapper to adapt to layout content
    implicitWidth: layout.implicitWidth + 30
    margins.bottom: anchors.bottom ? 15 : 0
    margins.right: anchors.right ? 15 : 0
    margins.top: anchors.top ? 15 : 0
    visible: notifModel.count > 0

    BackgroundEffect.blurRegion: Region {
        Region {
            item: notifWindow.popupBlurTarget(0)
            radius: item ? item.radius : 0
        }
        Region {
            item: notifWindow.popupBlurTarget(1)
            radius: item ? item.radius : 0
        }
        Region {
            item: notifWindow.popupBlurTarget(2)
            radius: item ? item.radius : 0
        }
        Region {
            item: notifWindow.popupBlurTarget(3)
            radius: item ? item.radius : 0
        }
        Region {
            item: notifWindow.popupBlurTarget(4)
            radius: item ? item.radius : 0
        }
        Region {
            item: notifWindow.popupBlurTarget(5)
            radius: item ? item.radius : 0
        }
    }
    mask: Region {
        item: layout
    }

    onMaxVisiblePopupsChanged: Qt.callLater(function () {
        notifWindow.trimPopupStack();
    })
    onPopupsSuppressedChanged: {
        if (popupsSuppressed)
            closeAllPopups();
    }

    // Connect to global NotificationManager
    Connections {
        function onNotification(notification) {
            if (notifWindow.popupsSuppressed)
                return;

            // Screenshot notifications have their own Windows-style toast
            // anchored to the bottom-right corner.
            if (isManagedScreenshotNotification(notification))
                return;

            // Do not show popups in DND mode
            handleNotify(notification);
        }

        enabled: notifWindow.isNotificationScreen
        target: globalNotificationManager
    }
    Connections {
        function onEffectiveDndActiveChanged() {
            if (QuickSettingsService.effectiveDndActive)
                notifWindow.closeAllPopups();
        }

        target: QuickSettingsService
    }
    Component {
        id: entryDelayTimerComponent

        Timer {
            property var targetModel: null

            repeat: false

            onTriggered: {
                if (targetModel)
                    targetModel.active = true;

                destroy();
            }
        }
    }

    // Component template for auto-dismiss timers
    Component {
        id: notifTimerComponent

        Timer {
            property int nid
            property var notif

            repeat: false

            onTriggered: {
                console.log("[Notification] Timer triggered for ID:", nid);
                triggerCloseAnimation(nid);
                // History already owns a lightweight snapshot. Once a normal
                // notification without actions expires, release its native
                // object and any image-provider resources it retains.
                if (notif && (notif.transient || !notif.actions || notif.actions.length === 0))
                    notif.expire();
            }
        }
    }

    // Notification list model
    ListModel {
        id: notifModel
    }
    Timer {
        id: stackHeightReleaseTimer

        interval: 230

        onTriggered: notifWindow.retainedStackHeight = 0
    }
    // UI Layout (Stacked list)
    Column {
        id: layout

        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10
        y: notifWindow.popupAtBottom ? parent.height - implicitHeight - 15 : 15

        move: Transition {
            NumberAnimation {
                duration: Config.animationDuration(notifWindow.retainedStackHeight > 0 ? 220 : 0)
                easing.type: Easing.OutCubic
                properties: "y"
            }
        }
        Behavior on y {
            enabled: notifWindow.popupAtBottom && notifWindow.retainedStackHeight > 0

            NumberAnimation {
                duration: Config.animationDuration(220)
                easing.type: Easing.OutCubic
            }
        }

        Repeater {
            id: notificationRepeater

            model: notifModel

            delegate: Component {
                id: notifDelegate

                Item {
                    id: delegateWrapper

                    property var actionsList: notifObj ? notifObj.actions : []
                    property bool active: model.active
                    property string appIcon: model.appIcon
                    property string appName: model.appName
                    readonly property Item blurTarget: container
                    property string body: model.body
                    property bool completed: false
                    property string image: model.image
                    property bool isCritical: model.isCritical
                    readonly property real naturalTextWidth: Math.max(summaryText.implicitWidth, bodyText.implicitWidth, 100 + delegateWrapper.actionsList.length * 115)

                    // Cache model properties on wrapper to avoid name conflicts in nested repeaters
                    property int nid: model.nid
                    property var notifObj: model.rawNotification
                    // Countdown progress bar properties and animation
                    property real progress: 1
                    property int revision: model.revision
                    property bool showActions: model.showActions
                    property string summary: model.summary

                    height: container.height
                    width: container.width

                    Component.onCompleted: {
                        var isFirst = notifModel.count <= 1;
                        var delay = isFirst ? 0 : 35;
                        var t = entryDelayTimerComponent.createObject(delegateWrapper, {
                            "interval": delay,
                            "targetModel": model
                        });
                        t.start();
                        Qt.callLater(function () {
                            completed = true;
                        });
                    }
                    onActionsListChanged: {
                        if (containerHover.hovered && actionsList.length > 0)
                            showActions = true;
                    }
                    onActiveChanged: {
                        if (!active) {
                            popupDismissTimer.restart();
                        } else {
                            popupDismissTimer.stop();
                        }
                    }
                    onNidChanged: {
                        container.swipeOffset = 0;
                    }
                    onRevisionChanged: {
                        progress = 1;
                        if (active && shouldAutoExpire(notifObj, isCritical))
                            progressAnim.restart();
                        else
                            progressAnim.stop();
                    }

                    Timer {
                        id: popupDismissTimer

                        interval: 155

                        onTriggered: {
                            handleCloseImmediate(delegateWrapper.nid);
                        }
                    }
                    NumberAnimation {
                        id: progressAnim

                        duration: {
                            var timeout = (delegateWrapper.notifObj && delegateWrapper.notifObj.expireTimeout > 0) ? delegateWrapper.notifObj.expireTimeout : Config.notificationPopupDuration;
                            return timeout;
                        }
                        from: 1
                        property: "progress"
                        running: {
                            if (delegateWrapper.isCritical)
                                return false;

                            if (delegateWrapper.notifObj && delegateWrapper.notifObj.expireTimeout === 0)
                                return false;

                            // Start running immediately when active to prevent any visual delay
                            return delegateWrapper.active;
                        }
                        target: delegateWrapper
                        to: 0
                    }
                    // Loop-free natural width calculations (bypasses circular dependency between container and layout)

                    // Main Container with Auto-fitting Width and Stable Heights!
                    ShellShadow {
                        active: container.opacity > 0
                        componentShadow: true
                        cornerRadius: container.radius
                        opacity: container.opacity
                        target: container

                        transform: Translate {
                            x: container.swipeOffset + container.xOffset
                        }
                    }
                    Rectangle {
                        id: container

                        readonly property real collapsedHeight: mainLayout.implicitHeight - actionsBlock.implicitHeight - 12 + 30
                        property real contentReveal: 0

                        // Loop-free stable height values (calculated from static mainLayout height)
                        readonly property real expandedHeight: mainLayout.implicitHeight + 30
                        // Swipe-right-to-dismiss
                        property real swipeOffset: 0
                        // Keep the travel short so the popup feels attached to the bar.
                        property real xOffset: notifWindow.popupAtRight ? 18 : 0
                        property real yOffset: notifWindow.popupFromTop ? -18 : 0

                        anchors.horizontalCenter: parent.horizontalCenter
                        border.color: delegateWrapper.isCritical ? Config.alpha(Config.md3.error, 0.72) : Config.alpha(Config.md3.outline_variant, 0.26)
                        border.width: 1
                        clip: true // Clean rounded clipping of actions panel
                        color: Config.shellBlurNotificationEnabled ? Config.alpha(Config.md3.background, Config.lightTheme ? Config.shellBlurPanelOpacityLight : Config.shellBlurPanelOpacityDark) : Config.md3.background
                        height: delegateWrapper.showActions ? expandedHeight : collapsedHeight
                        opacity: 0
                        radius: delegateWrapper.showActions ? 45 : height / 2
                        width: Math.min(notifWindow.popupMaximumWidth, Math.max(notifWindow.popupMinimumWidth, delegateWrapper.naturalTextWidth + 145))
                        y: yOffset

                        // Smooth container height changes (bypasses visual stutter by animating background at layout level)
                        Behavior on height {
                            enabled: delegateWrapper.completed

                            NumberAnimation {
                                duration: Config.animationDuration(250)
                                easing.type: Easing.OutQuad
                            }
                        }

                        // Smoothly animate radius changes during hover transition
                        Behavior on radius {
                            enabled: delegateWrapper.completed

                            NumberAnimation {
                                duration: Config.animationDuration(250)
                                easing.type: Easing.OutQuad
                            }
                        }
                        // Transition States matching OSD style
                        states: [
                            State {
                                name: "visible"
                                when: delegateWrapper.active

                                PropertyChanges {
                                    contentReveal: 1
                                    opacity: 1
                                    target: container
                                    xOffset: 0
                                    yOffset: 0
                                }
                            },
                            State {
                                name: "hidden"
                                when: !delegateWrapper.active

                                PropertyChanges {
                                    contentReveal: 0
                                    opacity: 0
                                    target: container
                                    xOffset: notifWindow.popupAtRight ? 14 : 0
                                    yOffset: notifWindow.popupFromTop ? -14 : 0
                                }
                            }
                        ]
                        Behavior on swipeOffset {
                            enabled: !swipeDrag.active

                            NumberAnimation {
                                duration: Config.animationDuration(150)
                                easing.type: Easing.OutCubic
                            }
                        }
                        transform: Translate {
                            x: container.swipeOffset + container.xOffset
                        }
                        // Animate compositor-friendly properties only. Scaling the clipped
                        // card forced the text, rounded mask, and progress canvas to redraw.
                        transitions: [
                            Transition {
                                from: "hidden"
                                to: "visible"

                                ParallelAnimation {
                                    NumberAnimation {
                                        duration: Config.animationDuration(160)
                                        easing.type: Easing.OutCubic
                                        property: "opacity"
                                        target: container
                                    }
                                    NumberAnimation {
                                        duration: Config.animationDuration(220)
                                        easing.type: Easing.OutCubic
                                        properties: "xOffset,yOffset"
                                        target: container
                                    }
                                    SequentialAnimation {
                                        PauseAnimation {
                                            duration: Config.animationDuration(30)
                                        }
                                        NumberAnimation {
                                            duration: Config.animationDuration(180)
                                            easing.type: Easing.OutCubic
                                            property: "contentReveal"
                                            target: container
                                        }
                                    }
                                }
                            },
                            Transition {
                                from: "visible"
                                to: "hidden"

                                ParallelAnimation {
                                    NumberAnimation {
                                        duration: Config.animationDuration(120)
                                        easing.type: Easing.InCubic
                                        property: "opacity"
                                        target: container
                                    }
                                    NumberAnimation {
                                        duration: Config.animationDuration(150)
                                        easing.type: Easing.InCubic
                                        properties: "xOffset,yOffset"
                                        target: container
                                    }
                                    NumberAnimation {
                                        duration: Config.animationDuration(90)
                                        easing.type: Easing.InQuad
                                        property: "contentReveal"
                                        target: container
                                    }
                                }
                            }
                        ]

                        // Use HoverHandler to prevent nested MouseArea hover conflicts (flickering)
                        HoverHandler {
                            id: containerHover

                            onHoveredChanged: {
                                if (hovered) {
                                    stopNotifTimer(delegateWrapper.nid);
                                    if (progressAnim.running)
                                        progressAnim.pause();

                                    if (delegateWrapper.actionsList.length > 0)
                                        delegateWrapper.showActions = true;
                                } else {
                                    resumeNotifTimer(delegateWrapper.nid, delegateWrapper.progress, delegateWrapper.notifObj);
                                    if (progressAnim.paused)
                                        progressAnim.resume();

                                    delegateWrapper.showActions = false;
                                }
                            }
                        }

                        // Main vertical column layout (anchored to top/left/right so height remains static during container animation, preventing text layout recalculations)
                        ColumnLayout {
                            id: mainLayout

                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 15
                            anchors.left: parent.left
                            anchors.leftMargin: 20
                            anchors.right: parent.right
                            anchors.rightMargin: 20
                            anchors.top: parent.top
                            anchors.topMargin: 15
                            spacing: 12

                            // Top Row: Left Icon + Right Text Column (Perfectly centered vertically!)
                            RowLayout {
                                id: innerLayout

                                Layout.fillWidth: true
                                opacity: 0.55 + 0.45 * container.contentReveal
                                spacing: 20

                                NotificationIcon {
                                    id: popupNotificationIcon

                                    Layout.alignment: Qt.AlignVCenter
                                    appIcon: delegateWrapper.appIcon
                                    appName: delegateWrapper.appName
                                    asynchronous: true
                                    backgroundColor: delegateWrapper.isCritical ? Config.md3.error_container : Config.md3.surface_container_high
                                    cacheImage: false
                                    height: 55
                                    iconSize: hasProvidedIcon ? 40 : 25
                                    implicitHeight: 55
                                    implicitWidth: 55
                                    notificationImage: delegateWrapper.image
                                    radius: hasProvidedIcon ? 14 : width / 2
                                    sourceSizeScale: 2
                                    tintAllIcons: true
                                    tintColor: delegateWrapper.isCritical ? Config.md3.on_error_container : Config.md3.on_surface
                                    width: 55
                                }

                                // Text Section (Right) - Vertically Centered with the Left Icon!
                                ColumnLayout {
                                    id: textColumn

                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        id: summaryText

                                        Layout.fillWidth: true
                                        // Bound max width to wrap/elide correctly as container sizes dynamically
                                        Layout.maximumWidth: container.width - 145
                                        color: Config.md3.on_surface
                                        elide: Text.ElideRight
                                        font.family: Config.fontName
                                        font.pixelSize: 16
                                        font.weight: Font.DemiBold
                                        maximumLineCount: 1
                                        text: delegateWrapper.summary
                                        textFormat: Text.PlainText
                                    }

                                    // Body text
                                    Text {
                                        id: bodyText

                                        Layout.fillWidth: true
                                        Layout.maximumWidth: container.width - 145
                                        color: Config.md3.on_surface_variant
                                        elide: Text.ElideRight
                                        font.family: Config.fontName
                                        font.pixelSize: 15
                                        font.weight: Font.Medium
                                        maximumLineCount: 3
                                        text: delegateWrapper.body
                                        textFormat: Text.PlainText
                                        visible: delegateWrapper.body !== ""
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }

                            // Bottom Section: Actions block (reveals on hover) - Positioned below the Row layout
                            ColumnLayout {
                                id: actionsBlock

                                Layout.fillWidth: true
                                enabled: delegateWrapper.showActions
                                opacity: delegateWrapper.showActions ? 1 : 0
                                spacing: 12
                                visible: true // Always visible in layout to stabilize implicitHeight calculations

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Config.animationDuration(150)
                                    }
                                }

                                // Separator line
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    color: Config.alpha(Config.md3.on_surface, 0.08)
                                }

                                // Full-width buttons row
                                RowLayout {
                                    id: buttonsFlow

                                    Layout.fillWidth: true
                                    spacing: 8

                                    // DBus custom actions — neutral subtle style
                                    Repeater {
                                        model: delegateWrapper.actionsList

                                        delegate: NotificationActionButton {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 40
                                            action: modelData
                                            cornerRadius: 18
                                            hoverBorderColor: modelData.text === "Edit" ? Config.alpha(Config.md3.tertiary, 0.66) : modelData.text === "Delete" ? Config.alpha(Config.md3.error, 0.46) : Config.alpha(Config.md3.on_surface, 0.22)
                                            hoverColor: modelData.text === "Edit" ? Config.alpha(Config.md3.tertiary, 0.42) : modelData.text === "Delete" ? Config.alpha(Config.md3.error, 0.22) : Config.alpha(Config.md3.on_surface, 0.15)
                                            labelPixelSize: 13
                                            labelWeight: Font.DemiBold
                                            normalBorderColor: modelData.text === "Edit" ? Config.alpha(Config.md3.tertiary, 0.48) : modelData.text === "Delete" ? Config.alpha(Config.md3.error, 0.3) : Config.alpha(Config.md3.on_surface, 0.12)
                                            normalColor: modelData.text === "Edit" ? Config.alpha(Config.md3.tertiary, 0.3) : modelData.text === "Delete" ? Config.alpha(Config.md3.error, 0.14) : Config.alpha(Config.md3.on_surface, 0.09)

                                            onClicked: {
                                                if (modelData) {
                                                    // A native action can close the notification
                                                    // synchronously and destroy this delegate.
                                                    var notificationId = delegateWrapper.nid;
                                                    var selectedAction = modelData;
                                                    selectedAction.invoke();
                                                    NotificationHistory.dismiss(notificationId);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Swipe-right-to-dismiss gesture
                        DragHandler {
                            id: swipeDrag

                            target: null
                            xAxis.enabled: true
                            xAxis.minimum: 0
                            yAxis.enabled: false

                            onActiveChanged: {
                                if (!active) {
                                    if (container.swipeOffset > container.width * 0.38) {
                                        // Swipe far enough → slide off then dismiss
                                        container.swipeOffset = container.width + 80;
                                        swipeDismissTimer.start();
                                    } else {
                                        // Not far enough → snap back
                                        container.swipeOffset = 0;
                                    }
                                }
                            }
                            onTranslationChanged: {
                                container.swipeOffset = Math.max(0, translation.x);
                            }
                        }
                        Timer {
                            id: swipeDismissTimer

                            interval: 160

                            onTriggered: {
                                NotificationHistory.dismiss(delegateWrapper.nid);
                                handleCloseImmediate(delegateWrapper.nid);
                            }
                        }

                        // Symmetrical border progress. Follow NumberAnimation
                        // frame-for-frame; the old 80 ms sampler limited this
                        // border to 12.5 FPS and made the countdown visibly step.
                        Canvas {
                            id: borderProgressCanvas

                            readonly property real halfPathLength: Math.max(1, width - lineThickness - 2 * pathRadius + height - lineThickness - 2 * pathRadius + Math.PI * pathRadius)
                            readonly property real lineThickness: 1
                            property real paintedProgress: delegateWrapper.progress
                            readonly property real pathRadius: Math.max(0, Math.min(container.radius, height / 2) - lineThickness / 2)
                            readonly property color progressColor: Config.alpha(delegateWrapper.isCritical ? Config.md3.error : Config.md3.primary, 0.08)

                            anchors.fill: parent
                            enabled: false
                            renderStrategy: Canvas.Immediate
                            visible: progressAnim.running || progressAnim.paused

                            onHeightChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                var progress = Math.max(0, Math.min(1, paintedProgress));
                                if (progress <= 0)
                                    return;

                                var t = lineThickness;
                                var r = pathRadius;
                                var startX = width / 2;
                                var visibleLength = halfPathLength * progress;
                                ctx.lineWidth = t;
                                ctx.lineCap = "butt";
                                ctx.strokeStyle = progressColor;
                                ctx.setLineDash([visibleLength, halfPathLength]);
                                ctx.beginPath();
                                ctx.moveTo(startX, t / 2);
                                ctx.arcTo(width - t / 2, t / 2, width - t / 2, height - t / 2, r);
                                ctx.arcTo(width - t / 2, height - t / 2, startX, height - t / 2, r);
                                ctx.lineTo(startX, height - t / 2);
                                ctx.stroke();
                                ctx.beginPath();
                                ctx.moveTo(startX, t / 2);
                                ctx.arcTo(t / 2, t / 2, t / 2, height - t / 2, r);
                                ctx.arcTo(t / 2, height - t / 2, startX, height - t / 2, r);
                                ctx.lineTo(startX, height - t / 2);
                                ctx.stroke();
                            }
                            onPaintedProgressChanged: requestPaint()
                            onPathRadiusChanged: requestPaint()
                            onVisibleChanged: {
                                if (visible)
                                    requestPaint();
                            }
                            onWidthChanged: requestPaint()
                        }
                    }
                }
            }
        }
    }
}
