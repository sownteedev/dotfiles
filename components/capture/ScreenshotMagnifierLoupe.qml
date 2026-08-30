import "../../"
import Qt5Compat.GraphicalEffects
import QtQuick

Item {
    id: root

    property real diameter: 172
    readonly property real loupeX: pointerX + 24 + diameter <= surfaceWidth ? pointerX + 24 : Math.max(0, pointerX - diameter - 24)
    readonly property real loupeY: pointerY + 24 + diameter <= surfaceHeight ? pointerY + 24 : Math.max(0, pointerY - diameter - 24)
    property real pointerX: 0
    property real pointerY: 0
    readonly property real sampleSize: diameter / Math.max(1.5, zoom)
    readonly property real sampleX: Math.max(0, Math.min(surfaceWidth - sampleSize, pointerX - sampleSize / 2))
    readonly property real sampleY: Math.max(0, Math.min(surfaceHeight - sampleSize, pointerY - sampleSize / 2))
    required property Item sourceItem
    required property real surfaceHeight
    required property real surfaceWidth
    property real zoom: 2.5

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
            live: root.visible
            mipmap: false
            smooth: true
            sourceItem: root.visible ? root.sourceItem : null
            sourceRect: Qt.rect(root.sampleX, root.sampleY, root.sampleSize, root.sampleSize)
            visible: false
        }
        Rectangle {
            id: loupeMask

            anchors.fill: parent
            radius: width / 2
            visible: false
        }
        OpacityMask {
            anchors.fill: parent
            cached: false
            maskSource: loupeMask
            source: loupeTexture
        }
        Rectangle {
            anchors.centerIn: parent
            color: Config.alpha(Config.md3.on_surface, 0.72)
            height: 1
            width: 22
        }
        Rectangle {
            anchors.centerIn: parent
            color: Config.alpha(Config.md3.on_surface, 0.72)
            height: 22
            width: 1
        }
        Rectangle {
            anchors.fill: parent
            border.color: Config.md3.tertiary
            border.width: 4
            color: "transparent"
            radius: width / 2
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            color: Config.alpha("#000000", 0.72)
            height: 24
            radius: 12
            width: zoomLabel.implicitWidth + 18

            Text {
                id: zoomLabel

                anchors.centerIn: parent
                color: "#ffffff"
                font.family: Config.fontName
                font.pixelSize: 11
                font.weight: Font.Bold
                text: qsTr("%1×").arg(root.zoom.toFixed(2).replace(/0+$/, "").replace(/\.$/, ""))
            }
        }
    }
}
