import "../../"
import Qt5Compat.GraphicalEffects
import QtQuick

Item {
    id: root

    readonly property int blueChannel: Math.round(pickedColor.b * 255)
    property real diameter: 184
    readonly property int greenChannel: Math.round(pickedColor.g * 255)
    readonly property string hexColor: "#" + hexChannel(redChannel) + hexChannel(greenChannel) + hexChannel(blueChannel)
    readonly property real labelReserve: Math.min(50, Math.max(0, surfaceHeight - diameter))
    readonly property real loupeX: pointerX + 26 + diameter <= surfaceWidth ? pointerX + 26 : Math.max(0, pointerX - diameter - 26)
    readonly property real loupeY: {
        var candidate = pointerY + 26 + diameter <= surfaceHeight ? pointerY + 26 : pointerY - diameter - 26;
        return Math.max(labelReserve, Math.min(Math.max(labelReserve, surfaceHeight - diameter), candidate));
    }
    property color pickedColor: "#000000"
    property real pointerX: 0
    property real pointerY: 0
    readonly property int redChannel: Math.round(pickedColor.r * 255)
    readonly property real sampleSize: Math.max(12, diameter / 3.2)
    readonly property real sampleX: sourceItem ? Math.max(0, Math.min(Math.max(0, sourceItem.width - sampleSize), sourceX - sampleSize / 2)) : 0
    readonly property real sampleY: sourceItem ? Math.max(0, Math.min(Math.max(0, sourceItem.height - sampleSize), sourceY - sampleSize / 2)) : 0
    property Item sourceItem: null
    property real sourceX: 0
    property real sourceY: 0
    required property real surfaceHeight
    required property real surfaceWidth

    function hexChannel(channel) {
        var value = Math.max(0, Math.min(255, Math.round(channel))).toString(16).toUpperCase();
        return value.length < 2 ? "0" + value : value;
    }

    Accessible.ignored: true

    Item {
        id: loupeFrame

        height: root.diameter
        width: root.diameter
        x: root.loupeX
        y: root.loupeY

        Rectangle {
            anchors.fill: parent
            color: Config.md3.surface_container_highest
            radius: width / 2
        }
        ShaderEffectSource {
            id: loupeTexture

            anchors.fill: parent
            live: root.visible && root.sourceItem !== null
            mipmap: false
            smooth: false
            sourceItem: root.sourceItem
            sourceRect: Qt.rect(root.sampleX, root.sampleY, root.sampleSize, root.sampleSize)
            visible: false
        }
        Rectangle {
            id: loupeMask

            anchors.fill: parent
            anchors.margins: 12
            radius: width / 2
            visible: false
        }
        OpacityMask {
            anchors.fill: loupeMask
            cached: false
            maskSource: loupeMask
            source: loupeTexture
        }
        Rectangle {
            anchors.fill: parent
            border.color: Config.alpha(Config.md3.on_surface, 0.62)
            border.width: 12
            color: "transparent"
            radius: width / 2
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 9
            border.color: root.pickedColor
            border.width: 6
            color: "transparent"
            radius: width / 2
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 15
            border.color: "#ffffff"
            border.width: 2
            color: "transparent"
            radius: width / 2
        }
        Rectangle {
            anchors.centerIn: parent
            color: "#000000"
            height: 2
            width: 24
        }
        Rectangle {
            anchors.centerIn: parent
            color: "#ffffff"
            height: 1
            width: 24
        }
        Rectangle {
            anchors.centerIn: parent
            color: "#000000"
            height: 24
            width: 2
        }
        Rectangle {
            anchors.centerIn: parent
            color: "#ffffff"
            height: 24
            width: 1
        }
        Rectangle {
            id: colorLabel

            anchors.bottom: parent.top
            anchors.bottomMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            color: Config.alpha("#000000", 0.88)
            height: colorLabelText.implicitHeight + 12
            radius: 7
            width: colorLabelText.implicitWidth + 18

            Text {
                id: colorLabelText

                anchors.centerIn: parent
                color: "#ffffff"
                font.family: "monospace"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignLeft
                lineHeight: 1.12
                text: root.hexColor + "\n" + qsTr("RGB %1, %2, %3").arg(root.redChannel).arg(root.greenChannel).arg(root.blueChannel)
            }
        }
    }
}
