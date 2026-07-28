import "../../"
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets

ClippingRectangle {
    id: root

    property string appIcon: notificationData && notificationData.appIcon ? notificationData.appIcon.toString() : ""
    property string appName: notificationData && notificationData.appName ? notificationData.appName.toString() : ""
    property bool asynchronous: false
    property color backgroundColor: Config.md3.surface
    property bool cacheImage: true
    readonly property bool directImageReady: hasDirectImage && directImage.status === Image.Ready
    readonly property string directImageSource: resolveDirectImage()
    readonly property bool hasDirectImage: directImageSource !== ""
    readonly property bool hasProvidedIcon: notificationImage !== "" || appIcon !== ""
    property real iconSize: Math.min(width, height) * 0.55
    property var notificationData: null
    property string notificationImage: notificationData && notificationData.image ? notificationData.image.toString() : ""
    property real sourceSizeScale: 1
    property bool tintAllIcons: false
    property color tintColor: Config.alpha(Config.md3.on_surface, 0.45)

    function isDirectPath(value) {
        return value.startsWith("/") || value.startsWith("file://") || value.startsWith("image://");
    }
    function normalizeDirectPath(value) {
        return value.startsWith("/") ? "file://" + value : value;
    }
    function resolveDirectImage() {
        if (isDirectPath(notificationImage))
            return normalizeDirectPath(notificationImage);

        if (isDirectPath(appIcon))
            return normalizeDirectPath(appIcon);

        return "";
    }
    function resolveNamedIcon() {
        if (notificationImage !== "" && !isDirectPath(notificationImage) && Quickshell.iconPath(notificationImage, true) !== "")
            return Quickshell.iconPath(notificationImage);

        if (appIcon !== "" && !isDirectPath(appIcon) && Quickshell.iconPath(appIcon, true) !== "")
            return Quickshell.iconPath(appIcon);

        var normalizedName = appName.toLowerCase().replace(/ /g, "-");
        if (normalizedName !== "") {
            var entry = DesktopEntries.byId(normalizedName) || DesktopEntries.heuristicLookup(normalizedName);
            if (entry && entry.icon && Quickshell.iconPath(entry.icon, true) !== "")
                return Quickshell.iconPath(entry.icon);

            if (Quickshell.iconPath(normalizedName, true) !== "")
                return Quickshell.iconPath(normalizedName);
        }
        return Quickshell.iconPath("preferences-system-notifications-symbolic");
    }

    color: directImageReady ? "transparent" : backgroundColor

    Image {
        id: directImage

        anchors.fill: parent
        asynchronous: root.asynchronous
        cache: root.cacheImage
        fillMode: Image.PreserveAspectCrop
        source: root.directImageSource
        sourceSize: Qt.size(root.width * root.sourceSizeScale, root.height * root.sourceSizeScale)
        visible: root.directImageReady
    }
    IconImage {
        anchors.centerIn: parent
        height: root.iconSize
        layer.enabled: root.tintAllIcons || source.toString().includes("symbolic")
        source: root.resolveNamedIcon()
        visible: !root.directImageReady
        width: root.iconSize

        layer.effect: ColorOverlay {
            color: root.tintColor
        }
    }
}
