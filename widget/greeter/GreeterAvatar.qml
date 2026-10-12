import Qt5Compat.GraphicalEffects
import QtQuick

Item {
    id: root

    property string sourcePath: GreeterProfile.sourcePath

    Accessible.ignored: true
    implicitHeight: 76
    implicitWidth: 76

    // Avatar Container
    Rectangle {
        id: avatarContainer

        anchors.centerIn: parent
        border.color: GreeterTheme.withAlpha(GreeterTheme.primary, 0.28)
        border.width: 1
        color: GreeterTheme.withAlpha(GreeterTheme.primaryContainer, 0.85)
        height: Math.min(parent.width, parent.height)
        radius: height * 0.32
        width: height

        Text {
            anchors.centerIn: parent
            color: GreeterTheme.primaryContainerText
            font.family: "Symbols Nerd Font"
            font.pixelSize: Math.round(avatarContainer.height * 0.42)
            text: "󰀄"
            visible: avatar.status !== Image.Ready
        }
        Image {
            id: avatar

            anchors.fill: parent
            anchors.margins: 3
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
                    radius: Math.min(width, height) * 0.3
                    width: avatar.width
                }
            }
        }
    }
}
