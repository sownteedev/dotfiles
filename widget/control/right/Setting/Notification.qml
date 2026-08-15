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
    function triggerClearAllAnimation() {
        var count = NotificationHistory.notificationGroups.length;
        if (count === 0)
            return;

        clearAllAnimationActive = true;

        // Cap the stagger so clearing a long history stays quick.
        var exactAnimationDuration = Math.min(Math.max(0, count - 1), 7) * 55 + 160;

        // The singleton timer survives closing Control Right or switching tabs,
        // so the requested clear cannot be cancelled with the page Loader.
        NotificationHistory.clearAllAfter(exactAnimationDuration);
        clearAllTimer.interval = exactAnimationDuration;
        clearAllTimer.start();
    }

    anchors.fill: parent

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
                model: NotificationHistory.notificationGroups
                opacity: NotificationHistory.notifications.count > 0 ? 1 : 0
                reuseItems: true
                spacing: 10
                topMargin: 2

                delegate: Rectangle {
                    id: groupItem

                    property string appName: modelData ? modelData.appName : "Notification"
                    property bool expanded: notificationPageRoot.isGroupExpanded(appName)
                    property bool heightBehaviorEnabled: false
                    property bool isDismissing: false
                    property bool isGroup: notifCount > 1
                    property int notifCount: notifications.length
                    property var notifications: modelData ? modelData.notifications : []
                    property bool pooled: false
                    property int renderedCount: notificationPageRoot.renderedCountFor(appName)
                    property real swipeOffset: 0

                    border.color: Config.alpha(Config.md3.on_surface, 0.075)
                    border.width: 1
                    clip: true
                    color: Config.md3.surface_container_low
                    height: isDismissing ? 0 : cardColumn.implicitHeight + 20
                    radius: 16
                    visible: !groupItem.pooled
                    width: ListView.view.width

                    Behavior on height {
                        enabled: groupItem.heightBehaviorEnabled || groupItem.isDismissing

                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic

                            onRunningChanged: {
                                if (!running) {
                                    groupItem.heightBehaviorEnabled = false;
                                }
                            }
                        }
                    }
                    Behavior on swipeOffset {
                        enabled: !groupDrag.active

                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutCubic
                        }
                    }
                    transform: Translate {
                        x: groupItem.swipeOffset
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
                    }

                    Connections {
                        function onClearAllAnimationActiveChanged() {
                            if (!groupItem.pooled && notificationPageRoot.clearAllAnimationActive) {
                                clearStaggerTimer.interval = Math.min(index, 7) * 55;
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

                        interval: 80

                        onTriggered: {
                            groupItem.isDismissing = true;
                            groupItem.heightBehaviorEnabled = true;
                            groupDismissTimer.start();
                        }
                    }
                    Timer {
                        id: groupDismissTimer

                        interval: 180

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
                                iconSize: 18
                                notificationData: groupItem.notifications[0] || null
                                radius: 10
                                tintColor: Config.md3.on_surface_variant
                            }

                            // App name
                            Text {
                                Layout.fillWidth: true
                                color: Config.md3.on_surface
                                elide: Text.ElideRight
                                font.family: Config.fontName
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                text: groupItem.appName
                            }

                            // Expand/collapse badge (groups only)
                            Rectangle {
                                Layout.preferredHeight: 26
                                Layout.preferredWidth: badgeRow.implicitWidth + 16
                                color: Config.alpha(Config.md3.primary, groupItem.expanded ? 0.18 : 0.10)
                                radius: 13
                                visible: groupItem.isGroup

                                RowLayout {
                                    id: badgeRow

                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        color: Config.md3.primary
                                        font.family: Config.fontName
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        text: groupItem.notifCount
                                    }
                                    IconImage {
                                        Layout.preferredHeight: 10
                                        Layout.preferredWidth: 10
                                        layer.enabled: true
                                        source: groupItem.expanded ? Quickshell.iconPath("go-up-symbolic") : Quickshell.iconPath("go-down-symbolic")

                                        layer.effect: ColorOverlay {
                                            color: Config.md3.primary
                                        }
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        groupItem.heightBehaviorEnabled = true;
                                        notificationPageRoot.setGroupExpanded(groupItem.appName, !groupItem.expanded);
                                    }
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
                            spacing: 3

                            Repeater {
                                id: groupRepeater

                                model: (groupItem.isGroup && !groupItem.expanded) ? groupItem.notifications.slice(0, 2) : groupItem.notifications.slice(0, groupItem.renderedCount)

                                delegate: Item {
                                    id: notifItem

                                    // compact = collapsed group rows; detail = single noti or expanded group
                                    property bool compact: groupItem.isGroup && !groupItem.expanded
                                    required property int index
                                    property bool isDismissing: false
                                    required property var modelData
                                    property real swipeOffset: 0

                                    clip: true
                                    height: implicitHeight
                                    // KEY: use implicitHeight so parent ColumnLayout stacks correctly
                                    implicitHeight: isDismissing ? 0 : rowLoader.implicitHeight + (compact ? 12 : 22)
                                    opacity: isDismissing ? 0 : 1
                                    width: parent.width

                                    Behavior on implicitHeight {
                                        enabled: notifItem.isDismissing || groupItem.heightBehaviorEnabled

                                        NumberAnimation {
                                            duration: 180
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                    Behavior on opacity {
                                        enabled: notifItem.isDismissing

                                        NumberAnimation {
                                            duration: 150
                                        }
                                    }
                                    Behavior on swipeOffset {
                                        enabled: !swipeDrag.active

                                        NumberAnimation {
                                            duration: 150
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    onModelDataChanged: {
                                        isDismissing = false;
                                        swipeOffset = 0;
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

                                        interval: 80

                                        onTriggered: {
                                            notifItem.isDismissing = true;
                                            groupItem.heightBehaviorEnabled = true;
                                            if (groupItem.notifCount === 1) {
                                                groupItem.isDismissing = true;
                                            }
                                            dismissTimer.start();
                                        }
                                    }
                                    Timer {
                                        id: dismissTimer

                                        interval: 180

                                        onTriggered: NotificationHistory.dismiss(modelData.nid)
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
                                                font.pixelSize: 14
                                                font.weight: Font.DemiBold
                                                text: notifItem.modelData.summary || ""
                                                textFormat: Text.PlainText
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                color: Config.md3.on_surface_variant
                                                elide: Text.ElideRight
                                                font.family: Config.fontName
                                                font.pixelSize: 13
                                                font.weight: Font.Medium
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
                                                            font.pixelSize: 16
                                                            font.weight: Font.DemiBold
                                                            text: notifItem.modelData.summary || ""
                                                            textFormat: Text.PlainText
                                                        }
                                                        Text {
                                                            color: Config.md3.outline
                                                            font.family: Config.fontName
                                                            font.pixelSize: 15
                                                            font.weight: Font.Medium
                                                            text: notifItem.modelData.timestamp ? notificationPageRoot.formatRelativeTime(notifItem.modelData.timestamp, notificationPageRoot.currentTimeTick) : (notifItem.modelData.timeText || "now")
                                                        }
                                                    }
                                                    Text {
                                                        Layout.fillWidth: true
                                                        color: Config.md3.on_surface_variant
                                                        font.family: Config.fontName
                                                        font.pixelSize: 15
                                                        font.weight: Font.Medium
                                                        lineHeight: 1.15
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
                                                                notifItem.isDismissing = true;
                                                                groupItem.heightBehaviorEnabled = true;
                                                                if (groupItem.notifCount === 1)
                                                                    groupItem.isDismissing = true;
                                                                dismissTimer.start();
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
                                        duration: 120
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    color: Config.md3.primary
                                    font.family: Config.fontName
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
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
                Behavior on opacity {
                    NumberAnimation {
                        duration: 200
                    }
                }
            }

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                visible: NotificationHistory.notifications.count === 0

                Rectangle {
                    Layout.alignment: Qt.AlignCenter
                    Layout.preferredHeight: 64
                    Layout.preferredWidth: 64
                    color: Config.alpha(Config.md3.primary, 0.09)
                    radius: 32

                    IconImage {
                        id: emptyNotificationIcon

                        anchors.centerIn: parent
                        implicitHeight: 28
                        implicitWidth: 28
                        source: Quickshell.iconPath("preferences-system-notifications-symbolic")
                        visible: false
                    }
                    ColorOverlay {
                        anchors.fill: emptyNotificationIcon
                        color: Config.alpha(Config.md3.primary, 0.65)
                        source: emptyNotificationIcon
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignCenter
                    color: Config.md3.on_surface_variant
                    font.family: Config.fontName
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
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
                color: Config.alpha(Config.md3.on_surface, 0.4)
                font.family: Config.fontName
                font.pixelSize: 14
                font.weight: Font.DemiBold
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
                        duration: 120
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 80
                    }
                }

                IconImage {
                    anchors.centerIn: parent
                    height: 16
                    layer.enabled: true
                    source: Quickshell.iconPath("edit-clear-all-symbolic")
                    width: 16

                    layer.effect: ColorOverlay {
                        color: clearHover.containsMouse ? Config.md3.on_surface : Config.alpha(Config.md3.on_surface, 0.45)
                    }
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
