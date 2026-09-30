import "../../../../" // for Config
import "../../../../service"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../../../../components"

Item {
    id: notificationPageRoot

    property bool clearAllAnimationActive: false
    property real currentTimeTick: Date.now()
    property var expandedGroups: ({})
    property var renderedCounts: ({})

    function formatRelativeTime(timestamp, tick) {
        if (!timestamp)
            return "now";
        var diff = Math.floor((tick - timestamp) / 1000);
        if (diff < 60)
            return "now";
        var diffMins = Math.floor(diff / 60);
        if (diffMins < 60)
            return diffMins + "m ago";
        var diffHours = Math.floor(diffMins / 60);
        if (diffHours < 24)
            return diffHours + "h ago";
        var date = new Date(timestamp);
        return date.toLocaleDateString(Qt.locale(), "MMM d");
    }
    function groupKey(appName) {
        return "$" + appName;
    }
    function isGroupExpanded(appName) {
        return expandedGroups[groupKey(appName)] === true;
    }
    function renderedCountFor(appName) {
        return renderedCounts[groupKey(appName)] || 12;
    }
    function setGroupExpanded(appName, expanded) {
        var state = Object.assign({}, expandedGroups);
        var key = groupKey(appName);
        if (expanded)
            state[key] = true;
        else
            delete state[key];
        expandedGroups = state;
    }
    function showMoreFor(appName) {
        var state = Object.assign({}, renderedCounts);
        var key = groupKey(appName);
        state[key] = (state[key] || 12) + 12;
        renderedCounts = state;
    }
    function syncGroups() {
        syncRows(groupModel, NotificationHistory.notificationGroups, "appName");
    }

    // Keep delegate identities across history snapshots, including unchanged icons/loaders.
    function syncRows(target, entries, keyRole) {
        var wanted = {};
        for (var i = 0; i < entries.length; ++i)
            wanted["$" + String(entries[i][keyRole])] = true;
        for (var oldIndex = target.count - 1; oldIndex >= 0; --oldIndex) {
            if (!wanted["$" + target.get(oldIndex).stableKey])
                target.remove(oldIndex);
        }
        for (var nextIndex = 0; nextIndex < entries.length; ++nextIndex) {
            var key = String(entries[nextIndex][keyRole]);
            var found = nextIndex;
            while (found < target.count && target.get(found).stableKey !== key)
                ++found;
            var payload = JSON.stringify(entries[nextIndex]);
            if (found === target.count) {
                target.insert(nextIndex, {
                    stableKey: key,
                    payload: payload
                });
            } else {
                if (found !== nextIndex)
                    target.move(found, nextIndex, 1);
                if (target.get(nextIndex).payload !== payload)
                    target.setProperty(nextIndex, "payload", payload);
            }
        }
    }
    function triggerClearAllAnimation() {
        var count = NotificationHistory.notificationGroups.length;
        if (count === 0)
            return;

        clearAllAnimationActive = true;

        // Cap the stagger so clearing a long history stays quick.
        var exactAnimationDuration = Config.animationDuration(Math.min(Math.max(0, count - 1), 7) * 55) + Config.animationDuration(Md3.motion.short3) + 10;

        // The singleton timer survives closing Control Right or switching tabs,
        // so the requested clear cannot be cancelled with the page Loader.
        NotificationHistory.clearAllAfter(exactAnimationDuration);
        clearAllTimer.interval = exactAnimationDuration;
        clearAllTimer.start();
    }

    anchors.fill: parent

    Component.onCompleted: syncGroups()

    ListModel {
        id: groupModel
    }
    Connections {
        function onNotificationGroupsChanged() {
            notificationPageRoot.syncGroups();
        }

        target: NotificationHistory
    }
    Timer {
        interval: 60000
        repeat: true
        running: notificationPageRoot.visible

        onTriggered: notificationPageRoot.currentTimeTick = Date.now()
    }
    Timer {
        id: clearAllTimer

        repeat: false

        onTriggered: {
            notificationPageRoot.expandedGroups = {};
            notificationPageRoot.renderedCounts = {};
            notificationPageRoot.clearAllAnimationActive = false;
        }
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true

            ListView {
                id: notifListView

                anchors.fill: parent
                bottomMargin: 6
                cacheBuffer: 80
                clip: true
                model: groupModel
                opacity: groupModel.count > 0 ? 1 : 0
                reuseItems: true
                spacing: 0
                topMargin: 2

                delegate: Item {
                    id: groupItem

                    property string appName: modelData ? modelData.appName : "Notification"
                    property bool compactRows: true
                    property bool expanded: notificationPageRoot.isGroupExpanded(appName)
                    property bool heightBehaviorEnabled: false
                    required property int index
                    property bool initialized: false
                    property bool isDismissing: false
                    property bool isGroup: notifCount > 1
                    readonly property var modelData: JSON.parse(payload)
                    readonly property real naturalCardHeight: cardColumn.implicitHeight + 20
                    property int notifCount: notifications.length
                    property var notifications: modelData ? modelData.notifications : []
                    required property string payload
                    property bool pooled: false
                    property int renderedCount: notificationPageRoot.renderedCountFor(appName)
                    property real swipeOffset: 0
                    // Include the inter-card gap in the same collapse, not a second removal step.
                    readonly property real trailingGap: isDismissing ? 10 * Math.min(1, height / Math.max(1, naturalCardHeight + 10)) : 10

                    function syncNotifications() {
                        if (pooled)
                            return;
                        var nextCompact = notifications.length > 1 && !expanded;
                        var limit = nextCompact ? 2 : renderedCount;
                        // Backfilled rows and compact/detail changes resize the card once.
                        // While a row is actively collapsing, its height drives the card directly.
                        var collapsing = false;
                        for (var i = 0; i < groupRepeater.count; ++i) {
                            var row = groupRepeater.itemAt(i);
                            if (row && row.isDismissing && row.height > 0.5)
                                collapsing = true;
                        }
                        if (initialized && !collapsing)
                            heightBehaviorEnabled = true;
                        notificationPageRoot.syncRows(rowModel, notifications.slice(0, limit), "nid");
                        compactRows = nextCompact;
                    }

                    clip: true
                    height: isDismissing ? 0 : naturalCardHeight + 10
                    visible: !groupItem.pooled
                    width: ListView.view.width

                    Behavior on height {
                        enabled: groupItem.heightBehaviorEnabled || groupItem.isDismissing

                        NumberAnimation {
                            duration: Config.animationDuration(180)
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on swipeOffset {
                        enabled: !groupDrag.active

                        NumberAnimation {
                            duration: Config.animationDuration(Md3.motion.short3)
                            easing.type: Easing.OutCubic
                        }
                    }
                    transform: Translate {
                        x: groupItem.swipeOffset
                    }

                    Component.onCompleted: {
                        syncNotifications();
                        initialized = true;
                    }
                    ListView.onPooled: {
                        pooled = true;
                        clearStaggerTimer.stop();
                        groupSwipeCollapseTimer.stop();
                        groupDismissTimer.stop();
                    }
                    ListView.onReused: {
                        pooled = false;
                        clearStaggerTimer.stop();
                        groupSwipeCollapseTimer.stop();
                        groupDismissTimer.stop();
                        swipeOffset = 0;
                        isDismissing = false;
                        heightBehaviorEnabled = false;
                        initialized = false;
                        syncNotifications();
                        initialized = true;
                    }
                    onExpandedChanged: Qt.callLater(syncNotifications)
                    onNotificationsChanged: Qt.callLater(syncNotifications)
                    onRenderedCountChanged: Qt.callLater(syncNotifications)

                    ListModel {
                        id: rowModel
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        border.color: controlRightWindow.sectionCardBorderColor
                        border.width: 1
                        color: controlRightWindow.sectionCardColor
                        height: Math.max(0, groupItem.height - groupItem.trailingGap)
                        radius: 16
                    }
                    Connections {
                        function onClearAllAnimationActiveChanged() {
                            if (!groupItem.pooled && notificationPageRoot.clearAllAnimationActive) {
                                clearStaggerTimer.interval = Config.animationDuration(Math.min(index, 7) * 55);
                                clearStaggerTimer.start();
                            }
                        }

                        enabled: !groupItem.pooled
                        target: notificationPageRoot
                    }
                    Timer {
                        id: clearStaggerTimer

                        repeat: false

                        onTriggered: {
                            if (!groupItem.pooled)
                                groupItem.swipeOffset = groupItem.width + 100;
                        }
                    }
                    Timer {
                        id: groupSwipeCollapseTimer

                        interval: Math.max(1, Config.animationDuration(80))

                        onTriggered: {
                            groupItem.heightBehaviorEnabled = true;
                            groupItem.isDismissing = true;
                            groupDismissTimer.start();
                        }
                    }
                    Timer {
                        id: groupDismissTimer

                        interval: Math.max(1, Config.animationDuration(180)) + 16

                        onTriggered: {
                            var nids = [];
                            for (var i = 0; i < groupItem.notifications.length; i++) {
                                nids.push(groupItem.notifications[i].nid);
                            }
                            NotificationHistory.dismissMany(nids);
                        }
                    }
                    ColumnLayout {
                        id: cardColumn

                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        spacing: 8

                        // ── Header: icon_app | App name | time | expand badge ──
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            DragHandler {
                                id: groupDrag

                                target: null
                                xAxis.enabled: true
                                xAxis.minimum: 0
                                yAxis.enabled: false

                                onActiveChanged: {
                                    if (!active) {
                                        if (groupItem.swipeOffset > groupItem.width * 0.38) {
                                            groupItem.swipeOffset = groupItem.width + 80;
                                            groupSwipeCollapseTimer.start();
                                        } else {
                                            groupItem.swipeOffset = 0;
                                        }
                                    }
                                }
                                onTranslationChanged: groupItem.swipeOffset = Math.max(0, translation.x)
                            }
                            NotificationIcon {
                                Layout.preferredHeight: 32
                                Layout.preferredWidth: 32
                                appName: groupItem.appName
                                asynchronous: true
                                cacheImage: false
                                forceAppIconOnly: true
                                iconSize: 20
                                notificationData: null
                                radius: 10
                                tintColor: Config.md3.on_surface_variant
                            }

                            // App name
                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.on_surface
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                                font.pixelSize: Md3.typeScale.titleMedium.size
                                font.weight: Font.DemiBold
                                lineHeight: Md3.typeScale.titleMedium.lineHeight
                                lineHeightMode: Text.FixedHeight
                                text: groupItem.appName
                            }

                            // Expand/collapse badge (groups only)
                            Rectangle {
                                id: groupExpandButton

                                readonly property color contentColor: groupItem.expanded ? Config.md3.on_secondary_container : Config.md3.on_surface

                                function toggleExpanded() {
                                    groupItem.heightBehaviorEnabled = true;
                                    notificationPageRoot.setGroupExpanded(groupItem.appName, !groupItem.expanded);
                                }

                                Accessible.name: groupItem.expanded ? qsTr("Collapse %1 notifications").arg(groupItem.notifCount) : qsTr("Expand %1 notifications").arg(groupItem.notifCount)
                                Accessible.role: Accessible.Button
                                Layout.preferredHeight: Md3.spacing.xl
                                Layout.preferredWidth: Math.max(Md3.spacing.xxl, badgeRow.implicitWidth + Md3.spacing.xs * 2)
                                color: groupItem.expanded ? Config.md3.secondary_container : Config.md3.surface_container_high
                                radius: Md3.shape.medium
                                visible: groupItem.isGroup

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Config.animationDuration(Md3.motion.short3)
                                        easing.type: Md3.motion.standard
                                    }
                                }

                                Accessible.onPressAction: toggleExpanded()

                                Rectangle {
                                    anchors.fill: parent
                                    color: Config.alpha(groupExpandButton.contentColor, groupExpandMouse.pressed ? Md3.state.pressed : groupExpandMouse.containsMouse ? Md3.state.hover : 0)
                                    radius: groupExpandButton.radius

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Config.animationDuration(Md3.motion.short3)
                                            easing.type: Md3.motion.standard
                                        }
                                    }
                                }
                                RowLayout {
                                    id: badgeRow

                                    anchors.centerIn: parent
                                    spacing: Md3.spacing.xxs

                                    Text {
                                        color: groupExpandButton.contentColor
                                        font.family: Config.fontName
                                        font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
                                        font.pixelSize: Md3.typeScale.labelLarge.size
                                        font.weight: Md3.typeScale.labelLarge.weight
                                        lineHeight: Md3.typeScale.labelLarge.lineHeight
                                        lineHeightMode: Text.FixedHeight
                                        text: groupItem.notifCount
                                    }
                                    Md3Icon {
                                        Layout.preferredHeight: Md3.spacing.md
                                        Layout.preferredWidth: Md3.spacing.md
                                        color: groupExpandButton.contentColor
                                        name: "expand_more"
                                        rotation: groupItem.expanded ? 180 : 0
                                        size: Md3.spacing.md

                                        Behavior on rotation {
                                            RotationAnimator {
                                                duration: Config.animationDuration(Md3.motion.short3)
                                                easing.type: Md3.motion.standard
                                            }
                                        }
                                    }
                                }
                                MouseArea {
                                    id: groupExpandMouse

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true

                                    onClicked: groupExpandButton.toggleExpanded()
                                }
                            }
                        }

                        // ── Divider ─────────────────────────────────────
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Config.alpha(Config.md3.on_surface, 0.045)
                        }

                        // ── Notification rows ────────────────────────────
                        // Collapsed group: show first 2; Expanded or single: show all
                        Column {
                            Layout.fillWidth: true
                            spacing: 0

                            Repeater {
                                id: groupRepeater

                                model: rowModel

                                delegate: Item {
                                    id: notifItem

                                    property bool collapseAnimationEnabled: false

                                    // compact = collapsed group rows; detail = single noti or expanded group
                                    property bool compact: groupItem.compactRows
                                    required property int index
                                    property bool isDismissing: false
                                    readonly property var modelData: JSON.parse(payload)
                                    required property string payload
                                    property real swipeOffset: 0

                                    function beginDismiss() {
                                        groupItem.heightBehaviorEnabled = false;
                                        collapseAnimationEnabled = true;
                                        isDismissing = true;
                                        if (groupItem.notifCount === 1) {
                                            groupItem.heightBehaviorEnabled = true;
                                            groupItem.isDismissing = true;
                                        }
                                        dismissTimer.start();
                                    }

                                    clip: true
                                    height: implicitHeight
                                    // KEY: use implicitHeight so parent ColumnLayout stacks correctly
                                    implicitHeight: isDismissing ? 0 : rowLoader.implicitHeight + (compact ? 12 : 22) + (index < groupRepeater.count - 1 ? 3 : 0)
                                    opacity: isDismissing ? 0 : 1
                                    width: parent.width

                                    Behavior on implicitHeight {
                                        enabled: notifItem.collapseAnimationEnabled

                                        NumberAnimation {
                                            duration: Config.animationDuration(180)
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                    Behavior on opacity {
                                        enabled: notifItem.collapseAnimationEnabled

                                        NumberAnimation {
                                            duration: Config.animationDuration(Md3.motion.short3)
                                        }
                                    }
                                    Behavior on swipeOffset {
                                        enabled: !swipeDrag.active

                                        NumberAnimation {
                                            duration: Config.animationDuration(Md3.motion.short3)
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    DragHandler {
                                        id: swipeDrag

                                        target: null
                                        xAxis.enabled: true
                                        xAxis.minimum: 0
                                        yAxis.enabled: false

                                        onActiveChanged: {
                                            if (!active) {
                                                if (notifItem.swipeOffset > notifItem.width * 0.38) {
                                                    notifItem.swipeOffset = notifItem.width + 80;
                                                    swipeCollapseTimer.start();
                                                } else {
                                                    notifItem.swipeOffset = 0;
                                                }
                                            }
                                        }
                                        onTranslationChanged: notifItem.swipeOffset = Math.max(0, translation.x)
                                    }
                                    Timer {
                                        id: swipeCollapseTimer

                                        interval: Math.max(1, Config.animationDuration(80))

                                        onTriggered: notifItem.beginDismiss()
                                    }
                                    Timer {
                                        id: dismissTimer

                                        interval: Math.max(1, Config.animationDuration(180)) + 16

                                        onTriggered: NotificationHistory.dismiss(notifItem.modelData.nid)
                                    }
                                    Loader {
                                        id: rowLoader

                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        sourceComponent: notifItem.compact ? compactComponent : detailComponent

                                        transform: Translate {
                                            x: notifItem.swipeOffset
                                        }
                                    }
                                    Component {
                                        id: compactComponent

                                        // ── COMPACT: [small icon] [Title] [Body] ──
                                        RowLayout {
                                            id: compactRow

                                            spacing: 10

                                            NotificationIcon {
                                                Layout.alignment: Qt.AlignVCenter
                                                Layout.preferredHeight: 30
                                                Layout.preferredWidth: 30
                                                asynchronous: true
                                                cacheImage: false
                                                iconSize: 16
                                                notificationData: notifItem.modelData
                                                radius: 9
                                            }
                                            Text {
                                                Layout.maximumWidth: Math.min(180, Math.max(105, compactRow.width * 0.38))
                                                color: Config.md3.on_surface
                                                elide: Text.ElideRight
                                                font.family: Config.fontName
                                                font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                                                font.pixelSize: Md3.typeScale.titleMedium.size
                                                font.weight: Font.DemiBold
                                                lineHeight: Md3.typeScale.titleMedium.lineHeight
                                                lineHeightMode: Text.FixedHeight
                                                text: notifItem.modelData.summary || ""
                                                textFormat: Text.PlainText
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                color: Config.md3.on_surface_variant
                                                elide: Text.ElideRight
                                                font.family: Config.fontName
                                                font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
                                                font.pixelSize: Md3.typeScale.bodyLarge.size
                                                font.weight: Md3.typeScale.bodyLarge.weight
                                                lineHeight: Md3.typeScale.bodyLarge.lineHeight
                                                lineHeightMode: Text.FixedHeight
                                                text: notifItem.modelData.body || ""
                                                textFormat: Text.PlainText
                                                visible: text !== ""
                                            }
                                        }
                                    }
                                    Component {
                                        id: detailComponent

                                        // ── DETAIL: icon | title/body/actions ──
                                        ColumnLayout {
                                            spacing: 10

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 12

                                                NotificationIcon {
                                                    Layout.alignment: Qt.AlignTop
                                                    Layout.preferredHeight: 38
                                                    Layout.preferredWidth: 38
                                                    asynchronous: true
                                                    cacheImage: false
                                                    iconSize: 20
                                                    notificationData: notifItem.modelData
                                                    radius: 8
                                                }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 3

                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 8

                                                        Text {
                                                            Layout.fillWidth: true
                                                            color: Config.md3.on_surface
                                                            elide: Text.ElideRight
                                                            font.family: Config.fontName
                                                            font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                                                            font.pixelSize: Md3.typeScale.titleMedium.size
                                                            font.weight: Font.DemiBold
                                                            lineHeight: Md3.typeScale.titleMedium.lineHeight
                                                            lineHeightMode: Text.FixedHeight
                                                            text: notifItem.modelData.summary || ""
                                                            textFormat: Text.PlainText
                                                        }
                                                        Text {
                                                            color: Config.md3.on_surface_variant
                                                            font.family: Config.fontName
                                                            font.letterSpacing: Md3.typeScale.bodyMedium.letterSpacing
                                                            font.pixelSize: Md3.typeScale.bodyMedium.size
                                                            font.weight: Md3.typeScale.bodyMedium.weight
                                                            lineHeight: Md3.typeScale.bodyMedium.lineHeight
                                                            lineHeightMode: Text.FixedHeight
                                                            text: notifItem.modelData.timestamp ? notificationPageRoot.formatRelativeTime(notifItem.modelData.timestamp, notificationPageRoot.currentTimeTick) : (notifItem.modelData.timeText || "now")
                                                        }
                                                    }
                                                    Text {
                                                        Layout.fillWidth: true
                                                        color: Config.md3.on_surface_variant
                                                        font.family: Config.fontName
                                                        font.letterSpacing: Md3.typeScale.bodyLarge.letterSpacing
                                                        font.pixelSize: Md3.typeScale.bodyLarge.size
                                                        font.weight: Md3.typeScale.bodyLarge.weight
                                                        lineHeight: Md3.typeScale.bodyLarge.lineHeight
                                                        lineHeightMode: Text.FixedHeight
                                                        text: notifItem.modelData.body || ""
                                                        textFormat: Text.PlainText
                                                        visible: text !== ""
                                                        wrapMode: Text.Wrap
                                                    }
                                                }
                                            }
                                            Flickable {
                                                id: actionViewport

                                                readonly property var actions: {
                                                    var raw = NotificationHistory.rawMap[notifItem.modelData.nid];
                                                    return raw ? raw.actions : [];
                                                }

                                                Layout.fillWidth: true
                                                Layout.leftMargin: notificationPageRoot.width < 420 ? 0 : 50
                                                Layout.preferredHeight: visible ? 36 : 0
                                                boundsBehavior: Flickable.StopAtBounds
                                                clip: contentWidth > width
                                                contentHeight: height
                                                contentWidth: Math.max(width, actionRow.implicitWidth)
                                                flickableDirection: Flickable.HorizontalFlick
                                                interactive: contentWidth > width
                                                visible: actions.length > 0

                                                Row {
                                                    id: actionRow

                                                    height: parent.height
                                                    spacing: 8

                                                    Repeater {
                                                        model: actionViewport.actions

                                                        delegate: NotificationActionButton {
                                                            readonly property real equalWidth: (actionViewport.width - Math.max(0, actionViewport.actions.length - 1) * actionRow.spacing) / Math.max(1, actionViewport.actions.length)
                                                            required property var modelData

                                                            action: modelData
                                                            height: 36
                                                            labelPixelSize: 13
                                                            width: Math.max(minimumWidth, equalWidth)

                                                            onClicked: {
                                                                modelData.invoke();
                                                                notifItem.beginDismiss();
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Separator between items in same group
                                    Rectangle {
                                        id: sepLine

                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.leftMargin: 40
                                        anchors.right: parent.right
                                        color: Config.alpha(Config.md3.on_surface, 0.05)
                                        height: 1
                                        visible: index < (groupRepeater.count - 1)
                                    }
                                }
                            }
                            Rectangle {
                                color: Config.alpha(Config.md3.primary, showMoreArea.containsMouse ? 0.14 : 0.08)
                                height: visible ? 36 : 0
                                radius: 10
                                visible: groupItem.expanded && groupItem.renderedCount < groupItem.notifCount
                                width: parent.width

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Config.animationDuration(120)
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    color: Config.md3.primary
                                    font.family: Config.fontName
                                    font.letterSpacing: Md3.typeScale.labelLarge.letterSpacing
                                    font.pixelSize: Md3.typeScale.labelLarge.size
                                    font.weight: Md3.typeScale.labelLarge.weight
                                    lineHeight: Md3.typeScale.labelLarge.lineHeight
                                    lineHeightMode: Text.FixedHeight
                                    text: qsTr("Show %1 older notifications").arg(Math.min(12, groupItem.notifCount - groupItem.renderedCount))
                                }
                                MouseArea {
                                    id: showMoreArea

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true

                                    onClicked: {
                                        groupItem.heightBehaviorEnabled = true;
                                        notificationPageRoot.showMoreFor(groupItem.appName);
                                    }
                                }
                            }
                        }
                    }
                }
                move: Transition {
                    NumberAnimation {
                        duration: Config.animationDuration(180)
                        easing.type: Easing.OutCubic
                        properties: "y"
                    }
                }
                moveDisplaced: Transition {
                    NumberAnimation {
                        duration: Config.animationDuration(180)
                        easing.type: Easing.OutCubic
                        properties: "y"
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Config.animationDuration(Md3.motion.short4)
                    }
                }
                removeDisplaced: Transition {
                    NumberAnimation {
                        duration: Config.animationDuration(140)
                        easing.type: Easing.OutCubic
                        properties: "y"
                    }
                }
            }

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                visible: groupModel.count === 0

                Rectangle {
                    Layout.alignment: Qt.AlignCenter
                    Layout.preferredHeight: 64
                    Layout.preferredWidth: 64
                    color: Config.alpha(Config.md3.primary, 0.09)
                    radius: 32

                    Md3Icon {
                        anchors.centerIn: parent
                        color: Config.alpha(Config.md3.primary, 0.65)
                        filled: true
                        name: "preferences-system-notifications-symbolic"
                        size: 28
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignCenter
                    color: Config.md3.on_surface_variant
                    font.family: Config.fontName
                    font.letterSpacing: Md3.typeScale.titleMedium.letterSpacing
                    font.pixelSize: Md3.typeScale.titleMedium.size
                    font.weight: Md3.typeScale.titleMedium.weight
                    lineHeight: Md3.typeScale.titleMedium.lineHeight
                    lineHeightMode: Text.FixedHeight
                    text: qsTr("No notifications")
                }
            }
        }

        // Bottom bar
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            visible: NotificationHistory.notifications.count > 0

            Text {
                color: Config.md3.on_surface_variant
                font.family: Config.fontName
                font.letterSpacing: Md3.typeScale.bodyMedium.letterSpacing
                font.pixelSize: Md3.typeScale.bodyMedium.size
                font.weight: Md3.typeScale.bodyMedium.weight
                lineHeight: Md3.typeScale.bodyMedium.lineHeight
                lineHeightMode: Text.FixedHeight
                text: NotificationHistory.notifications.count === 1 ? qsTr("1 notification") : qsTr("%1 notifications").arg(NotificationHistory.notifications.count)
            }
            Item {
                Layout.fillWidth: true
            }
            Rectangle {
                Layout.preferredHeight: 32
                Layout.preferredWidth: 32
                color: clearHover.pressed ? Config.md3.surface_container_highest : (clearHover.containsMouse ? Config.md3.surface_container_high : "transparent")
                radius: 16
                scale: clearHover.pressed ? 0.95 : 1.0

                Behavior on color {
                    ColorAnimation {
                        duration: Config.animationDuration(120)
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Config.animationDuration(80)
                    }
                }

                Md3Icon {
                    anchors.centerIn: parent
                    color: clearHover.containsMouse ? Config.md3.on_surface : Config.alpha(Config.md3.on_surface, 0.45)
                    name: "edit-clear-all-symbolic"
                    size: 20
                }
                MouseArea {
                    id: clearHover

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true

                    onClicked: notificationPageRoot.triggerClearAllAnimation()
                }
            }
        }
    }
}
