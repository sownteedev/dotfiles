import "../../"
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets

Rectangle {
    id: root

    property color accentColor: Config.md3.primary
    property string fallbackIcon: "avatar-default-symbolic"
    property string sourcePath: ""
    readonly property string sourceUrl: {
        var value = Config.expandHomePath(sourcePath);
        if (value === "")
            return "";
        return value.indexOf("file:") === 0 ? value : "file://" + value;
    }

    Accessible.ignored: true
    border.color: Config.alpha(accentColor, 0.34)
    border.width: 1
    color: Config.alpha(accentColor, 0.15)
    implicitHeight: 72
    implicitWidth: 72
    radius: Math.min(width, height) / 2

    IconImage {
        anchors.centerIn: parent
        implicitHeight: Math.round(Math.min(root.width, root.height) * 0.43)
        implicitWidth: implicitHeight
        layer.enabled: true
        source: Quickshell.iconPath(root.fallbackIcon)
        visible: avatar.status !== Image.Ready

        layer.effect: ColorOverlay {
            color: root.accentColor
        }
    }
    Image {
        id: avatar

        anchors.fill: parent
        anchors.margins: 3
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        layer.enabled: status === Image.Ready
        smooth: true
        source: root.sourceUrl
        sourceSize: Qt.size(Math.max(1, width * 2), Math.max(1, height * 2))
        visible: status === Image.Ready

        layer.effect: OpacityMask {
            maskSource: Rectangle {
                height: avatar.height
                radius: Math.min(width, height) / 2
                width: avatar.width
            }
        }
    }
}
