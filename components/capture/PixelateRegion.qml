import "../../"
import QtQuick

Item {
    id: root

    readonly property real blockSize: 5 + Math.max(2, Math.min(24, shapeData.width || 6)) * 0.75
    readonly property real leftEdge: Math.min(shapeData.startX, shapeData.endX)

    // Render only this region into a low-resolution texture, then scale it
    // without smoothing so no external image-processing process is needed.
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
        anchors.fill: parent
        // The screenshot itself is static. A committed region only needs one
        // texture update; the region being dragged stays live.
        live: root.showOutline
        mipmap: false
        smooth: false
        sourceItem: root.sourceItem
        sourceRect: Qt.rect(root.leftEdge, root.topEdge, root.width, root.height)
        textureSize: Qt.size(Math.max(1, Math.ceil(root.width / root.blockSize)), Math.max(1, Math.ceil(root.height / root.blockSize)))
    }
    Rectangle {
        anchors.fill: parent
        border.color: Config.md3.tertiary
        border.width: 2
        color: "transparent"
        visible: root.showOutline
    }
}
