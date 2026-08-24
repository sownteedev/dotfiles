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
    property var notificationGroups: []
    property ListModel notifications: ListModel {
    }
    property var pendingNativeUpdates: ({})
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
        if (!n || n.transient || appMatchesList(n.appName, Config.notificationHistoryExcludedApps))
            return;

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

        // 1. Update rawMap FIRST using a shallow copy so the delegate can find the raw notification actions on creation
        rawMap = Object.assign({}, rawMap, {
            [n.id]: n
        });
        connectNativeUpdates(n);
        trackUnread(n);
        // 2. Insert into the ListModel and trigger UI update
        notifications.insert(0, notifData);
        trimToLimit();
        scheduleGroupRebuild();
        saveHistory();
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
            if (rawMap[nid])
                nativeNotifications.push(rawMap[nid]);
        }
        notifications.clear();
        rawMap = {};
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
            if (rawMap[nid])
                nativeNotifications.push(rawMap[nid]);
        }
        // Mutate the model and derived data once. The previous implementation
        // rebuilt every group and serialized history once per removed item.
        for (var modelIndex = notifications.count - 1; modelIndex >= 0; modelIndex--) {
            if (idSet[notifications.get(modelIndex).nid])
                notifications.remove(modelIndex);
        }
        var cleanRawMap = Object.assign({}, rawMap);
        for (var mapIndex = 0; mapIndex < nids.length; mapIndex++) {
            delete cleanRawMap[nids[mapIndex]];
            disconnectNativeUpdates(nids[mapIndex]);
        }
        rawMap = cleanRawMap;
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
    function notificationKeys(notification) {
        return appKeys(notification ? notification.desktopEntry : "", notification ? notification.appName : "");
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
        disconnectNativeUpdates(nid, expectedObject);
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
    function remove(nid) {
        for (var i = 0; i < notifications.count; i++) {
            if (notifications.get(i).nid === nid) {
                notifications.remove(i);
                break;
            }
        }
        var m = Object.assign({}, rawMap);
        delete m[nid];
        rawMap = m;
        removeUnread(nid);
        disconnectNativeUpdates(nid);
        scheduleGroupRebuild();
        saveHistory();
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
            disconnectNativeUpdates(oldestId, oldestNative);
            notifications.remove(notifications.count - 1);
            removeUnread(oldestId);
            // Do not expire the native notification here. A history limit of
            // zero must still allow its popup and actions to live normally.
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
            notifications.remove(index);
            removeUnread(n.id);
            releaseNative(n.id, n);
        } else {
            var oldItem = notifications.get(index);
            notifications.set(index, snapshotFor(n, oldItem.timestamp || Date.now()));
            refreshUnread(n);
        }
        scheduleGroupRebuild();
        saveHistory();
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
