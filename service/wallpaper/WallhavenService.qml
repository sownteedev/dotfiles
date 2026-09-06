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
    property bool collectionRefreshPending: false
    property CoreRequest collectionRequest: CoreRequest {
        property string activeRequestKey: ""
        property int panelGeneration: -1

        timeoutMs: 40000

        onFailed: message => {
            if (!root.generationIsCurrent(panelGeneration)) {
                root.runPendingCollection();
                return;
            }
            if (root.collectionRefreshPending) {
                root.runPendingCollection();
                return;
            }
            root.collectionErrorMessage = String(message || qsTr("Could not load this Wallhaven collection"));
            root.runPendingCollection();
        }
        onSucceeded: response => {
            if (!root.generationIsCurrent(panelGeneration)) {
                root.runPendingCollection();
                return;
            }
            if (root.collectionRefreshPending) {
                root.runPendingCollection();
                return;
            }
            if (response && response.ok) {
                root.collectionErrorMessage = "";
                root.replaceModel(root.collectionResults, response.items || []);
                root.collectionPage = Number(response.current_page || 1);
                root.collectionLastPage = Number(response.last_page || 1);
                root.collectionTotalResults = Number(response.total || root.collectionResults.count);
            } else {
                root.collectionErrorMessage = response && response.message ? String(response.message) : qsTr("Could not load this Wallhaven collection");
            }
            root.runPendingCollection();
        }
    }
    property ListModel collectionResults: ListModel {
        dynamicRoles: true
    }
    property int collectionTotalResults: 0
    property ListModel collections: ListModel {
        dynamicRoles: true
    }
    property bool collectionsLoaded: false
    property bool collectionsRefreshPending: false
    property CoreRequest collectionsRequest: CoreRequest {
        property string activeApiKey: ""
        property int panelGeneration: -1

        timeoutMs: 40000

        onFailed: message => {
            if (!root.generationIsCurrent(panelGeneration)) {
                root.restartCollectionsLoadIfPending();
                return;
            }
            if (root.collectionsRefreshPending) {
                root.restartCollectionsLoadIfPending();
                return;
            }
            root.collectionErrorMessage = String(message || qsTr("Could not load Wallhaven collections"));
            root.restartCollectionsLoadIfPending();
        }
        onSucceeded: response => {
            if (!root.generationIsCurrent(panelGeneration)) {
                root.restartCollectionsLoadIfPending();
                return;
            }
            if (root.collectionsRefreshPending) {
                root.restartCollectionsLoadIfPending();
                return;
            }
            if (!response || !response.ok) {
                root.collectionErrorMessage = response && response.message ? String(response.message) : qsTr("Could not load Wallhaven collections");
                root.restartCollectionsLoadIfPending();
                return;
            }
            root.collectionErrorMessage = "";
            root.collectionsLoaded = true;
            root.replaceModel(root.collections, response.items || []);
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
    }
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

        command: [root.helperPath, "request-stdin", "wallpaper.wallhaven.download"]
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
    readonly property string helperPath: Config.sownteeshellDir + "/backend/rust/core-daemon/run-core-daemon"
    property string installedErrorMessage: ""
    property bool installedLoaded: false
    property Process installedProcess: Process {
        property bool launchPending: false
        property int requestGeneration: -1
        property string requestJson: "{}"

        command: [root.helperPath, "request-stdin", "wallpaper.wallhaven.list"]
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
    readonly property bool loadingCollection: collectionRequest.active || collectionRefreshPending
    readonly property bool loadingCollections: collectionsRequest.active || collectionsRefreshPending
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

        command: [root.helperPath, "request-stdin", "wallpaper.wallhaven.remove"]
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
    property bool searchRefreshPending: false
    property CoreRequest searchRequest: CoreRequest {
        property int panelGeneration: -1

        timeoutMs: 40000

        onFailed: message => {
            if (!root.generationIsCurrent(panelGeneration)) {
                root.runPendingSearch();
                return;
            }
            if (root.searchRefreshPending) {
                root.runPendingSearch();
                return;
            }
            root.searchErrorMessage = String(message || qsTr("Wallhaven search failed"));
            root.statusMessage = "";
            root.runPendingSearch();
        }
        onSucceeded: response => {
            if (!root.generationIsCurrent(panelGeneration)) {
                root.runPendingSearch();
                return;
            }
            if (root.searchRefreshPending) {
                root.runPendingSearch();
                return;
            }
            if (response && response.ok) {
                root.searchErrorMessage = "";
                root.replaceModel(root.results, response.items || []);
                root.page = Number(response.current_page || 1);
                root.lastPage = Number(response.last_page || 1);
                root.totalResults = Number(response.total || root.results.count);
                root.seed = root.sorting === "random" ? String(response.seed || root.seed || "") : "";
                root.statusMessage = "";
            } else {
                root.searchErrorMessage = response && response.message ? String(response.message) : qsTr("Wallhaven search failed");
                root.statusMessage = "";
            }
            root.runPendingSearch();
        }
    }
    readonly property bool searching: searchRequest.active || searchRefreshPending
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
    function generationIsCurrent(generation) {
        return panelConsumers > 0 && generation === requestGeneration;
    }
    function loadCollection(collectionId, label, requestedPage) {
        if (panelConsumers <= 0 || !accountConfigured || String(collectionId || "") === "")
            return false;

        var targetCollectionId = String(collectionId);
        selectedCollectionId = targetCollectionId;
        selectedCollectionLabel = String(label || "");
        var collectionIndex = modelIndexForId(collections, selectedCollectionId);
        if (collectionIndex >= 0)
            collectionTotalResults = Number(collections.get(collectionIndex).count || 0);

        var targetPage = Math.max(1, Number(requestedPage || 1));
        var apiKey = Config.wallhavenApiKey.trim();
        var username = Config.wallhavenUsername.trim();
        var wallpaperDir = Config.wallhavenCacheFolder;
        var targetRequestKey = JSON.stringify([targetCollectionId, targetPage, apiKey, username, wallpaperDir]);
        if (collectionRequest.active) {
            if (collectionRequest.activeRequestKey === targetRequestKey) {
                collectionRefreshPending = false;
                collectionPendingId = "";
                collectionPendingLabel = "";
                return true;
            }
            collectionPendingId = selectedCollectionId;
            collectionPendingLabel = selectedCollectionLabel;
            collectionPendingPage = targetPage;
            collectionRefreshPending = true;
            return true;
        }
        collectionErrorMessage = "";
        collectionRequest.activeRequestKey = targetRequestKey;
        collectionRequest.panelGeneration = requestGeneration;
        collectionRequest.start("wallpaper.wallhaven.collection", {
            "api_key": apiKey,
            "collection_id": selectedCollectionId,
            "page": targetPage,
            "username": username,
            "wallpaper_dir": wallpaperDir
        });
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
        var apiKey = Config.wallhavenApiKey.trim();
        if (collectionsRequest.active) {
            collectionsRefreshPending = collectionsRequest.activeApiKey !== apiKey;
            return true;
        }

        if (collectionsLoaded && !force) {
            if (selectedCollectionId !== "" && collectionResults.count === 0)
                loadCollection(selectedCollectionId, selectedCollectionLabel, 1);

            return true;
        }
        collectionErrorMessage = "";
        collectionsRequest.activeApiKey = apiKey;
        collectionsRequest.panelGeneration = requestGeneration;
        collectionsRequest.start("wallpaper.wallhaven.collections", {
            "api_key": apiKey
        });
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
        searchRequest.cancel();
        collectionRequest.cancel();
        collectionsRequest.cancel();
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

        if (searchRequest.active) {
            searchPendingPage = page;
            searchPendingPreserveSeed = preserveRandomSeed === true;
            searchRefreshPending = true;
            return true;
        }
        searchErrorMessage = "";
        statusMessage = "";
        searchRequest.panelGeneration = requestGeneration;
        searchRequest.start("wallpaper.wallhaven.search", {
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
