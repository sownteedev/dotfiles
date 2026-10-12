import QtQuick

Item {
    id: root

    readonly property bool armed: dragging && !canceled && overlapsTarget
    property bool canceled: false
    default property alias content: surface.data
    property bool deletePending: false
    property bool dragHovered: false
    readonly property bool dragging: dragHandler.active
    property real dropDistance: 200
    property real dropOffsetX: 0
    property Item dropTarget: null
    property bool followingPointer: false
    property Item hitItem: surface
    readonly property bool hovered: mouse.containsMouse || dragHovered || deletePending
    property real lastPullDistance: 0
    property bool overlapsTarget: false
    readonly property real progress: Math.min(1, pullDistance / Math.max(1, dropDistance))
    readonly property real pullDistance: !canceled ? Math.min(lastPullDistance, Math.max(0, dropDistance)) : 0

    signal clicked
    signal dragFinished(bool accepted)
    signal dragStarted

    function cancelDrag() {
        followingPointer = false;
        dragHovered = false;
        canceled = true;
    }
    function finishDrag(accepted) {
        followingPointer = false;
        dragFinished(accepted);
        dragHovered = false;
        lastPullDistance = 0;
        overlapsTarget = false;
    }
    function intersectsDropTarget() {
        if (!dropTarget || !hitItem)
            return false;

        var corners = [hitItem.mapToItem(dropTarget, 0, 0), hitItem.mapToItem(dropTarget, hitItem.width, 0), hitItem.mapToItem(dropTarget, hitItem.width, hitItem.height), hitItem.mapToItem(dropTarget, 0, hitItem.height)];
        var centerX = dropTarget.width / 2;
        var centerY = dropTarget.height / 2;
        var radius = Math.min(dropTarget.width, dropTarget.height) / 2;
        var positiveSide = false;
        var negativeSide = false;
        for (var edge = 0; edge < corners.length; ++edge) {
            var start = corners[edge];
            var end = corners[(edge + 1) % corners.length];
            var deltaX = end.x - start.x;
            var deltaY = end.y - start.y;
            var lengthSquared = deltaX * deltaX + deltaY * deltaY;
            if (lengthSquared <= 0)
                return false;

            var projection = Math.max(0, Math.min(1, ((centerX - start.x) * deltaX + (centerY - start.y) * deltaY) / lengthSquared));
            var distanceX = start.x + projection * deltaX - centerX;
            var distanceY = start.y + projection * deltaY - centerY;
            if (distanceX * distanceX + distanceY * distanceY <= radius * radius)
                return true;

            var cross = deltaX * (centerY - start.y) - deltaY * (centerX - start.x);
            positiveSide = positiveSide || cross > 0;
            negativeSide = negativeSide || cross < 0;
        }
        return !(positiveSide && negativeSide);
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
                x: root.dropOffsetX * (root.deletePending ? 1 : root.progress)
                y: root.deletePending ? root.dropDistance : root.pullDistance

                Behavior on x {
                    enabled: !root.followingPointer

                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
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
                    root.dragHovered = true;
                    root.followingPointer = true;
                    root.canceled = false;
                    root.lastPullDistance = 0;
                    root.overlapsTarget = false;
                    root.dragStarted();
                }
            }
            onActiveTranslationChanged: {
                if (active && root.followingPointer) {
                    root.lastPullDistance = Math.max(0, root.mapFromItem(null, 0, activeTranslation.y).y - root.mapFromItem(null, 0, 0).y);
                    root.overlapsTarget = root.intersectsDropTarget();
                }
            }
            onGrabChanged: (transition, point) => {
                if (transition === PointerDevice.UngrabExclusive)
                    root.finishDrag(root.enabled && root.visible && !root.canceled && root.intersectsDropTarget());
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
