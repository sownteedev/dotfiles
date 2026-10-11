import QtQuick

Item {
    id: root

    readonly property bool armed: dragging && !canceled && pullDistance >= Math.max(48, dropDistance - 28)
    property bool canceled: false
    default property alias content: surface.data
    property bool deletePending: false
    readonly property bool dragging: dragHandler.active
    property real dropDistance: 200
    property bool followingPointer: false
    readonly property bool hovered: mouse.containsMouse
    property real lastPullDistance: 0
    readonly property real progress: Math.min(1, pullDistance / Math.max(1, dropDistance))
    readonly property real pullDistance: !canceled ? lastPullDistance : 0

    signal clicked
    signal dragFinished(bool accepted)
    signal dragStarted

    function cancelDrag() {
        followingPointer = false;
        canceled = true;
    }
    function finishDrag(accepted) {
        followingPointer = false;
        dragFinished(accepted);
        lastPullDistance = 0;
    }

    data: [
        Item {
            id: surface

            anchors.fill: parent
            opacity: root.deletePending ? 0 : 1
            scale: root.deletePending ? 0.05 : 1 - root.progress * 0.55

            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                }
            }
            Behavior on scale {
                enabled: !root.followingPointer

                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
            transform: Translate {
                y: root.deletePending ? root.dropDistance : root.pullDistance

                Behavior on y {
                    enabled: !root.followingPointer

                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }
        },
        MouseArea {
            id: mouse

            anchors.fill: parent
            cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: root.clicked()
        },
        DragHandler {
            id: dragHandler

            acceptedButtons: Qt.LeftButton
            dragThreshold: 12
            enabled: root.enabled && root.visible
            target: null
            xAxis.enabled: false
            yAxis.enabled: true

            onActiveChanged: {
                if (active) {
                    root.followingPointer = true;
                    root.canceled = false;
                    root.lastPullDistance = 0;
                    root.dragStarted();
                }
            }
            onActiveTranslationChanged: {
                if (active && root.followingPointer)
                    root.lastPullDistance = Math.max(0, root.mapFromItem(null, 0, activeTranslation.y).y - root.mapFromItem(null, 0, 0).y);
            }
            onGrabChanged: (transition, point) => {
                if (transition === PointerDevice.UngrabExclusive)
                    root.finishDrag(root.enabled && root.visible && !root.canceled && root.lastPullDistance >= Math.max(48, root.dropDistance - 28));
                else if (transition === PointerDevice.CancelGrabExclusive)
                    root.finishDrag(false);
            }
        }
    ]

    onEnabledChanged: {
        if (!enabled)
            cancelDrag();
    }
    onVisibleChanged: {
        if (!visible)
            cancelDrag();
    }
}
