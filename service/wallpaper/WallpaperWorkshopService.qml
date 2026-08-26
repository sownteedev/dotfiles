pragma Singleton
import "../../"
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string actionStatusMessage: ""
    readonly property int activeFilterCount: (typeFilter === "all" ? 0 : 1) + (ageRatingFilter === "" ? 0 : 1) + (resolutionFilter === "" ? 0 : 1) + genreFilters.length + featureFilters.length
    property string ageRatingFilter: ""
    readonly property string browseErrorMessage: loginErrorMessage || downloadErrorMessage || searchErrorMessage
    property bool browseFiltersDirty: false
    readonly property string browseStatusMessage: actionStatusMessage || searchStatusMessage
    readonly property bool busy: downloading || listingInstalled || loginRunning || removing || searching || subscriptionProcess.running
    readonly property bool configured: Config.steamWebApiKey.trim() !== "" && Config.steamUsername.trim() !== ""
    property bool downloadCancelRequested: false
    readonly property bool downloadCancelling: downloadCancelRequested
    property string downloadErrorCode: ""
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
            var response = root.parseResponse(downloadOutput.text, downloadError.text, qsTr("Wallpaper download failed"));
            var completedId = root.downloadingId;
            var completedTitle = root.downloadingTitle || completedId;
            var completedPurpose = root.downloadPurpose;
            var cancelled = root.downloadCancelRequested;
            root.downloadCancelRequested = false;
            root.downloadingId = "";
            root.downloadingTitle = "";
            root.downloadPurpose = "";
            if (cancelled && (exitCode !== 0 || !response.ok)) {
                root.downloadErrorCode = "";
                root.downloadErrorMessage = "";
                root.actionStatusMessage = qsTr("Cancelled %1").arg(completedTitle);
                return;
            }
            if (exitCode !== 0 || !response.ok) {
                root.downloadErrorCode = response.code || "";
                root.downloadErrorMessage = response.message || qsTr("Wallpaper download failed");
                root.actionStatusMessage = "";
                return;
            }

            root.downloadErrorCode = "";
            root.downloadErrorMessage = "";
            root.actionStatusMessage = qsTr("Downloaded %1").arg(response.title || completedId);
            root.markDownloaded(completedId, response.path, response.modified, response.file_size);
            EngineWallpaperService.refresh();
            root.installedLoaded = false;
            if (root.panelConsumers > 0)
                root.loadInstalled(true);
            root.downloadCompleted(completedId, response.path, response.modified, completedPurpose);
        }
        onRunningChanged: {
            if (!running && launchPending) {
                launchPending = false;
                root.downloadCancelRequested = false;
                root.downloadingId = "";
                root.downloadingTitle = "";
                root.downloadPurpose = "";
                root.downloadErrorCode = "";
                root.downloadErrorMessage = qsTr("Could not start the wallpaper download helper");
                root.actionStatusMessage = "";
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
    property var featureFilters: []
    property ListModel filteredInstalledResults: ListModel {
        dynamicRoles: true
    }
    property ListModel filteredResults: ListModel {
        dynamicRoles: true
    }
    property var genreFilters: []
    readonly property bool hasMore: results.count < totalResults
    readonly property string helperPath: Config.quickshellDir + "/scripts/wallpaper_workshop.py"
    property string installedLoadErrorMessage: ""
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
            var response = root.parseResponse(installedOutput.text, installedError.text, qsTr("Could not load installed wallpapers"));
            if (exitCode !== 0 || !response.ok) {
                root.installedLoadErrorMessage = response.message || qsTr("Could not load installed wallpapers");
                root.installedStatusMessage = "";
                root.restartInstalledLoadIfPending();
                return;
            }

            root.installedLoadErrorMessage = "";
            root.installedLoaded = true;
            root.replaceModel(root.installedResults, response.items || []);
            root.rebuildFilteredInstalledResults();
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
                root.installedLoadErrorMessage = qsTr("Could not start the installed-wallpaper helper");
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
    readonly property bool listingInstalled: installedProcess.running
    property string loginErrorCode: ""
    property string loginErrorMessage: ""
    readonly property bool loginRequired: downloadErrorCode === "steamcmd_login_required" || loginErrorCode === "steamcmd_login_required"
    readonly property bool loginRunning: loginTerminal.running
    property Process loginTerminal: Process {
        property bool launchPending: false

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.loginErrorCode = "";
                root.loginErrorMessage = "";
                root.actionStatusMessage = qsTr("SteamCMD login finished — retry the download");
            } else {
                root.loginErrorCode = "steamcmd_login_required";
                root.loginErrorMessage = qsTr("SteamCMD login was not completed");
                root.actionStatusMessage = "";
            }
        }
        onRunningChanged: {
            if (!running && launchPending) {
                launchPending = false;
                root.loginErrorCode = "steamcmd_login_required";
                root.loginErrorMessage = qsTr("Could not start Black Box for SteamCMD login");
                root.actionStatusMessage = "";
            }
        }
        onStarted: launchPending = false
    }
    readonly property string manageErrorMessage: loginErrorMessage || downloadErrorMessage || removeErrorMessage || installedLoadErrorMessage
    readonly property string manageStatusMessage: actionStatusMessage || installedStatusMessage
    property int page: 1
    property int panelConsumers: 0
    property var pendingSearchRequest: null
    property string query: ""
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
            var response = root.parseResponse(removeOutput.text, removeError.text, qsTr("Could not remove wallpaper"));
            var completedId = root.removingId;
            root.removingId = "";
            root.removingTitle = "";
            if (exitCode !== 0 || !response.ok) {
                root.removeErrorMessage = response.message || qsTr("Could not remove wallpaper");
                root.actionStatusMessage = "";
                return;
            }

            root.removeErrorMessage = "";
            root.actionStatusMessage = qsTr("Deleted %1 permanently").arg(response.title || completedId);
            root.markRemoved(completedId);
            EngineWallpaperService.refresh();
            root.installedLoaded = false;
            if (root.panelConsumers > 0)
                root.loadInstalled(true);
            root.removeCompleted(completedId, response.path || "");
        }
        onRunningChanged: {
            if (!running && launchPending) {
                launchPending = false;
                root.removingId = "";
                root.removingTitle = "";
                root.removeErrorMessage = qsTr("Could not start the wallpaper removal helper");
                root.actionStatusMessage = "";
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
    property string resolutionFilter: ""
    property ListModel results: ListModel {
        dynamicRoles: true
    }
    property string searchErrorMessage: ""
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
                root.restartSearchIfPending();
                return;
            }
            var response = root.parseResponse(searchOutput.text, searchError.text, qsTr("Could not search Steam Workshop"));
            if (exitCode !== 0 || !response.ok) {
                root.results.clear();
                root.rebuildFilteredResults();
                root.totalResults = 0;
                root.searchErrorMessage = response.message || qsTr("Could not search Steam Workshop");
                root.searchStatusMessage = "";
            } else {
                root.searchErrorMessage = "";
                root.replaceModel(root.results, response.items || []);
                root.rebuildFilteredResults();
                root.totalResults = Number(response.total || root.results.count);
                root.searchStatusMessage = root.results.count > 0 ? qsTr("%1 wallpapers").arg(root.totalResults) : "";
            }
            root.restartSearchIfPending();
        }
        onRunningChanged: {
            if (!running && launchPending) {
                launchPending = false;
                if (!root.requestIsCurrent(searchProcess)) {
                    root.restartSearchIfPending();
                    return;
                }
                root.results.clear();
                root.rebuildFilteredResults();
                root.totalResults = 0;
                root.searchErrorMessage = qsTr("Could not start the Workshop search helper");
                root.searchStatusMessage = "";
                root.restartSearchIfPending();
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
    property string searchStatusMessage: ""
    readonly property bool searching: searchProcess.running
    property string sortMode: "trending"
    property string steamItemId: ""
    property bool steamItemSubscribed: false
    property string steamItemTitle: ""
    property FileView subscriptionManifest: FileView {
        path: Config.steamDir + "/steamapps/workshop/appworkshop_431960.acf"
        printErrors: false
        watchChanges: true

        onFileChanged: {
            reload();
            subscriptionRefreshDebounce.restart();
        }
        onLoadedChanged: {
            if (loaded)
                subscriptionRefreshDebounce.restart();
        }
        onTextChanged: {
            if (loaded)
                subscriptionRefreshDebounce.restart();
        }
    }
    property Process subscriptionProcess: Process {
        property bool launchPending: false
        property int requestGeneration: -1
        property string requestJson: "{}"

        command: ["python3", "-u", root.helperPath, "subscriptions"]
        stdinEnabled: true

        stderr: StdioCollector {
            id: subscriptionError
        }
        stdout: StdioCollector {
            id: subscriptionOutput
        }

        onExited: (exitCode, exitStatus) => {
            if (!root.requestIsCurrent(subscriptionProcess)) {
                root.restartSubscriptionRefreshIfPending();
                return;
            }
            var response = root.parseResponse(subscriptionOutput.text, subscriptionError.text, qsTr("Could not refresh Steam subscriptions"));
            if (exitCode === 0 && response.ok) {
                root.subscriptionsLoaded = true;
                root.applySubscriptions(response.ids || []);
            }
            root.restartSubscriptionRefreshIfPending();
        }
        onRunningChanged: {
            if (!running && launchPending) {
                launchPending = false;
                if (!root.requestIsCurrent(subscriptionProcess)) {
                    root.restartSubscriptionRefreshIfPending();
                    return;
                }
                root.restartSubscriptionRefreshIfPending();
            }
        }
        onStarted: {
            launchPending = false;
            if (!root.requestIsCurrent(subscriptionProcess)) {
                requestJson = "{}";
                running = false;
                return;
            }
            write(requestJson + "\n");
            requestJson = "{}";
        }
    }
    property Timer subscriptionRefreshDebounce: Timer {
        interval: 160
        repeat: false

        onTriggered: root.refreshSubscriptions(true)
    }
    property bool subscriptionRefreshPending: false
    property bool subscriptionsLoaded: false
    property int totalResults: 0
    property string typeFilter: "all"

    signal downloadCompleted(string publishedFileId, string path, var modified, string purpose)
    signal removeCompleted(string publishedFileId, string path)

    function acquirePanel() {
        panelConsumers += 1;
    }
    function applySubscriptionState(model, subscribedIds) {
        var subscribed = {};
        for (var i = 0; i < subscribedIds.length; ++i)
            subscribed[String(subscribedIds[i])] = true;

        for (var itemIndex = 0; itemIndex < model.count; ++itemIndex) {
            var item = model.get(itemIndex);
            var nextSubscribed = Boolean(subscribed[String(item.id || "")]);
            if (Boolean(item.subscribed) !== nextSubscribed)
                model.setProperty(itemIndex, "subscribed", nextSubscribed);
        }
    }
    function applySubscriptions(subscribedIds) {
        var subscribed = {};
        for (var i = 0; i < subscribedIds.length; ++i)
            subscribed[String(subscribedIds[i])] = true;

        applySubscriptionState(results, subscribedIds);
        applySubscriptionState(installedResults, subscribedIds);
        rebuildFilteredModels();
        if (steamItemId === "")
            return;
        var nextSubscribed = Boolean(subscribed[steamItemId]);
        if (nextSubscribed === steamItemSubscribed)
            return;
        actionStatusMessage = nextSubscribed ? qsTr("Subscribed to %1").arg(steamItemTitle || steamItemId) : qsTr("Unsubscribed from %1").arg(steamItemTitle || steamItemId);
        steamItemId = "";
        steamItemTitle = "";
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
        if (!downloading || downloadCancelRequested)
            return false;
        downloadCancelRequested = true;
        actionStatusMessage = qsTr("Cancelling %1…").arg(downloadingTitle || downloadingId);
        downloadProcess.running = false;
        return true;
    }
    function clearFilters() {
        if (activeFilterCount === 0)
            return false;

        ageRatingFilter = "";
        featureFilters = [];
        genreFilters = [];
        resolutionFilter = "";
        typeFilter = "all";
        markFiltersChanged();
        return true;
    }
    function clearPanelModels() {
        results.clear();
        filteredResults.clear();
        installedResults.clear();
        filteredInstalledResults.clear();
        installedLoaded = false;
        subscriptionsLoaded = false;
        page = 1;
        totalResults = 0;
        searchErrorMessage = "";
        searchStatusMessage = "";
        installedLoadErrorMessage = "";
        installedStatusMessage = "";
    }
    function containsFilter(filters, value) {
        var expected = normalizedTag(value);
        var hasArrayLength = filters && filters.length !== undefined;
        var count = hasArrayLength ? filters.length : Number(filters && filters.count || 0);
        for (var i = 0; i < count; ++i) {
            var candidate = hasArrayLength ? filters[i] : (typeof filters.get === "function" ? filters.get(i) : "");
            if (candidate && typeof candidate === "object")
                candidate = candidate.tag !== undefined ? candidate.tag : (candidate.value !== undefined ? candidate.value : candidate.modelData);

            if (normalizedTag(candidate) === expected)
                return true;
        }
        return false;
    }
    function download(item, purpose) {
        if (!item || downloading)
            return false;
        if (Config.steamUsername.trim() === "") {
            downloadErrorCode = "";
            downloadErrorMessage = qsTr("Add your Steam username in Settings first");
            return false;
        }

        downloadingId = String(item.id || "");
        downloadingTitle = String(item.title || downloadingId);
        downloadPurpose = String(purpose || "desktop");
        downloadCancelRequested = false;
        downloadErrorCode = "";
        downloadErrorMessage = "";
        actionStatusMessage = qsTr("Downloading %1…").arg(downloadingTitle);
        downloadProcess.requestJson = JSON.stringify({
            "id": downloadingId,
            "steam_root": Config.steamDir,
            "username": Config.steamUsername.trim(),
            "workshop_root": Config.wallpaperEngineWorkshopDir
        });
        downloadProcess.launchPending = true;
        downloadProcess.running = true;
        return true;
    }
    function itemHasTag(item, expectedTag) {
        var tags = item && item.tags ? item.tags : [];
        return containsFilter(tags, expectedTag);
    }
    function itemMatchesFilters(item) {
        var itemType = String(item && item.type || "").toLowerCase();
        if (itemType === "application" || itemType === "web")
            return false;

        if (typeFilter !== "all" && itemType !== typeFilter)
            return false;

        if (ageRatingFilter !== "" && !itemHasTag(item, ageRatingFilter))
            return false;

        if (resolutionFilter !== "" && !itemHasTag(item, resolutionFilter) && normalizedResolution(item && item.resolution) !== normalizedResolution(resolutionFilter))
            return false;

        for (var genreIndex = 0; genreIndex < genreFilters.length; ++genreIndex) {
            if (!itemHasTag(item, genreFilters[genreIndex]))
                return false;
        }
        for (var featureIndex = 0; featureIndex < featureFilters.length; ++featureIndex) {
            if (!itemHasTag(item, featureFilters[featureIndex]))
                return false;
        }
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
        installedLoadErrorMessage = "";
        installedStatusMessage = qsTr("Loading installed wallpapers…");
        installedProcess.requestJson = JSON.stringify({
            "legacy_workshop_root": Config.legacyWallpaperEngineWorkshopDir,
            "steam_root": Config.steamDir,
            "workshop_root": Config.wallpaperEngineWorkshopDir
        });
        installedProcess.launchPending = true;
        installedProcess.requestGeneration = requestGeneration;
        installedProcess.running = true;
        return true;
    }
    function loginSteamCmd() {
        if (loginTerminal.running)
            return false;
        var username = Config.steamUsername.trim();
        if (username === "") {
            loginErrorCode = "";
            loginErrorMessage = qsTr("Add your Steam username in Settings first");
            return false;
        }

        loginErrorCode = "";
        loginErrorMessage = "";
        actionStatusMessage = qsTr("Opening SteamCMD login in Black Box…");
        var loginCommand = "python3 " + shellQuote(helperPath) + " login " + shellQuote(username) + "; result=$?; print; if [ $result -eq 0 ]; then print -r -- 'SteamCMD login complete.'; else print -r -- \"SteamCMD login failed (exit $result).\"; fi; print -rn -- 'Press any key to close…'; read -rk 1; exit $result";
        var terminalCommand = "exec /usr/bin/zsh -c " + shellQuote(loginCommand);
        loginTerminal.command = ["blackbox-terminal", "--command", terminalCommand];
        loginTerminal.launchPending = true;
        loginTerminal.running = true;
        return true;
    }
    function markDownloaded(publishedFileId, path, modified, fileSize) {
        var index = modelIndexForId(results, publishedFileId);
        if (index >= 0) {
            results.setProperty(index, "downloaded", true);
            results.setProperty(index, "path", path);
            results.setProperty(index, "file_size", Number(fileSize || results.get(index).file_size || 0));
            results.setProperty(index, "modified", modified);
            rebuildFilteredResults();
        }
    }
    function markFiltersChanged() {
        browseFiltersDirty = true;
        rebuildFilteredModels();
    }
    function markRemoved(publishedFileId) {
        var resultIndex = modelIndexForId(results, publishedFileId);
        if (resultIndex >= 0) {
            results.setProperty(resultIndex, "downloaded", false);
            results.setProperty(resultIndex, "path", "");
            results.setProperty(resultIndex, "modified", 0);
        }
        var installedIndex = modelIndexForId(installedResults, publishedFileId);
        if (installedIndex >= 0)
            installedResults.remove(installedIndex, 1);

        rebuildFilteredModels();
    }
    function modelIndexForId(model, publishedFileId) {
        var expectedId = String(publishedFileId || "");
        for (var i = 0; i < model.count; ++i) {
            if (String(model.get(i).id || "") === expectedId)
                return i;
        }
        return -1;
    }
    function normalizedResolution(value) {
        return String(value || "").toLowerCase().replace(/[^0-9]+/g, "x").replace(/^x+|x+$/g, "");
    }
    function normalizedTag(value) {
        return String(value || "").trim().toLowerCase();
    }
    function openInSteam(item) {
        var publishedFileId = String(item && item.id || "");
        if (!/^\d+$/.test(publishedFileId))
            return false;
        steamItemId = publishedFileId;
        steamItemSubscribed = Boolean(item.subscribed);
        steamItemTitle = String(item.title || publishedFileId);
        actionStatusMessage = qsTr("Opening %1 in Steam…").arg(String(item.title || publishedFileId));
        Quickshell.execDetached(["xdg-open", "steam://url/CommunityFilePage/" + publishedFileId]);
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
    function rebuildFilteredInstalledResults() {
        rebuildFilteredModel(filteredInstalledResults, installedResults);
    }
    function rebuildFilteredModel(targetModel, sourceModel) {
        var items = [];
        for (var i = 0; i < sourceModel.count; ++i) {
            var item = sourceModel.get(i);
            if (itemMatchesFilters(item))
                items.push(item);
        }
        replaceModel(targetModel, items);
    }
    function rebuildFilteredModels() {
        rebuildFilteredResults();
        rebuildFilteredInstalledResults();
    }
    function rebuildFilteredResults() {
        var items = [];
        for (var i = 0; i < results.count; ++i)
            items.push(results.get(i));

        replaceModel(filteredResults, items);
    }
    function refreshSubscriptions(force) {
        if (panelConsumers <= 0)
            return false;

        if (force !== true && subscriptionsLoaded)
            return false;
        if (subscriptionProcess.running) {
            subscriptionRefreshPending = true;
            return false;
        }
        subscriptionRefreshPending = false;
        subscriptionProcess.requestJson = JSON.stringify({
            "steam_root": Config.steamDir
        });
        subscriptionProcess.launchPending = true;
        subscriptionProcess.requestGeneration = requestGeneration;
        subscriptionProcess.running = true;
        return true;
    }
    function releasePanel() {
        if (panelConsumers <= 0)
            return;

        panelConsumers -= 1;
        if (panelConsumers > 0)
            return;

        requestGeneration += 1;
        pendingSearchRequest = null;
        installedReloadPending = false;
        subscriptionRefreshPending = false;
        subscriptionRefreshDebounce.stop();
        cancelBrowseProcess(searchProcess);
        cancelBrowseProcess(installedProcess);
        cancelBrowseProcess(subscriptionProcess);
        clearPanelModels();
    }
    function removeInstalled(item) {
        if (!item || removeProcess.running)
            return false;
        var publishedFileId = String(item.id || "");
        var installedPath = String(item.path || "");
        if (!/^\d+$/.test(publishedFileId) || installedPath === "") {
            removeErrorMessage = qsTr("Invalid installed wallpaper");
            return false;
        }
        if (String(WallpaperService.currentWallpaper || "") === installedPath) {
            removeErrorMessage = qsTr("Choose another wallpaper before removing this one");
            return false;
        }
        removingId = publishedFileId;
        removingTitle = String(item.title || publishedFileId);
        removeErrorMessage = "";
        actionStatusMessage = qsTr("Deleting %1 permanently…").arg(removingTitle);
        removeProcess.requestJson = JSON.stringify({
            "current_path": WallpaperService.currentWallpaper,
            "id": publishedFileId,
            "legacy_workshop_root": Config.legacyWallpaperEngineWorkshopDir,
            "path": installedPath,
            "steam_root": Config.steamDir,
            "workshop_root": Config.wallpaperEngineWorkshopDir
        });
        removeProcess.launchPending = true;
        removeProcess.running = true;
        return true;
    }
    function replaceModel(model, items) {
        var incoming = Array.isArray(items) ? items : [];
        for (var targetIndex = 0; targetIndex < incoming.length; ++targetIndex) {
            var item = incoming[targetIndex];
            var publishedFileId = String(item.id || "");
            var currentIndex = modelIndexForId(model, publishedFileId);
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
    function requiredTags() {
        var tags = [];
        if (typeFilter === "video")
            tags.push("Video");
        else if (typeFilter === "scene")
            tags.push("Scene");
        if (ageRatingFilter !== "")
            tags.push(ageRatingFilter);

        if (resolutionFilter !== "")
            tags.push(resolutionFilter);

        for (var genreIndex = 0; genreIndex < genreFilters.length; ++genreIndex)
            tags.push(genreFilters[genreIndex]);
        for (var featureIndex = 0; featureIndex < featureFilters.length; ++featureIndex)
            tags.push(featureFilters[featureIndex]);
        return tags;
    }
    function restartInstalledLoadIfPending() {
        if (panelConsumers <= 0) {
            installedReloadPending = false;
            return;
        }
        if (!installedReloadPending)
            return;
        installedReloadPending = false;
        var generation = requestGeneration;
        Qt.callLater(() => {
            if (root.panelConsumers > 0 && root.requestGeneration === generation)
                root.loadInstalled(true);
        });
    }
    function restartSearchIfPending() {
        if (panelConsumers <= 0) {
            pendingSearchRequest = null;
            return;
        }
        if (!pendingSearchRequest)
            return;
        var request = pendingSearchRequest;
        var generation = requestGeneration;
        pendingSearchRequest = null;
        Qt.callLater(() => {
            if (root.panelConsumers > 0 && root.requestGeneration === generation)
                root.search(request.query, request.page, request.sort);
        });
    }
    function restartSubscriptionRefreshIfPending() {
        if (panelConsumers <= 0) {
            subscriptionRefreshPending = false;
            return;
        }
        if (!subscriptionRefreshPending)
            return;
        subscriptionRefreshPending = false;
        var generation = requestGeneration;
        Qt.callLater(() => {
            if (root.panelConsumers > 0 && root.requestGeneration === generation)
                root.refreshSubscriptions(true);
        });
    }
    function search(searchText, requestedPage, requestedSort) {
        if (panelConsumers <= 0)
            return false;

        if (!configured) {
            results.clear();
            rebuildFilteredResults();
            totalResults = 0;
            searchErrorMessage = qsTr("Add your Steam username and Web API key in Settings");
            searchStatusMessage = "";
            return false;
        }
        var request = {
            "page": Math.max(1, Number(requestedPage || 1)),
            "query": String(searchText || "").trim(),
            "sort": String(requestedSort || "trending")
        };
        if (searchProcess.running) {
            pendingSearchRequest = request;
            return true;
        }
        query = request.query;
        page = request.page;
        sortMode = request.sort;
        browseFiltersDirty = false;
        searchErrorMessage = "";
        searchStatusMessage = qsTr("Searching Steam Workshop…");
        searchProcess.requestJson = JSON.stringify({
            "api_key": Config.steamWebApiKey.trim(),
            "excluded_tags": ["Application", "Web"],
            "legacy_workshop_root": Config.legacyWallpaperEngineWorkshopDir,
            "match_all_tags": true,
            "page": page,
            "query": query,
            "required_tags": requiredTags(),
            "sort": sortMode,
            "steam_root": Config.steamDir,
            "workshop_root": Config.wallpaperEngineWorkshopDir
        });
        searchProcess.launchPending = true;
        searchProcess.requestGeneration = requestGeneration;
        searchProcess.running = true;
        return true;
    }
    function setAgeRatingFilter(filter) {
        var normalized = String(filter || "");
        if (["", "Everyone", "Questionable", "Mature"].indexOf(normalized) < 0)
            normalized = "";

        if (ageRatingFilter === normalized)
            return false;

        ageRatingFilter = normalized;
        markFiltersChanged();
        return true;
    }
    function setResolutionFilter(filter) {
        var normalized = String(filter || "").trim();
        if (resolutionFilter === normalized)
            return false;

        resolutionFilter = normalized;
        markFiltersChanged();
        return true;
    }
    function setTypeFilter(filter) {
        var normalized = String(filter || "all").toLowerCase();
        if (["all", "video", "scene"].indexOf(normalized) < 0)
            normalized = "all";

        if (typeFilter === normalized)
            return false;

        typeFilter = normalized;
        markFiltersChanged();
        return true;
    }
    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\"'\"'") + "'";
    }
    function toggleFeatureFilter(filter) {
        featureFilters = toggledFilters(featureFilters, String(filter || ""));
        markFiltersChanged();
    }
    function toggleGenreFilter(filter) {
        genreFilters = toggledFilters(genreFilters, String(filter || ""));
        markFiltersChanged();
    }
    function toggledFilters(filters, value) {
        var next = [];
        var expected = normalizedTag(value);
        var removed = false;
        for (var i = 0; i < filters.length; ++i) {
            if (normalizedTag(filters[i]) === expected)
                removed = true;
            else
                next.push(filters[i]);
        }
        if (!removed)
            next.push(value);

        return next;
    }
}
