import QtQuick
import QtQuick.Window
import Native.ImageCache 1.0

Image {
    id: root

    property string cacheKey: ""
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

    asynchronous: true
    cache: true
    fillMode: Image.PreserveAspectCrop
    source: localPath && width >= 2 && height >= 2 ? "image://" + provider + encodeURI(localPath) + (cacheKey ? "?v=" + encodeURIComponent(cacheKey) : "") : ""
    sourceSize: Qt.size(Math.max(1, Math.ceil(width * Screen.devicePixelRatio)), Math.max(1, Math.ceil(height * Screen.devicePixelRatio)))
}
