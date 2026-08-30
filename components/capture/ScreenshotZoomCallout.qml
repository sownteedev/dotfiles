import "../../"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    readonly property real calloutHeight: Math.max(1, Number(shapeData.calloutHeight || 0))
    readonly property real calloutWidth: Math.max(1, Number(shapeData.calloutWidth || 0))
    readonly property real calloutX: Number(shapeData.calloutX || 0) + offsetX
    readonly property real calloutY: Number(shapeData.calloutY || 0) + offsetY
    property real offsetX: 0
    property real offsetY: 0
    required property var shapeData
    readonly property real shapeOpacity: Math.max(0.1, Math.min(1, Number(shapeData.opacity === undefined ? 1 : shapeData.opacity)))
    readonly property real sourceHeight: Math.max(1, Math.abs(shapeData.endY - shapeData.startY))
    required property Item sourceItem
    readonly property real sourceLeft: Math.min(shapeData.startX, shapeData.endX) + offsetX
    readonly property real sourceTop: Math.min(shapeData.startY, shapeData.endY) + offsetY
    readonly property real sourceWidth: Math.max(1, Math.abs(shapeData.endX - shapeData.startX))
    readonly property real transformBottom: Math.max(sourceTop + sourceHeight, calloutY + calloutHeight)
    readonly property real transformCenterX: (transformLeft + transformRight) / 2
    readonly property real transformCenterY: (transformTop + transformBottom) / 2
    readonly property real transformLeft: Math.min(sourceLeft, calloutX)
    readonly property real transformRight: Math.max(sourceLeft + sourceWidth, calloutX + calloutWidth)
    readonly property real transformTop: Math.min(sourceTop, calloutY)

    Accessible.ignored: true
    opacity: shapeOpacity
    visible: sourceWidth >= 8 && sourceHeight >= 8 && calloutWidth >= 8 && calloutHeight >= 8

    transform: Rotation {
        angle: Number(root.shapeData.rotation || 0)
        origin.x: root.transformCenterX
        origin.y: root.transformCenterY
    }

    Shape {
        anchors.fill: parent
        antialiasing: true

        ShapePath {
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            startX: root.sourceLeft + root.sourceWidth / 2
            startY: root.sourceTop + root.sourceHeight / 2
            strokeColor: root.shapeData.color || Config.md3.tertiary
            strokeWidth: Math.max(2, Math.min(5, Number(root.shapeData.width || 3)))

            PathLine {
                x: root.calloutX + root.calloutWidth / 2
                y: root.calloutY + root.calloutHeight / 2
            }
        }
    }
    Rectangle {
        border.color: root.shapeData.color || Config.md3.tertiary
        border.width: Math.max(2, Math.min(5, Number(root.shapeData.width || 3)))
        color: "transparent"
        height: root.sourceHeight
        radius: Math.min(10, height / 4, width / 4)
        width: root.sourceWidth
        x: root.sourceLeft
        y: root.sourceTop
    }
    Item {
        id: zoomFrame

        height: root.calloutHeight
        width: root.calloutWidth
        x: root.calloutX
        y: root.calloutY

        Rectangle {
            anchors.fill: parent
            color: Config.md3.surface_container_highest
            radius: Math.min(18, width / 4, height / 4)
        }
        ShaderEffectSource {
            id: zoomTexture

            anchors.fill: parent
            live: true
            mipmap: false
            smooth: true
            sourceItem: root.sourceItem
            sourceRect: Qt.rect(root.sourceLeft, root.sourceTop, root.sourceWidth, root.sourceHeight)
            visible: false
        }
        Rectangle {
            id: zoomMask

            anchors.fill: parent
            radius: Math.min(18, width / 4, height / 4)
            visible: false
        }
        OpacityMask {
            anchors.fill: parent
            cached: false
            maskSource: zoomMask
            source: zoomTexture
        }
        Rectangle {
            anchors.fill: parent
            border.color: root.shapeData.color || Config.md3.tertiary
            border.width: Math.max(3, Math.min(6, Number(root.shapeData.width || 3) + 1))
            color: "transparent"
            radius: Math.min(18, width / 4, height / 4)
        }
    }
}
