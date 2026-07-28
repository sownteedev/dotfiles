import "../../"
import "../../components"
import "../../service"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Widgets

PanelWindow {
    // Starts false for entry transition
    // Avoid uploading Niri's full-resolution screenshot just to draw a
    // 55 px popup icon. Edit/Open still use CaptureService's file path.

    id: notifWindow

    readonly property int maxVisiblePopups: 3

    // Track active timer objects by notification ID
    property var timersMap: ({})

    function closeAllPopups() {
        for (var i = 0; i < notifModel.count; ++i) {
            var nid = notifModel.get(i).nid;
            stopNotifTimer(nid);
            notifModel.setProperty(i, "active", false);
        }
    }

    // Auto-dismiss or close trigger (just closes popup visually)
    function closeNotif(nid) {
        stopNotifTimer(nid);
        triggerCloseAnimation(nid);
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
            "receivedAt": Date.now(),
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
            notifModel.append(notifData);
            // Connect to native closed signal to run exit animation automatically
            notification.closed.connect(function () {
                console.log("[Notification] Received closed signal for ID:", notification.id);
                stopNotifTimer(notification.id);
                triggerCloseAnimation(notification.id);
            });
            // Manage auto-dismiss timeout using pre-compiled Timer Component
            // Only auto-dismiss if expireTimeout > 0, or if it's not persistent (expireTimeout != 0) and not critical
            if (notification.expireTimeout > 0 || (notification.expireTimeout !== 0 && !isCritical)) {
                var timeout = notification.expireTimeout > 0 ? notification.expireTimeout : 5000;
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
    function removePopupAt(index) {
        if (index < 0 || index >= notifModel.count)
            return;

        var nid = notifModel.get(index).nid;
        if (timersMap[nid]) {
            timersMap[nid].destroy();
            delete timersMap[nid];
        }
        notifModel.remove(index);
    }

    // Reset notification timer
    function resetNotifTimer(nid) {
        if (timersMap[nid]) {
            timersMap[nid].stop();
            timersMap[nid].start();
        } else {
            // Re-create timer if it was cleared
            var isCrit = false;
            var notifObj = null;
            for (var i = 0; i < notifModel.count; i++) {
                if (notifModel.get(i).nid === nid) {
                    isCrit = notifModel.get(i).isCritical;
                    notifObj = notifModel.get(i).rawNotification;
                    break;
                }
            }
            if (!isCrit) {
                var timeout = (notifObj && notifObj.expireTimeout > 0) ? notifObj.expireTimeout : 5000;
                var timer = notifTimerComponent.createObject(notifWindow, {
                    "interval": timeout,
                    "nid": nid,
                    "notif": notifObj
                });
                timersMap[nid] = timer;
                timer.start();
            }
        }
    }

    // Resume notification timer with remaining progress
    function resumeNotifTimer(nid, remainingProgress, notifObj) {
        if (timersMap[nid]) {
            timersMap[nid].stop();
            var timeout = (notifObj && notifObj.expireTimeout > 0) ? notifObj.expireTimeout : 5000;
            timersMap[nid].interval = Math.max(50, timeout * remainingProgress);
            timersMap[nid].start();
        }
    }

    // Timer management
    function stopNotifTimer(nid) {
        if (timersMap[nid])
            timersMap[nid].stop();
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
            for (var i = 0; i < notifModel.count; i++) {
                if (!notifModel.get(i).isCritical) {
                    removeIndex = i;
                    break;
                }
            }
            removePopupAt(removeIndex >= 0 ? removeIndex : 0);
        }
    }

    aboveWindows: true
    anchors.bottom: false
    anchors.left: false
    anchors.right: false

    // Position: top center of screen
    anchors.top: true
    color: "transparent"
    exclusiveZone: 0 // Float, do not reserve space or push windows

    focusable: false
    implicitHeight: visible ? layout.implicitHeight + 30 : 0
    // Dynamically sized window wrapper to adapt to layout content
    implicitWidth: layout.implicitWidth + 30
    visible: notifModel.count > 0

    // Connect to global NotificationManager
    Connections {
        function onNotification(notification) {
            if (QuickSettingsService.dndActive)
                return;

            // Do not show popups in DND mode
            handleNotify(notification);
        }

        target: globalNotificationManager
    }
    Connections {
        function onDndActiveChanged() {
            if (QuickSettingsService.dndActive)
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
                if (notif && (!notif.actions || notif.actions.length === 0))
                    notif.dismiss();
            }
        }
    }

    // Notification list model
    ListModel {
        id: notifModel
    }

    // UI Layout (Stacked list)
    Column {
        id: layout

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 15
        spacing: 10

        Repeater {
            model: notifModel

            delegate: Component {
                id: notifDelegate

                Item {
                    id: delegateWrapper

                    property var actionsList: {
                        if (hasScreenshotActions)
                            return [
                                {
                                    "text": "Edit",
                                    "invoke": function () {
                                        CaptureService.openScreenshotEditor(notifWindow.screen ? notifWindow.screen.name : "");
                                    }
                                },
                                {
                                    "text": "Open",
                                    "invoke": function () {
                                        CaptureService.openScreenshot();
                                    }
                                },
                                {
                                    "text": "Folder",
                                    "invoke": function () {
                                        CaptureService.openScreenshotFolder();
                                    }
                                },
                                {
                                    "text": "Delete",
                                    "invoke": function () {
                                        CaptureService.trashScreenshot();
                                    }
                                }
                            ];

                        return notifObj ? notifObj.actions : [];
                    }
                    property bool active: model.active
                    property string appIcon: model.appIcon
                    property string appName: model.appName
                    property string body: model.body
                    property bool completed: false
                    readonly property bool hasScreenshotActions: isScreenshotNotification && CaptureService.screenshotPath !== "" && Math.abs(CaptureService.screenshotCapturedAt - receivedAt) < 5000
                    property string image: model.image
                    property bool isCritical: model.isCritical
                    property bool isDismissing: false
                    readonly property bool isScreenshotNotification: summary.toLowerCase().indexOf("screenshot captured") !== -1
                    readonly property real naturalTextWidth: Math.max(summaryText.implicitWidth, bodyText.implicitWidth, 100 + delegateWrapper.actionsList.length * 115)

                    // Cache model properties on wrapper to avoid name conflicts in nested repeaters
                    property int nid: model.nid
                    property var notifObj: model.rawNotification
                    // Countdown progress bar properties and animation
                    property real progress: 1
                    property double receivedAt: model.receivedAt
                    property bool showActions: model.showActions
                    property string summary: model.summary

                    clip: true
                    height: isDismissing ? 0 : container.height
                    width: container.width

                    Behavior on height {
                        enabled: delegateWrapper.isDismissing

                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }

                    Component.onCompleted: {
                        var isFirst = notifModel.count <= 1;
                        var delay = isFirst ? 150 : 80;
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
                            popupCollapseTimer.start();
                        } else {
                            popupCollapseTimer.stop();
                            popupDismissTimer.stop();
                            isDismissing = false;
                        }
                    }
                    onNidChanged: {
                        isDismissing = false;
                        container.swipeOffset = 0;
                    }

                    Timer {
                        id: popupCollapseTimer

                        interval: 120

                        onTriggered: {
                            isDismissing = true;
                            popupDismissTimer.start();
                        }
                    }
                    Timer {
                        id: popupDismissTimer

                        interval: 120

                        onTriggered: {
                            handleCloseImmediate(delegateWrapper.nid);
                        }
                    }
                    NumberAnimation {
                        id: progressAnim

                        duration: {
                            var timeout = (delegateWrapper.notifObj && delegateWrapper.notifObj.expireTimeout > 0) ? delegateWrapper.notifObj.expireTimeout : 5000;
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
                    Rectangle {
                        id: container

                        readonly property real collapsedHeight: mainLayout.implicitHeight - actionsBlock.implicitHeight - 12 + 30

                        // Loop-free stable height values (calculated from static mainLayout height)
                        readonly property real expandedHeight: mainLayout.implicitHeight + 30
                        // Swipe-right-to-dismiss
                        property real swipeOffset: 0
                        // Smooth slide transition offsets
                        property real yOffset: -50

                        anchors.horizontalCenter: parent.horizontalCenter
                        border.color: delegateWrapper.isCritical ? Config.alpha(Config.md3.error, 0.8) : Config.alpha(Config.md3.surface_container_high, 0.8)
                        border.width: 1
                        clip: true // Clean rounded clipping of actions panel
                        color: Config.md3.background
                        height: delegateWrapper.showActions ? expandedHeight : collapsedHeight
                        opacity: 0
                        radius: delegateWrapper.showActions ? 45 : height / 2
                        // Width automatically adjusts to content, bounded between 380px and 600px
                        width: Math.min(600, Math.max(380, delegateWrapper.naturalTextWidth + 145))
                        y: yOffset

                        // Smooth container height changes (bypasses visual stutter by animating background at layout level)
                        Behavior on height {
                            enabled: delegateWrapper.completed

                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutQuad
                            }
                        }

                        // Smoothly animate radius changes during hover transition
                        Behavior on radius {
                            enabled: delegateWrapper.completed

                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutQuad
                            }
                        }
                        // Transition States matching OSD style
                        states: [
                            State {
                                name: "visible"
                                when: delegateWrapper.active

                                PropertyChanges {
                                    opacity: 1
                                    target: container
                                    yOffset: 0
                                }
                            },
                            State {
                                name: "hidden"
                                when: !delegateWrapper.active

                                PropertyChanges {
                                    opacity: 0
                                    target: container
                                    yOffset: -50
                                }
                            }
                        ]
                        Behavior on swipeOffset {
                            enabled: !swipeDrag.active

                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }
                        }
                        transform: Translate {
                            x: container.swipeOffset
                        }
                        // Smooth transitions: Springy slide down entry and fast slide up exit
                        transitions: [
                            Transition {
                                from: "hidden"
                                to: "visible"

                                ParallelAnimation {
                                    NumberAnimation {
                                        duration: 250
                                        easing.type: Easing.OutQuad
                                        properties: "opacity"
                                    }
                                    NumberAnimation {
                                        duration: 400
                                        easing.type: Easing.OutBack
                                        properties: "yOffset"
                                    }
                                }
                            },
                            Transition {
                                from: "visible"
                                to: "hidden"

                                ParallelAnimation {
                                    NumberAnimation {
                                        duration: 120
                                        easing.type: Easing.OutQuad
                                        properties: "opacity"
                                    }
                                    NumberAnimation {
                                        duration: 120
                                        easing.type: Easing.InQuad
                                        properties: "yOffset"
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
                                spacing: 20

                                NotificationIcon {
                                    id: popupNotificationIcon

                                    Layout.alignment: Qt.AlignVCenter
                                    appIcon: delegateWrapper.appIcon
                                    appName: delegateWrapper.appName
                                    asynchronous: true
                                    backgroundColor: Config.md3.surface_container
                                    cacheImage: false
                                    height: 55
                                    iconSize: hasProvidedIcon ? 40 : 25
                                    implicitHeight: 55
                                    implicitWidth: 55
                                    notificationImage: delegateWrapper.image
                                    radius: hasProvidedIcon ? 14 : width / 2
                                    sourceSizeScale: 2
                                    tintAllIcons: true
                                    tintColor: delegateWrapper.isCritical ? Config.alpha(Config.md3.error, 0.8) : Config.md3.on_surface
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
                                        text: delegateWrapper.summary
                                    }

                                    // Body text
                                    Text {
                                        id: bodyText

                                        Layout.fillWidth: true
                                        Layout.maximumWidth: container.width - 145
                                        color: Config.alpha(Config.md3.on_surface, 0.7)
                                        font.family: Config.fontName
                                        font.pixelSize: 15
                                        font.weight: Font.Medium
                                        text: delegateWrapper.body
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
                                        duration: 150
                                    }
                                }

                                // Separator line
                                Rectangle {
                                    Layout.fillWidth: true
                                    color: Config.alpha(Config.md3.on_surface, 0.08)
                                    height: 1
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
                                        swipeCollapseTimer.start();
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
                            id: swipeCollapseTimer

                            interval: 80

                            onTriggered: {
                                delegateWrapper.isDismissing = true;
                                swipeDismissTimer.start();
                            }
                        }
                        Timer {
                            id: swipeDismissTimer

                            interval: 180

                            onTriggered: handleCloseImmediate(delegateWrapper.nid)
                        }

                        // Symmetrical border progress. Painting is throttled and
                        // moved off the GUI thread; paused popups do no work.
                        Canvas {
                            id: borderProgressCanvas

                            readonly property real halfPathLength: Math.max(1, width - lineThickness - 2 * pathRadius + height - lineThickness - 2 * pathRadius + Math.PI * pathRadius)
                            readonly property real lineThickness: 1
                            property real paintedProgress: delegateWrapper.progress
                            readonly property real pathRadius: Math.max(0, Math.min(container.radius, height / 2) - lineThickness / 2)
                            readonly property color progressColor: Config.alpha(delegateWrapper.isCritical ? Config.md3.error : Config.md3.primary, 0.08)

                            anchors.fill: parent
                            enabled: false
                            renderStrategy: Canvas.Threaded
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
                            onPathRadiusChanged: requestPaint()
                            onVisibleChanged: {
                                if (visible) {
                                    paintedProgress = delegateWrapper.progress;
                                    requestPaint();
                                }
                            }
                            onWidthChanged: requestPaint()

                            Timer {
                                interval: 80
                                repeat: true
                                running: borderProgressCanvas.visible && progressAnim.running && !progressAnim.paused

                                onTriggered: {
                                    var nextProgress = delegateWrapper.progress;
                                    if (Math.abs(nextProgress - borderProgressCanvas.paintedProgress) < 0.002)
                                        return;

                                    borderProgressCanvas.paintedProgress = nextProgress;
                                    borderProgressCanvas.requestPaint();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
