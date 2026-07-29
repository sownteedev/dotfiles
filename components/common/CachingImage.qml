import QtQuick
import QtQuick.Window
import Native.ImageCache 1.0

Image {
    id: root

    property string cacheKey: ""
    property int loadTimeout: 4500
    property int maxRetries: 2
    property int retryCount: 0
    property int retryRevision: 0
    readonly property string localPath: {
        var value = String(path || "");
        if (value.startsWith("file://"))
            return decodeURIComponent(value.substring(7));
        return value;
    }
    property string path: ""
    readonly property string provider: {
        if (fillMode === Image.PreserveAspectFit)
            return "dotffitcache";
        if (fillMode === Image.Stretch)
            return "dotfstretchcache";
        return "dotfcache";
    }

    function requestQuery() {
        var values = [];
        if (cacheKey)
            values.push("v=" + encodeURIComponent(cacheKey));
        if (retryRevision > 0)
            values.push("retry=" + String(retryRevision));
        return values.length > 0 ? "?" + values.join("&") : "";
    }
    function scheduleRetry() {
        if (!localPath || retryCount >= maxRetries)
            return false;

        if (!retryTimer.running)
            retryTimer.restart();
        return true;
    }

    asynchronous: true
    cache: true
    fillMode: Image.PreserveAspectCrop
    source: localPath && width >= 2 && height >= 2 ? "image://" + provider + encodeURI(localPath) + requestQuery() : ""
    sourceSize: Qt.size(Math.max(1, Math.ceil(width * Screen.devicePixelRatio)), Math.max(1, Math.ceil(height * Screen.devicePixelRatio)))

    onLocalPathChanged: {
        retryTimer.stop();
        loadWatchdog.stop();
        retryCount = 0;
        retryRevision = 0;
    }
    onStatusChanged: {
        if (status === Image.Ready) {
            retryTimer.stop();
            loadWatchdog.stop();
            retryCount = 0;
        } else if (status === Image.Loading) {
            loadWatchdog.restart();
        } else if (status === Image.Error) {
            loadWatchdog.stop();
            scheduleRetry();
        }
    }

    Timer {
        id: retryTimer

        interval: 120
        repeat: false

        onTriggered: {
            ++root.retryCount;
            ++root.retryRevision;
        }
    }

    Timer {
        id: loadWatchdog

        interval: Math.max(1000, root.loadTimeout)
        repeat: false

        onTriggered: {
            if (root.status === Image.Loading)
                root.scheduleRetry();
        }
    }
}
