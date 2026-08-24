import Qt5Compat.GraphicalEffects
import QtQuick

Rectangle {
    id: root

    property string sourcePath: GreeterProfile.sourcePath

    Accessible.ignored: true
    border.color: GreeterTheme.withAlpha(GreeterTheme.primary, 0.42)
    border.width: 1
    color: GreeterTheme.withAlpha(GreeterTheme.primaryContainer, 0.82)
    implicitHeight: 92
    implicitWidth: 92
    radius: Math.min(width, height) / 2

    Text {
        anchors.centerIn: parent
        color: GreeterTheme.primaryContainerText
        font.family: "Symbols Nerd Font"
        font.pixelSize: Math.round(Math.min(root.width, root.height) * 0.38)
        text: "󰀄"
        visible: avatar.status !== Image.Ready
    }
    Image {
        id: avatar

        anchors.fill: parent
        anchors.margins: 4
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        layer.enabled: status === Image.Ready
        smooth: true
        source: GreeterProfile.fileUrl(root.sourcePath)
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
