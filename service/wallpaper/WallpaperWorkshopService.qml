pragma Singleton
import "../../"
import ".."
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property string actionStatusMessage: ""
    readonly property string browseErrorMessage: loginErrorMessage || downloadErrorMessage || searchErrorMessage
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
            var cancelled = root.downloadCancelRequested;
            root.downloadCancelRequested = false;
            root.downloadingId = "";
            root.downloadingTitle = "";
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
            root.loadInstalled(true);
            root.downloadCompleted(completedId, response.path, response.modified);
        }
        onRunningChanged: {
            if (!running && launchPending) {
                launchPending = false;
                root.downloadCancelRequested = false;
                root.downloadingId = "";
                root.downloadingTitle = "";
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
    readonly property bool downloading: downloadingId !== ""
    property string downloadingId: ""
    property string downloadingTitle: ""
    readonly property bool hasMore: results.count < totalResults
    readonly property string helperPath: Config.quickshellDir + "/scripts/wallpaper_workshop.py"
    property string installedLoadErrorMessage: ""
    property bool installedLoaded: false
    property Process installedProcess: Process {
        property bool launchPending: false
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
            root.installedStatusMessage = "";
            root.restartInstalledLoadIfPending();
        }
        onRunningChanged: {
            if (!running && launchPending) {
                launchPending = false;
                root.installedLoadErrorMessage = qsTr("Could not start the installed-wallpaper helper");
                root.installedStatusMessage = "";
                root.restartInstalledLoadIfPending();
            }
        }
        onStarted: {
            launchPending = false;
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
    property ListModel results: ListModel {
        dynamicRoles: true
    }
    property string searchErrorMessage: ""
    property Process searchProcess: Process {
        property bool launchPending: false
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
            var response = root.parseResponse(searchOutput.text, searchError.text, qsTr("Could not search Steam Workshop"));
            if (exitCode !== 0 || !response.ok) {
                root.results.clear();
                root.totalResults = 0;
                root.searchErrorMessage = response.message || qsTr("Could not search Steam Workshop");
                root.searchStatusMessage = "";
                return;
            }

            root.searchErrorMessage = "";
            root.replaceModel(root.results, response.items || []);
            root.totalResults = Number(response.total || root.results.count);
            root.searchStatusMessage = root.results.count > 0 ? qsTr("%1 wallpapers").arg(root.totalResults) : "";
        }
        onRunningChanged: {
            if (!running && launchPending) {
                launchPending = false;
                root.results.clear();
                root.totalResults = 0;
                root.searchErrorMessage = qsTr("Could not start the Workshop search helper");
                root.searchStatusMessage = "";
            }
        }
        onStarted: {
            launchPending = false;
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
                root.restartSubscriptionRefreshIfPending();
            }
        }
        onStarted: {
            launchPending = false;
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

    signal downloadCompleted(string publishedFileId, string path, var modified)
    signal removeCompleted(string publishedFileId, string path)

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
        if (steamItemId === "")
            return;
        var nextSubscribed = Boolean(subscribed[steamItemId]);
        if (nextSubscribed === steamItemSubscribed)
            return;
        actionStatusMessage = nextSubscribed ? qsTr("Subscribed to %1").arg(steamItemTitle || steamItemId) : qsTr("Unsubscribed from %1").arg(steamItemTitle || steamItemId);
        steamItemId = "";
        steamItemTitle = "";
    }
    function cancelDownload() {
        if (!downloading || downloadCancelRequested)
            return false;
        downloadCancelRequested = true;
        actionStatusMessage = qsTr("Cancelling %1…").arg(downloadingTitle || downloadingId);
        downloadProcess.running = false;
        return true;
    }
    function download(item) {
        if (!item || downloading)
            return false;
        if (Config.steamUsername.trim() === "") {
            downloadErrorCode = "";
            downloadErrorMessage = qsTr("Add your Steam username in Settings first");
            return false;
        }

        downloadingId = String(item.id || "");
        downloadingTitle = String(item.title || downloadingId);
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
    function loadInstalled(force) {
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
        }
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
    }
    function modelIndexForId(model, publishedFileId) {
        var expectedId = String(publishedFileId || "");
        for (var i = 0; i < model.count; ++i) {
            if (String(model.get(i).id || "") === expectedId)
                return i;
        }
        return -1;
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
    function refreshSubscriptions(force) {
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
        subscriptionProcess.running = true;
        return true;
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
    function restartInstalledLoadIfPending() {
        if (!installedReloadPending)
            return;
        installedReloadPending = false;
        Qt.callLater(() => root.loadInstalled(true));
    }
    function restartSubscriptionRefreshIfPending() {
        if (!subscriptionRefreshPending)
            return;
        subscriptionRefreshPending = false;
        Qt.callLater(() => root.refreshSubscriptions(true));
    }
    function search(searchText, requestedPage, requestedSort) {
        if (searchProcess.running)
            return false;
        if (!configured) {
            results.clear();
            totalResults = 0;
            searchErrorMessage = qsTr("Add your Steam username and Web API key in Settings");
            searchStatusMessage = "";
            return false;
        }

        query = String(searchText || "").trim();
        page = Math.max(1, Number(requestedPage || 1));
        sortMode = String(requestedSort || "trending");
        searchErrorMessage = "";
        searchStatusMessage = qsTr("Searching Steam Workshop…");
        searchProcess.requestJson = JSON.stringify({
            "api_key": Config.steamWebApiKey.trim(),
            "legacy_workshop_root": Config.legacyWallpaperEngineWorkshopDir,
            "page": page,
            "query": query,
            "sort": sortMode,
            "steam_root": Config.steamDir,
            "workshop_root": Config.wallpaperEngineWorkshopDir
        });
        searchProcess.launchPending = true;
        searchProcess.running = true;
        return true;
    }
    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\"'\"'") + "'";
    }
}
