pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../components"

Item {
    id: root

    property var entry: null
    property string fallbackIcon: "application-x-executable"
    property int requestedSourceSize: 96
    readonly property string shellIconKind: {
        if (!root.entry)
            return "";
        var id = typeof root.entry === "string" ? root.entry : String(root.entry.id || "").trim();
        id = id.toLowerCase();
        if (id.endsWith(".desktop"))
            id = id.slice(0, -8);
        if (id === "sownteeshell-settings" || id === "sownteeshell-calendar" || id === "sownteeshell-connect")
            return id.slice("sownteeshell-".length);
        var icon = typeof root.entry === "object" ? String(root.entry.icon || "").trim().toLowerCase() : "";
        if (icon.endsWith(".svg") || icon.endsWith(".png"))
            icon = icon.replace(/\.(svg|png)$/, "");
        if (icon === "sownteeshell-settings" || icon === "sownteeshell-calendar" || icon === "sownteeshell-connect")
            return icon.slice("sownteeshell-".length);
        return "";
    }

    implicitHeight: 96
    implicitWidth: 96

    SownteeAppIcon {
        anchors.fill: parent
        kind: root.shellIconKind
        visible: root.shellIconKind !== ""
    }
    Image {
        anchors.fill: parent
        cache: true
        fillMode: Image.PreserveAspectFit
        mipmap: true
        smooth: true
        source: visible && root.entry ? Quickshell.iconPath(root.entry.icon || root.fallbackIcon, root.fallbackIcon) : ""
        sourceSize.height: root.requestedSourceSize
        sourceSize.width: root.requestedSourceSize
        visible: root.shellIconKind === ""
    }
}
