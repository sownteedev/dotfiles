import "../.."
import QtQuick
import QtQuick.Effects

Item {
    id: root

    readonly property real leftEdge: Math.min(shapeData.startX, shapeData.endX)
    required property var shapeData
    property bool showOutline: false
    required property var sourceItem
    required property real surfaceHeight
    required property real surfaceWidth
    readonly property real topEdge: Math.min(shapeData.startY, shapeData.endY)

    clip: true
    height: Math.max(1, Math.abs(shapeData.endY - shapeData.startY))
    opacity: Math.max(0.1, Math.min(1, Number(shapeData.opacity === undefined ? 1 : shapeData.opacity)))
    width: Math.max(1, Math.abs(shapeData.endX - shapeData.startX))
    x: leftEdge
    y: topEdge

    ShaderEffectSource {
        id: regionSource

        anchors.fill: parent
        live: root.showOutline
        mipmap: false
        smooth: true
        sourceItem: root.sourceItem
        sourceRect: Qt.rect(root.leftEdge, root.topEdge, root.width, root.height)
    }
    MultiEffect {
        anchors.fill: parent
        autoPaddingEnabled: false
        blur: 1
        blurEnabled: true
        blurMax: Math.round(24 + Math.max(2, Math.min(24, root.shapeData.width || 6)) * 2)
        source: regionSource
    }
    Rectangle {
        anchors.fill: parent
        border.color: Config.md3.tertiary
        border.width: 2
        color: "transparent"
        visible: root.showOutline
    }
}
