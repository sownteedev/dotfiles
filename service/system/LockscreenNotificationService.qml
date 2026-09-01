pragma Singleton
import "../.."
import QtQuick

QtObject {
    id: root

    property Connections configConnections: Connections {
        function onNotificationLockscreenPrivacyChanged() {
            if (Config.notificationLockscreenPrivacyMode === "hidden")
                root.clear();
        }
        function onNotificationShowOnLockChanged() {
            if (Config.notificationLockscreenPrivacyMode === "hidden")
                root.clear();
        }

        target: Config
    }
    property ListModel groups: ListModel {
    }
    property int groupsRevision: 0
    readonly property int maximumRetained: 100
    property ListModel notifications: ListModel {
    }
    property Connections sessionConnections: Connections {
        function onSessionLockedChanged() {
            if (!StateManager.sessionLocked)
                root.clear();
        }

        target: StateManager
    }
    property var transientNotifications: ({})

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
    function clear() {
        var transientObjects = [];
        for (var nid in transientNotifications) {
            if (transientNotifications[nid])
                transientObjects.push(transientNotifications[nid]);
        }
        notifications.clear();
        groups.clear();
        groupsRevision += 1;
        transientNotifications = {};
        for (var i = 0; i < transientObjects.length; ++i) {
            try {
                transientObjects[i].expire();
            } catch (error) {
                console.log("[LockscreenNotification] Transient notification already closed:", error);
            }
        }
    }
    function dismiss(nid, expireTransient, syncGroups) {
        var removed = false;
        for (var i = 0; i < notifications.count; ++i) {
            if (notifications.get(i).nid === nid) {
                notifications.remove(i);
                removed = true;
                break;
            }
        }

        if (removed && syncGroups !== false)
            rebuildGroups("remove");

        var transientNotification = transientNotifications[nid];
        if (!transientNotification)
            return;
        var remaining = Object.assign({}, transientNotifications);
        delete remaining[nid];
        transientNotifications = remaining;
        if (expireTransient) {
            try {
                transientNotification.expire();
            } catch (error) {
                console.log("[LockscreenNotification] Transient notification already closed:", error);
            }
        }
    }
    function groupKeyFor(notification) {
        var appName = String(notification.appName || "").trim().toLowerCase();
        if (appName !== "")
            return "app:" + appName;

        var appIcon = String(notification.appIcon || "").trim().toLowerCase();
        return appIcon !== "" ? "icon:" + appIcon : "notification";
    }
    function notificationsForGroup(groupKey) {
        var result = [];
        for (var index = 0; index < notifications.count; ++index) {
            var notification = notifications.get(index);
            if (groupKeyFor(notification) !== groupKey)
                continue;

            result.push({
                "nid": notification.nid,
                "appName": notification.appName,
                "appIcon": notification.appIcon,
                "summary": notification.summary,
                "body": notification.body,
                "image": notification.image,
                "isCritical": notification.isCritical
            });
        }
        return result;
    }
    function rebuildGroups(changeKind) {
        var desired = [];
        var byKey = {};
        var nextRevision = groupsRevision + 1;

        for (var notificationIndex = 0; notificationIndex < notifications.count; ++notificationIndex) {
            var notification = notifications.get(notificationIndex);
            var key = groupKeyFor(notification);
            var group = byKey[key];
            if (!group) {
                group = {
                    "groupKey": key,
                    "groupCount": 1,
                    "nid": notification.nid,
                    "appName": notification.appName,
                    "appIcon": notification.appIcon,
                    "summary": notification.summary,
                    "body": notification.body,
                    "image": notification.image,
                    "isCritical": notification.isCritical,
                    "changeKind": changeKind || "sync",
                    "changeRevision": nextRevision
                };
                byKey[key] = group;
                desired.push(group);
            } else {
                group.groupCount += 1;
            }
        }

        for (var targetIndex = 0; targetIndex < desired.length; ++targetIndex) {
            var desiredGroup = desired[targetIndex];
            var existingIndex = -1;
            for (var currentIndex = targetIndex; currentIndex < groups.count; ++currentIndex) {
                if (groups.get(currentIndex).groupKey === desiredGroup.groupKey) {
                    existingIndex = currentIndex;
                    break;
                }
            }

            if (existingIndex < 0) {
                groups.insert(targetIndex, desiredGroup);
                continue;
            }
            if (existingIndex !== targetIndex)
                groups.move(existingIndex, targetIndex, 1);

            var previousGroup = groups.get(targetIndex);
            var changed = previousGroup.nid !== desiredGroup.nid || previousGroup.groupCount !== desiredGroup.groupCount;
            desiredGroup.changeKind = changed ? (changeKind || "sync") : previousGroup.changeKind;
            desiredGroup.changeRevision = changed ? nextRevision : previousGroup.changeRevision;
            groups.set(targetIndex, desiredGroup);
        }

        while (groups.count > desired.length)
            groups.remove(groups.count - 1);
        groupsRevision = nextRevision;
    }
    function show(notification) {
        if (!notification || !StateManager.sessionLocked || Config.notificationLockscreenPrivacyMode === "hidden")
            return;
        if (appMatchesList(notification.appName, Config.notificationBlockedApps))
            return;

        var index = -1;
        for (var i = 0; i < notifications.count; ++i) {
            if (notifications.get(i).nid === notification.id) {
                index = i;
                break;
            }
        }
        var previousTransient = transientNotifications[notification.id];
        if (index >= 0)
            dismiss(notification.id, false, false);

        if (notification.transient) {
            if (previousTransient && previousTransient !== notification) {
                try {
                    previousTransient.expire();
                } catch (error) {
                    console.log("[LockscreenNotification] Replaced transient notification already closed:", error);
                }
            }
            transientNotifications = Object.assign({}, transientNotifications, {
                [notification.id]: notification
            });
        }

        notifications.insert(0, {
            "nid": notification.id,
            "appName": notification.appName || qsTr("Notification"),
            "appIcon": notification.appIcon || "",
            "summary": notification.summary || "",
            "body": notification.body || "",
            "image": notification.image || "",
            "isCritical": notification.urgency === 2
        });

        while (notifications.count > maximumRetained)
            dismiss(notifications.get(notifications.count - 1).nid, true, false);
        rebuildGroups("add");
        return true;
    }
}
