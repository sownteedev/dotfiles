pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

QtObject {
    id: root

    readonly property var pinnedEntries: {
        var available = DesktopEntries.applications.values || [];
        var availableById = {};
        for (var entryIndex = 0; entryIndex < available.length; ++entryIndex) {
            var item = available[entryIndex];
            availableById[item.id] = item;
            if (item.id.endsWith(".desktop"))
                availableById[item.id.slice(0, -8)] = item;
        }

        var entries = [];
        for (var i = 0; i < pinnedIds.length; ++i) {
            var rawId = pinnedIds[i];
            var strippedId = rawId.endsWith(".desktop") ? rawId.slice(0, -8) : rawId;
            var entry = availableById[rawId] || availableById[strippedId] || DesktopEntries.byId(rawId) || DesktopEntries.byId(strippedId);
            if (!entry) {
                for (var shellIndex = 0; shellIndex < shellEntries.length; ++shellIndex) {
                    var shellEntryId = shellEntries[shellIndex].id;
                    if (shellEntryId === rawId || shellEntryId === strippedId) {
                        entry = shellEntries[shellIndex];
                        break;
                    }
                }
            }
            if (entry)
                entries.push(entry);
        }
        return entries;
    }
    property var pinnedIds: []
    readonly property var shellEntries: [
        {
            "id": "sownteeshell-settings",
            "name": qsTr("SownteeShell Settings"),
            "icon": "sownteeshell-settings"
        },
        {
            "id": "sownteeshell-calendar",
            "name": qsTr("SownteeShell Calendar"),
            "icon": "sownteeshell-calendar"
        }
    ]
    property FileView stateFile: FileView {
        atomicWrites: true
        blockLoading: true
        blockWrites: true
        path: root.statePath
        printErrors: false
        watchChanges: false

        onLoadFailed: root.persistState()
        onLoadedChanged: {
            if (loaded)
                root.loadState(text());
        }
        onSaveFailed: error => console.warn("[DockService] Could not save Dock state:", error)
    }
    readonly property string statePath: Config.cacheRoot + "/dock.json"

    function entryId(entryOrId) {
        if (!entryOrId)
            return "";
        if (typeof entryOrId === "string")
            return entryOrId;
        return String(entryOrId.id || "");
    }
    function isPinned(entryOrId) {
        var id = entryId(entryOrId);
        if (id === "")
            return false;
        var stripped = id.endsWith(".desktop") ? id.slice(0, -8) : id;
        return pinnedIds.indexOf(id) !== -1 || pinnedIds.indexOf(stripped) !== -1 || pinnedIds.indexOf(stripped + ".desktop") !== -1;
    }
    function launch(entryOrId) {
        var id = entryId(entryOrId);
        var stripped = id.endsWith(".desktop") ? id.slice(0, -8) : id;
        if (stripped === "sownteeshell-settings") {
            StateManager.showSettingsHub();
            return;
        }
        if (stripped === "sownteeshell-calendar") {
            StateManager.showCalendarApp();
            return;
        }
        var entry = typeof entryOrId === "string" ? (DesktopEntries.byId(id) || DesktopEntries.byId(stripped)) : entryOrId;
        if (entry)
            entry.execute();
    }
    function loadState(rawText) {
        var next = [];
        try {
            var parsed = JSON.parse(String(rawText || "{}"));
            var ids = Array.isArray(parsed) ? parsed : parsed.ids;
            if (Array.isArray(ids)) {
                for (var i = 0; i < ids.length; ++i) {
                    var id = String(ids[i] || "");
                    if (id !== "" && next.indexOf(id) === -1)
                        next.push(id);
                }
            }
        } catch (error) {
            console.warn("[DockService] Ignoring invalid Dock state:", error);
        }
        pinnedIds = next;
    }
    function persistState() {
        stateFile.setText(JSON.stringify({
            "version": 1,
            "ids": pinnedIds
        }) + "\n");
    }
    function pin(entryOrId) {
        var id = entryId(entryOrId);
        if (id === "" || pinnedIds.indexOf(id) !== -1)
            return;
        var next = pinnedIds.slice();
        next.push(id);
        pinnedIds = next;
        persistState();
    }
    function setPinnedOrder(ids) {
        if (!Config.isList(ids))
            return;

        var orderedIds = Config.listOrEmpty(ids);
        var next = [];
        for (var i = 0; i < orderedIds.length; ++i) {
            var id = entryId(orderedIds[i]);
            if (id !== "" && pinnedIds.indexOf(id) !== -1 && next.indexOf(id) === -1)
                next.push(id);
        }
        for (var pinnedIndex = 0; pinnedIndex < pinnedIds.length; ++pinnedIndex) {
            var pinnedId = pinnedIds[pinnedIndex];
            if (next.indexOf(pinnedId) === -1)
                next.push(pinnedId);
        }
        if (JSON.stringify(next) === JSON.stringify(pinnedIds))
            return;
        pinnedIds = next;
        persistState();
    }
    function togglePinned(entryOrId) {
        if (isPinned(entryOrId))
            unpin(entryOrId);
        else
            pin(entryOrId);
    }
    function unpin(entryOrId) {
        var id = entryId(entryOrId);
        var index = pinnedIds.indexOf(id);
        if (index === -1)
            return;
        var next = pinnedIds.slice();
        next.splice(index, 1);
        pinnedIds = next;
        persistState();
    }
}
