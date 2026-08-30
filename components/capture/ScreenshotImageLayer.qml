import QtQuick

Item {
    id: root

    property bool hidden: false
    readonly property Item imageItem: layerImage
    readonly property size imageSourceSize: Qt.size(Math.max(0, layerImage.implicitWidth), Math.max(0, layerImage.implicitHeight))
    readonly property int imageStatus: layerImage.status
    property bool loadEnabled: true
    property real offsetX: 0
    property real offsetY: 0
    required property var shapeData
    readonly property real sourceCropHeight: Math.max(0.0001, Math.min(1, Number(shapeData.cropHeight === undefined ? 1 : shapeData.cropHeight)))
    readonly property real sourceCropWidth: Math.max(0.0001, Math.min(1, Number(shapeData.cropWidth === undefined ? 1 : shapeData.cropWidth)))
    readonly property real sourceCropX: Math.max(0, Math.min(1 - sourceCropWidth, Number(shapeData.cropX || 0)))
    readonly property real sourceCropY: Math.max(0, Math.min(1 - sourceCropHeight, Number(shapeData.cropY || 0)))
    readonly property size sourceSize: imageSourceSize
    readonly property int status: imageStatus

    clip: true
    height: Math.abs(shapeData.endY - shapeData.startY)
    rotation: Number(shapeData.rotation || 0)
    transformOrigin: Item.Center
    visible: !hidden && !Boolean(shapeData.hidden) && width > 0 && height > 0 && shapeData.source
    width: Math.abs(shapeData.endX - shapeData.startX)
    x: Math.min(shapeData.startX, shapeData.endX) + offsetX
    y: Math.min(shapeData.startY, shapeData.endY) + offsetY

    Image {
        id: layerImage

        asynchronous: true
        cache: false
        fillMode: Image.Stretch
        height: root.height / root.sourceCropHeight
        opacity: Math.max(0.1, Math.min(1, Number(root.shapeData.opacity === undefined ? 1 : root.shapeData.opacity)))
        smooth: true
        source: root.loadEnabled && root.shapeData.source ? "file://" + root.shapeData.source : ""
        sourceSize: root.shapeData.decodeWidth > 0 || root.shapeData.decodeHeight > 0 ? Qt.size(root.shapeData.decodeWidth || -1, root.shapeData.decodeHeight || -1) : undefined
        width: root.width / root.sourceCropWidth
        x: -root.sourceCropX * width
        y: -root.sourceCropY * height
    }
}
