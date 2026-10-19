import QtQuick
import ".."

QtObject {
    id: root

    property string apiKey: ""
    property var attemptedAt: ({})
    property var batchIds: []
    property double batchStartedAt: 0
    readonly property int cacheLifetime: 300000
    property Connections coreConnections: Connections {
        function onReadyChanged() {
            if (CoreService.ready && root.failedIds.length > 0) {
                root.retryAfter = 0;
                root.nextBatch.stop();
                root.retryFailed();
            }
        }

        target: CoreService
    }
    property var counts: ({})
    property bool enabled: false
    property var failedIds: []
    property var fetchedAt: ({})
    required property string field
    readonly property int maxTrackedEntries: 512
    property Timer nextBatch: Timer {
        onTriggered: root.fetchNext()
    }
    property var pendingIds: []
    required property string provider
    property CoreRequest request: CoreRequest {
        onFailed: root.complete(null)
        onSucceeded: response => root.complete(response)
    }
    property double retryAfter: 0
    property var trackedIds: []

    function complete(response) {
        if (response && response.ok) {
            var updated = Object.assign({}, counts);
            for (var item of response.items || []) {
                var itemId = String(item.id || "");
                if (batchIds.indexOf(itemId) >= 0 && validCount(item.count) && !(fetchedAt[itemId] > batchStartedAt)) {
                    updated[itemId] = Number(item.count);
                    fetchedAt[itemId] = Date.now();
                    track(itemId);
                }
            }
            counts = updated;
        } else {
            failedIds = failedIds.concat(batchIds).filter((itemId, index, items) => items.indexOf(itemId) === index);
            retryAfter = Date.now() + 60000;
        }
        batchIds = [];
        pruneCache();
        schedule();
    }
    function countFor(itemId) {
        var value = counts[String(itemId)];
        return value === undefined ? -1 : value;
    }
    function fetchNext() {
        if (!enabled || request.active)
            return;
        var now = Date.now();
        var queue = pendingIds.filter(itemId => !fetchedAt[itemId] || now - fetchedAt[itemId] >= cacheLifetime);
        batchIds = queue.splice(0, provider === "workshop" ? 50 : 12);
        pendingIds = queue;
        if (batchIds.length === 0)
            return;
        batchStartedAt = now;
        for (var itemId of batchIds)
            attemptedAt[itemId] = now;
        request.start("wallpaper." + provider + ".stats", {
            ids: batchIds,
            api_key: apiKey
        }, 35000);
    }
    function observe(items, local) {
        var now = Date.now();
        var updated = Object.assign({}, counts);
        var queue = pendingIds.slice();
        for (var item of items) {
            var itemId = String(item.id || "");
            if (!(provider === "workshop" ? /^[0-9]+$/.test(itemId) : /^[a-z0-9]{6}$/.test(itemId)))
                continue;
            if (!local && validCount(item[field])) {
                updated[itemId] = Number(item[field]);
                fetchedAt[itemId] = now;
                track(itemId);
            } else if ((!fetchedAt[itemId] || now - fetchedAt[itemId] >= cacheLifetime) && (!attemptedAt[itemId] || now - attemptedAt[itemId] >= 60000) && queue.indexOf(itemId) < 0 && batchIds.indexOf(itemId) < 0) {
                queue.push(itemId);
                track(itemId);
            }
        }
        counts = updated;
        pendingIds = queue;
        pruneCache();
        schedule();
    }
    function pruneCache() {
        var uniquePending = [];
        for (var pending of pendingIds) {
            if (uniquePending.indexOf(pending) < 0)
                uniquePending.push(pending);
            if (uniquePending.length >= maxTrackedEntries)
                break;
        }
        pendingIds = uniquePending;
        failedIds = failedIds.filter((itemId, index, items) => items.indexOf(itemId) === index).slice(-maxTrackedEntries);

        var protectedIds = {};
        for (var pendingId of pendingIds)
            protectedIds[pendingId] = true;
        for (var batchId of batchIds)
            protectedIds[batchId] = true;
        for (var failedId of failedIds)
            protectedIds[failedId] = true;

        var next = trackedIds.slice();
        while (next.length > maxTrackedEntries) {
            var removableIndex = -1;
            for (var index = 0; index < next.length; ++index) {
                if (!protectedIds[next[index]]) {
                    removableIndex = index;
                    break;
                }
            }
            if (removableIndex < 0)
                break;

            var itemId = next.splice(removableIndex, 1)[0];
            delete counts[itemId];
            delete attemptedAt[itemId];
            delete fetchedAt[itemId];
        }
        trackedIds = next;
    }
    function retryFailed() {
        if (!enabled || failedIds.length === 0)
            return;
        pendingIds = pendingIds.concat(failedIds).filter((itemId, index, items) => items.indexOf(itemId) === index && batchIds.indexOf(itemId) < 0);
        failedIds = [];
        pruneCache();
        schedule();
    }
    function schedule() {
        if (!enabled || request.active || nextBatch.running || pendingIds.length === 0)
            return;
        nextBatch.interval = Math.max(provider === "workshop" ? 100 : 0, retryAfter - Date.now());
        nextBatch.start();
    }
    function track(itemId) {
        var next = [];
        for (var index = 0; index < trackedIds.length; ++index) {
            if (trackedIds[index] !== itemId)
                next.push(trackedIds[index]);
        }
        next.push(itemId);
        trackedIds = next;
    }
    function validCount(value) {
        return (typeof value === "number" || (typeof value === "string" && value.trim() !== "")) && Number.isSafeInteger(Number(value)) && Number(value) >= 0;
    }

    onEnabledChanged: {
        if (enabled) {
            retryFailed();
            schedule();
        } else {
            nextBatch.stop();
            pendingIds = batchIds.concat(pendingIds);
            batchIds = [];
            request.cancel();
            pruneCache();
        }
    }
}
