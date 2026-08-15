pragma Singleton
import "../.."
import QtQuick

QtObject {
    id: root

    property Connections configConnections: Connections {
        function onNotificationShowOnLockChanged() {
            if (!Config.notificationShowOnLock)
                root.clear();
        }

        target: Config
    }
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
        transientNotifications = {};
        for (var i = 0; i < transientObjects.length; ++i) {
            try {
                transientObjects[i].expire();
            } catch (error) {
                console.log("[LockscreenNotification] Transient notification already closed:", error);
            }
        }
    }
    function dismiss(nid, expireTransient) {
        for (var i = 0; i < notifications.count; ++i) {
            if (notifications.get(i).nid === nid) {
                notifications.remove(i);
                break;
            }
        }

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
    function show(notification) {
        if (!notification || !StateManager.sessionLocked || !Config.notificationShowOnLock)
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
            dismiss(notification.id, false);

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

        var limit = Math.max(1, Math.min(3, Config.notificationMaxVisible));
        while (notifications.count > limit)
            dismiss(notifications.get(notifications.count - 1).nid, true);
        return true;
    }
}
