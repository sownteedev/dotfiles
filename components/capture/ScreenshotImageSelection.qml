import "../../"
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    required property string layerId
    property bool removable: true
    required property var shapeData
    required property real surfaceHeight
    required property real surfaceWidth

    signal cropCanceled(string layerId)
    signal cropFinished(string layerId)
    signal cropRequested(string layerId, real localX, real localY, real width, real height)
    signal cropStarted(string layerId)
    signal removeRequested(string layerId)
    signal resizeCanceled(string layerId)
    signal resizeFinished(string layerId)
    signal resizeRequested(string layerId, real x, real y, real width, real height)
    signal resizeStarted(string layerId)
    signal rotationCanceled(string layerId)
    signal rotationFinished(string layerId)
    signal rotationRequested(string layerId, real angle)
    signal rotationStarted(string layerId)

    function cursorForHandle(horizontalSign, verticalSign) {
        var angle = (horizontalSign === verticalSign ? 45 : 135) + rotation;
        angle = ((angle % 180) + 180) % 180;
        if (angle < 22.5 || angle >= 157.5)
            return Qt.SizeHorCursor;
        if (angle < 67.5)
            return Qt.SizeFDiagCursor;
        if (angle < 112.5)
            return Qt.SizeVerCursor;
        return Qt.SizeBDiagCursor;
    }

    height: Math.abs(shapeData.endY - shapeData.startY)
    rotation: Number(shapeData.rotation || 0)
    transformOrigin: Item.Center
    width: Math.abs(shapeData.endX - shapeData.startX)
    x: Math.min(shapeData.startX, shapeData.endX)
    y: Math.min(shapeData.startY, shapeData.endY)

    Rectangle {
        anchors.fill: parent
        border.color: Config.md3.tertiary
        border.width: 2
        color: "transparent"
    }
    Repeater {
        model: ["left", "right", "top", "bottom"]

        delegate: MouseArea {
            id: cropPointer

            required property string modelData
            property real startCenterX: 0
            property real startCenterY: 0
            property real startHeight: 0
            property real startRotation: 0
            property real startWidth: 0

            function pointerInOriginalSpace(mouse) {
                var surfacePoint = cropPointer.mapToItem(root.parent, mouse.x, mouse.y);
                var dx = surfacePoint.x - startCenterX;
                var dy = surfacePoint.y - startCenterY;
                var radians = -startRotation * Math.PI / 180;
                return {
                    "x": dx * Math.cos(radians) - dy * Math.sin(radians) + startWidth / 2,
                    "y": dx * Math.sin(radians) + dy * Math.cos(radians) + startHeight / 2
                };
            }
            function updateCrop(mouse) {
                var localPoint = pointerInOriginalSpace(mouse);
                var minimumSize = Math.min(48, Math.max(16, Math.min(startWidth, startHeight) * 0.25));
                var localX = 0;
                var localY = 0;
                var nextWidth = startWidth;
                var nextHeight = startHeight;
                if (modelData === "left") {
                    localX = Math.max(0, Math.min(startWidth - minimumSize, localPoint.x));
                    nextWidth = startWidth - localX;
                } else if (modelData === "right") {
                    nextWidth = Math.max(minimumSize, Math.min(startWidth, localPoint.x));
                } else if (modelData === "top") {
                    localY = Math.max(0, Math.min(startHeight - minimumSize, localPoint.y));
                    nextHeight = startHeight - localY;
                } else {
                    nextHeight = Math.max(minimumSize, Math.min(startHeight, localPoint.y));
                }
                root.cropRequested(root.layerId, localX, localY, nextWidth, nextHeight);
            }

            cursorShape: modelData === "left" || modelData === "right" ? Qt.SizeHorCursor : Qt.SizeVerCursor
            height: modelData === "left" || modelData === "right" ? Math.max(0, root.height - 30) : 12
            hoverEnabled: true
            preventStealing: true
            width: modelData === "left" || modelData === "right" ? 12 : Math.max(0, root.width - 30)
            x: modelData === "right" ? root.width - width / 2 : modelData === "left" ? -width / 2 : 15
            y: modelData === "bottom" ? root.height - height / 2 : modelData === "top" ? -height / 2 : 15
            z: 1

            onCanceled: root.cropCanceled(root.layerId)
            onPositionChanged: mouse => {
                if (pressed)
                    updateCrop(mouse);
            }
            onPressed: mouse => {
                startWidth = root.width;
                startHeight = root.height;
                startCenterX = root.x + root.width / 2;
                startCenterY = root.y + root.height / 2;
                startRotation = root.rotation;
                root.cropStarted(root.layerId);
            }
            onReleased: root.cropFinished(root.layerId)
        }
    }
    Rectangle {
        id: removeButton

        Accessible.name: qsTr("Remove image")
        Accessible.role: Accessible.Button
        anchors.right: parent.right
        anchors.rightMargin: 18
        anchors.top: parent.top
        anchors.topMargin: 18
        color: removePointer.pressed ? Config.md3.error : Config.alpha(Config.md3.error, removePointer.containsMouse ? 0.92 : 0.78)
        height: 28
        radius: 9
        visible: root.removable
        width: 28
        z: 2

        IconImage {
            anchors.centerIn: parent
            height: 15
            layer.enabled: true
            source: Quickshell.iconPath("window-close-symbolic")
            width: 15

            layer.effect: ColorOverlay {
                color: Config.md3.on_error
            }
        }
        MouseArea {
            id: removePointer

            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: root.removeRequested(root.layerId)
        }
    }
    Repeater {
        model: [
            {
                "horizontal": "left",
                "vertical": "top",
                "horizontalSign": -1,
                "verticalSign": -1
            },
            {
                "horizontal": "right",
                "vertical": "top",
                "horizontalSign": 1,
                "verticalSign": -1
            },
            {
                "horizontal": "left",
                "vertical": "bottom",
                "horizontalSign": -1,
                "verticalSign": 1
            },
            {
                "horizontal": "right",
                "vertical": "bottom",
                "horizontalSign": 1,
                "verticalSign": 1
            }
        ]

        delegate: Rectangle {
            id: resizeHandle

            required property var modelData
            property bool resizeFromCenter: false
            property real startCenterX: 0
            property real startCenterY: 0
            property real startHeight: 0
            property real startPointerX: 0
            property real startPointerY: 0
            property real startRotation: 0
            property real startWidth: 0

            function pointerPosition(mouse) {
                return resizePointer.mapToItem(root.parent, mouse.x, mouse.y);
            }
            function updateResize(mouse) {
                var pointer = pointerPosition(mouse);
                var dx = pointer.x - startPointerX;
                var dy = pointer.y - startPointerY;
                var radians = startRotation * Math.PI / 180;
                var localDx = dx * Math.cos(radians) + dy * Math.sin(radians);
                var localDy = -dx * Math.sin(radians) + dy * Math.cos(radians);
                var horizontalSpan = modelData.horizontalSign * startWidth * (resizeFromCenter ? 0.5 : 1);
                var verticalSpan = modelData.verticalSign * startHeight * (resizeFromCenter ? 0.5 : 1);
                var diagonalSquared = horizontalSpan * horizontalSpan + verticalSpan * verticalSpan;
                var scale = 1 + (localDx * horizontalSpan + localDy * verticalSpan) / Math.max(1, diagonalSquared);
                scale = Math.max(0.1, Math.min(8, scale));

                var nextWidth = startWidth * scale;
                var nextHeight = startHeight * scale;
                var nextCenterX = startCenterX;
                var nextCenterY = startCenterY;
                if (!resizeFromCenter) {
                    var fixedLocalX = -modelData.horizontalSign * startWidth / 2;
                    var fixedLocalY = -modelData.verticalSign * startHeight / 2;
                    var fixedWorldX = startCenterX + fixedLocalX * Math.cos(radians) - fixedLocalY * Math.sin(radians);
                    var fixedWorldY = startCenterY + fixedLocalX * Math.sin(radians) + fixedLocalY * Math.cos(radians);
                    var nextHalfX = modelData.horizontalSign * nextWidth / 2;
                    var nextHalfY = modelData.verticalSign * nextHeight / 2;
                    nextCenterX = fixedWorldX + nextHalfX * Math.cos(radians) - nextHalfY * Math.sin(radians);
                    nextCenterY = fixedWorldY + nextHalfX * Math.sin(radians) + nextHalfY * Math.cos(radians);
                }
                root.resizeRequested(root.layerId, nextCenterX - nextWidth / 2, nextCenterY - nextHeight / 2, nextWidth, nextHeight);
            }

            border.color: Config.md3.tertiary
            border.width: 1
            color: resizePointer.pressed ? Config.md3.tertiary : resizePointer.containsMouse ? Config.md3.tertiary_container : Config.md3.surface
            height: 10
            width: 10
            x: modelData.horizontal === "left" ? -width / 2 : root.width - width / 2
            y: modelData.vertical === "top" ? -height / 2 : root.height - height / 2
            z: 3

            MouseArea {
                id: resizePointer

                Accessible.name: qsTr("Resize image")
                Accessible.role: Accessible.Button
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: root.cursorForHandle(resizeHandle.modelData.horizontalSign, resizeHandle.modelData.verticalSign)
                hoverEnabled: true
                preventStealing: true

                onCanceled: root.resizeCanceled(root.layerId)
                onPositionChanged: mouse => {
                    if (pressed)
                        resizeHandle.updateResize(mouse);
                }
                onPressed: mouse => {
                    var pointer = resizeHandle.pointerPosition(mouse);
                    resizeHandle.startPointerX = pointer.x;
                    resizeHandle.startPointerY = pointer.y;
                    resizeHandle.startCenterX = root.x + root.width / 2;
                    resizeHandle.startCenterY = root.y + root.height / 2;
                    resizeHandle.startWidth = root.width;
                    resizeHandle.startHeight = root.height;
                    resizeHandle.startRotation = root.rotation;
                    resizeHandle.resizeFromCenter = (mouse.modifiers & Qt.AltModifier) !== 0;
                    root.resizeStarted(root.layerId);
                }
                onReleased: root.resizeFinished(root.layerId)
            }
        }
    }
    Rectangle {
        anchors.bottom: parent.top
        anchors.bottomMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        color: Config.md3.tertiary
        height: 22
        width: 2
        z: 2
    }
    Rectangle {
        id: rotationHandle

        property real startPointerAngle: 0
        property real startRotation: 0

        anchors.bottom: parent.top
        anchors.bottomMargin: 22
        anchors.horizontalCenter: parent.horizontalCenter
        border.color: Config.md3.surface
        border.width: 2
        color: Config.md3.tertiary
        height: 18
        radius: 9
        width: 18
        z: 3

        MouseArea {
            id: rotationPointer

            function pointerAngle(mouse) {
                var pointerPosition = rotationPointer.mapToItem(root.parent, mouse.x, mouse.y);
                var centerX = root.x + root.width / 2;
                var centerY = root.y + root.height / 2;
                return Math.atan2(pointerPosition.y - centerY, pointerPosition.x - centerX) * 180 / Math.PI;
            }

            anchors.fill: parent
            anchors.margins: -8
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            preventStealing: true

            onCanceled: root.rotationCanceled(root.layerId)
            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                var delta = pointerAngle(mouse) - rotationHandle.startPointerAngle;
                while (delta > 180)
                    delta -= 360;
                while (delta < -180)
                    delta += 360;
                var nextRotation = rotationHandle.startRotation + delta;
                if (mouse.modifiers & Qt.ShiftModifier)
                    nextRotation = Math.round(nextRotation / 15) * 15;
                root.rotationRequested(root.layerId, nextRotation);
            }
            onPressed: mouse => {
                rotationHandle.startRotation = root.rotation;
                rotationHandle.startPointerAngle = pointerAngle(mouse);
                root.rotationStarted(root.layerId);
            }
            onReleased: root.rotationFinished(root.layerId)
        }
    }
}
