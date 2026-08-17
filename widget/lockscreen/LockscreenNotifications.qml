pragma ComponentBehavior: Bound

import "../.."
import "../../service"
import QtQuick

Item {
    id: root

    readonly property real cardHeight: 40 * scaleFactor
    readonly property real cardSpacing: 6 * scaleFactor
    property string expandedGroupKey: ""
    readonly property real expandedHeightAdjustment: heightAdjustmentForExpandedGroup()
    property real maximumHeight: visibleStackHeight
    readonly property real scaleFactor: width > 0 ? width / 220 : 1
    readonly property real stackLayerOffset: 3 * scaleFactor
    readonly property int visibleCardCount: Math.min(LockscreenNotificationService.groups.count, Math.max(1, Config.notificationMaxVisible))
    readonly property real visibleStackHeight: heightForGroups(visibleCardCount) + expandedHeightAdjustment

    function groupCountForKey(groupKey) {
        var revision = LockscreenNotificationService.groupsRevision;
        for (var index = 0; index < LockscreenNotificationService.groups.count; ++index) {
            var group = LockscreenNotificationService.groups.get(index);
            if (group.groupKey === groupKey)
                return group.groupCount + revision * 0;
        }
        return revision * 0;
    }
    function groupStackDepth(groupCount) {
        return Math.min(2, Math.max(0, Number(groupCount) - 1)) * stackLayerOffset;
    }
    function heightAdjustmentForExpandedGroup() {
        var count = groupCountForKey(expandedGroupKey);
        if (count <= 1)
            return 0;

        var expandedHeight = count * cardHeight + (count - 1) * cardSpacing;
        return expandedHeight - cardHeight - groupStackDepth(count);
    }
    function heightForGroups(limit) {
        var revision = LockscreenNotificationService.groupsRevision;
        var count = Math.min(LockscreenNotificationService.groups.count, Math.max(0, Number(limit)));
        if (count <= 0)
            return revision * 0;

        var total = (count - 1) * cardSpacing;
        for (var index = 0; index < count; ++index)
            total += cardHeight + groupStackDepth(LockscreenNotificationService.groups.get(index).groupCount);
        return total;
    }

    height: Math.min(visibleStackHeight, Math.max(0, maximumHeight))
    implicitHeight: height
    visible: Config.notificationShowOnLock && StateManager.sessionLocked && (LockscreenNotificationService.groups.count > 0 || height > 0.5)

    Behavior on height {
        NumberAnimation {
            duration: Config.animationDuration(320)
            easing.type: Easing.OutQuint
        }
    }

    Connections {
        function onGroupsRevisionChanged() {
            if (root.expandedGroupKey !== "" && root.groupCountForKey(root.expandedGroupKey) <= 1)
                root.expandedGroupKey = "";
        }

        target: LockscreenNotificationService
    }
    ListView {
        id: notificationList

        anchors.fill: parent
        boundsBehavior: Flickable.StopAtBounds
        clip: contentHeight > height
        flickDeceleration: 4200 * root.scaleFactor
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        maximumFlickVelocity: 2600 * root.scaleFactor
        model: LockscreenNotificationService.groups
        spacing: root.cardSpacing

        add: Transition {
            ParallelAnimation {
                OpacityAnimator {
                    duration: Config.animationDuration(200)
                    easing.type: Easing.OutCubic
                    from: 0
                    to: 1
                }
                XAnimator {
                    duration: Config.animationDuration(300)
                    easing.type: Easing.OutQuint
                    from: root.width + 18 * root.scaleFactor
                    to: 0
                }
            }
        }
        addDisplaced: Transition {
            YAnimator {
                duration: Config.animationDuration(320)
                easing.type: Easing.OutQuint
            }
        }
        delegate: Item {
            id: notificationDelegate

            required property string changeKind
            required property int changeRevision
            readonly property bool expanded: root.expandedGroupKey === groupKey
            required property int groupCount
            required property string groupKey
            property bool initialized: false
            readonly property real stackDepth: root.groupStackDepth(groupCount)

            function syncNotifications() {
                var desired = LockscreenNotificationService.notificationsForGroup(groupKey);
                for (var targetIndex = 0; targetIndex < desired.length; ++targetIndex) {
                    var desiredNotification = desired[targetIndex];
                    var existingIndex = -1;
                    for (var currentIndex = targetIndex; currentIndex < groupNotificationsModel.count; ++currentIndex) {
                        if (groupNotificationsModel.get(currentIndex).nid === desiredNotification.nid) {
                            existingIndex = currentIndex;
                            break;
                        }
                    }

                    if (existingIndex < 0) {
                        groupNotificationsModel.insert(targetIndex, desiredNotification);
                        continue;
                    }
                    if (existingIndex !== targetIndex)
                        groupNotificationsModel.move(existingIndex, targetIndex, 1);
                    groupNotificationsModel.set(targetIndex, desiredNotification);
                }

                while (groupNotificationsModel.count > desired.length)
                    groupNotificationsModel.remove(groupNotificationsModel.count - 1);
            }

            height: expanded ? groupNotificationsModel.count * root.cardHeight + Math.max(0, groupNotificationsModel.count - 1) * root.cardSpacing : root.cardHeight + stackDepth
            width: ListView.view.width

            Behavior on height {
                NumberAnimation {
                    duration: Config.animationDuration(320)
                    easing.type: Easing.OutQuint
                }
            }

            Component.onCompleted: {
                syncNotifications();
                initialized = true;
            }
            onChangeRevisionChanged: {
                if (!initialized)
                    return;

                Qt.callLater(function () {
                    notificationDelegate.syncNotifications();
                });
            }

            ListModel {
                id: groupNotificationsModel
            }
            Repeater {
                model: groupNotificationsModel

                delegate: Item {
                    id: notificationItem

                    required property string appIcon
                    required property string appName
                    required property string body
                    required property string image
                    required property int index
                    required property bool isCritical
                    required property int nid
                    required property string summary

                    anchors.horizontalCenter: parent.horizontalCenter
                    height: root.cardHeight
                    opacity: notificationDelegate.expanded || index <= 2 ? 1 : 0
                    visible: notificationDelegate.expanded || index <= 2 || opacity > 0.01
                    width: notificationDelegate.expanded || index === 0 ? notificationDelegate.width : notificationDelegate.width - Math.min(index, 2) * 8 * root.scaleFactor
                    y: notificationDelegate.expanded ? index * (root.cardHeight + root.cardSpacing) : Math.min(index, 2) * root.stackLayerOffset
                    z: groupNotificationsModel.count - index

                    Behavior on opacity {
                        OpacityAnimator {
                            duration: Config.animationDuration(220)
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on width {
                        NumberAnimation {
                            duration: Config.animationDuration(320)
                            easing.type: Easing.OutQuint
                        }
                    }
                    Behavior on y {
                        YAnimator {
                            duration: Config.animationDuration(320)
                            easing.type: Easing.OutQuint
                        }
                    }

                    Component.onCompleted: {
                        if (notificationDelegate.initialized && notificationItem.index === 0 && notificationDelegate.changeKind === "add") {
                            Qt.callLater(function () {
                                notificationCard.revealFromRight();
                            });
                        }
                    }

                    LockscreenNotificationCard {
                        id: notificationCard

                        anchors.fill: parent
                        appIcon: notificationItem.appIcon
                        appName: notificationItem.appName
                        body: notificationItem.body
                        groupCount: notificationDelegate.groupCount
                        image: notificationItem.image
                        isCritical: notificationItem.isCritical
                        nid: notificationItem.nid
                        scaleFactor: root.scaleFactor
                        showGroupCount: notificationItem.index === 0 && !notificationDelegate.expanded
                        summary: notificationItem.summary
                        swipeEnabled: notificationDelegate.expanded || notificationItem.index === 0
                        tapEnabled: notificationItem.index === 0 && notificationDelegate.groupCount > 1

                        onTapped: root.expandedGroupKey = notificationDelegate.expanded ? "" : notificationDelegate.groupKey
                    }
                }
            }
        }
        move: Transition {
            YAnimator {
                duration: Config.animationDuration(320)
                easing.type: Easing.OutQuint
            }
        }
        moveDisplaced: Transition {
            YAnimator {
                duration: Config.animationDuration(320)
                easing.type: Easing.OutQuint
            }
        }
        remove: Transition {
            OpacityAnimator {
                duration: Config.animationDuration(150)
                easing.type: Easing.OutCubic
                to: 0
            }
        }
        removeDisplaced: Transition {
            YAnimator {
                duration: Config.animationDuration(320)
                easing.type: Easing.OutQuint
            }
        }
    }
}
