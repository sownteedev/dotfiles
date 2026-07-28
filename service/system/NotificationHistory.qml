pragma Singleton
import "../../"
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
                                var loadCount = Math.min(100, list.length);
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
    property var notificationGroups: []
    property ListModel notifications: ListModel {
    }
    property var rawMap: ({})
    property Timer groupRebuildTimer: Timer {
        interval: 16
        repeat: false

        onTriggered: root.rebuildNotificationGroups()
    }
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

    function add(n) {
        // Check if it already exists (update in place)
        var index = -1;
        for (var i = 0; i < notifications.count; i++) {
            if (notifications.get(i).nid === n.id) {
                index = i;
                break;
            }
        }
        var isCritical = n.urgency === 2;
        var notifData = {
            "nid": n.id,
            "appName": n.appName || "",
            "appIcon": n.appIcon || "",
            "summary": n.summary || "",
            "body": n.body || "",
            "image": n.image || "",
            "isCritical": isCritical,
            "timeText": new Date().toLocaleTimeString(Qt.locale(), "hh:mm"),
            "timestamp": Date.now()
        };
        if (index !== -1)
            notifications.remove(index);

        // 1. Update rawMap FIRST using a shallow copy so the delegate can find the raw notification actions on creation
        rawMap = Object.assign({}, rawMap, {
            [n.id]: n
        });
        var notificationId = n.id;
        n.closed.connect(function () {
            root.releaseNative(notificationId, n);
        });
        // 2. Insert into the ListModel and trigger UI update
        notifications.insert(0, notifData);
        // Cap history at 100 items to prevent infinite file/memory growth
        while (notifications.count > 100) {
            var oldestId = notifications.get(notifications.count - 1).nid;
            var cleanRawMap = Object.assign({}, rawMap);
            delete cleanRawMap[oldestId];
            rawMap = cleanRawMap;
            notifications.remove(notifications.count - 1);
        }
        scheduleGroupRebuild();
        saveHistory();
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
        for (var mapIndex = 0; mapIndex < nids.length; mapIndex++)
            delete cleanRawMap[nids[mapIndex]];
        rawMap = cleanRawMap;
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
    function releaseNative(nid, expectedObject) {
        if (!rawMap[nid] || (expectedObject && rawMap[nid] !== expectedObject))
            return;
        var cleanRawMap = Object.assign({}, rawMap);
        delete cleanRawMap[nid];
        rawMap = cleanRawMap;
    }
    function scheduleGroupRebuild() {
        groupRebuildTimer.restart();
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
        scheduleGroupRebuild();
        saveHistory();
    }
    function saveHistory() {
        saveTimer.restart();
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", Config.homeDir + "/.cache/quickshell"])
}
