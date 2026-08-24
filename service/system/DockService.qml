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
        for (var entryIndex = 0; entryIndex < available.length; ++entryIndex)
            availableById[available[entryIndex].id] = available[entryIndex];

        var entries = [];
        for (var i = 0; i < pinnedIds.length; ++i) {
            var entry = availableById[pinnedIds[i]] || DesktopEntries.byId(pinnedIds[i]);
            if (entry)
                entries.push(entry);
        }
        return entries;
    }
    property var pinnedIds: []
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
        return id !== "" && pinnedIds.indexOf(id) !== -1;
    }
    function launch(entryOrId) {
        var entry = typeof entryOrId === "string" ? DesktopEntries.byId(entryOrId) : entryOrId;
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
        if (!Array.isArray(ids))
            return;

        var next = [];
        for (var i = 0; i < ids.length; ++i) {
            var id = entryId(ids[i]);
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
