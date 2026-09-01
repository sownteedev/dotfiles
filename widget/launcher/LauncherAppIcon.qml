pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Item {
    id: root

    property var entry: null
    property string fallbackIcon: "application-x-executable"
    property int requestedSourceSize: 96

    implicitHeight: 96
    implicitWidth: 96

    Image {
        anchors.fill: parent
        cache: true
        fillMode: Image.PreserveAspectFit
        mipmap: true
        smooth: true
        source: root.entry ? Quickshell.iconPath(root.entry.icon || root.fallbackIcon, root.fallbackIcon) : ""
        sourceSize.height: root.requestedSourceSize
        sourceSize.width: root.requestedSourceSize
    }
}
