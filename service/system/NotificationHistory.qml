pragma Singleton
import "../../"
import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

QtObject {
    // --- Persistence implementation ---
    // Insert at top (newest first)
    // qsimage URLs only exist for the current process and become
    // invalid after a Quickshell reload.

    id: root

    property Timer clearAllDelayTimer: Timer {
        repeat: false

        onTriggered: root.clearAll()
    }
    property Connections configConnections: Connections {
        function onNotificationHistoryLimitChanged() {
            root.trimToLimit();
            root.pruneNativeRetention();
            root.scheduleGroupRebuild();
            root.saveHistory();
        }

        target: Config
    }
    property Timer groupRebuildTimer: Timer {
        interval: 16
        repeat: false

        onTriggered: root.rebuildNotificationGroups()
    }
    property FileView historyFile: FileView {
        id: historyFile

        atomicWrites: true
        blockLoading: true
        path: root.historyPath
        watchChanges: false

        onLoadedChanged: {
            if (loaded) {
                try {
                    var storedText = text().trim();
                    if (storedText !== "") {
                        var legacyBase64 = !storedText.startsWith("[");
                        var jsonText = legacyBase64 ? b64_to_utf8(storedText) : storedText;
                        if (jsonText !== "") {
                            var list = JSON.parse(jsonText);
                            if (Array.isArray(list)) {
                                // Defend against an old or externally modified file
                                // exceeding the same cap used by add().
                                var loadCount = Math.min(Config.notificationHistoryLimit, list.length);
                                for (var i = 0; i < loadCount; i++) {
                                    var item = list[i];
                                    if (String(item.image || "").startsWith("image://qsimage/"))
                                        item.image = "";

                                    if (String(item.appIcon || "").startsWith("image://qsimage/"))
                                        item.appIcon = "";

                                    item.nid = -(i + 1); // Assign a negative temporary ID to prevent conflict with new notifications
                                    item.timestamp = item.timestamp || Date.now();
                                    notifications.append(item);
                                }
                                rebuildNotificationGroups();
                                // Migrate the old base64 format once. Subsequent
                                // reloads read plain JSON and avoid deprecated Qt.atob.
                                if (legacyBase64)
                                    saveHistory();
                            }
                        }
                    }
                } catch (e) {
                    console.log("[NotificationHistory] Failed to parse history:", e);
                }
            }
        }
    }
    readonly property string historyPath: Config.homeDir + "/.cache/quickshell/notifications.json"
    property var nativeConnections: ({})
    property var nativeRetainedAt: ({})
    readonly property int nativeRetentionLimit: Math.max(0, Math.min(24, Config.notificationHistoryLimit))
    property Timer nativeRetentionTimer: Timer {
        interval: 60000
        repeat: true
        running: Object.keys(root.rawMap).length > 0

        onTriggered: root.pruneNativeRetention()
    }
    readonly property int nativeRetentionTtlMs: 30 * 60 * 1000
    property var notificationGroups: []
    property ListModel notifications: ListModel {
    }
    property var pendingNativeUpdates: ({})
    property var popupOwners: ({})
    property var rawMap: ({})
    property Timer saveTimer: Timer {
        id: saveTimer

        interval: 100
        repeat: false

        onTriggered: {
            var list = [];
            for (var i = 0; i < notifications.count; i++) {
                var item = notifications.get(i);
                list.push({
                    "nid": item.nid,
                    "appName": item.appName,
                    "appIcon": String(item.appIcon || "").startsWith("image://qsimage/") ? "" : item.appIcon,
                    "summary": item.summary,
                    "body": item.body,
                    "image": String(item.image || "").startsWith("image://qsimage/") ? "" : item.image,
                    "isCritical": item.isCritical,
                    "timeText": item.timeText,
                    "timestamp": item.timestamp || Date.now()
                });
            }
            historyFile.setText(JSON.stringify(list));
        }
    }
    property var unreadNotifications: []
    property Timer updateTimer: Timer {
        interval: 0
        repeat: false

        onTriggered: root.flushNativeUpdates()
    }
    property Connections workspaceConnections: Connections {
        function onActiveWindowByOutputChanged() {
            root.clearUnreadForFocusedWindows();
        }

        target: WorkspaceService
    }

    function add(n) {
        // Transient notifications are intentionally popup-only and must not be
        // retained or serialized in the notification centre.
        if (!n)
            return;
        if (n.transient || appMatchesList(n.appName, Config.notificationHistoryExcludedApps)) {
            if (!n.transient) {
                Qt.callLater(function () {
                    root.releaseUnownedNative(n.id, n);
                });
            }
            return;
        }

        // Check if it already exists (update in place)
        var index = -1;
        for (var i = 0; i < notifications.count; i++) {
            if (notifications.get(i).nid === n.id) {
                index = i;
                break;
            }
        }
        var notifData = snapshotFor(n, Date.now());
        if (index !== -1)
            notifications.remove(index);

        var previousNative = rawMap[n.id];
        if (previousNative && previousNative !== n && pendingNativeUpdates[n.id] !== undefined) {
            var remainingUpdates = Object.assign({}, pendingNativeUpdates);
            delete remainingUpdates[n.id];
            pendingNativeUpdates = remainingUpdates;
        }
        // 1. Update rawMap FIRST using a shallow copy so the delegate can find the raw notification actions on creation
        rawMap = Object.assign({}, rawMap, {
            [n.id]: n
        });
        markNativeRetention(n);
        connectNativeUpdates(n);
        trackUnread(n);
        // 2. Insert into the ListModel and trigger UI update
        notifications.insert(0, notifData);
        trimToLimit();
        scheduleGroupRebuild();
        saveHistory();
        Qt.callLater(function () {
            if (previousNative && previousNative !== n)
                root.releaseUnownedNative(n.id, previousNative);
            root.releaseUnownedNative(n.id, n);
            root.pruneNativeRetention();
        });
    }
    function addAppKey(keys, value) {
        var rawValue = String(value || "").trim().toLowerCase();
        if (rawValue === "")
            return;

        var baseName = rawValue.replace(/^.*[\\/]/, "");
        var normalized = baseName.replace(/[^a-z0-9]/g, "");
        if (normalized !== "" && keys.indexOf(normalized) === -1)
            keys.push(normalized);
    }
    function addDesktopEntryKeys(keys, value) {
        var rawValue = String(value || "").trim();
        if (rawValue === "")
            return;

        var baseName = rawValue.replace(/^.*[\\/]/, "");
        var candidates = [baseName];
        if (baseName.toLowerCase().endsWith(".desktop"))
            candidates.push(baseName.slice(0, -8));

        var entry = null;
        for (var i = 0; i < candidates.length && !entry; ++i)
            entry = DesktopEntries.byId(candidates[i]);
        for (var lookupIndex = 0; lookupIndex < candidates.length && !entry; ++lookupIndex)
            entry = DesktopEntries.heuristicLookup(candidates[lookupIndex]);
        if (!entry)
            return;
        addAppKey(keys, entry.id);
        addAppKey(keys, entry.name);
    }
    function appKeys(identity, displayName) {
        var keys = [];
        addAppKey(keys, identity);
        addAppKey(keys, displayName);
        addDesktopEntryKeys(keys, identity);
        addDesktopEntryKeys(keys, displayName);
        return keys;
    }
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
    function b64_to_utf8(str) {
        try {
            return decodeURIComponent(Qt.atob(str).split('').map(function (c) {
                var code = c.charCodeAt(0);
                return '%' + (code < 16 ? '0' : '') + code.toString(16);
            }).join(''));
        } catch (e) {
            return "";
        }
    }
    function clearAll() {
        var nativeNotifications = [];
        for (var nid in rawMap) {
            if (rawMap[nid]) {
                nativeNotifications.push(rawMap[nid]);
                forgetPopupOwner(nid, rawMap[nid]);
            }
        }
        notifications.clear();
        rawMap = {};
        nativeRetainedAt = {};
        pendingNativeUpdates = {};
        unreadNotifications = [];
        var connectionIds = Object.keys(nativeConnections);
        for (var connectionIndex = 0; connectionIndex < connectionIds.length; ++connectionIndex)
            disconnectNativeUpdates(connectionIds[connectionIndex]);
        scheduleGroupRebuild();
        saveHistory();
        for (var i = 0; i < nativeNotifications.length; i++) {
            try {
                nativeNotifications[i].dismiss();
            } catch (e) {
                console.log("[NotificationHistory] Object already dismissed:", e);
            }
        }
    }
    function clearAllAfter(delayMs) {
        clearAllDelayTimer.interval = Math.max(0, delayMs);
        clearAllDelayTimer.restart();
    }
    function clearUnreadForFocusedWindows() {
        var next = [];
        for (var i = 0; i < root.unreadNotifications.length; ++i) {
            var unread = root.unreadNotifications[i];
            if (!isNotificationAppFocused(unread))
                next.push(unread);
        }
        if (next.length !== root.unreadNotifications.length)
            root.unreadNotifications = next;
    }
    function connectNativeUpdates(n) {
        if (!n)
            return;

        var notificationId = n.id;
        var existing = nativeConnections[notificationId];
        if (existing && existing.object === n)
            return;
        if (existing)
            disconnectNativeUpdates(notificationId, existing.object);

        var schedule = function () {
            root.scheduleNativeUpdate(n);
        };
        var closed = function () {
            root.releaseNative(notificationId, n);
        };
        n.closed.connect(closed);
        n.appNameChanged.connect(schedule);
        n.appIconChanged.connect(schedule);
        n.summaryChanged.connect(schedule);
        n.bodyChanged.connect(schedule);
        n.imageChanged.connect(schedule);
        n.urgencyChanged.connect(schedule);
        n.actionsChanged.connect(schedule);
        n.transientChanged.connect(schedule);
        n.desktopEntryChanged.connect(schedule);

        var nextConnections = Object.assign({}, nativeConnections);
        nextConnections[notificationId] = {
            "closed": closed,
            "object": n,
            "schedule": schedule
        };
        nativeConnections = nextConnections;
    }
    function disconnectNativeUpdates(nid, expectedObject) {
        var connection = nativeConnections[nid];
        if (!connection || expectedObject && connection.object !== expectedObject)
            return;

        var n = connection.object;
        if (n) {
            try {
                n.closed.disconnect(connection.closed);
                n.appNameChanged.disconnect(connection.schedule);
                n.appIconChanged.disconnect(connection.schedule);
                n.summaryChanged.disconnect(connection.schedule);
                n.bodyChanged.disconnect(connection.schedule);
                n.imageChanged.disconnect(connection.schedule);
                n.urgencyChanged.disconnect(connection.schedule);
                n.actionsChanged.disconnect(connection.schedule);
                n.transientChanged.disconnect(connection.schedule);
                n.desktopEntryChanged.disconnect(connection.schedule);
            } catch (error) {
                // The notification may already have been destroyed natively.
            }
        }

        var nextConnections = Object.assign({}, nativeConnections);
        delete nextConnections[nid];
        nativeConnections = nextConnections;
    }
    function dismiss(nid) {
        dismissMany([nid]);
    }
    function dismissMany(nids) {
        if (!nids || nids.length === 0)
            return;

        var idSet = {};
        var nativeNotifications = [];
        for (var i = 0; i < nids.length; i++) {
            var nid = nids[i];
            idSet[nid] = true;
            var popupOwner = popupOwners[nid];
            var nativeNotification = rawMap[nid] || (popupOwner ? popupOwner.object : null);
            if (nativeNotification && nativeNotifications.indexOf(nativeNotification) < 0)
                nativeNotifications.push(nativeNotification);
        }
        // Mutate the model and derived data once. The previous implementation
        // rebuilt every group and serialized history once per removed item.
        for (var modelIndex = notifications.count - 1; modelIndex >= 0; modelIndex--) {
            if (idSet[notifications.get(modelIndex).nid])
                notifications.remove(modelIndex);
        }
        var cleanRawMap = Object.assign({}, rawMap);
        var cleanRetainedAt = Object.assign({}, nativeRetainedAt);
        for (var mapIndex = 0; mapIndex < nids.length; mapIndex++) {
            var owner = popupOwners[nids[mapIndex]];
            forgetPopupOwner(nids[mapIndex], rawMap[nids[mapIndex]] || (owner ? owner.object : null));
            delete cleanRawMap[nids[mapIndex]];
            delete cleanRetainedAt[nids[mapIndex]];
            disconnectNativeUpdates(nids[mapIndex]);
        }
        rawMap = cleanRawMap;
        nativeRetainedAt = cleanRetainedAt;
        removeUnreadMany(nids);
        scheduleGroupRebuild();
        saveHistory();
        for (var nativeIndex = 0; nativeIndex < nativeNotifications.length; nativeIndex++) {
            try {
                nativeNotifications[nativeIndex].dismiss();
            } catch (e) {
                console.log("[NotificationHistory] Object already dismissed:", e);
            }
        }
    }
    function flushNativeUpdates() {
        var updates = pendingNativeUpdates;
        pendingNativeUpdates = {};
        for (var nid in updates)
            updateFromNative(updates[nid]);
    }
    function forgetPopupOwner(nid, expectedObject) {
        var owner = popupOwners[nid];
        if (!owner || expectedObject && owner.object !== expectedObject)
            return;

        var nextOwners = Object.assign({}, popupOwners);
        delete nextOwners[nid];
        popupOwners = nextOwners;
    }
    function hasInteractiveActions(notification) {
        if (!notification)
            return false;
        try {
            return Boolean(notification.hasInlineReply || notification.actions && notification.actions.length > 0);
        } catch (error) {
            return false;
        }
    }
    function isNotificationAppFocused(notification) {
        var keys = notificationKeys(notification);
        if (keys.length === 0)
            return false;
        var focusedWindows = WorkspaceService.activeWindowByOutput || {};
        for (var outputName in focusedWindows) {
            if (keysIntersect(keys, windowKeys(focusedWindows[outputName])))
                return true;
        }
        return false;
    }
    function keysIntersect(first, second) {
        for (var i = 0; i < first.length; ++i) {
            if (second.indexOf(first[i]) !== -1)
                return true;
        }
        return false;
    }
    function markNativeRetention(notification) {
        if (!notification)
            return;

        var retained = Object.assign({}, nativeRetainedAt);
        if (hasInteractiveActions(notification))
            retained[notification.id] = Date.now();
        else
            delete retained[notification.id];
        nativeRetainedAt = retained;
    }
    function notificationKeys(notification) {
        return appKeys(notification ? notification.desktopEntry : "", notification ? notification.appName : "");
    }
    function pruneNativeRetention() {
        var now = Date.now();
        var candidates = [];
        for (var key in rawMap) {
            var notification = rawMap[key];
            if (!notification || !hasInteractiveActions(notification))
                continue;

            var nid = Number(key);
            var owner = popupOwners[nid];
            if (owner && owner.object === notification && Number(owner.count || 0) > 0)
                continue;

            candidates.push({
                "nid": nid,
                "notification": notification,
                "retainedAt": Number(nativeRetainedAt[nid] || now)
            });
        }
        candidates.sort(function (left, right) {
            return right.retainedAt - left.retainedAt;
        });
        for (var i = 0; i < candidates.length; ++i) {
            var candidate = candidates[i];
            if (i >= nativeRetentionLimit || now - candidate.retainedAt >= nativeRetentionTtlMs)
                releaseRetainedNative(candidate.nid, candidate.notification);
        }
    }
    function rebuildNotificationGroups() {
        var groups = [];
        var groupIndexes = {};
        for (var i = 0; i < notifications.count; i++) {
            var item = notifications.get(i);
            var name = item.appName || "Notification";
            var groupIndex = groupIndexes[name];
            if (groupIndex === undefined) {
                groupIndex = groups.length;
                groupIndexes[name] = groupIndex;
                groups.push({
                    "appName": name,
                    "notifications": []
                });
            }
            // Do not retain ListModel.get() wrappers in the JS grouping model.
            // Plain snapshots are cheaper for delegates and let old groups be
            // collected immediately after a rebuild.
            groups[groupIndex].notifications.push({
                "nid": item.nid,
                "appName": item.appName,
                "appIcon": item.appIcon,
                "summary": item.summary,
                "body": item.body,
                "image": item.image,
                "isCritical": item.isCritical,
                "timeText": item.timeText,
                "timestamp": item.timestamp
            });
        }
        notificationGroups = groups;
    }
    function refreshUnread(notification) {
        if (!notification)
            return;
        for (var i = 0; i < root.unreadNotifications.length; ++i) {
            if (root.unreadNotifications[i].nid === notification.id) {
                if (isNotificationAppFocused(notification)) {
                    removeUnread(notification.id);
                } else {
                    var next = root.unreadNotifications.slice();
                    next[i] = {
                        "nid": notification.id,
                        "desktopEntry": String(notification.desktopEntry || ""),
                        "appName": String(notification.appName || "")
                    };
                    root.unreadNotifications = next;
                }
                return;
            }
        }
    }
    function releaseNative(nid, expectedObject) {
        var trackedObject = rawMap[nid];
        if (expectedObject && trackedObject && trackedObject !== expectedObject)
            return;
        forgetPopupOwner(nid, expectedObject);
        disconnectNativeUpdates(nid, expectedObject);
        var retained = Object.assign({}, nativeRetainedAt);
        delete retained[nid];
        nativeRetainedAt = retained;
        if (!trackedObject)
            return;
        if (pendingNativeUpdates[nid] !== undefined) {
            var remainingUpdates = Object.assign({}, pendingNativeUpdates);
            delete remainingUpdates[nid];
            pendingNativeUpdates = remainingUpdates;
        }
        var cleanRawMap = Object.assign({}, rawMap);
        delete cleanRawMap[nid];
        rawMap = cleanRawMap;
    }
    function releasePopup(nid, expectedObject) {
        var owner = popupOwners[nid];
        if (!owner || expectedObject && owner.object !== expectedObject)
            return;

        var nextOwners = Object.assign({}, popupOwners);
        var remaining = Math.max(0, Number(owner.count || 1) - 1);
        if (remaining > 0) {
            nextOwners[nid] = {
                "count": remaining,
                "object": owner.object
            };
        } else {
            delete nextOwners[nid];
        }
        popupOwners = nextOwners;
        if (remaining === 0) {
            Qt.callLater(function () {
                root.releaseUnownedNative(nid, owner.object);
                root.pruneNativeRetention();
            });
        }
    }
    function releaseRetainedNative(nid, notification) {
        if (!notification)
            return;
        var owner = popupOwners[nid];
        if (owner && owner.object === notification && Number(owner.count || 0) > 0)
            return;

        releaseNative(nid, notification);
        try {
            if (notification.tracked)
                notification.expire();
        } catch (error) {
            console.log("[NotificationHistory] Native notification already closed:", error);
        }
    }
    function releaseUnownedNative(nid, notification) {
        if (!notification)
            return;

        var owner = popupOwners[nid];
        if (owner && owner.object === notification && Number(owner.count || 0) > 0)
            return;
        if (rawMap[nid] === notification && hasInteractiveActions(notification))
            return;

        try {
            if (notification.tracked)
                notification.expire();
        } catch (error) {
            console.log("[NotificationHistory] Native notification already closed:", error);
        }
    }
    function remove(nid) {
        var nativeNotification = rawMap[nid];
        for (var i = 0; i < notifications.count; i++) {
            if (notifications.get(i).nid === nid) {
                notifications.remove(i);
                break;
            }
        }
        var m = Object.assign({}, rawMap);
        delete m[nid];
        rawMap = m;
        var retained = Object.assign({}, nativeRetainedAt);
        delete retained[nid];
        nativeRetainedAt = retained;
        removeUnread(nid);
        disconnectNativeUpdates(nid);
        scheduleGroupRebuild();
        saveHistory();
        releaseUnownedNative(nid, nativeNotification);
    }
    function removeUnread(nid) {
        var next = [];
        for (var i = 0; i < root.unreadNotifications.length; ++i) {
            if (root.unreadNotifications[i].nid !== nid)
                next.push(root.unreadNotifications[i]);
        }
        if (next.length !== root.unreadNotifications.length)
            root.unreadNotifications = next;
    }
    function removeUnreadMany(nids) {
        if (!nids || nids.length === 0)
            return;
        var idSet = {};
        for (var i = 0; i < nids.length; ++i)
            idSet[nids[i]] = true;
        var next = [];
        for (var unreadIndex = 0; unreadIndex < root.unreadNotifications.length; ++unreadIndex) {
            if (!idSet[root.unreadNotifications[unreadIndex].nid])
                next.push(root.unreadNotifications[unreadIndex]);
        }
        if (next.length !== root.unreadNotifications.length)
            root.unreadNotifications = next;
    }
    function retainPopup(notification) {
        if (!notification)
            return;

        var nid = notification.id;
        var owner = popupOwners[nid];
        var nextOwners = Object.assign({}, popupOwners);
        nextOwners[nid] = {
            "count": owner && owner.object === notification ? Number(owner.count || 0) + 1 : 1,
            "object": notification
        };
        popupOwners = nextOwners;
    }
    function saveHistory() {
        saveTimer.restart();
    }
    function scheduleGroupRebuild() {
        groupRebuildTimer.restart();
    }
    function scheduleNativeUpdate(n) {
        if (!n)
            return;
        var updates = Object.assign({}, pendingNativeUpdates);
        updates[n.id] = n;
        pendingNativeUpdates = updates;
        updateTimer.restart();
    }
    function snapshotFor(n, timestamp) {
        return {
            "nid": n.id,
            "appName": n.appName || "",
            "appIcon": n.appIcon || "",
            "summary": n.summary || "",
            "body": n.body || "",
            "image": n.image || "",
            "isCritical": n.urgency === 2,
            "timeText": new Date(timestamp).toLocaleTimeString(Qt.locale(), "hh:mm"),
            "timestamp": timestamp
        };
    }
    function trackUnread(notification) {
        if (!notification)
            return;
        var next = [];
        for (var i = 0; i < root.unreadNotifications.length; ++i) {
            if (root.unreadNotifications[i].nid !== notification.id)
                next.push(root.unreadNotifications[i]);
        }
        if (!isNotificationAppFocused(notification)) {
            next.push({
                "nid": notification.id,
                "desktopEntry": String(notification.desktopEntry || ""),
                "appName": String(notification.appName || "")
            });
        }
        root.unreadNotifications = next;
    }
    function trimToLimit() {
        var limit = Math.max(0, Config.notificationHistoryLimit);
        while (notifications.count > limit) {
            var oldestId = notifications.get(notifications.count - 1).nid;
            var oldestNative = rawMap[oldestId];
            var cleanRawMap = Object.assign({}, rawMap);
            delete cleanRawMap[oldestId];
            rawMap = cleanRawMap;
            var retained = Object.assign({}, nativeRetainedAt);
            delete retained[oldestId];
            nativeRetainedAt = retained;
            disconnectNativeUpdates(oldestId, oldestNative);
            notifications.remove(notifications.count - 1);
            removeUnread(oldestId);
            if (pendingNativeUpdates[oldestId] !== undefined) {
                var remainingUpdates = Object.assign({}, pendingNativeUpdates);
                delete remainingUpdates[oldestId];
                pendingNativeUpdates = remainingUpdates;
            }
            // A visible popup remains an owner until its exit animation ends.
            // Otherwise the native object can be released immediately.
            releaseUnownedNative(oldestId, oldestNative);
        }
    }
    function unreadCountForEntry(entryId, appName) {
        var unread = root.unreadNotifications;
        var entryKeys = appKeys(entryId, appName);
        var count = 0;
        for (var i = 0; i < unread.length; ++i) {
            if (keysIntersect(entryKeys, notificationKeys(unread[i])))
                ++count;
        }
        return count;
    }
    function updateFromNative(n) {
        if (!n)
            return;

        var index = -1;
        for (var i = 0; i < notifications.count; i++) {
            if (notifications.get(i).nid === n.id) {
                index = i;
                break;
            }
        }
        if (index < 0)
            return;

        if (n.transient) {
            remove(n.id);
            return;
        } else {
            var oldItem = notifications.get(index);
            notifications.set(index, snapshotFor(n, oldItem.timestamp || Date.now()));
            markNativeRetention(n);
            refreshUnread(n);
        }
        scheduleGroupRebuild();
        saveHistory();
        Qt.callLater(function () {
            root.releaseUnownedNative(n.id, n);
            root.pruneNativeRetention();
        });
    }
    function windowKeys(windowData) {
        if (!windowData)
            return [];
        var appId = String(windowData.app_id || "");
        return appKeys(appId, appId === "" ? windowData.title : "");
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", Config.homeDir + "/.cache/quickshell"])
    Component.onDestruction: {
        var connectionIds = Object.keys(nativeConnections);
        for (var i = 0; i < connectionIds.length; ++i)
            disconnectNativeUpdates(connectionIds[i]);
    }
}
