pragma Singleton

import QtQuick
import Quickshell.Io
import "../../"

QtObject {
    id: root

    property var groups: []
    property FileView stateFile: FileView {
        atomicWrites: true
        blockLoading: true
        blockWrites: true
        path: root.statePath
        printErrors: false
        watchChanges: false

        onLoadFailed: root.persistState()
        onSaveFailed: error => console.warn("[LauncherGroupService] Could not save app folders:", error)
    }
    readonly property string statePath: Config.cacheRoot + "/launcher-groups.json"

    function addApp(groupId, appId) {
        var normalizedGroupId = String(groupId || "");
        var normalizedAppId = String(appId || "");
        var targetGroup = groupById(normalizedGroupId);
        if (!targetGroup || normalizedAppId === "" || targetGroup.appIds.indexOf(normalizedAppId) !== -1)
            return false;

        var next = [];
        for (var index = 0; index < groups.length; ++index) {
            var group = groups[index];
            var ids = group.appIds.slice();
            if (group.id === normalizedGroupId) {
                ids.push(normalizedAppId);
            } else {
                var existingIndex = ids.indexOf(normalizedAppId);
                if (existingIndex !== -1)
                    ids.splice(existingIndex, 1);
            }

            if (ids.length >= 2) {
                next.push({
                    "appIds": ids,
                    "id": group.id,
                    "name": group.name
                });
            }
        }

        groups = next;
        persistState();
        return true;
    }
    function createGroup(firstAppId, secondAppId) {
        var firstId = String(firstAppId || "");
        var secondId = String(secondAppId || "");
        if (firstId === "" || secondId === "" || firstId === secondId)
            return "";

        var secondGroup = groupForApp(secondId);
        if (secondGroup) {
            addApp(secondGroup.id, firstId);
            return secondGroup.id;
        }

        var firstGroup = groupForApp(firstId);
        if (firstGroup) {
            addApp(firstGroup.id, secondId);
            return firstGroup.id;
        }

        var groupId = uniqueGroupId();
        var next = groups.slice();
        next.push({
            "appIds": [firstId, secondId],
            "id": groupId,
            "name": qsTr("Apps")
        });
        groups = next;
        persistState();
        return groupId;
    }
    function dissolveGroup(groupId) {
        var normalizedGroupId = String(groupId || "");
        var next = groups.filter(function (group) {
            return group.id !== normalizedGroupId;
        });
        if (next.length === groups.length)
            return false;
        groups = next;
        persistState();
        return true;
    }
    function groupById(groupId) {
        var normalizedGroupId = String(groupId || "");
        for (var index = 0; index < groups.length; ++index) {
            if (groups[index].id === normalizedGroupId)
                return groups[index];
        }
        return null;
    }
    function groupForApp(appId) {
        var normalizedAppId = String(appId || "");
        if (normalizedAppId === "")
            return null;
        for (var index = 0; index < groups.length; ++index) {
            if (groups[index].appIds.indexOf(normalizedAppId) !== -1)
                return groups[index];
        }
        return null;
    }
    function loadState(rawText) {
        var next = [];
        var usedAppIds = {};
        var usedGroupIds = {};

        try {
            var parsed = JSON.parse(String(rawText || "{}"));
            var sourceGroups = Array.isArray(parsed) ? parsed : parsed.groups;
            if (!Array.isArray(sourceGroups))
                sourceGroups = [];

            for (var groupIndex = 0; groupIndex < sourceGroups.length; ++groupIndex) {
                var sourceGroup = sourceGroups[groupIndex] || {};
                var sourceIds = Array.isArray(sourceGroup.appIds) ? sourceGroup.appIds : [];
                var appIds = [];
                var localAppIds = {};
                for (var appIndex = 0; appIndex < sourceIds.length; ++appIndex) {
                    var appId = String(sourceIds[appIndex] || "");
                    if (appId === "" || usedAppIds[appId] || localAppIds[appId])
                        continue;
                    localAppIds[appId] = true;
                    appIds.push(appId);
                }
                if (appIds.length < 2)
                    continue;

                for (var usedIndex = 0; usedIndex < appIds.length; ++usedIndex)
                    usedAppIds[appIds[usedIndex]] = true;

                var groupId = String(sourceGroup.id || "");
                if (groupId === "" || usedGroupIds[groupId])
                    groupId = uniqueGroupIdForMap(usedGroupIds);
                usedGroupIds[groupId] = true;

                var name = String(sourceGroup.name || "").trim();
                next.push({
                    "appIds": appIds,
                    "id": groupId,
                    "name": name === "" ? qsTr("Apps") : name
                });
            }
        } catch (error) {
            console.warn("[LauncherGroupService] Ignoring invalid app folder state:", error);
        }

        groups = next;
    }
    function persistState() {
        stateFile.setText(JSON.stringify({
            "groups": groups,
            "version": 1
        }) + "\n");
    }
    function removeApp(groupId, appId) {
        var normalizedGroupId = String(groupId || "");
        var normalizedAppId = String(appId || "");
        var changed = false;
        var next = [];

        for (var index = 0; index < groups.length; ++index) {
            var group = groups[index];
            if (group.id !== normalizedGroupId) {
                next.push(group);
                continue;
            }

            var ids = group.appIds.slice();
            var appIndex = ids.indexOf(normalizedAppId);
            if (appIndex === -1) {
                next.push(group);
                continue;
            }

            changed = true;
            ids.splice(appIndex, 1);
            if (ids.length >= 2) {
                next.push({
                    "appIds": ids,
                    "id": group.id,
                    "name": group.name
                });
            }
        }

        if (!changed)
            return false;
        groups = next;
        persistState();
        return true;
    }
    function renameGroup(groupId, name) {
        var normalizedGroupId = String(groupId || "");
        var normalizedName = String(name || "").trim();
        if (normalizedName === "")
            return false;

        var changed = false;
        var next = [];
        for (var index = 0; index < groups.length; ++index) {
            var group = groups[index];
            if (group.id === normalizedGroupId && group.name !== normalizedName) {
                changed = true;
                next.push({
                    "appIds": group.appIds.slice(),
                    "id": group.id,
                    "name": normalizedName
                });
            } else {
                next.push(group);
            }
        }

        if (!changed)
            return false;
        groups = next;
        persistState();
        return true;
    }
    function uniqueGroupId() {
        var used = {};
        for (var index = 0; index < groups.length; ++index)
            used[groups[index].id] = true;
        return uniqueGroupIdForMap(used);
    }
    function uniqueGroupIdForMap(usedIds) {
        var base = "folder-" + Date.now();
        var candidate = base;
        var suffix = 1;
        while (usedIds[candidate]) {
            candidate = base + "-" + suffix;
            ++suffix;
        }
        return candidate;
    }

    Component.onCompleted: loadState(stateFile.text())
}
