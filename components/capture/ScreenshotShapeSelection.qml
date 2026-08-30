import "../../"
import QtQuick

Item {
    id: root

    required property rect frameRect
    property real offsetX: 0
    property real offsetY: 0
    property bool resizeEnabled: true
    property real rotationAngle: 0
    property bool rotationEnabled: true

    signal resizeCanceled
    signal resizeFinished
    signal resizeRequested(real pointerX, real pointerY)
    signal resizeStarted(int horizontalSign, int verticalSign, real pointerX, real pointerY, int modifiers)
    signal rotationCanceled
    signal rotationFinished
    signal rotationRequested(real angle)
    signal rotationStarted

    function cursorForHandle(horizontalSign, verticalSign) {
        var angle = (horizontalSign === verticalSign ? 45 : 135) + rotationAngle;
        angle = ((angle % 180) + 180) % 180;
        if (angle < 22.5 || angle >= 157.5)
            return Qt.SizeHorCursor;
        if (angle < 67.5)
            return Qt.SizeFDiagCursor;
        if (angle < 112.5)
            return Qt.SizeVerCursor;
        return Qt.SizeBDiagCursor;
    }

    height: frameRect.height
    rotation: rotationAngle
    transformOrigin: Item.Center
    width: frameRect.width
    x: frameRect.x + offsetX
    y: frameRect.y + offsetY

    Rectangle {
        Accessible.ignored: true
        anchors.fill: parent
        border.color: Config.md3.tertiary
        border.width: 1
        color: "transparent"
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

            function pointerPosition(mouse) {
                return resizePointer.mapToItem(root.parent, mouse.x, mouse.y);
            }

            border.color: Config.md3.tertiary
            border.width: 1
            color: resizePointer.pressed ? Config.md3.tertiary : resizePointer.containsMouse ? Config.md3.tertiary_container : Config.md3.surface
            height: 10
            visible: root.resizeEnabled
            width: 10
            x: modelData.horizontal === "left" ? -width / 2 : root.width - width / 2
            y: modelData.vertical === "top" ? -height / 2 : root.height - height / 2
            z: 2

            MouseArea {
                id: resizePointer

                Accessible.name: qsTr("Resize annotation")
                Accessible.role: Accessible.Button
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: root.cursorForHandle(resizeHandle.modelData.horizontalSign, resizeHandle.modelData.verticalSign)
                hoverEnabled: true
                preventStealing: true

                onCanceled: root.resizeCanceled()
                onPositionChanged: mouse => {
                    if (!pressed)
                        return;
                    var pointer = resizeHandle.pointerPosition(mouse);
                    root.resizeRequested(pointer.x, pointer.y);
                }
                onPressed: mouse => {
                    var pointer = resizeHandle.pointerPosition(mouse);
                    root.resizeStarted(resizeHandle.modelData.horizontalSign, resizeHandle.modelData.verticalSign, pointer.x, pointer.y, mouse.modifiers);
                }
                onReleased: root.resizeFinished()
            }
        }
    }
    Rectangle {
        anchors.bottom: parent.top
        anchors.bottomMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        color: Config.md3.tertiary
        height: 20
        visible: root.rotationEnabled
        width: 1
        z: 2
    }
    Rectangle {
        id: rotationHandle

        property real startPointerAngle: 0
        property real startRotation: 0

        Accessible.ignored: true
        anchors.bottom: parent.top
        anchors.bottomMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        border.color: Config.md3.surface
        border.width: 2
        color: rotationPointer.pressed ? Config.md3.primary : rotationPointer.containsMouse ? Config.md3.primary_container : Config.md3.tertiary
        height: 17
        radius: 9
        visible: root.rotationEnabled
        width: 17
        z: 3

        MouseArea {
            id: rotationPointer

            function pointerAngle(mouse) {
                var pointer = rotationPointer.mapToItem(root.parent, mouse.x, mouse.y);
                var centerX = root.x + root.width / 2;
                var centerY = root.y + root.height / 2;
                return Math.atan2(pointer.y - centerY, pointer.x - centerX) * 180 / Math.PI;
            }

            Accessible.name: qsTr("Rotate annotation")
            Accessible.role: Accessible.Button
            anchors.fill: parent
            anchors.margins: -8
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            preventStealing: true

            onCanceled: root.rotationCanceled()
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
                root.rotationRequested(nextRotation);
            }
            onPressed: mouse => {
                rotationHandle.startRotation = root.rotationAngle;
                rotationHandle.startPointerAngle = pointerAngle(mouse);
                root.rotationStarted();
            }
            onReleased: root.rotationFinished()
        }
    }
}
