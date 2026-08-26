pragma Singleton
import ".."
import "../../"
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property bool accountConfigured: Config.wallhavenUsername.trim() !== "" && Config.wallhavenApiKey.trim() !== ""
    property string atleast: ""
    readonly property bool busy: searching || loadingCollections || loadingCollection || downloading || listingInstalled || removing
    property string categories: "111"
    property string collectionErrorMessage: ""
    property int collectionLastPage: 1
    property int collectionPage: 1
    property string collectionPendingId: ""
    property string collectionPendingLabel: ""
    property int collectionPendingPage: 1
    property Process collectionProcess: Process {
        property bool launchPending: false
        property int requestGeneration: -1
        property string requestJson: "{}"

        command: ["python3", "-u", root.helperPath, "collection"]
        stdinEnabled: true

        stderr: StdioCollector {
            id: collectionError
        }
        stdout: StdioCollector {
            id: collectionOutput
        }

        onExited: (exitCode, exitStatus) => {
            if (!root.requestIsCurrent(collectionProcess)) {
                root.runPendingCollection();
                return;
            }
            var response = root.parseResponse(collectionOutput.text, collectionError.text, qsTr("Could not load this Wallhaven collection"));
            var superseded = root.collectionRefreshPending;
            if (superseded) {
                root.runPendingCollection();
                return;
            }
            if (exitCode !== 0 || !response.ok) {
                root.collectionErrorMessage = response.message || qsTr("Could not load this Wallhaven collection");
            } else {
                root.collectionErrorMessage = "";
                root.replaceModel(root.collectionResults, response.items);
                root.collectionPage = Number(response.current_page || 1);
                root.collectionLastPage = Number(response.last_page || 1);
                root.collectionTotalResults = Number(response.total || root.collectionResults.count);
            }
            root.runPendingCollection();
        }
        onRunningChanged: {
            if (!running && launchPending) {
                launchPending = false;
                if (!root.requestIsCurrent(collectionProcess)) {
                    root.runPendingCollection();
                    return;
                }
                root.collectionErrorMessage = qsTr("Could not start the Wallhaven collection request");
                root.runPendingCollection();
            }
        }
        onStarted: {
            launchPending = false;
            if (!root.requestIsCurrent(collectionProcess)) {
                requestJson = "{}";
                running = false;
                return;
            }
            write(requestJson + "\n");
            requestJson = "{}";
        }
    }
    property bool collectionRefreshPending: false
    property ListModel collectionResults: ListModel {
        dynamicRoles: true
    }
    property int collectionTotalResults: 0
    property ListModel collections: ListModel {
        dynamicRoles: true
    }
    property bool collectionsLoaded: false
    property Process collectionsProcess: Process {
        property bool launchPending: false
        property int requestGeneration: -1
        property string requestJson: "{}"

        command: ["python3", "-u", root.helperPath, "collections"]
        stdinEnabled: true

        stderr: StdioCollector {
            id: collectionsError
        }
        stdout: StdioCollector {
            id: collectionsOutput
        }

        onExited: (exitCode, exitStatus) => {
            if (!root.requestIsCurrent(collectionsProcess)) {
                root.restartCollectionsLoadIfPending();
                return;
            }
            var response = root.parseResponse(collectionsOutput.text, collectionsError.text, qsTr("Could not load Wallhaven collections"));
            if (root.collectionsRefreshPending) {
                root.restartCollectionsLoadIfPending();
                return;
            }
            if (exitCode !== 0 || !response.ok) {
                root.collectionErrorMessage = response.message || qsTr("Could not load Wallhaven collections");
                return;
            }
            root.collectionErrorMessage = "";
            root.collectionsLoaded = true;
            root.replaceModel(root.collections, response.items);
            if (root.collections.count === 0) {
                root.selectedCollectionId = "";
                root.selectedCollectionLabel = "";
                root.collectionTotalResults = 0;
                root.collectionResults.clear();
                return;
            }
            if (root.modelIndexForId(root.collections, root.selectedCollectionId) < 0) {
                var first = root.collections.get(0);
                root.selectedCollectionId = String(first.id || "");
                root.selectedCollectionLabel = String(first.label || "");
            }
            root.loadCollection(root.selectedCollectionId, root.selectedCollectionLabel, 1);
        }
        onRunningChanged: {
            if (!running && launchPending) {
                launchPending = false;
                if (!root.requestIsCurrent(collectionsProcess)) {
                    root.restartCollectionsLoadIfPending();
                    return;
                }
                root.collectionErrorMessage = qsTr("Could not start the Wallhaven collection request");
                root.restartCollectionsLoadIfPending();
            }
        }
        onStarted: {
            launchPending = false;
            if (!root.requestIsCurrent(collectionsProcess)) {
                requestJson = "{}";
                running = false;
                return;
            }
            write(requestJson + "\n");
            requestJson = "{}";
        }
    }
    property bool collectionsRefreshPending: false
    property string colors: ""
    property Connections configConnections: Connections {
        function onWallhavenApiKeyChanged() {
            root.collectionsLoaded = false;
            root.collections.clear();
            root.collectionResults.clear();
            root.collectionTotalResults = 0;
        }
        function onWallhavenUsernameChanged() {
            root.collectionsLoaded = false;
            root.collections.clear();
            root.collectionResults.clear();
            root.collectionTotalResults = 0;
        }

        target: Config
    }
    property bool downloadCancelRequested: false
    property string downloadErrorMessage: ""
    property Process downloadProcess: Process {
        property bool launchPending: false
        property string requestJson: "{}"

        command: ["python3", "-u", root.helperPath, "download"]
        stdinEnabled: true

        stderr: StdioCollector {
            id: downloadError
        }
        stdout: StdioCollector {
            id: downloadOutput
        }

        onExited: (exitCode, exitStatus) => {
            var completedId = root.downloadingId;
            var completedTitle = root.downloadingTitle || completedId;
            var completedPurpose = root.downloadPurpose;
            var cancelled = root.downloadCancelRequested;
            var response = root.parseResponse(downloadOutput.text, downloadError.text, qsTr("Wallpaper download failed"));
            root.downloadCancelRequested = false;
            root.downloadingId = "";
            root.downloadingTitle = "";
            root.downloadPurpose = "";
            if (cancelled && (exitCode !== 0 || !response.ok)) {
                root.downloadErrorMessage = "";
                root.statusMessage = qsTr("Cancelled %1").arg(completedTitle);
                return;
            }
            if (exitCode !== 0 || !response.ok) {
                root.downloadErrorMessage = response.message || qsTr("Wallpaper download failed");
                root.statusMessage = "";
                return;
            }
            root.downloadErrorMessage = "";
            root.statusMessage = response.existing ? qsTr("%1 is already downloaded").arg(completedTitle) : qsTr("Downloaded %1").arg(completedTitle);
            root.markDownloaded(completedId, response.path, response.modified, response.file_size);
            root.installedLoaded = false;
            root.downloadCompleted(completedId, response.path, response.modified, completedPurpose);
        }
        onRunningChanged: {
            if (!running && launchPending) {
                launchPending = false;
                root.downloadCancelRequested = false;
                root.downloadingId = "";
                root.downloadingTitle = "";
                root.downloadPurpose = "";
                root.downloadErrorMessage = qsTr("Could not start the Wallhaven downloader");
            }
        }
        onStarted: {
            launchPending = false;
            write(requestJson + "\n");
            requestJson = "{}";
        }
    }
    property string downloadPurpose: ""
    readonly property bool downloading: downloadingId !== ""
    property string downloadingId: ""
    property string downloadingTitle: ""
    readonly property string helperPath: Config.quickshellDir + "/scripts/wallhaven.py"
    property string installedErrorMessage: ""
    property bool installedLoaded: false
    property Process installedProcess: Process {
        property bool launchPending: false
        property int requestGeneration: -1
        property string requestJson: "{}"

        command: ["python3", "-u", root.helperPath, "list"]
        stdinEnabled: true

        stderr: StdioCollector {
            id: installedError
        }
        stdout: StdioCollector {
            id: installedOutput
        }

        onExited: (exitCode, exitStatus) => {
            if (!root.requestIsCurrent(installedProcess)) {
                root.restartInstalledLoadIfPending();
                return;
            }
            var response = root.parseResponse(installedOutput.text, installedError.text, qsTr("Could not load installed Wallhaven wallpapers"));
            if (root.installedReloadPending) {
                root.restartInstalledLoadIfPending();
                return;
            }
            if (exitCode !== 0 || !response.ok) {
                root.installedErrorMessage = response.message || qsTr("Could not load installed Wallhaven wallpapers");
                root.installedStatusMessage = "";
                root.restartInstalledLoadIfPending();
                return;
            }
            root.installedErrorMessage = "";
            root.installedLoaded = true;
            root.replaceModel(root.installedResults, response.items || []);
            root.installedStatusMessage = "";
            root.restartInstalledLoadIfPending();
        }
        onRunningChanged: {
            if (!running && launchPending) {
                launchPending = false;
                if (!root.requestIsCurrent(installedProcess)) {
                    root.restartInstalledLoadIfPending();
                    return;
                }
                root.installedErrorMessage = qsTr("Could not start the installed-wallpaper helper");
                root.installedStatusMessage = "";
                root.restartInstalledLoadIfPending();
            }
        }
        onStarted: {
            launchPending = false;
            if (!root.requestIsCurrent(installedProcess)) {
                requestJson = "{}";
                running = false;
                return;
            }
            write(requestJson + "\n");
            requestJson = "{}";
        }
    }
    property bool installedReloadPending: false
    property ListModel installedResults: ListModel {
        dynamicRoles: true
    }
    property string installedStatusMessage: ""
    property int lastPage: 1
    readonly property bool listingInstalled: installedProcess.running || installedReloadPending
    readonly property bool loadingCollection: collectionProcess.running || collectionRefreshPending
    readonly property bool loadingCollections: collectionsProcess.running || collectionsRefreshPending
    property string order: "desc"
    property int page: 1
    property int panelConsumers: 0
    property string purity: "111"
    property string query: ""
    property string ratios: ""
    property string removeErrorMessage: ""
    property Process removeProcess: Process {
        property bool launchPending: false
        property string requestJson: "{}"

        command: ["python3", "-u", root.helperPath, "remove"]
        stdinEnabled: true

        stderr: StdioCollector {
            id: removeError
        }
        stdout: StdioCollector {
            id: removeOutput
        }

        onExited: (exitCode, exitStatus) => {
            var response = root.parseResponse(removeOutput.text, removeError.text, qsTr("Could not delete wallpaper"));
            var completedId = root.removingId;
            var completedTitle = root.removingTitle || completedId;
            root.removingId = "";
            root.removingTitle = "";
            if (exitCode !== 0 || !response.ok) {
                root.removeErrorMessage = response.message || qsTr("Could not delete wallpaper");
                root.installedStatusMessage = "";
                return;
            }
            root.removeErrorMessage = "";
            root.installedStatusMessage = qsTr("Deleted %1 permanently").arg(response.title || completedTitle);
            root.markRemoved(completedId);
            root.removeCompleted(completedId, response.path || "");
        }
        onRunningChanged: {
            if (!running && launchPending) {
                launchPending = false;
                root.removingId = "";
                root.removingTitle = "";
                root.removeErrorMessage = qsTr("Could not start the wallpaper removal helper");
            }
        }
        onStarted: {
            launchPending = false;
            write(requestJson + "\n");
            requestJson = "{}";
        }
    }
    readonly property bool removing: removeProcess.running
    property string removingId: ""
    property string removingTitle: ""
    property int requestGeneration: 0
    property string resolutionMode: "atleast"
    property string resolutions: ""
    property ListModel results: ListModel {
        dynamicRoles: true
    }
    property string searchErrorMessage: ""
    property int searchPendingPage: 1
    property bool searchPendingPreserveSeed: false
    property Process searchProcess: Process {
        property bool launchPending: false
        property int requestGeneration: -1
        property string requestJson: "{}"

        command: ["python3", "-u", root.helperPath, "search"]
        stdinEnabled: true

        stderr: StdioCollector {
            id: searchError
        }
        stdout: StdioCollector {
            id: searchOutput
        }

        onExited: (exitCode, exitStatus) => {
            if (!root.requestIsCurrent(searchProcess)) {
                root.runPendingSearch();
                return;
            }
            var response = root.parseResponse(searchOutput.text, searchError.text, qsTr("Wallhaven search failed"));
            var superseded = root.searchRefreshPending;
            if (superseded) {
                root.runPendingSearch();
                return;
            }
            if (exitCode !== 0 || !response.ok) {
                root.searchErrorMessage = response.message || qsTr("Wallhaven search failed");
                root.statusMessage = "";
            } else {
                root.searchErrorMessage = "";
                root.replaceModel(root.results, response.items);
                root.page = Number(response.current_page || 1);
                root.lastPage = Number(response.last_page || 1);
                root.totalResults = Number(response.total || root.results.count);
                root.seed = root.sorting === "random" ? String(response.seed || root.seed || "") : "";
                root.statusMessage = root.results.count > 0 ? qsTr("Showing %1 wallpapers").arg(root.results.count) : "";
            }
            root.runPendingSearch();
        }
        onRunningChanged: {
            if (!running && launchPending) {
                launchPending = false;
                if (!root.requestIsCurrent(searchProcess)) {
                    root.runPendingSearch();
                    return;
                }
                root.searchErrorMessage = qsTr("Could not start Wallhaven search");
                root.statusMessage = "";
                root.runPendingSearch();
            }
        }
        onStarted: {
            launchPending = false;
            if (!root.requestIsCurrent(searchProcess)) {
                requestJson = "{}";
                running = false;
                return;
            }
            write(requestJson + "\n");
            requestJson = "{}";
        }
    }
    property bool searchRefreshPending: false
    readonly property bool searching: searchProcess.running || searchRefreshPending
    property string seed: ""
    property string selectedCollectionId: ""
    property string selectedCollectionLabel: ""
    property string sorting: "toplist"
    property string statusMessage: ""
    property string topRange: "1M"
    property int totalResults: 0

    signal downloadCompleted(string wallpaperId, string path, var modified, string purpose)
    signal removeCompleted(string wallpaperId, string path)

    function acquirePanel() {
        panelConsumers += 1;
    }
    function cancelBrowseProcess(process) {
        if (!process)
            return;

        process.launchPending = false;
        process.requestJson = "{}";
        if (process.running)
            process.running = false;
    }
    function cancelDownload() {
        if (!downloadProcess.running)
            return false;

        downloadCancelRequested = true;
        downloadProcess.running = false;
        return true;
    }
    function clearPanelModels() {
        results.clear();
        installedResults.clear();
        collections.clear();
        collectionResults.clear();
        installedLoaded = false;
        collectionsLoaded = false;
        page = 1;
        lastPage = 1;
        totalResults = 0;
        collectionPage = 1;
        collectionLastPage = 1;
        collectionTotalResults = 0;
        searchErrorMessage = "";
        collectionErrorMessage = "";
        installedErrorMessage = "";
        installedStatusMessage = "";
    }
    function download(item, purpose) {
        if (!item || downloadProcess.running)
            return false;

        var wallpaperId = String(item.id || "");
        var fullUrl = String(item.full || "");
        if (wallpaperId === "" || fullUrl === "") {
            downloadErrorMessage = qsTr("Wallhaven did not provide a downloadable image");
            return false;
        }
        downloadingId = wallpaperId;
        downloadingTitle = qsTr("wallhaven-%1").arg(wallpaperId);
        downloadPurpose = String(purpose || "desktop");
        downloadErrorMessage = "";
        statusMessage = qsTr("Downloading %1…").arg(downloadingTitle);
        downloadProcess.requestJson = JSON.stringify({
            "id": wallpaperId,
            "url": fullUrl,
            "wallpaper_dir": Config.wallhavenCacheFolder
        });
        downloadProcess.launchPending = true;
        downloadProcess.running = true;
        return true;
    }
    function loadCollection(collectionId, label, requestedPage) {
        if (panelConsumers <= 0 || !accountConfigured || String(collectionId || "") === "")
            return false;

        selectedCollectionId = String(collectionId);
        selectedCollectionLabel = String(label || "");
        var collectionIndex = modelIndexForId(collections, selectedCollectionId);
        if (collectionIndex >= 0)
            collectionTotalResults = Number(collections.get(collectionIndex).count || 0);

        var targetPage = Math.max(1, Number(requestedPage || 1));
        if (collectionProcess.running) {
            collectionPendingId = selectedCollectionId;
            collectionPendingLabel = selectedCollectionLabel;
            collectionPendingPage = targetPage;
            collectionRefreshPending = true;
            return true;
        }
        collectionErrorMessage = "";
        collectionProcess.requestJson = JSON.stringify({
            "api_key": Config.wallhavenApiKey.trim(),
            "collection_id": selectedCollectionId,
            "page": targetPage,
            "username": Config.wallhavenUsername.trim(),
            "wallpaper_dir": Config.wallhavenCacheFolder
        });
        collectionProcess.launchPending = true;
        collectionProcess.requestGeneration = requestGeneration;
        collectionProcess.running = true;
        return true;
    }
    function loadCollections(force) {
        if (panelConsumers <= 0)
            return false;

        if (!accountConfigured) {
            collectionsRefreshPending = false;
            collectionErrorMessage = qsTr("Add your Wallhaven username and API key in Settings");
            return false;
        }
        if (collectionsProcess.running) {
            if (force === true)
                collectionsRefreshPending = true;

            return force === true;
        }

        if (collectionsLoaded && !force) {
            if (selectedCollectionId !== "" && collectionResults.count === 0)
                loadCollection(selectedCollectionId, selectedCollectionLabel, 1);

            return true;
        }
        collectionErrorMessage = "";
        collectionsProcess.requestJson = JSON.stringify({
            "api_key": Config.wallhavenApiKey.trim()
        });
        collectionsProcess.launchPending = true;
        collectionsProcess.requestGeneration = requestGeneration;
        collectionsProcess.running = true;
        return true;
    }
    function loadInstalled(force) {
        if (panelConsumers <= 0)
            return false;

        if (force !== true && installedLoaded)
            return false;

        if (installedProcess.running) {
            installedReloadPending = true;
            return false;
        }
        installedReloadPending = false;
        installedErrorMessage = "";
        removeErrorMessage = "";
        installedStatusMessage = qsTr("Loading installed wallpapers…");
        installedProcess.requestJson = JSON.stringify({
            "wallpaper_dir": Config.wallhavenCacheFolder
        });
        installedProcess.launchPending = true;
        installedProcess.requestGeneration = requestGeneration;
        installedProcess.running = true;
        return true;
    }
    function markDownloaded(wallpaperId, path, modified, fileSize) {
        updateDownloaded(results, wallpaperId, path, modified, fileSize);
        updateDownloaded(collectionResults, wallpaperId, path, modified, fileSize);
    }
    function markRemoved(wallpaperId) {
        var models = [results, collectionResults];
        for (var modelIndex = 0; modelIndex < models.length; ++modelIndex) {
            var index = modelIndexForId(models[modelIndex], wallpaperId);
            if (index < 0)
                continue;

            models[modelIndex].setProperty(index, "downloaded", false);
            models[modelIndex].setProperty(index, "path", "");
            models[modelIndex].setProperty(index, "modified", 0);
        }
        var installedIndex = modelIndexForId(installedResults, wallpaperId);
        if (installedIndex >= 0)
            installedResults.remove(installedIndex, 1);
    }
    function modelIndexForId(model, wallpaperId) {
        var expectedId = String(wallpaperId || "");
        for (var i = 0; i < model.count; ++i) {
            if (String(model.get(i).id || "") === expectedId)
                return i;
        }
        return -1;
    }
    function openPage(url) {
        var target = String(url || "");
        if (target.indexOf("https://wallhaven.cc/") !== 0)
            return false;

        Quickshell.execDetached(["xdg-open", target]);
        return true;
    }
    function parseResponse(output, errorOutput, fallbackMessage) {
        try {
            var parsed = JSON.parse(String(output || "").trim());
            if (parsed && typeof parsed === "object")
                return parsed;
        } catch (error) {}
        return {
            "ok": false,
            "message": String(errorOutput || "").trim() || fallbackMessage
        };
    }
    function releasePanel() {
        if (panelConsumers <= 0)
            return;

        panelConsumers -= 1;
        if (panelConsumers > 0)
            return;

        requestGeneration += 1;
        searchRefreshPending = false;
        collectionRefreshPending = false;
        collectionsRefreshPending = false;
        installedReloadPending = false;
        collectionPendingId = "";
        collectionPendingLabel = "";
        searchPendingPreserveSeed = false;
        cancelBrowseProcess(searchProcess);
        cancelBrowseProcess(collectionProcess);
        cancelBrowseProcess(collectionsProcess);
        cancelBrowseProcess(installedProcess);
        clearPanelModels();
    }
    function removeInstalled(item) {
        if (!item || removeProcess.running)
            return false;

        var wallpaperId = String(item.id || "");
        var path = String(item.path || "");
        if (wallpaperId === "" || path === "") {
            removeErrorMessage = qsTr("Installed wallpaper information is incomplete");
            return false;
        }
        removingId = wallpaperId;
        removingTitle = qsTr("wallhaven-%1").arg(wallpaperId);
        removeErrorMessage = "";
        installedStatusMessage = qsTr("Deleting %1…").arg(removingTitle);
        removeProcess.requestJson = JSON.stringify({
            "current_path": WallpaperService.currentWallpaper,
            "id": wallpaperId,
            "path": path,
            "wallpaper_dir": Config.wallhavenCacheFolder
        });
        removeProcess.launchPending = true;
        removeProcess.running = true;
        return true;
    }
    function replaceModel(model, items) {
        var incoming = Array.isArray(items) ? items : [];
        for (var targetIndex = 0; targetIndex < incoming.length; ++targetIndex) {
            var item = incoming[targetIndex];
            var currentIndex = modelIndexForId(model, item.id);
            if (currentIndex < 0) {
                model.insert(targetIndex, item);
            } else {
                if (currentIndex !== targetIndex)
                    model.move(currentIndex, targetIndex, 1);

                model.set(targetIndex, item);
            }
        }
        if (model.count > incoming.length)
            model.remove(incoming.length, model.count - incoming.length);
    }
    function requestIsCurrent(process) {
        return panelConsumers > 0 && process && process.requestGeneration === requestGeneration;
    }
    function restartCollectionsLoadIfPending() {
        if (panelConsumers <= 0) {
            collectionsRefreshPending = false;
            return;
        }
        if (!collectionsRefreshPending)
            return;

        var generation = requestGeneration;
        Qt.callLater(() => {
            if (root.panelConsumers <= 0 || root.requestGeneration !== generation)
                return;
            if (!root.collectionsRefreshPending)
                return;

            root.collectionsRefreshPending = false;
            root.loadCollections(true);
        });
    }
    function restartInstalledLoadIfPending() {
        if (panelConsumers <= 0) {
            installedReloadPending = false;
            return;
        }
        if (!installedReloadPending)
            return;

        var generation = requestGeneration;
        Qt.callLater(() => {
            if (root.panelConsumers <= 0 || root.requestGeneration !== generation)
                return;
            if (!root.installedReloadPending)
                return;

            root.installedReloadPending = false;
            root.loadInstalled(true);
        });
    }
    function runPendingCollection() {
        if (panelConsumers <= 0) {
            collectionRefreshPending = false;
            collectionPendingId = "";
            collectionPendingLabel = "";
            return;
        }
        if (!collectionRefreshPending)
            return;

        var collectionId = collectionPendingId;
        var label = collectionPendingLabel;
        var targetPage = collectionPendingPage;
        collectionPendingId = "";
        collectionPendingLabel = "";
        var generation = requestGeneration;
        Qt.callLater(() => {
            if (root.panelConsumers <= 0 || root.requestGeneration !== generation)
                return;
            root.collectionRefreshPending = false;
            root.loadCollection(collectionId, label, targetPage);
        });
    }
    function runPendingSearch() {
        if (panelConsumers <= 0) {
            searchRefreshPending = false;
            searchPendingPreserveSeed = false;
            return;
        }
        if (!searchRefreshPending)
            return;

        var targetPage = searchPendingPage;
        var preserveSeed = searchPendingPreserveSeed;
        var generation = requestGeneration;
        Qt.callLater(() => {
            if (root.panelConsumers <= 0 || root.requestGeneration !== generation)
                return;
            root.searchRefreshPending = false;
            root.searchPendingPreserveSeed = false;
            root.search(root.query, targetPage, root.sorting, preserveSeed);
        });
    }
    function search(searchText, requestedPage, requestedSorting, preserveRandomSeed) {
        if (panelConsumers <= 0)
            return false;

        query = String(searchText || "").trim();
        page = Math.max(1, Number(requestedPage || 1));
        sorting = String(requestedSorting || sorting || "toplist");
        if (preserveRandomSeed !== true)
            seed = "";

        if (searchProcess.running) {
            searchPendingPage = page;
            searchPendingPreserveSeed = preserveRandomSeed === true;
            searchRefreshPending = true;
            return true;
        }
        searchErrorMessage = "";
        statusMessage = qsTr("Searching Wallhaven…");
        searchProcess.requestJson = JSON.stringify({
            "api_key": Config.wallhavenApiKey.trim(),
            "atleast": resolutionMode === "atleast" ? atleast : "",
            "categories": categories,
            "colors": colors,
            "order": order,
            "page": page,
            "purity": purity,
            "query": query,
            "ratios": ratios,
            "resolutions": resolutionMode === "exact" ? resolutions : "",
            "seed": sorting === "random" ? seed : "",
            "sorting": sorting,
            "top_range": topRange,
            "wallpaper_dir": Config.wallhavenCacheFolder
        });
        searchProcess.launchPending = true;
        searchProcess.requestGeneration = requestGeneration;
        searchProcess.running = true;
        return true;
    }
    function updateDownloaded(model, wallpaperId, path, modified, fileSize) {
        var index = modelIndexForId(model, wallpaperId);
        if (index < 0)
            return;

        model.setProperty(index, "downloaded", true);
        model.setProperty(index, "path", String(path || ""));
        model.setProperty(index, "modified", Number(modified || 0));
        model.setProperty(index, "file_size", Number(fileSize || model.get(index).file_size || 0));
    }
}
